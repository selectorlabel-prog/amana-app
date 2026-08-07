/**
 * Single Chromium process → two Glass-safe preview ports.
 * Market :8100  Admin :8101
 * Plain HTML + PNG only (no Flutter/WASM in Glass).
 */
const http = require("http");
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const evidenceDir = path.join(__dirname, "evidence");
fs.mkdirSync(evidenceDir, { recursive: true });

const targets = [
  {
    name: "market",
    flutterUrl: "http://127.0.0.1:8095/",
    bridgePort: 8100,
    viewport: { width: 390, height: 844 },
  },
  {
    name: "admin",
    flutterUrl: "http://127.0.0.1:7400/",
    bridgePort: 8101,
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
      page: null,
    },
  ])
);

function htmlPage(t) {
  const s = state[t.name];
  return `<!DOCTYPE html>
<html lang="ar" dir="rtl"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>أمانة · ${t.name}</title>
<style>
body{margin:0;background:#0f1419;color:#e7ecf1;font-family:Tahoma,sans-serif}
header{padding:10px 14px;border-bottom:1px solid #243041;background:#151b24;font-size:13px}
img{display:block;width:min(100%,${t.viewport.width}px);margin:12px auto;background:#111;min-height:200px;border:1px solid #2a3648;border-radius:8px}
.meta{color:#9aa8b8;font-size:12px;margin-top:4px}
.ok{color:#6ddea8}.err{color:#ff8f8f}
</style></head><body>
<header>
  <div>أمانة · معاينة ${t.name} (HTML+صورة — بدون Flutter في Glass)</div>
  <div class="meta" id="st">${s.status}</div>
</header>
<img id="i" src="/frame.png?t=0" alt="preview"/>
<script>
async function tick(){
  try{
    const j=await(await fetch('/status.json',{cache:'no-store'})).json();
    const el=document.getElementById('st');
    el.textContent=(j.error?('ERROR: '+j.error):('Live #'+j.captureCount+' · '+j.status+' · '+(j.lastCaptureAt||'')));
    el.className='meta '+(j.error?'err':'ok');
    if(j.hasFrame) document.getElementById('i').src='/frame.png?t='+Date.now();
  }catch(e){}
}
setInterval(tick,1000);tick();
</script></body></html>`;
}

function listen(t) {
  http
    .createServer((req, res) => {
      const u = (req.url || "/").split("?")[0];
      const s = state[t.name];
      if (u === "/frame.png") {
        if (!s.png) {
          const svg = Buffer.from(
            `<svg xmlns="http://www.w3.org/2000/svg" width="${t.viewport.width}" height="${t.viewport.height}">
              <rect width="100%" height="100%" fill="#0f1419"/>
              <text x="50%" y="46%" fill="#e7ecf1" font-size="18" text-anchor="middle" font-family="Tahoma">أمانة · ${t.name}</text>
              <text x="50%" y="52%" fill="#9aa8b8" font-size="13" text-anchor="middle" font-family="Tahoma">${s.status}</text>
            </svg>`
          );
          res.writeHead(200, { "Content-Type": "image/svg+xml", "Cache-Control": "no-store" });
          res.end(svg);
          return;
        }
        res.writeHead(200, { "Content-Type": "image/png", "Cache-Control": "no-store" });
        res.end(s.png);
        return;
      }
      if (u === "/status.json" || u === "/health") {
        res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
        res.end(
          JSON.stringify({
            name: t.name,
            flutterUrl: t.flutterUrl,
            bridgePort: t.bridgePort,
            hasFrame: !!s.png,
            firstFrameReady: s.ready,
            captureCount: s.n,
            lastCaptureAt: s.lastAt,
            status: s.status,
            error: s.error,
            bytes: s.png ? s.png.length : 0,
          })
        );
        return;
      }
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
      res.end(htmlPage(t));
    })
    .listen(t.bridgePort, "127.0.0.1", () => {
      console.log(`[dual] Glass http://127.0.0.1:${t.bridgePort}/ <- ${t.flutterUrl}`);
    });
}

async function waitPaint(page, s) {
  await page.evaluate(() => {
    window.__amanaFirstFrame = false;
    window.addEventListener("flutter-first-frame", () => {
      window.__amanaFirstFrame = true;
    });
  });
  const started = Date.now();
  while (Date.now() - started < 180000) {
    const st = await page.evaluate(() => {
      const boot = document.getElementById("amana-boot");
      const glass = document.querySelector("flt-glass-pane");
      const c =
        (glass && glass.shadowRoot && glass.shadowRoot.querySelector("canvas")) ||
        document.querySelector("canvas");
      return { ff: !!window.__amanaFirstFrame, boot: !!boot, canvas: !!c };
    });
    s.status = `wait paint ff=${st.ff} canvas=${st.canvas} boot=${st.boot}`;
    if (st.ff || (st.canvas && !st.boot) || st.canvas) {
      await page.waitForTimeout(2000);
      s.ready = true;
      s.status = st.ff ? "flutter-first-frame" : "canvas-detected";
      return;
    }
    await page.waitForTimeout(2000);
  }
  s.status = "timeout-capturing-anyway";
}

async function main() {
  for (const t of targets) listen(t);

  // Prefer Playwright Chromium (bundled) — more stable than system Chrome when two apps run
  let browser;
  const launchAttempts = [
    {
      label: "playwright-chromium",
      opts: {
        headless: true,
        args: ["--disable-dev-shm-usage", "--no-sandbox", "--enable-webgl", "--ignore-gpu-blocklist"],
      },
    },
    {
      label: "system-chrome",
      opts: {
        headless: true,
        executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
        args: ["--disable-dev-shm-usage", "--no-sandbox", "--enable-webgl", "--ignore-gpu-blocklist"],
      },
    },
  ];

  for (const attempt of launchAttempts) {
    try {
      console.log(`[dual] launching ${attempt.label}…`);
      browser = await chromium.launch(attempt.opts);
      console.log(`[dual] ${attempt.label} OK`);
      break;
    } catch (e) {
      console.error(`[dual] ${attempt.label} failed:`, e.message);
    }
  }
  if (!browser) {
    for (const t of targets) {
      state[t.name].error = "failed to launch any browser";
      state[t.name].status = "browser-launch-failed";
    }
    return;
  }

  // Open pages sequentially so WASM compile isn't parallel-thrashed
  for (const t of targets) {
    const s = state[t.name];
    try {
      s.status = "navigating";
      const context = await browser.newContext({
        viewport: t.viewport,
        deviceScaleFactor: 1,
      });
      const page = await context.newPage();
      page.on("pageerror", (err) => {
        s.error = `pageerror: ${String(err.message).slice(0, 200)}`;
      });
      s.page = page;
      await page.goto(t.flutterUrl, { waitUntil: "domcontentloaded", timeout: 90000 });
      await page.waitForTimeout(2000);
      await waitPaint(page, s);
      const buf = await page.screenshot({ type: "png" });
      s.png = buf;
      s.n = 1;
      s.lastAt = new Date().toISOString();
      const proof = path.join(evidenceDir, `PROOF-LIVE-${t.name}.png`);
      fs.writeFileSync(proof, buf);
      console.log(`[dual] ${t.name} first frame ${buf.length} bytes -> ${proof}`);
    } catch (e) {
      s.error = String(e.message || e).slice(0, 300);
      s.status = "nav-error";
      console.error(`[dual] ${t.name} error`, e);
    }
  }

  // Continuous capture loop (sequential)
  for (;;) {
    for (const t of targets) {
      const s = state[t.name];
      if (!s.page) continue;
      try {
        const buf = await s.page.screenshot({ type: "png" });
        s.png = buf;
        s.n += 1;
        s.lastAt = new Date().toISOString();
        s.error = null;
        if (s.n % 15 === 0) {
          fs.writeFileSync(path.join(evidenceDir, `PROOF-LIVE-${t.name}.png`), buf);
        }
      } catch (e) {
        s.error = String(e.message || e).slice(0, 200);
        s.status = "capture-error";
      }
    }
    await new Promise((r) => setTimeout(r, 1500));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
