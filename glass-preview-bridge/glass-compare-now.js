/**
 * Capture what a real Chromium sees on market :8095 vs admin :7400.
 * Not curl. Console + failed network + first-frame + screenshot.
 */
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const evidenceDir = path.join(__dirname, "evidence");
fs.mkdirSync(evidenceDir, { recursive: true });

const targets = [
  { name: "market", url: "http://127.0.0.1:8095/" },
  { name: "admin", url: "http://127.0.0.1:7400/" },
];

async function probe(t, extraArgs = []) {
  const consoleLines = [];
  const pageErrors = [];
  const failed = [];
  const requests = [];
  const responses = [];

  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.CHROME_PATH,
    args: ["--disable-dev-shm-usage", "--no-sandbox", ...extraArgs],
  });
  const context = await browser.newContext({
    viewport: { width: 420, height: 800 },
    serviceWorkers: "block",
  });
  const page = await context.newPage();

  page.on("console", (msg) => {
    consoleLines.push(`[${msg.type()}] ${msg.text()}`);
  });
  page.on("pageerror", (err) => pageErrors.push(String(err)));
  page.on("requestfailed", (req) => {
    failed.push({
      url: req.url(),
      method: req.method(),
      failure: req.failure() && req.failure().errorText,
      resourceType: req.resourceType(),
    });
  });
  page.on("request", (req) => {
    requests.push({
      t: Date.now(),
      url: req.url(),
      method: req.method(),
      resourceType: req.resourceType(),
    });
  });
  page.on("response", (res) => {
    responses.push({
      t: Date.now(),
      url: res.url(),
      status: res.status(),
      contentType: (res.headers()["content-type"] || "").slice(0, 80),
      headers: {
        csp: res.headers()["content-security-policy"] || null,
        xfo: res.headers()["x-frame-options"] || null,
        coop: res.headers()["cross-origin-opener-policy"] || null,
        coep: res.headers()["cross-origin-embedder-policy"] || null,
        corp: res.headers()["cross-origin-resource-policy"] || null,
        mime: res.headers()["content-type"] || null,
      },
    });
  });

  let navError = null;
  const started = Date.now();
  try {
    await page.goto(t.url, { waitUntil: "domcontentloaded", timeout: 20000 });
  } catch (e) {
    navError = String(e.message || e);
  }

  // Wait for Flutter first frame or timeout
  let firstFrame = false;
  try {
    await page.waitForFunction(
      () =>
        !!(
          window._flutter &&
          (document.querySelector("flt-glass-pane") ||
            document.querySelector("flutter-view") ||
            document.querySelector("flt-scene-host"))
        ),
      { timeout: 25000 }
    );
    firstFrame = true;
  } catch (_) {}

  await page.waitForTimeout(4000);

  const state = await page.evaluate(() => {
    const boot = document.getElementById("amana-boot");
    const glass = document.querySelector("flt-glass-pane");
    const canvas =
      (glass && glass.shadowRoot && glass.shadowRoot.querySelector("canvas")) ||
      document.querySelector("flutter-view canvas") ||
      document.querySelector("canvas");
    return {
      title: document.title,
      href: location.href,
      bootPresent: !!boot,
      bootText: boot ? boot.innerText.slice(0, 300) : null,
      flutterView: !!document.querySelector("flutter-view"),
      fltGlass: !!glass,
      fltScene: !!document.querySelector("flt-scene-host"),
      canvas: !!canvas,
      canvasW: canvas ? canvas.width : 0,
      canvasH: canvas ? canvas.height : 0,
      bodyText: (document.body && document.body.innerText || "").slice(0, 400),
      swController: !!(navigator.serviceWorker && navigator.serviceWorker.controller),
    };
  });

  const shot = path.join(evidenceDir, `LIVE-${t.name}.png`);
  await page.screenshot({ path: shot, type: "png" });

  await browser.close();
  return {
    name: t.name,
    url: t.url,
    extraArgs,
    navError,
    firstFrameDom: firstFrame,
    elapsedMs: Date.now() - started,
    state,
    pageErrors,
    failed,
    console: consoleLines,
    badStatus: responses.filter((r) => r.status >= 400),
    responses: responses.map((r) => ({
      status: r.status,
      url: r.url,
      mime: r.headers.mime,
      xfo: r.headers.xfo,
      csp: r.headers.csp,
      coop: r.headers.coop,
      coep: r.headers.coep,
      corp: r.headers.corp,
    })),
    shot,
  };
}

(async () => {
  const results = [];
  for (const t of targets) {
    console.log("PROBE", t.url);
    results.push(await probe(t));
  }

  // Admin inside iframe (Glass-like embed)
  console.log("PROBE admin-in-iframe");
  const browser = await chromium.launch({
    headless: true,
    executablePath: process.env.CHROME_PATH,
    args: ["--disable-dev-shm-usage", "--no-sandbox"],
  });
  const context = await browser.newContext({ viewport: { width: 420, height: 800 } });
  const page = await context.newPage();
  const iframeFailed = [];
  const iframeConsole = [];
  const iframeErrors = [];
  page.on("console", (m) => iframeConsole.push(`[${m.type()}] ${m.text()}`));
  page.on("pageerror", (e) => iframeErrors.push(String(e)));
  page.on("requestfailed", (req) =>
    iframeFailed.push({ url: req.url(), failure: req.failure() && req.failure().errorText })
  );
  await page.setContent(
    `<!doctype html><iframe src="http://127.0.0.1:7400/" style="width:100%;height:100%;border:0"></iframe>`,
    { waitUntil: "domcontentloaded" }
  );
  await page.waitForTimeout(20000);
  let iframeState = null;
  try {
    const frame = page.frames().find((f) => f.url().includes("7400"));
    if (frame) {
      iframeState = await frame.evaluate(() => ({
        title: document.title,
        boot: !!document.getElementById("amana-boot"),
        flutterView: !!document.querySelector("flutter-view"),
        fltGlass: !!document.querySelector("flt-glass-pane"),
        body: (document.body && document.body.innerText || "").slice(0, 300),
      }));
    }
  } catch (e) {
    iframeState = { evaluateError: String(e.message || e) };
  }
  const iframeShot = path.join(evidenceDir, "LIVE-admin-iframe.png");
  await page.screenshot({ path: iframeShot, type: "png" });
  await browser.close();

  const out = {
    at: new Date().toISOString(),
    results,
    iframe: { iframeState, iframeFailed, iframeConsole, iframeErrors, iframeShot },
  };
  const outPath = path.join(evidenceDir, "LIVE-compare.json");
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log("WROTE", outPath);
  for (const r of results) {
    console.log(
      JSON.stringify(
        {
          name: r.name,
          navError: r.navError,
          firstFrameDom: r.firstFrameDom,
          elapsedMs: r.elapsedMs,
          state: r.state,
          pageErrors: r.pageErrors,
          failed: r.failed,
          badStatus: r.badStatus,
          consoleTail: r.console.slice(-20),
        },
        null,
        2
      )
    );
  }
  console.log("IFRAME", JSON.stringify({ iframeState, iframeFailed, iframeErrors }, null, 2));
})().catch((e) => {
  console.error("FATAL", e);
  process.exit(1);
});
