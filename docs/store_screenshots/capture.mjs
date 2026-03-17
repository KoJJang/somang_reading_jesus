import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const { default: puppeteer } = await import('puppeteer');

const htmlPath = path.resolve(__dirname, 'preview.html');
const fileUrl = `file://${htmlPath}`;

const targets = [
  // 휴대전화 (1290×2796)
  { selector: '.slide-home', output: 'screenshot_1_home.png',     w: 1290, h: 2796 },
  { selector: '.slide-cal',  output: 'screenshot_2_calendar.png', w: 1290, h: 2796 },
  { selector: '.slide-team', output: 'screenshot_3_team.png',     w: 1290, h: 2796 },
  // Feature Graphic (1024×500)
  { selector: '#feature-graphic', output: 'feature_graphic.png', w: 1024, h: 500 },
  // 7인치 태블릿 (1200×1920)
  { selector: '#tab7-1', output: 'tablet7_1_home.png',     w: 1200, h: 1920 },
  { selector: '#tab7-2', output: 'tablet7_2_calendar.png', w: 1200, h: 1920 },
  { selector: '#tab7-3', output: 'tablet7_3_team.png',     w: 1200, h: 1920 },
  // 10인치 태블릿 (1600×2560)
  { selector: '#tab10-1', output: 'tablet10_1_home.png',     w: 1600, h: 2560 },
  { selector: '#tab10-2', output: 'tablet10_2_calendar.png', w: 1600, h: 2560 },
  { selector: '#tab10-3', output: 'tablet10_3_team.png',     w: 1600, h: 2560 },
];

console.log('Launching browser...');
const browser = await puppeteer.launch({
  headless: true,
  args: [
    '--window-size=1920,3000',
    '--font-render-hinting=none',
    '--lang=ko-KR',
  ],
});

for (const t of targets) {
  const page = await browser.newPage();
  await page.setViewport({ width: t.w + 200, height: t.h + 200, deviceScaleFactor: 1 });
  await page.goto(fileUrl, { waitUntil: 'networkidle0' });

  await page.evaluate((sel) => {
    // 타겟만 남기고 모두 숨기기
    const allSlides = document.querySelectorAll(
      '.slide-wrapper, .fg-wrapper, .tablet-wrapper'
    );
    allSlides.forEach(wrapper => {
      const inner = wrapper.querySelector('.slide, .feature-graphic, .tablet-slide');
      if (!inner || !inner.matches(sel)) wrapper.style.display = 'none';
    });

    // 타겟 transform 제거
    const target = document.querySelector(sel);
    if (target) {
      target.style.transform = 'none';
      target.style.transformOrigin = 'unset';
      target.style.position = 'static';
    }

    // spacer/wrapper 제거
    document.querySelectorAll(
      '.slide-spacer, .fg-spacer, .tablet-spacer'
    ).forEach(el => {
      el.style.height = 'auto';
      el.style.overflow = 'visible';
      el.style.position = 'static';
    });

    // body 초기화
    document.body.style.padding = '0';
    document.body.style.margin = '0';
    document.body.style.background = 'none';
    document.body.style.gap = '0';
    document.body.style.fontFamily = "'Apple SD Gothic Neo', 'AppleGothic', 'Malgun Gothic', sans-serif";
  }, t.selector);

  await new Promise(r => setTimeout(r, 400));

  const element = await page.$(t.selector);
  if (!element) {
    console.error(`Not found: ${t.selector}`);
    await page.close();
    continue;
  }

  const outputPath = path.resolve(__dirname, t.output);
  await element.screenshot({ path: outputPath });
  console.log(`✓ ${t.output} (${t.w}×${t.h})`);
  await page.close();
}

await browser.close();
console.log('\n완료! docs/store_screenshots/ 에 저장되었습니다.');
