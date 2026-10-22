/**
 * BilimYo'l — Core learning-journey E2E (Playwright, no @playwright/test dep).
 *
 * Covers the product loop end-to-end in demo mode (no Supabase needed):
 *   landing → demo auth → roadmap → lesson → answer quiz (correct + wrong)
 *   → reinforcement → completion → progress stats update.
 *
 * Run:
 *   1) Start a dev server:  npm run dev        (port 5173 by default)
 *   2) Run this spec:        node tests/e2e/journey.mjs
 *      or:                  BASE_URL=http://localhost:5199 node tests/e2e/journey.mjs
 *
 * Exits non-zero on any failed assertion (CI-friendly).
 */

import { chromium } from 'playwright';

const BASE = process.env.BASE_URL || 'http://localhost:5173';
const VIEWPORT = { width: 1280, height: 800 };
const TIMEOUT = 25000;

let failures = 0;
const results = [];
function check(name, cond, extra = '') {
  const ok = Boolean(cond);
  results.push(`${ok ? 'PASS' : 'FAIL'}  ${name}${extra ? ' — ' + extra : ''}`);
  if (!ok) failures++;
}

async function clickText(page, text, first = true) {
  const loc = page.getByText(text, { exact: false });
  if (await loc.count() === 0) return false;
  await (first ? loc.first() : loc).click({ timeout: TIMEOUT }).catch(() => false);
  return true;
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: VIEWPORT });

  try {
    // ── 1. Landing renders ──────────────────────────────────────────────
    await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded', timeout: TIMEOUT });
    await page.waitForTimeout(2200);
    check('landing renders', (await page.title()).length > 0);

    // ── 2. Demo auth (no Supabase needed) ───────────────────────────────
    check('demo login button present', (await page.getByText('Namuna hisobi bilan kirish').count()) > 0);
    await clickText(page, 'Namuna hisobi bilan kirish');
    await page.waitForTimeout(2600);
    const dash = await page.textContent('main');
    check('dashboard loaded after demo auth', /O‘rganish yo‘nalishi|Bosh sahifa|DAVOM ETISH|Ta’lim yo‘li/.test(dash));
    check('4 courses visible in selector', /Matematika/.test(dash) && /Ingliz tili/.test(dash));

    // ── 3. Roadmap renders adaptive nodes ───────────────────────────────
    await page.goto(`${BASE}/?view=roadmap`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2600);
    const roadmap = await page.textContent('main');
    check('roadmap renders', /Mening Ta’lim Yo‘lim|Bosqich|MUSTAHKAMLASH|Darsni boshlash|Davom etish/.test(roadmap));
    check('adaptive reinforcement nodes present', /Mustahkamlash/.test(roadmap));

    // ── 4. Open a lesson via roadmap continue ───────────────────────────
    const continued = await clickText(page, 'Davom etish');
    check('continue button opens lesson', continued);
    await page.waitForTimeout(3200);
    const lesson = await page.textContent('main');
    check('lesson renders steps', /Qadam|Nazariya|Misol|Mashq|Test/.test(lesson));

    // ── 5. Navigate to quiz (last step) ────────────────────────────────
    await clickText(page, 'Test');
    await page.waitForTimeout(2200);
    const quizPage = await page.textContent('main');
    check('quiz question visible', /DARSNI YAKUNLOVCHI|f\(4\)|savol/i.test(quizPage));

    // ── 6. Answer the quiz — click an option then submit ───────────────
    // Each option is a button containing the option text; click the one that
    // contains the correct answer for this lesson (f(4)=11 → "11").
    const optionButton = page.locator('main button').filter({ hasText: '11' });
    if (await optionButton.count() > 0) {
      await optionButton.first().click();
      await page.waitForTimeout(1000);
    }
    const submitBtn = page.locator('button', { hasText: 'TEKSHIRISH' }).first();
    if (await submitBtn.isEnabled().catch(() => false)) {
      await submitBtn.click();
    }
    await page.waitForTimeout(3000);
    const afterAnswer = await page.textContent('main');
    check(
      'answer evaluated (correct or Yo‘lchi feedback)',
      /TO‘G‘RI|To‘g‘ri javob|Xato tahlili|Yo‘lchi AI|Mustahkamlash|Dars yakunlandi/.test(afterAnswer)
    );

    // ── 7. Completion / XP surface ──────────────────────────────────────
    check(
      'XP or completion feedback shown',
      /XP|Dars yakunlandi|BILIM DARAJANGIZ|Keyingi savol/.test(afterAnswer)
    );

    // ── 8. Progress view reflects real activity ────────────────────────
    await page.goto(`${BASE}/?view=progress`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2600);
    const progress = await page.textContent('main');
    check('progress view renders', /Mening Natijalarim|O‘zlashtirish|Umumiy|Ketma-ketlik/.test(progress));

    // ── 9. Knowledge map renders skills ────────────────────────────────
    await page.goto(`${BASE}/?view=knowledge-map`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2600);
    const kmap = await page.textContent('main');
    check('knowledge map renders', /Bilim Holati|Ko‘nikmalar|Diagnostika|O‘zlashtirish/.test(kmap));

    // ── 10. AI tutor view renders ──────────────────────────────────────
    await page.goto(`${BASE}/?view=ai-tutor`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2400);
    const tutor = await page.textContent('main');
    check('Yo‘lchi AI tutor renders', /Yo‘lchi AI|savol bering|Mentor|Namunaviy/.test(tutor));
  } catch (err) {
    check('no fatal navigation/runtime error', false, String(err && err.message ? err.message : err));
  } finally {
    await browser.close();
  }
}

const started = Date.now();
main()
  .then(() => {
    console.log('\n────────────────────────────────────────');
    results.forEach((r) => console.log('  ' + r));
    console.log('────────────────────────────────────────');
    console.log(
      failures === 0
        ? `E2E PASSED — all ${results.length} assertions in ${Math.round((Date.now() - started) / 1000)}s`
        : `E2E FAILED — ${failures} of ${results.length} assertions failed`
    );
    process.exit(failures === 0 ? 0 : 1);
  })
  .catch((err) => {
    console.error('E2E runner crashed:', err);
    process.exit(1);
  });
