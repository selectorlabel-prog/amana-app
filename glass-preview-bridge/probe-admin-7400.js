const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const chrome = process.env.CHROME_PATH;
const outDir = path.join(__dirname, "evidence");
const userData = path.join(outDir, "pw-ud-" + Date.now());
fs.mkdirSync(userData, { recursive: true });

(async () => {
  const context = await chromium.launchPersistentContext(userData, {
    executablePath: chrome,
    headless: true,
    viewport: { width: 420, height: 800 },
    serviceWorkers: "block",
    args: ["--disable-dev-shm-usage", "--no-sandbox"],
  });
  const page = context.pages()[0] || (await context.newPage());
  const consoleLines = [];
  const pageErrors = [];
  const failed = [];
  page.on("console", (m) => consoleLines.push(`[${m.type()}] ${m.text()}`));
  page.on("pageerror", (e) => pageErrors.push(String(e)));
  page.on("requestfailed", (r) =>
    failed.push({ url: r.url(), err: r.failure() && r.failure().errorText })
  );

  await page.goto("http://127.0.0.1:7400/", {
    waitUntil: "domcontentloaded",
    timeout: 20000,
  });
  let mounted = false;
  try {
    await page.waitForFunction(
      () =>
        !!(
          document.querySelector("flt-glass-pane") ||
          document.querySelector("flutter-view")
        ),
      { timeout: 40000 }
    );
    mounted = true;
  } catch (_) {}
  await page.waitForTimeout(3000);
  const state = await page.evaluate(() => ({
    title: document.title,
    boot: !!document.getElementById("amana-boot"),
    flutterView: !!document.querySelector("flutter-view"),
    fltGlass: !!document.querySelector("flt-glass-pane"),
    body: (document.body && document.body.innerText || "").slice(0, 400),
  }));
  const shot = path.join(outDir, "LIVE-admin-fixed.png");
  await page.screenshot({ path: shot });
  await context.close();
  const report = { mounted, state, pageErrors, failed, console: consoleLines, shot };
  fs.writeFileSync(path.join(outDir, "LIVE-admin-fixed.json"), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
})().catch((e) => {
  console.error("FATAL", e);
  process.exit(1);
});
