/**
 * Prove Flutter-in-Simple-Browser failure mode vs Chromium paint.
 * Saves console dump + screenshots under ./evidence
 */
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");
const http = require("http");

const targets = [
  { name: "market", url: "http://127.0.0.1:8095/" },
  { name: "admin", url: "http://127.0.0.1:7400/" },
];

const evidenceDir = path.join(__dirname, "evidence");
fs.mkdirSync(evidenceDir, { recursive: true });

function httpProbe(url) {
  return new Promise((resolve) => {
    const req = http.get(url, { timeout: 5000 }, (res) => {
      let body = "";
      res.on("data", (c) => (body += c));
      res.on("end", () =>
        resolve({ ok: true, status: res.statusCode, len: body.length, sample: body.slice(0, 200) })
      );
    });
    req.on("error", (e) => resolve({ ok: false, error: String(e.message || e) }));
    req.on("timeout", () => {
      req.destroy();
      resolve({ ok: false, error: "timeout" });
    });
  });
}

function isMostlyWhite(pngBuffer) {
  // Heuristic: PNG with high size variance usually has UI; tiny/near-empty often white.
  // Use pixel sampling via raw decode is heavy; instead compare file size + note for human.
  return { bytes: pngBuffer.length, note: "inspect PNG visually; white CanvasKit fail often still >10KB" };
}

async function captureTarget(t) {
  const consoleLines = [];
  const pageErrors = [];
  const probe = await httpProbe(t.url);
  const browser = await chromium.launch({
    headless: true,
    args: ["--disable-dev-shm-usage", "--no-sandbox"],
  });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const page = await context.newPage();
  page.on("console", (msg) => {
    consoleLines.push(`[${msg.type()}] ${msg.text()}`);
  });
  page.on("pageerror", (err) => pageErrors.push(String(err)));

  let navError = null;
  try {
    await page.goto(t.url, { waitUntil: "networkidle", timeout: 45000 });
  } catch (e) {
    navError = String(e.message || e);
    try {
      await page.goto(t.url, { waitUntil: "domcontentloaded", timeout: 30000 });
    } catch (e2) {
      navError = String(e2.message || e2);
    }
  }
  await page.waitForTimeout(4000);
  const shotPath = path.join(evidenceDir, `prove-${t.name}-chromium.png`);
  const buf = await page.screenshot({ type: "png", fullPage: false });
  fs.writeFileSync(shotPath, buf);

  // Simulate "Glass-like" limited GPU: force CPU via flag in second browser
  let cpuShot = null;
  try {
    const browserCpu = await chromium.launch({
      headless: true,
      args: [
        "--disable-dev-shm-usage",
        "--no-sandbox",
        "--disable-gpu",
        "--use-gl=swiftshader",
      ],
    });
    const ctx2 = await browserCpu.newContext({ viewport: { width: 390, height: 844 } });
    const p2 = await ctx2.newPage();
    const cpuConsole = [];
    p2.on("console", (m) => cpuConsole.push(`[${m.type()}] ${m.text()}`));
    await p2.goto(t.url, { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => {});
    await p2.waitForTimeout(4000);
    cpuShot = path.join(evidenceDir, `prove-${t.name}-swiftshader.png`);
    fs.writeFileSync(cpuShot, await p2.screenshot({ type: "png" }));
    fs.writeFileSync(
      path.join(evidenceDir, `prove-${t.name}-swiftshader-console.txt`),
      cpuConsole.join("\n")
    );
    await browserCpu.close();
  } catch (e) {
    cpuShot = `failed: ${e.message}`;
  }

  const report = {
    name: t.name,
    url: t.url,
    httpProbe: probe,
    navError,
    consoleSample: consoleLines.slice(0, 80),
    pageErrors,
    chromiumShot: shotPath,
    chromiumBytes: buf.length,
    whiteHeuristic: isMostlyWhite(buf),
    swiftshaderShot: cpuShot,
    glassNote:
      "Cursor Glass Simple Browser often fails CanvasKit/WASM (blank white) even when HTTP 200. " +
      "Chromium (Playwright) below is the engine that CAN paint; bridge serves PNG HTML to Glass.",
  };
  fs.writeFileSync(
    path.join(evidenceDir, `prove-${t.name}-report.json`),
    JSON.stringify(report, null, 2)
  );
  fs.writeFileSync(
    path.join(evidenceDir, `prove-${t.name}-console.txt`),
    consoleLines.join("\n") + "\n\nPAGE ERRORS:\n" + pageErrors.join("\n")
  );
  await browser.close();
  return report;
}

(async () => {
  const results = [];
  for (const t of targets) {
    console.log("Proving", t.url);
    try {
      results.push(await captureTarget(t));
    } catch (e) {
      results.push({ name: t.name, url: t.url, fatal: String(e.message || e) });
    }
  }
  const summaryPath = path.join(evidenceDir, "prove-summary.json");
  fs.writeFileSync(summaryPath, JSON.stringify(results, null, 2));
  console.log("Wrote", summaryPath);
  console.log(JSON.stringify(results.map((r) => ({
    name: r.name,
    http: r.httpProbe && r.httpProbe.status,
    bytes: r.chromiumBytes,
    errors: (r.pageErrors || []).length,
    fatal: r.fatal,
  })), null, 2));
})();
