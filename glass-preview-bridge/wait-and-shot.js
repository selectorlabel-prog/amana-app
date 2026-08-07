/** Wait up to 3 min for flutter paint on a URL; save evidence PNG. */
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const url = process.argv[2] || "http://127.0.0.1:8095/";
const name = process.argv[3] || "market";
const evidenceDir = path.join(__dirname, "evidence");
fs.mkdirSync(evidenceDir, { recursive: true });

(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: ["--disable-dev-shm-usage", "--no-sandbox"],
  });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const logs = [];
  page.on("console", (m) => logs.push(`[${m.type()}] ${m.text()}`));
  page.on("pageerror", (e) => logs.push(`[pageerror] ${e.message}`));

  console.log("goto", url);
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.evaluate(() => {
    window.__ff = false;
    window.addEventListener("flutter-first-frame", () => {
      window.__ff = true;
    });
  });

  let painted = false;
  for (let i = 0; i < 90; i++) {
    const st = await page.evaluate(() => {
      const boot = document.getElementById("amana-boot");
      const glass = document.querySelector("flt-glass-pane");
      const c =
        (glass && glass.shadowRoot && glass.shadowRoot.querySelector("canvas")) ||
        document.querySelector("canvas");
      return {
        ff: !!window.__ff,
        boot: !!boot,
        canvas: !!c,
        text: (document.body.innerText || "").slice(0, 80),
      };
    });
    console.log(i, st);
    if (st.ff || (st.canvas && !st.boot)) {
      painted = true;
      await page.waitForTimeout(2000);
      break;
    }
    await page.waitForTimeout(2000);
  }

  const shot = path.join(
    evidenceDir,
    `longwait-${name}-${painted ? "painted" : "stuck"}.png`
  );
  fs.writeFileSync(shot, await page.screenshot({ type: "png" }));
  fs.writeFileSync(
    path.join(evidenceDir, `longwait-${name}-console.txt`),
    logs.join("\n")
  );
  console.log("saved", shot, "painted=", painted);
  await browser.close();
  process.exit(painted ? 0 : 3);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
