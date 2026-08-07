/** Poll bridge /status.json until painted frames exist; download proof PNGs. */
const http = require("http");
const fs = require("fs");
const path = require("path");

const evidenceDir = path.join(__dirname, "evidence");
fs.mkdirSync(evidenceDir, { recursive: true });

function getJson(port, pathname) {
  return new Promise((resolve, reject) => {
    http
      .get(`http://127.0.0.1:${port}${pathname}`, (res) => {
        let d = "";
        res.on("data", (c) => (d += c));
        res.on("end", () => {
          try {
            resolve(JSON.parse(d));
          } catch (e) {
            reject(e);
          }
        });
      })
      .on("error", reject);
  });
}

function getBin(port, pathname) {
  return new Promise((resolve, reject) => {
    http
      .get(`http://127.0.0.1:${port}${pathname}`, (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve(Buffer.concat(chunks)));
      })
      .on("error", reject);
  });
}

async function waitOne(name, port, maxMs) {
  const started = Date.now();
  let last = null;
  while (Date.now() - started < maxMs) {
    try {
      last = await getJson(port, "/status.json");
      console.log(
        `[${name}] n=${last.captureCount} ready=${last.firstFrameReady} status=${last.status} bytes=${last.bytes}`
      );
      if (last.hasFrame && last.firstFrameReady && last.bytes > 20000) {
        const png = await getBin(port, "/frame.png");
        const out = path.join(evidenceDir, `PROOF-LIVE-${name}.png`);
        fs.writeFileSync(out, png);
        console.log(`[${name}] PROOF saved ${out} (${png.length} bytes)`);
        return { ok: true, out, status: last, bytes: png.length };
      }
    } catch (e) {
      console.log(`[${name}] waiting… ${e.message}`);
    }
    await new Promise((r) => setTimeout(r, 3000));
  }
  // Save whatever we have even if not fully painted
  try {
    const png = await getBin(port, "/frame.png");
    const out = path.join(evidenceDir, `PROOF-LIVE-${name}.png`);
    fs.writeFileSync(out, png);
    console.log(`[${name}] timeout — saved last frame ${out} (${png.length})`);
    return { ok: false, out, status: last, bytes: png.length };
  } catch (e) {
    return { ok: false, error: String(e), status: last };
  }
}

(async () => {
  const maxMs = Number(process.argv[2] || 240000);
  const market = await waitOne("market", 8100, maxMs);
  const admin = await waitOne("admin", 8101, maxMs);
  const summary = { market, admin, at: new Date().toISOString() };
  fs.writeFileSync(
    path.join(evidenceDir, "PROOF-LIVE-summary.json"),
    JSON.stringify(summary, null, 2)
  );
  console.log(JSON.stringify(summary, null, 2));
  if (!market.ok || !admin.ok) process.exit(2);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
