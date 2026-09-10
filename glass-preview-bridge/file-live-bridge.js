/**
 * Radical Glass preview: write PNG + dead-simple HTML files to workspace.
 * Plan A: Glass opens file://.../live/market.html (meta refresh + img)
 * Plan B: http://127.0.0.1:8100/ and :8101/ serve same HTML+PNG (no JS)
 *
 * Critical: never block the capture loop on paint waits — open pages in
 * background and screenshot continuously (even during WASM boot).
 */
const http = require("http");
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const liveDir = path.join(__dirname, "live");
fs.mkdirSync(liveDir, { recursive: true });

const INTERVAL_MS = 2000;
const FREEZE_MS = 15000;

const targets = [
  {
    name: "market",
    flutterUrl: "http://127.0.0.1:8095/",
    bridgePort: 8100,
    pngFile: path.join(liveDir, "market.png"),
    htmlFile: path.join(liveDir, "market.html"),
    viewport: { width: 390, height: 844 },
  },
  {
    name: "admin",
    flutterUrl: "http://127.0.0.1:7400/",
    bridgePort: 8101,
    pngFile: path.join(liveDir, "admin.png"),
    htmlFile: path.join(liveDir, "admin.html"),
    viewport: { width: 390, height: 844 },
  },
];

const state = Object.fromEntries(
  targets.map((t) => [
    t.name,
    {
      png: null,
      n: 0,
      status: "starting",
      error: null,
      ready: false,
      lastAt: null,
      lastMs: 0,
      page: null,
      context: null,
      opening: false,
      captureBusy: false,
    },
  ])
);

let browser = null;

function writeStaticHtml(t) {
  const html = `<!DOCTYPE html><meta charset=utf-8>
<meta http-equiv="refresh" content="2">
<meta http-equiv="Cache-Control" content="no-store">
<title>امانة · ${t.name}</title>
<img src="${t.name}.png" style="width:100%;height:100%;object-fit:contain;background:#111;display:block;margin:0;border:0" alt="${t.name}">
`;
  fs.writeFileSync(t.htmlFile, html, "utf8");
}

function writePngAtomic(filePath, buf) {
  const tmp = filePath + ".tmp";
  fs.writeFileSync(tmp, buf);
  try {
    fs.renameSync(tmp, filePath);
  } catch (_) {
    fs.copyFileSync(tmp, filePath);
    try {
      fs.unlinkSync(tmp);
    } catch (__) {}
  }
}

function placeholderSvg(t, msg) {
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${t.viewport.width}" height="${t.viewport.height}">
      <rect width="100%" height="100%" fill="#111"/>
      <text x="50%" y="48%" fill="#eee" font-size="18" text-anchor="middle" font-family="Tahoma">امانة · ${t.name}</text>
      <text x="50%" y="54%" fill="#888" font-size="13" text-anchor="middle" font-family="Tahoma">${msg}</text>
    </svg>`
  );
}

function httpHtml(t) {
  const s = state[t.name];
  const ts = Date.now();
  return `<!DOCTYPE html><meta charset=utf-8>
<meta http-equiv="refresh" content="2">
<meta http-equiv="Cache-Control" content="no-store">
<title>امانة · ${t.name}</title>
<body style="margin:0;background:#111;color:#aaa;font-family:Tahoma,sans-serif">
<div style="padding:8px;font-size:12px">#${s.n} ${s.status} ${s.lastAt || ""}</div>
<img src="/live.png?ts=${ts}" style="width:100%;height:100%;object-fit:contain;background:#111;display:block" alt="${t.name}">
</body>`;
}

function listenPlanB(t) {
  http
    .createServer((req, res) => {
      const u = (req.url || "/").split("?")[0];
      const s = state[t.name];
      if (u === "/live.png" || u === "/frame.png") {
        if (!s.png) {
          res.writeHead(200, {
            "Content-Type": "image/svg+xml",
            "Cache-Control": "no-store",
          });
          res.end(placeholderSvg(t, s.status));
          return;
        }
        res.writeHead(200, {
          "Content-Type": "image/png",
          "Cache-Control": "no-store",
        });
        res.end(s.png);
        return;
      }
      if (u === "/health" || u === "/status.json") {
        const ageMs = s.lastMs ? Date.now() - s.lastMs : null;
        res.writeHead(200, {
          "Content-Type": "application/json",
          "Cache-Control": "no-store",
        });
        res.end(
          JSON.stringify({
            name: t.name,
            ok: true,
            hasFrame: !!s.png,
            firstFrameReady: s.ready,
            captureCount: s.n,
            frameAgeMs: ageMs,
            lastCaptureAt: s.lastAt,
            status: s.status,
            error: s.error,
            bytes: s.png ? s.png.length : 0,
            livePng: t.pngFile,
            liveHtml: t.htmlFile,
          })
        );
        return;
      }
      res.writeHead(200, {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
      });
      res.end(httpHtml(t));
    })
    .listen(t.bridgePort, "127.0.0.1", () => {
      console.log(
        `[file-live] PlanB http://127.0.0.1:${t.bridgePort}/ <- ${t.flutterUrl}`
      );
      console.log(`[file-live] PlanA file: ${t.htmlFile}`);
    });
}

async function checkPaint(page) {
  return page.evaluate(() => {
    const boot = document.getElementById("amana-boot");
    const glass = document.querySelector("flt-glass-pane");
    const c =
      (glass && glass.shadowRoot && glass.shadowRoot.querySelector("canvas")) ||
      document.querySelector("canvas");
    return {
      ff: !!window.__amanaFirstFrame,
      boot: !!boot,
      canvas: !!c,
    };
  });
}

async function openPage(t) {
  const s = state[t.name];
  if (!browser || s.opening) return;
  s.opening = true;
  try {
    if (s.context) {
      try {
        await s.context.close();
      } catch (_) {}
      s.context = null;
      s.page = null;
    }
    s.status = "navigating";
    s.context = await browser.newContext({
      viewport: t.viewport,
      deviceScaleFactor: 1,
    });
    s.page = await s.context.newPage();
    await s.page.goto(t.flutterUrl, {
      waitUntil: "domcontentloaded",
      timeout: 60000,
    });
    await s.page.evaluate(() => {
      window.__amanaFirstFrame = false;
      window.addEventListener("flutter-first-frame", () => {
        window.__amanaFirstFrame = true;
      });
    });
    s.status = "loaded-capturing";
    s.error = null;
  } catch (e) {
    s.error = e.message;
    s.status = "open-failed";
    console.error(`[file-live] ${t.name} open failed:`, e.message);
  } finally {
    s.opening = false;
  }
}

async function captureOne(t) {
  const s = state[t.name];
  if (!s.page || s.captureBusy) return;
  s.captureBusy = true;
  try {
    try {
      const st = await checkPaint(s.page);
      if (st.ff || st.canvas) {
        s.ready = true;
        s.status = st.ff ? "flutter-first-frame" : "canvas-detected";
      } else {
        s.status = `booting canvas=${st.canvas} boot=${st.boot}`;
      }
    } catch (_) {}

    const buf = await s.page.screenshot({ type: "png", timeout: 10000 });
    s.png = buf;
    s.n += 1;
    s.lastMs = Date.now();
    s.lastAt = new Date(s.lastMs).toISOString();
    s.error = null;
    writePngAtomic(t.pngFile, buf);
    writeStaticHtml(t);
    if (s.n === 1 || s.n % 10 === 0) {
      console.log(
        `[file-live] ${t.name} #${s.n} ${buf.length}b -> ${path.basename(t.pngFile)} (${s.status})`
      );
    }
  } catch (e) {
    s.error = e.message;
    s.status = "capture-error";
    console.error(`[file-live] ${t.name} capture error:`, e.message);
  } finally {
    s.captureBusy = false;
  }
}

async function tick() {
  for (const t of targets) {
    const s = state[t.name];
    if (!s.page && !s.opening && browser) {
      // fire-and-forget open; don't await in tick
      openPage(t);
      continue;
    }
    await captureOne(t);
  }
}

async function freezeWatch() {
  for (const t of targets) {
    const s = state[t.name];
    if (!browser || s.opening) continue;
    const age = s.lastMs ? Date.now() - s.lastMs : Infinity;
    if (age > FREEZE_MS) {
      console.warn(
        `[file-live] ${t.name} frozen ${Math.round(age / 1000)}s — restarting page`
      );
      s.status = "restarting-frozen";
      await openPage(t);
    }
  }
}

async function main() {
  for (const t of targets) {
    writeStaticHtml(t);
    if (!fs.existsSync(t.pngFile)) {
      const tiny = Buffer.from(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
        "base64"
      );
      writePngAtomic(t.pngFile, tiny);
    }
    listenPlanB(t);
  }

  try {
    console.log("[file-live] launching playwright-chromium…");
    browser = await chromium.launch({
      headless: true,
      args: [
        "--disable-dev-shm-usage",
        "--no-sandbox",
        "--enable-webgl",
        "--ignore-gpu-blocklist",
      ],
    });
    console.log("[file-live] playwright-chromium OK");
  } catch (e) {
    console.error("[file-live] browser launch failed:", e.message);
    for (const t of targets) {
      state[t.name].error = e.message;
      state[t.name].status = "browser-launch-failed";
    }
    return;
  }

  // Open both in parallel — do NOT await paint
  await Promise.all(targets.map((t) => openPage(t)));

  // Immediate first shots, then continuous loop
  await tick();
  setInterval(() => {
    tick().catch((e) => console.error("[file-live] tick", e.message));
  }, INTERVAL_MS);
  setInterval(() => {
    freezeWatch().catch((e) => console.error("[file-live] freeze", e.message));
  }, 5000);

  console.log("[file-live] OPEN Plan A (preferred):");
  console.log(
    "  file:///C:/Users/Administrator.user-HP/AndroidStudioProjects/amana/glass-preview-bridge/live/market.html"
  );
  console.log(
    "  file:///C:/Users/Administrator.user-HP/AndroidStudioProjects/amana/glass-preview-bridge/live/admin.html"
  );
  console.log(
    "[file-live] OPEN Plan B fallback: http://127.0.0.1:8100/  http://127.0.0.1:8101/"
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
