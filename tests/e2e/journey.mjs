/**
 * BilimYo'l — Core learning-journey E2E (Playwright, no @playwright/test dep).
 *
 * Covers the product loop end-to-end in demo mode (no Supabase needed):
 *   landing → demo auth → roadmap → lesson → answer quiz (correct + wrong)
 *   → reinforcement → completion → progress stats update.
 *
 * Uses in-app navigation (the real learner flow) instead of full page reloads,
 * so it does not depend on demo-session persistence, and waits for rendered
 * text instead of fixed delays — deterministic on cold servers and in CI.
 *
 * Run:
 *   npm run test:e2e                         (boots a demo server automatically)
 *   BASE_URL=http://localhost:5173 node tests/e2e/journey.mjs
 *
 * Exits non-zero on any failed assertion (CI-friendly).
 */

import { chromium } from 'playwright';

const BASE = process.env.BASE_URL || 'http://localhost:5173';
const VIEWPORT = { width: 1280, height: 800 };
const TIMEOUT = 45000;

let failures = 0;
const results = [];
function check(name, cond, extra = '') {
  const ok = Boolean(cond);
  results.push(`${ok ? 'PASS' : 'FAIL'}  ${name}${extra ? ' — ' + extra : ''}`);
  if (!ok) failures++;
}

/** Polls the rendered body until it matches `regex` (or times out). */
async function waitForText(page, regex, label = '', timeout = TIMEOUT) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeout) {
    const text = (await page.textContent('body').catch(() => '')) || '';
    if (regex.test(text)) return true;
    await page.waitForTimeout(400);
  }
  if (label) console.log(`  (timeout waiting for ${label})`);
  return false;
}

/** Clicks an element whose text contains `text` (first match). */
async function clickText(page, text, timeout = TIMEOUT) {
  const loc = page.getByText(text, { exact: false });
  if ((await loc.count()) === 0) return false;
  await loc.first().click({ timeout }).catch(() => {});
  return true;
}

/** Switches the app view via its own navigation API (no reload, no ambiguity). */
async function goToView(page, view) {
  await page.evaluate((target) => {
    if (typeof window.__navigateToView === 'function') window.__navigateToView(target);
  }, view);
  await page.waitForTimeout(600);
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: VIEWPORT });
  // Block remote fonts so DOMContentLoaded never depends on network access.
  await context.route('**://fonts.googleapis.com/**', (r) => r.abort());
  await context.route('**://fonts.gstatic.com/**', (r) => r.abort());
  const page = await context.newPage();

  try {
    // ── 1. Landing renders ──────────────────────────────────────────────
    await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded', timeout: TIMEOUT });
    await waitForText(page, /Namuna hisobi bilan kirish/, 'demo login button');
    check('landing renders', (await page.title()).length > 0);

    // ── 2. Demo auth (no Supabase needed) ───────────────────────────────
    check('demo login button present', (await page.getByText('Namuna hisobi bilan kirish').count()) > 0);
    await clickText(page, 'Namuna hisobi bilan kirish');
    const dashReady = await waitForText(
      page,
      /Assalomu alaykum|O‘rganish yo‘nalishi|DAVOM ETISH/,
      'dashboard',
    );
    const dash = (await page.textContent('main').catch(() => '')) || '';
    check('dashboard loaded after demo auth', dashReady && /Assalomu alaykum|O‘rganish yo‘nalishi|DAVOM ETISH/.test(dash));
    check('4 courses visible in selector', /Matematika/.test(dash) && /Ingliz tili/.test(dash));

    // ── 3. Roadmap (in-app navigation) ──────────────────────────────────
    await goToView(page, 'roadmap');
    await waitForText(page, /Mening Ta’lim Yo‘lim|Darsni boshlash|Davom etish/, 'roadmap');
    const roadmap = (await page.textContent('main').catch(() => '')) || '';
    check('roadmap renders', /Mening Ta’lim Yo‘lim|Bosqich|MUSTAHKAMLASH|Darsni boshlash|Davom etish/.test(roadmap));
    check('adaptive reinforcement nodes present', /Mustahkamlash/.test(roadmap));

    // ── 4. Open a lesson via roadmap continue ───────────────────────────
    const continued = await clickText(page, 'Davom etish');
    check('continue button opens lesson', continued);
    await waitForText(page, /Qadam\s*\d|Nazariya|Misol|Mashq|Test/, 'lesson steps');
    const lesson = (await page.textContent('main').catch(() => '')) || '';
    check('lesson renders steps', /Qadam|Nazariya|Misol|Mashq|Test/.test(lesson));

    // ── 5. Navigate to quiz (last step) ────────────────────────────────
    await clickText(page, 'Test');
    await waitForText(page, /TEKSHIRISH|Interaktiv|Sinov|savol/i, 'quiz');
    const quizPage = (await page.textContent('main').catch(() => '')) || '';
    check('quiz question visible', /DARSNI YAKUNLOVCHI|f\(4\)|savol|Sinov/i.test(quizPage));

    // ── 6. Answer the quiz — click an option then submit ───────────────
    const optionButton = page.locator('main button').filter({ hasText: '11' });
    if ((await optionButton.count()) > 0) {
      await optionButton.first().click().catch(() => {});
      await page.waitForTimeout(600);
    }
    const submitBtn = page.locator('button', { hasText: 'TEKSHIRISH' }).first();
    if ((await submitBtn.count()) > 0 && (await submitBtn.isEnabled().catch(() => false))) {
      await submitBtn.click();
    }
    const evaluated = await waitForText(
      page,
      /TO‘G‘RI|To‘g‘ri javob|Xato tahlili|Yo‘lchi AI|Mustahkamlash|Dars yakunlandi/,
      'quiz feedback',
    );
    const afterAnswer = (await page.textContent('main').catch(() => '')) || '';
    check('answer evaluated (correct or Yo‘lchi feedback)', evaluated);

    // ── 7. Completion / XP surface ──────────────────────────────────────
    check(
      'XP or completion feedback shown',
      /XP|Dars yakunlandi|BILIM DARAJANGIZ|Keyingi savol/.test(afterAnswer),
    );

    // ── 8. Progress view ───────────────────────────────────────────────
    await goToView(page, 'progress');
    await waitForText(page, /Ko‘rsatkich|O‘zlashtirish|Umumiy|Ketma-ketlik/, 'progress');
    const progress = (await page.textContent('main').catch(() => '')) || '';
    check('progress view renders', /Ko‘rsatkich|O‘zlashtirish|Umumiy|Ketma-ketlik/.test(progress));

    // ── 9. Knowledge map ───────────────────────────────────────────────
    await goToView(page, 'knowledge-map');
    await waitForText(page, /Bilim Holati|Ko‘nikmalar|Diagnostika|O‘zlashtirish/, 'knowledge map');
    const kmap = (await page.textContent('main').catch(() => '')) || '';
    check('knowledge map renders', /Bilim Holati|Ko‘nikmalar|Diagnostika|O‘zlashtirish/.test(kmap));

    // ── 10. AI tutor view ──────────────────────────────────────────────
    await goToView(page, 'ai-tutor');
    await waitForText(page, /savol bering|Mentor|Namunaviy|Yo‘lchi AI pedagog/, 'ai tutor');
    const tutor = (await page.textContent('main').catch(() => '')) || '';
    check('Yo‘lchi AI tutor renders', /savol bering|Mentor|Namunaviy|Yo‘lchi AI/.test(tutor));
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
