// Renders intro.svg (from fig.js) to inst/app/intro.png at 2x.
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const svg = path.join(__dirname, 'intro.svg');
  const png = path.join(__dirname, '..', '..', 'inst', 'app', 'intro.png');
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 2020, height: 1022 }, deviceScaleFactor: 2 });
  await p.goto('file://' + svg);
  await p.screenshot({ path: png });
  await b.close();
  console.log('wrote', png);
})();
