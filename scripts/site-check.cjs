#!/usr/bin/env node
// Serves site/ under /bt-audio-idle-disconnect/ (the GitHub Pages path) and checks both
// language versions with Playwright: console errors, failed requests, broken images,
// internal links and anchors, the language switch, the lightbox, and mobile overflow.
// With --og it also renders site/assets/img/og-image-{pl,en}.jpg from scripts/og-image.html.
//
// Playwright is not a dependency of the app. Run with, e.g.:
//   npm i -g playwright && npx playwright install chromium
//   NODE_PATH="$(npm root -g)" node scripts/site-check.cjs [--og] [--shots <dir>]

const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..');
const SITE = path.join(ROOT, 'site');
const BASE = '/bt-audio-idle-disconnect/';
const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript',
  '.webp': 'image/webp', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.txt': 'text/plain' };

const args = process.argv.slice(2);
const wantOg = args.includes('--og');
const shotsDir = args.includes('--shots') ? args[args.indexOf('--shots') + 1] : null;

function serve() {
  const server = http.createServer((req, res) => {
    let url = decodeURIComponent(req.url.split('?')[0]);
    let file;
    if (url.startsWith('/__root__/')) file = path.join(ROOT, url.slice('/__root__/'.length));
    else if (url.startsWith(BASE)) file = path.join(SITE, url.slice(BASE.length));
    else { res.writeHead(404); return res.end(); }
    if (file.endsWith(path.sep) || (fs.existsSync(file) && fs.statSync(file).isDirectory())) {
      if (!url.endsWith('/')) { res.writeHead(301, { Location: url + '/' }); return res.end(); }
      file = path.join(file, 'index.html');
    }
    if (!file.startsWith(ROOT) || !fs.existsSync(file)) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

async function main() {
  const server = await serve();
  const origin = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  const problems = [];
  const fail = (msg) => { problems.push(msg); console.log('  ✗ ' + msg); };

  if (wantOg) {
    const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
    for (const lang of ['pl', 'en']) {
      await page.goto(`${origin}/__root__/scripts/og-image.html?lang=${lang}`, { waitUntil: 'networkidle' });
      const out = path.join(SITE, 'assets', 'img', `og-image-${lang}.jpg`);
      await page.screenshot({ path: out, type: 'jpeg', quality: 85 });
      console.log('wrote ' + path.relative(ROOT, out));
    }
    await page.close();
  }

  const pages = [
    { lang: 'pl', url: BASE, other: BASE + 'en/' },
    { lang: 'en', url: BASE + 'en/', other: BASE },
  ];
  const viewports = [
    { name: 'desktop', width: 1440, height: 900 },
    { name: 'mobile', width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 3 },
  ];

  for (const scheme of ['light', 'dark']) {
    for (const vp of viewports) {
      const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height },
        isMobile: !!vp.isMobile, hasTouch: !!vp.hasTouch, deviceScaleFactor: vp.deviceScaleFactor || 1,
        colorScheme: scheme });
      for (const p of pages) {
        console.log(`• ${p.lang} ${vp.name} ${scheme}`);
        const page = await context.newPage();
        page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') fail(`console ${m.type()}: ${m.text()}`); });
        page.on('pageerror', (e) => fail('page error: ' + e.message));
        page.on('response', (r) => { if (r.status() >= 400 && r.url().startsWith(origin)) fail(`HTTP ${r.status()} ${r.url()}`); });
        page.on('requestfailed', (r) => { if (r.url().startsWith(origin)) fail('request failed ' + r.url()); });

        await page.goto(origin + p.url, { waitUntil: 'networkidle' });

        if ((await page.getAttribute('html', 'lang')) !== p.lang) fail('wrong <html lang>');

        // Bring every (lazy) image into view and wait for it to decode.
        const broken = await page.$$eval('img', async (imgs) => {
          const bad = [];
          for (const i of imgs) {
            if (!i.getAttribute('src')) continue;
            i.scrollIntoView({ block: 'center' });
            try { await i.decode(); } catch (e) { /* reported below */ }
            if (i.naturalWidth === 0) bad.push(i.currentSrc || i.src);
          }
          window.scrollTo(0, 0);
          return bad;
        });
        broken.forEach((b) => fail('broken image ' + b));
        const noAlt = await page.$$eval('img', (imgs) => imgs.filter((i) => !i.hasAttribute('alt')).length);
        if (noAlt) fail(`${noAlt} <img> without alt`);

        // Dark scheme must pick the dark screenshots.
        const heroSrc = await page.$eval('.hero-shot img', (i) => i.currentSrc);
        if (!heroSrc.includes(`-${scheme}.webp`)) fail(`hero picks ${heroSrc} in ${scheme} mode`);

        // No horizontal scrolling on mobile.
        const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
        if (overflow > 0) fail(`horizontal overflow ${overflow}px`);

        // Internal links and #anchors resolve.
        const links = await page.$$eval('a[href]', (as) => as.map((a) => a.getAttribute('href')));
        for (const href of links) {
          if (href.startsWith('#')) {
            if (!(await page.$(href))) fail('missing anchor ' + href);
          } else if (!/^(https?:|mailto:)/.test(href)) {
            const target = new URL(href, origin + p.url).toString();
            const res = await page.request.get(target);
            if (res.status() !== 200) fail(`link ${href} → ${res.status()}`);
          }
        }

        // hreflang alternates are consistent across both versions.
        const alternates = await page.$$eval('link[rel=alternate][hreflang]', (ls) => ls.map((l) => l.hreflang + '=' + l.href).sort().join(' '));
        if (!alternates.includes('pl=https://jash90.github.io/bt-audio-idle-disconnect/') || !alternates.includes('en=https://jash90.github.io/bt-audio-idle-disconnect/en/')) fail('hreflang alternates incomplete');

        // Lightbox via keyboard: focus the first screenshot button, Enter opens, Escape closes.
        await page.focus('#' + (p.lang === 'pl' ? 'funkcje' : 'features') + ' .shot-button');
        await page.keyboard.press('Enter');
        if (!(await page.$eval('#lightbox', (d) => d.open))) fail('lightbox did not open');
        const lbImg = await page.$eval('#lightbox img', (i) => i.complete && i.naturalWidth > 0);
        if (!lbImg) fail('lightbox image not loaded');
        if (shotsDir && vp.name === 'desktop' && scheme === 'light') await page.screenshot({ path: path.join(shotsDir, `site-${p.lang}-lightbox.png`) });
        await page.keyboard.press('Escape');
        if (await page.$eval('#lightbox', (d) => d.open)) fail('lightbox did not close on Escape');

        if (shotsDir) {
          fs.mkdirSync(shotsDir, { recursive: true });
          await page.screenshot({ path: path.join(shotsDir, `site-${p.lang}-${vp.name}-${scheme}.png`), fullPage: true });
        }

        // Language switch goes to the other version.
        await page.click('.lang-switch');
        await page.waitForLoadState('networkidle');
        if (new URL(page.url()).pathname !== p.other) fail(`lang switch went to ${page.url()}`);
        await page.close();
      }
      await context.close();
    }
  }

  await browser.close();
  server.close();
  console.log(problems.length ? `\n${problems.length} problem(s)` : '\n✓ all checks passed');
  process.exit(problems.length ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });
