/**
 * Hit bridge URLs and save proof that Glass-safe HTML shows painted UI frames.
 */
const http = require("http");
const fs = require("fs");
const path = require("path");

const evidenceDir = path.join(__dirname, "evidence");
fs.mkdirSync(evidenceDir, { recursive: true });

function get(url) {
  return new Promise((resolve, reject) => {
    http
      .get(url, { timeout: 10000 }, (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () =>
          resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) })
        );
      })
      .on("error", reject);
  });
}

async function waitForFrame(port, name, tries = 40) {
  for (let i = 0; i < tries; i++) {
    try {
      const st = await get(`http://127.0.0.1:${port}/status.json`);
      const j = JSON.parse(st.body.toString("utf8"));
      if (j.hasFrame && j.bytes > 5000) {
        const frame = await get(`http://127.0.0.1:${port}/frame.png`);
        const out = path.join(evidenceDir, `bridge-${name}-visible.png`);
        fs.writeFileSync(out, frame.body);
        const html = await get(`http://127.0.0.1:${port}/`);
        fs.writeFileSync(
          path.join(evidenceDir, `bridge-${name}-page.html`),
          html.body
        );
        return { name, port, ok: true, bytes: frame.body.length, status: j, out };
      }
      console.log(`[wait] ${name} try ${i + 1}:`, j);
    } catch (e) {
      console.log(`[wait] ${name} try ${i + 1} err:`, e.message);
    }
    await new Promise((r) => setTimeout(r, 1500));
  }
  return { name, port, ok: false };
}

(async () => {
  const results = [
    await waitForFrame(8100, "market"),
    await waitForFrame(8101, "admin"),
  ];
  fs.writeFileSync(
    path.join(evidenceDir, "bridge-evidence.json"),
    JSON.stringify(results, null, 2)
  );
  console.log(JSON.stringify(results, null, 2));
  if (!results.every((r) => r.ok)) process.exit(2);
})();
