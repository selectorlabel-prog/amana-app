/**
 * Glass Preview Bridge
 * Loads Flutter web in real Chromium (Playwright), waits for a painted frame,
 * then serves plain HTML + PNG screenshots that Cursor Glass can render.
 *
 *   node server.js --name market --flutter-port 8095 --bridge-port 8100
 *   node server.js --name admin  --flutter-port 7400 --bridge-port 8101
 */

const http = require("http");
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

function parseArgs(argv) {
  const out = {
    name: "preview",
    flutterHost: "127.0.0.1",
    flutterPort: 8095,
    bridgePort: 8100,
    intervalMs: 1500,
    viewportW: 390,
    viewportH: 844,
    firstFrameTimeoutMs: 180000,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    const next = argv[i + 1];
    if (a === "--name" && next) {
      out.name = next;
      i++;
    } else if (a === "--flutter-host" && next) {
      out.flutterHost = next;
      i++;
    } else if (a === "--flutter-port" && next) {
      out.flutterPort = Number(next);
      i++;
    } else if (a === "--bridge-port" && next) {
      out.bridgePort = Number(next);
      i++;
    } else if (a === "--interval" && next) {
      out.intervalMs = Number(next);
      i++;
    }
  }
  return out;
}

const cfg = parseArgs(process.argv);
const flutterUrl = `http://${cfg.flutterHost}:${cfg.flutterPort}`;
const evidenceDir = path.join(__dirname, "evidence");
fs.mkdirSync(evidenceDir, { recursive: true });

let latestPng = null;
let lastCaptureAt = null;
let lastError = null;
let lastStatus = "starting";
let captureCount = 0;
let page = null;
let browser = null;
let capturing = false;
let firstFrameReady = false;

function htmlPage() {
  const status = lastError
    ? `ERROR: ${lastError}`
    : lastCaptureAt
      ? `Live · frame #${captureCount} · ${lastStatus} · ${lastCaptureAt}`
      : `Waiting… ${lastStatus}`;
  const title = `أمانة · ${cfg.name} preview bridge`;
  return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title}</title>
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    body {
      margin: 0; font-family: "Segoe UI", Tahoma, sans-serif;
      background: #0f1419; color: #e7ecf1; min-height: 100vh;
    }
    header {
      padding: 10px 14px; border-bottom: 1px solid #243041;
      display: flex; flex-wrap: wrap; gap: 8px 16px; align-items: baseline;
      background: #151b24;
    }
    h1 { font-size: 15px; margin: 0; font-weight: 600; }
    .meta { font-size: 12px; color: #9aa8b8; }
    .ok { color: #6ddea8; }
    .err { color: #ff8f8f; }
    main { display: flex; justify-content: center; padding: 12px; }
    .frame {
      position: relative;
      width: min(100%, ${cfg.viewportW}px);
      background: #000;
      border: 1px solid #2a3648;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 8px 28px rgba(0,0,0,.35);
    }
    img {
      display: block; width: 100%; height: auto;
      background: #111; min-height: 200px;
    }
    .hint {
      padding: 8px 12px; font-size: 11px; color: #8b9aab;
      border-top: 1px solid #243041; background: #121820;
    }
    a { color: #7eb6ff; }
  </style>
</head>
<body>
  <header>
    <h1>${title}</h1>
    <span class="meta ${lastError ? "err" : "ok"}" id="status">${status}</span>
    <span class="meta">مصدر Flutter: <a href="${flutterUrl}">${flutterUrl}</a></span>
  </header>
  <main>
    <div class="frame">
      <img id="shot" src="/frame.png?t=${Date.now()}" alt="Flutter preview frame" />
      <div class="hint">
        HTML عادي بدون Flutter/WASM — يعمل في لوحة Cursor الجانبية.
        لقطة حية كل ~${Math.round(cfg.intervalMs / 1000)}ث من Chromium الحقيقي.
        للتفاعل الكامل لاحقاً: ${flutterUrl}
      </div>
    </div>
  </main>
  <script>
    const img = document.getElementById("shot");
    const statusEl = document.getElementById("status");
    async function tick() {
      try {
        const r = await fetch("/status.json", { cache: "no-store" });
        const j = await r.json();
        statusEl.textContent = j.error
          ? ("ERROR: " + j.error)
          : ("Live · frame #" + j.captureCount + " · " + (j.status || "") + " · " + (j.lastCaptureAt || "…"));
        statusEl.className = "meta " + (j.error ? "err" : "ok");
        if (j.hasFrame) img.src = "/frame.png?t=" + Date.now();
      } catch (e) {
        statusEl.textContent = "bridge unreachable";
        statusEl.className = "meta err";
      }
    }
    setInterval(tick, ${Math.max(800, Math.floor(cfg.intervalMs / 2))});
    tick();
  </script>
</body>
</html>`;
}

async function pageHasFlutterPaint(p) {
  return p.evaluate(() => {
    const boot = document.getElementById("amana-boot");
    const glass = document.querySelector("flt-glass-pane");
    const shadowCanvas =
      glass && glass.shadowRoot && glass.shadowRoot.querySelector("canvas");
    const anyCanvas =
      shadowCanvas ||
      document.querySelector("flt-scene-host") ||
      document.querySelector("flutter-view canvas") ||
      document.querySelector("canvas");
    const firstFrame =
      window.__amanaFirstFrame === true ||
      document.documentElement.getAttribute("data-flutter-first-frame") === "true";
    return {
      bootGone: !boot,
      hasCanvas: !!anyCanvas,
      firstFrame,
      title: document.title || "",
      bodyText: (document.body && document.body.innerText || "").slice(0, 120),
    };
  });
}

async function waitForPaint(p) {
  lastStatus = "waiting-for-flutter-paint";
  const started = Date.now();
  // Listen for flutter-first-frame
  await p.evaluate(() => {
    window.__amanaFirstFrame = false;
    window.addEventListener("flutter-first-frame", () => {
      window.__amanaFirstFrame = true;
    });
  });

  while (Date.now() - started < cfg.firstFrameTimeoutMs) {
    const state = await pageHasFlutterPaint(p);
    if (state.firstFrame || (state.bootGone && state.hasCanvas) || state.hasCanvas) {
      // Extra settle so first meaningful UI paints
      await p.waitForTimeout(1500);
      firstFrameReady = true;
      lastStatus = state.firstFrame
        ? "flutter-first-frame"
        : state.bootGone
          ? "boot-gone+canvas"
          : "canvas-detected";
      return state;
    }
    lastStatus = `loading ${Math.round((Date.now() - started) / 1000)}s · boot=${!state.bootGone} canvas=${state.hasCanvas}`;
    await p.waitForTimeout(2000);
  }
  const finalState = await pageHasFlutterPaint(p);
  lastStatus = "timeout-capturing-anyway";
  return finalState;
}

async function ensureBrowser() {
  if (browser && page) return;
  lastStatus = "launching-chromium";
  // Prefer Playwright bundled Chromium — system Chrome often crashes under
  // concurrent headless launches on this machine ("browser has been closed").
  const launchOpts = {
    headless: true,
    args: [
      "--disable-dev-shm-usage",
      "--no-sandbox",
      "--disable-gpu-sandbox",
      "--enable-webgl",
      "--ignore-gpu-blocklist",
      "--use-gl=angle",
      "--use-angle=swiftshader-webgl",
      "--font-render-hinting=none",
    ],
  };
  if (process.env.CHROME_PATH && fs.existsSync(process.env.CHROME_PATH)) {
    launchOpts.executablePath = process.env.CHROME_PATH;
  }
  try {
    browser = await chromium.launch(launchOpts);
  } catch (e1) {
    lastStatus = "launch-fallback-chrome";
    browser = await chromium.launch({
      ...launchOpts,
      channel: "chrome",
      executablePath: undefined,
    });
  }
  const context = await browser.newContext({
    viewport: { width: cfg.viewportW, height: cfg.viewportH },
    deviceScaleFactor: 1,
  });
  page = await context.newPage();
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      lastError = `console: ${msg.text()}`.slice(0, 240);
    }
  });
  page.on("pageerror", (err) => {
    lastError = `pageerror: ${err.message}`.slice(0, 240);
  });
  lastStatus = "navigating";
  await page.goto(flutterUrl, { waitUntil: "domcontentloaded", timeout: 90000 });
  // Give CanvasKit WASM a moment to compile before paint polling
  await page.waitForTimeout(2500);
  await waitForPaint(page);
}

async function captureOnce() {
  if (capturing) return;
  capturing = true;
  try {
    await ensureBrowser();
    try {
      await page.evaluate(() => document.title);
    } catch {
      page = null;
      browser = null;
      firstFrameReady = false;
      await ensureBrowser();
    }
    // If still on boot splash after long wait, keep capturing (honest evidence)
    const buf = await page.screenshot({ type: "png", fullPage: false });
    latestPng = buf;
    lastCaptureAt = new Date().toISOString();
    captureCount += 1;
    // Clear launch/console noise once we have real painted frames
    if (firstFrameReady && latestPng) lastError = null;
    if (captureCount === 1 || captureCount % 8 === 0) {
      const dest = path.join(
        evidenceDir,
        `${cfg.name}-frame-${captureCount}${firstFrameReady ? "-painted" : "-boot"}.png`
      );
      fs.writeFileSync(dest, buf);
      console.log(`[bridge:${cfg.name}] saved ${dest} (${buf.length} bytes) status=${lastStatus}`);
    }
  } catch (e) {
    lastError = String(e && e.message ? e.message : e).slice(0, 300);
    lastStatus = "capture-error";
    try {
      if (browser) await browser.close();
    } catch (_) {}
    browser = null;
    page = null;
    firstFrameReady = false;
  } finally {
    capturing = false;
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://127.0.0.1:${cfg.bridgePort}`);

  if (url.pathname === "/frame.png") {
    if (!latestPng) {
      // Placeholder SVG so Glass never shows pure empty white while waiting
      const svg = Buffer.from(
        `<svg xmlns="http://www.w3.org/2000/svg" width="390" height="844">
          <rect width="100%" height="100%" fill="#0f1419"/>
          <text x="50%" y="46%" fill="#e7ecf1" font-size="18" text-anchor="middle" font-family="Tahoma">أمانة · ${cfg.name}</text>
          <text x="50%" y="52%" fill="#9aa8b8" font-size="13" text-anchor="middle" font-family="Tahoma">${lastStatus}</text>
        </svg>`
      );
      res.writeHead(200, {
        "Content-Type": "image/svg+xml; charset=utf-8",
        "Cache-Control": "no-store",
      });
      res.end(svg);
      return;
    }
    res.writeHead(200, {
      "Content-Type": "image/png",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    });
    res.end(latestPng);
    return;
  }

  if (url.pathname === "/status.json") {
    res.writeHead(200, {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    });
    res.end(
      JSON.stringify({
        name: cfg.name,
        flutterUrl,
        bridgePort: cfg.bridgePort,
        hasFrame: Boolean(latestPng),
        firstFrameReady,
        captureCount,
        lastCaptureAt,
        status: lastStatus,
        error: lastError,
        bytes: latestPng ? latestPng.length : 0,
      })
    );
    return;
  }

  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        ok: true,
        hasFrame: Boolean(latestPng),
        firstFrameReady,
      })
    );
    return;
  }

  res.writeHead(200, {
    "Content-Type": "text/html; charset=utf-8",
    "Cache-Control": "no-store",
  });
  res.end(htmlPage());
});

async function main() {
  console.log(`[bridge:${cfg.name}] Flutter source: ${flutterUrl}`);
  console.log(`[bridge:${cfg.name}] Glass URL:      http://127.0.0.1:${cfg.bridgePort}/`);
  server.listen(cfg.bridgePort, "127.0.0.1", () => {
    console.log(`[bridge:${cfg.name}] listening on 127.0.0.1:${cfg.bridgePort}`);
  });
  // Kick capture without blocking listen
  captureOnce().then(() => {
    setInterval(captureOnce, cfg.intervalMs);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
