#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p bash -c 'echo "CAPTURE_URL=${CAPTURE_URL:-<unset>} CAPTURE_DIR=${CAPTURE_DIR:-<unset>}"'
/usr/bin/time -p bash -c ': "${CAPTURE_URL:?Set CAPTURE_URL.}" ; : "${CAPTURE_DIR:?Set CAPTURE_DIR.}"'
/usr/bin/time -p mkdir -p "$CAPTURE_DIR"
/usr/bin/time -p node - "$CAPTURE_URL" "$CAPTURE_DIR" <<'NODE'
// capture: desktop + mobile screenshots, exit 75 transient / 1 defect
const [url, out] = [process.argv[2], process.argv[3]];
const { mkdirSync } = require('fs');
const { join } = require('path');
const fail = (code, ...a) => { console.error(...a); process.exit(code); };
if (!url || !out) fail(1, 'Set CAPTURE_URL and CAPTURE_DIR.');
(async () => {
  let pw;
  try { pw = require('/home/runner/.local/share/omgithub-playwright/node_modules/playwright-core'); }
  catch (e) { fail(1, 'playwright-core missing:', e.message); }
  const exeCandidates = [
    '/home/runner/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',
    '/home/runner/.cache/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-linux64/chrome-headless-shell'
  ];
  const { existsSync } = require('fs');
  const exe = exeCandidates.find(p => existsSync(p));
  if (!exe) fail(75, 'no chromium executable (transient)');
  let browser;
  try {
    browser = await pw.chromium.launch({ executablePath: exe, headless: true, timeout: 30000, args: ['--no-sandbox','--disable-dev-shm-usage'] });
  } catch (e) { fail(75, 'browser launch failed (transient):', e.message); }
  const TRANSIENT = new Set([408, 429, 500, 502, 503, 504]);
  try {
    mkdirSync(out, { recursive: true });
    for (const [name, w, h] of [['desktop', 1440, 900], ['mobile', 390, 844]]) {
      const ctx = await browser.newContext({ viewport: { width: w, height: h } }).catch(e => fail(75, 'context failed (transient):', e.message));
      const page = await ctx.newPage().catch(e => fail(75, 'newPage failed (transient):', e.message));
      page.setDefaultTimeout(30000);
      let resp;
      try { resp = await page.goto(url, { waitUntil: 'load', timeout: 45000 }); }
      catch (e) { fail(75, `goto ${name} timeout (transient):`, e.message); }
      if (!resp) fail(75, `no response ${name} (transient)`);
      const st = resp.status();
      if (!resp.ok()) fail(TRANSIENT.has(st) || !st ? 75 : 1, `HTTP ${st} loading preview (${name})`);
      try {
        await page.locator(process.env.CAPTURE_READY_SELECTOR || 'body').first().waitFor({ state: 'visible', timeout: 20000 });
        await page.waitForFunction(() => document.fonts ? document.fonts.status === 'loaded' : true, { timeout: 15000 }).catch(() => {});
        await page.waitForTimeout(1500);
        const title = await page.title().catch(() => '');
        if (!title && (await page.content()).length < 500) fail(1, `render defect ${name}: empty document`);
      } catch (e) { if (e && e.exitCode) throw e; fail(1, `render wait defect ${name}:`, e.message); }
      try { await page.screenshot({ path: join(out, `final-${name}.png`), timeout: 30000 }); }
      catch (e) { fail(/Timeout|closed|disconnected/i.test(e.message || '') ? 75 : 1, `screenshot ${name} failed:`, e.message); }
      console.log(`captured ${name}`);
      await ctx.close().catch(() => {});
    }
  } finally { await browser.close().catch(e => { console.error(e.message); process.exitCode ||= 75; }); }
})().catch(e => { console.error(e); process.exit(e.exitCode || 1); });
NODE
/usr/bin/time -p test -f "$CAPTURE_DIR/final-desktop.png"
/usr/bin/time -p test -f "$CAPTURE_DIR/final-mobile.png"
/usr/bin/time -p ls -la "$CAPTURE_DIR"
