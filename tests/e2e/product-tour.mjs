import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { chromium } from 'playwright';

const base = process.env.BASE_URL;
assert(base, 'Set BASE_URL (use npm run test:e2e) to run product-tour E2E tests.');

const renderDir = process.env.TOUR_RENDER_DIR;
if (renderDir) {
  await mkdir(renderDir, { recursive: true });
}

const browser = await chromium.launch();
const errors = [];
let assertions = 0;

async function openFreshContext(options = {}) {
  const context = await browser.newContext({
    viewport: options.viewport ?? { width: 1280, height: 800 },
    reducedMotion: options.reducedMotion ?? 'reduce',
  });
  if (options.initScript) {
    await context.addInitScript(options.initScript, options.initArg);
  }
  const page = await context.newPage();
  page.setDefaultTimeout(12000);
  page.on('pageerror', (err) => errors.push(err.message));
  await page.route('https://fonts.googleapis.com/**', (route) =>
    route.fulfill({ status: 200, contentType: 'text/css', body: '/* E2E font stub */' }),
  );
  await page.route('https://fonts.gstatic.com/**', (route) => route.abort());
  return { context, page };
}

async function checkNoOverflow(page, label) {
  const sizes = await page.evaluate(() => ({
    width: document.documentElement.clientWidth,
    scroll: document.documentElement.scrollWidth,
  }));
  assert(
    sizes.scroll <= sizes.width + 1,
    `${label} horizontal overflow: ${JSON.stringify(sizes)}`,
  );
  assertions++;
}

async function assertFirstFoldOnMobile(page, expectedStage, ctaName, label) {
  const stage = page.locator(`[data-stage="${expectedStage}"]`);
  const cta = page.getByRole('main').getByRole('button', { name: ctaName, exact: true });
  await stage.waitFor({ state: 'visible' });
  await cta.waitFor({ state: 'visible' });
  const stageBox = await stage.boundingBox();
  const ctaBox = await cta.boundingBox();
  assert(stageBox && ctaBox, `${label}: stage or CTA missing boundingBox`);
  assert(
    stageBox.y >= 0 && ctaBox.y + ctaBox.height <= 844,
    `${label}: first fold overflow at 390x844 (stage.y=${stageBox.y}, ctaBottom=${ctaBox.y + ctaBox.height})`,
  );
  assertions++;
}

async function snap(page, filename) {
  if (renderDir) {
    await page.screenshot({ path: join(renderDir, filename), animations: 'disabled' });
  }
}

try {
  // 1. Fresh guest -> Scene 1 -> Skip -> WelcomeView -> reload persists WelcomeView
  {
    const { context, page } = await openFreshContext();
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    const main = page.getByRole('main');
    await main.getByRole('heading', { level: 1, name: 'Qaysi dars aynan sizga mos?' }).waitFor();
    await main.getByText(/qisqa diagnostika orqali/i).waitFor();
    await main.getByRole('button', { name: 'Sinab ko‘rish', exact: true }).waitFor();
    await main.getByRole('button', { name: 'O‘tkazib yuborish', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: /O‘zingizga mos\s+yo‘ldan o‘rganing\./ }).waitFor();
    const flag = await page.evaluate(() => localStorage.getItem('bilimyol.product_tour_completed'));
    assert.equal(flag, 'true');
    await page.reload({ waitUntil: 'domcontentloaded' });
    await main.getByRole('heading', { level: 1, name: /O‘zingizga mos\s+yo‘ldan o‘rganing\./ }).waitFor();
    assert.equal(await main.getByRole('button', { name: 'O‘tkazib yuborish', exact: true }).count(), 0);
    await context.close();
    assertions += 3;
    console.log('PASS fresh guest skip & reload persistence');
  }

  // 2. Desktop Light 3-scene walkthrough + mini-exercise retry & guest isolation + renders
  {
    const { context, page } = await openFreshContext({ viewport: { width: 1280, height: 800 } });
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    const main = page.getByRole('main');
    await main.getByRole('heading', { level: 1, name: 'Qaysi dars aynan sizga mos?' }).waitFor();
    await checkNoOverflow(page, 'desktop light scene 1');
    await snap(page, 'scene1_desktop_light.png');

    await main.getByRole('button', { name: 'Sinab ko‘rish', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: 'Bir savolni sinab ko‘ring.' }).waitFor();
    await checkNoOverflow(page, 'desktop light scene 2');

    // Wrong option -> hint feedback + retry allowed
    await main.getByRole('button', { name: 'is', exact: true }).click();
    await main.getByText(/uchinchi shaxs/i).waitFor();
    assert.equal(await main.getByRole('button', { name: 'am', exact: true }).isDisabled(), false);

    // Correct option -> exact feedback
    await main.getByRole('button', { name: 'am', exact: true }).click();
    await main.getByText('I bilan am ishlatiladi: I am a student.', { exact: true }).waitFor();
    await snap(page, 'scene2_desktop_light.png');

    // Verify guest isolation: zero progress/XP/tour flag persisted mid-tour
    const storageSnapshot = await page.evaluate(() => ({
      localKeys: Object.keys(localStorage),
      sessionKeys: Object.keys(sessionStorage),
    }));
    assert.deepEqual(storageSnapshot.localKeys, []);
    assert.deepEqual(storageSnapshot.sessionKeys, []);

    await main.getByRole('button', { name: 'Keyingi', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: 'Keyingi qadamingiz ko‘rinib turadi.' }).waitFor();
    await main.getByText(/Namuna xaritasi/i).waitFor();
    await main.getByText('Kasblar va kundalik suhbat', { exact: true }).waitFor();
    await checkNoOverflow(page, 'desktop light scene 3');
    await snap(page, 'scene3_desktop_light.png');

    await main.getByRole('button', { name: 'Boshlash', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: /O‘zingizga mos\s+yo‘ldan o‘rganing\./ }).waitFor();
    assert.equal(await page.evaluate(() => localStorage.getItem('bilimyol.product_tour_completed')), 'true');
    await page.reload({ waitUntil: 'domcontentloaded' });
    await main.getByRole('heading', { level: 1, name: /O‘zingizga mos\s+yo‘ldan o‘rganing\./ }).waitFor();
    await context.close();
    assertions += 6;
    console.log('PASS desktop light 3-scene completion, exercise feedback & guest isolation');
  }

  // 3. Scene 2 Keyingi without answering + Desktop Dark captures + RU locale verification
  {
    const { context, page } = await openFreshContext({ viewport: { width: 1280, height: 800 } });
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    const main = page.getByRole('main');

    // Toggle dark theme in PreferencesBar
    await page.getByRole('button', { name: 'Qorong‘i rejimni yoqish', exact: true }).click();
    assert.equal(await page.locator('html').getAttribute('data-theme'), 'dark');
    await main.getByRole('heading', { level: 1, name: 'Qaysi dars aynan sizga mos?' }).waitFor();
    await snap(page, 'scene1_desktop_dark.png');

    await main.getByRole('button', { name: 'Sinab ko‘rish', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: 'Bir savolni sinab ko‘ring.' }).waitFor();
    // Advance without answering!
    await main.getByRole('button', { name: 'Keyingi', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: 'Keyingi qadamingiz ko‘rinib turadi.' }).waitFor();
    await snap(page, 'scene3_desktop_dark.png');

    // Go back to Scene 2 in Dark + switch to RU to verify localized exercise & feedback
    await main.getByRole('button', { name: 'Orqaga', exact: true }).click();
    await page.locator('#interface-language').selectOption('ru');
    await main.getByRole('heading', { level: 1, name: 'Попробуйте один вопрос.' }).waitFor();
    await main.getByRole('button', { name: 'am', exact: true }).click();
    await main.getByText('С местоимением I используется am: I am a student.', { exact: true }).waitFor();
    await snap(page, 'scene2_desktop_dark_ru.png');

    await context.close();
    assertions += 4;
    console.log('PASS Scene 2 un-answered Keyingi, Dark theme & RU locale');
  }

  // 4. 390x844 Mobile first-fold fit in Light UZ and Dark UZ + renders
  {
    const { context, page } = await openFreshContext({ viewport: { width: 390, height: 844 } });
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    const main = page.getByRole('main');

    await checkNoOverflow(page, 'mobile 390 light scene 1');
    await assertFirstFoldOnMobile(page, 'discovery', 'Sinab ko‘rish', 'mobile 390 light scene 1');
    await snap(page, 'scene1_mobile_390_light.png');

    await main.getByRole('button', { name: 'Sinab ko‘rish', exact: true }).click();
    await checkNoOverflow(page, 'mobile 390 light scene 2');
    await assertFirstFoldOnMobile(page, 'exercise', 'Keyingi', 'mobile 390 light scene 2 (unanswered)');
    await main.getByRole('button', { name: 'am', exact: true }).click();
    await main.getByText('I bilan am ishlatiladi: I am a student.', { exact: true }).waitFor();
    await assertFirstFoldOnMobile(page, 'exercise', 'Keyingi', 'mobile 390 light scene 2 (answered)');
    await snap(page, 'scene2_mobile_390_light.png');

    await main.getByRole('button', { name: 'Keyingi', exact: true }).click();
    await checkNoOverflow(page, 'mobile 390 light scene 3');
    await assertFirstFoldOnMobile(page, 'result', 'Boshlash', 'mobile 390 light scene 3');
    await snap(page, 'scene3_mobile_390_light.png');

    // Mobile Dark renders across scenes
    await page.getByRole('button', { name: 'Qorong‘i rejimni yoqish', exact: true }).click();
    await checkNoOverflow(page, 'mobile 390 dark scene 3');
    await snap(page, 'scene3_mobile_390_dark.png');
    await main.getByRole('button', { name: 'Orqaga', exact: true }).click();
    await main.locator('[data-stage="exercise"]').waitFor({ state: 'visible' });
    await snap(page, 'scene2_mobile_390_dark.png');
    await main.getByRole('button', { name: 'Orqaga', exact: true }).click();
    await main.locator('[data-stage="discovery"]').waitFor({ state: 'visible' });
    await snap(page, 'scene1_mobile_390_dark.png');

    await context.close();
    assertions += 7;
    console.log('PASS 390px mobile Light/Dark first-fold visibility & zero overflow');
  }

  // 5. Blocked localStorage fallback + Direct routes + Auth callback guard
  {
    const { context, page } = await openFreshContext({
      initScript: () => {
        const denied = () => {
          throw new DOMException('Blocked by privacy mode', 'SecurityError');
        };
        Object.defineProperty(Storage.prototype, 'getItem', { value: denied, configurable: true });
        Object.defineProperty(Storage.prototype, 'setItem', { value: denied, configurable: true });
      },
    });
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    const main = page.getByRole('main');
    await main.getByRole('heading', { level: 1, name: 'Qaysi dars aynan sizga mos?' }).waitFor();
    await main.getByRole('button', { name: 'O‘tkazib yuborish', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: /O‘zingizga mos\s+yo‘ldan o‘rganing\./ }).waitFor();
    await context.close();

    // Direct routes & auth callback bypass tour
    const direct = await openFreshContext();
    await direct.page.goto(base + '/login', { waitUntil: 'domcontentloaded' });
    await direct.page.getByRole('heading', { level: 1, name: 'Xush kelibsiz!' }).waitFor();
    await direct.page.goto(base + '/#access_token=dummy&type=recovery', { waitUntil: 'domcontentloaded' });
    assert.equal(
      await direct.page.getByRole('button', { name: 'Sinab ko‘rish', exact: true }).count(),
      0,
    );
    await direct.context.close();
    assertions += 3;
    console.log('PASS blocked storage fallback, direct route & auth callback guard');
  }

  // 6. Active Demo Session + Profile Replay returns to Profile
  {
    const { context, page } = await openFreshContext({ viewport: { width: 1280, height: 800 } });
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    const main = page.getByRole('main');
    await main.getByRole('button', { name: 'O‘tkazib yuborish', exact: true }).click();
    await main.getByRole('button', { name: 'Namuna hisobi bilan kirish', exact: true }).click();
    await main.getByRole('heading', { name: 'O‘zingizga mos fanni tanlang' }).waitFor();
    await main.getByRole('button', { name: /Ingliz tili fanini tanlash/ }).click();
    await main.getByRole('radio', { name: /Noldan boshlayman/ }).check();
    await main.getByRole('button', { name: 'Birinchi darsni boshlash', exact: true }).click();
    await main.getByRole('heading', { name: 'Birinchi inglizcha so‘zlar' }).waitFor();

    // Reloading root while active demo session exists must bypass Product Tour
    await page.goto(base + '/', { waitUntil: 'domcontentloaded' });
    await main.getByRole('heading', { name: /Assalomu alaykum/ }).waitFor();
    assert.equal(await main.getByRole('button', { name: 'Sinab ko‘rish', exact: true }).count(), 0);

    // Navigate to Profile -> Tanishtiruvni qayta ko‘rish -> Complete -> returns to Profile
    await page.getByRole('button', { name: 'Profil', exact: true }).first().click();
    await main.getByRole('heading', { level: 1, name: 'Profil' }).waitFor();
    await main.getByRole('button', { name: 'Tanishtiruvni qayta ko‘rish', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: 'Qaysi dars aynan sizga mos?' }).waitFor();
    await main.getByRole('button', { name: 'Sinab ko‘rish', exact: true }).click();
    await main.getByRole('button', { name: 'Keyingi', exact: true }).click();
    await main.getByRole('button', { name: 'Boshlash', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: 'Profil' }).waitFor();

    // Replay again -> Skip -> also returns to Profile
    await main.getByRole('button', { name: 'Tanishtiruvni qayta ko‘rish', exact: true }).click();
    await main.getByRole('button', { name: 'O‘tkazib yuborish', exact: true }).click();
    await main.getByRole('heading', { level: 1, name: 'Profil' }).waitFor();

    await context.close();
    assertions += 4;
    console.log('PASS active demo session bypass & Profile replay -> returns to Profile');
  }

  // 7. Full Keyboard Navigation & Focus Order across all 3 scenes
  {
    const { context, page } = await openFreshContext({ viewport: { width: 1280, height: 800 } });
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    const main = page.getByRole('main');

    async function tabToButton(targetName) {
      for (let step = 0; step < 25; step++) {
        await page.keyboard.press('Tab');
        const activeText = await page.evaluate(() => document.activeElement?.textContent?.trim() ?? '');
        const tag = await page.evaluate(() => document.activeElement?.tagName ?? '');
        if (tag === 'BUTTON' && activeText.includes(targetName)) {
          return;
        }
      }
      throw new Error(`Could not Tab to button containing "${targetName}"`);
    }

    await tabToButton('Sinab ko‘rish');
    await page.keyboard.press('Enter');
    await main.getByRole('heading', { level: 1, name: 'Bir savolni sinab ko‘ring.' }).waitFor();

    await tabToButton('am');
    await page.keyboard.press('Enter');
    await main.getByText('I bilan am ishlatiladi: I am a student.', { exact: true }).waitFor();

    await tabToButton('Keyingi');
    await page.keyboard.press('Enter');
    await main.getByRole('heading', { level: 1, name: 'Keyingi qadamingiz ko‘rinib turadi.' }).waitFor();

    await tabToButton('Boshlash');
    await page.keyboard.press('Enter');
    await main.getByRole('heading', { level: 1, name: /O‘zingizga mos\s+yo‘ldan o‘rganing\./ }).waitFor();

    await context.close();
    assertions += 4;
    console.log('PASS keyboard-only navigation across all 3 tour scenes');
  }

  assert.deepEqual(errors, []);
  console.log(`PRODUCT TOUR E2E PASSED — ${assertions} verification groups passed with 0 page errors`);
} catch (error) {
  console.error('Product Tour E2E failed:', error);
  process.exitCode = 1;
} finally {
  await browser.close();
}
