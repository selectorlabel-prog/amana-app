/** Minimal Glass screenshot bridge — plain HTML + JPEG, no Flutter/WASM in Glass. */
const http = require("http");
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const name = process.argv[2] || "market";
const flutterPort = Number(process.argv[3] || 8095);
const bridgePort = Number(process.argv[4] || 8100);
const flutterUrl = `http://127.0.0.1:${flutterPort}/`;
const evidenceDir = path.join(__dirname, "evidence");
fs.mkdirSync(evidenceDir, { recursive: true });

let jpeg = null;
let status = "starting";
let n = 0;
let page, browser;

const HTML = () => `<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>أمانة ${name}</title>
<style>body{margin:0;background:#111;color:#eee;font-family:Tahoma,sans-serif;text-align:center}
img{max-width:100%;height:auto;display:block;margin:0 auto;background:#222;min-height:240px}
.b{padding:8px;font-size:12px;color:#9ab}</style></head><body>
<div class="b" id="s">${status}</div>
<img id="i" src="/live.jpg?t=0" alt="preview"/>
<script>
async function t(){try{const j=await(await fetch('/status')).json();
document.getElementById('s').textContent=j.status+' #'+j.n;
if(j.ok)document.getElementById('i').src='/live.jpg?t='+Date.now()}catch(e){}}
setInterval(t,1000);t();
</script></body></html>`;

async function loop() {
  for (;;) {
    try {
      if (!browser) {
        status = "launch chromium";
        browser = await chromium.launch({ headless: true, args: ["--no-sandbox", "--disable-dev-shm-usage"] });
        page = await browser.newPage({ viewport: { width: 390, height: 844 } });
      }
      status = "goto " + flutterUrl;
      await page.goto(flutterUrl, { waitUntil: "domcontentloaded", timeout: 60000 });
      // Wait up to ~2 min for first Flutter paint (debug DDC is slow)
      for (let i = 0; i < 60; i++) {
        const ok = await page.evaluate(() => {
          const boot = document.getElementById("amana-boot");
          const glass = document.querySelector("flt-glass-pane");
          const c = (glass && glass.shadowRoot && glass.shadowRoot.querySelector("canvas")) || document.querySelector("canvas");
          return !!(c && !boot);
        });
        if (ok) break;
        status = `wait paint ${i}s`;
        await page.waitForTimeout(2000);
      }
      status = "live";
      while (true) {
        jpeg = await page.screenshot({ type: "jpeg", quality: 72 });
        n++;
        if (n === 1 || n % 20 === 0) {
          fs.writeFileSync(path.join(evidenceDir, `proof-${name}.jpg`), jpeg);
        }
        status = `live frame ${n}`;
        await page.waitForTimeout(1000);
      }
    } catch (e) {
      status = "err " + String(e.message || e).slice(0, 120);
      try { if (browser) await browser.close(); } catch (_) {}
      browser = null; page = null;
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
}

http.createServer((req, res) => {
  const u = (req.url || "/").split("?")[0];
  if (u === "/live.jpg") {
    if (!jpeg) {
      res.writeHead(503); res.end("wait"); return;
    }
    res.writeHead(200, { "Content-Type": "image/jpeg", "Cache-Control": "no-store" });
    res.end(jpeg); return;
  }
  if (u === "/status") {
    res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(JSON.stringify({ ok: !!jpeg, n, status, name, flutterUrl })); return;
  }
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
  res.end(HTML());
}).listen(bridgePort, "127.0.0.1", () => {
  console.log(`[${name}] Glass http://127.0.0.1:${bridgePort}/ <- ${flutterUrl}`);
});

loop();
