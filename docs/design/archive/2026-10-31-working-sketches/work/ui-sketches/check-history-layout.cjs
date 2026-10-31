const { chromium } = require('C:/Users/Lance/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const output = __dirname;
(async () => {
  const browser = await chromium.launchPersistentContext(process.env.SETTRACE_SKETCH_PROFILE, {
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true,
    viewport: { width: 736, height: 1100 },
    args: ['--no-first-run', '--no-default-browser-check', '--disable-background-networking'],
    env: { ...process.env },
  });
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto('http://127.0.0.1:8766/', { waitUntil: 'networkidle' });
    const frame = page.frames().find(frame => frame.parentFrame());
    await frame.waitForSelector('#settrace-history-sketch');
    await frame.addScriptTag({ path: 'C:/Users/Lance/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/lucide/dist/umd/lucide.js' });
    await frame.evaluate(() => lucide.createIcons());
    const order = await frame.evaluate(() => {
      const content = document.querySelector('.st-content');
      const nodes = ['.st-counts', '.st-month-summary', '.st-recent', '.st-month-section'].map(selector => content.querySelector(selector));
      return nodes.every((node, i) => i === 0 || Boolean(nodes[i - 1].compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING)) && document.querySelector('.st-month-picker').nextElementSibling.matches('[data-history]');
    });
    const checks = [];
    for (const width of [736, 360, 320]) {
      await page.setViewportSize({ width, height: 1100 });
      for (const scale of [1, 1.6]) {
        await frame.evaluate(scale => window.dispatchEvent(new CustomEvent('openai:set_globals', {
          detail: { globals: { widgetState: { modelContent: { scale, longDuration: true, appearance: 'light' } } } },
        })), scale);
        for (const index of [0]) {
          await frame.locator('.st-phone').nth(index).waitFor({ state: 'visible' });
          const result = await frame.evaluate(index => {
            const phone = document.querySelectorAll('.st-phone')[index];
            const overflow = Array.from(phone.querySelectorAll('.st-count,.st-duration,.st-content,.st-session,.st-month-summary,.st-nav')).filter(el => el.scrollWidth > el.clientWidth + 1).map(el => el.className);
            return { width: phone.getBoundingClientRect().width, overflow, hours: phone.querySelector('[data-hours]').textContent };
          }, index);
          checks.push({ viewport: width, scale, variant: index, ...result });
          if (width === 736) await frame.locator('.st-phone').nth(index).screenshot({ path: path.join(output, `history-${index}-${scale === 1 ? 'normal' : 'large'}.png`) });
        }
      }
    }
    await frame.getByRole('button', { name: '上一个月', exact: true }).first().click();
    const previous = await frame.locator('[data-month-title]').first().textContent();
    const previousSummary = await frame.locator('[data-summary-title]').textContent();
    const emptyVisible = await frame.locator('[data-empty]').first().isVisible();
    await frame.getByRole('button', { name: '下一个月', exact: true }).first().click();
    const restored = await frame.locator('[data-month-title]').first().textContent();
    await page.setViewportSize({ width: 736, height: 1100 });
    for (const appearance of ['light', 'dark']) {
      await frame.evaluate(appearance => window.dispatchEvent(new CustomEvent('openai:set_globals', {
        detail: { globals: { widgetState: { modelContent: { scale: 1, longDuration: false, appearance } } } },
      })), appearance);
      await frame.locator('.st-full').screenshot({ path: path.join(output, `history-recommended-${appearance}.png`) });
    }
    const report = { browser: 'Browser plugin not available; existing Chrome with bundled Playwright', order, checks, errors, interaction: { previous, previousSummary, emptyVisible, restored } };
    fs.writeFileSync(path.join(output, 'preview-check.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify(report));
    if (!order || errors.length || checks.some(check => check.overflow.length) || previous !== '2026年9月' || previousSummary !== '2026年9月汇总' || !emptyVisible || restored !== '2026年10月') process.exitCode = 1;
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
