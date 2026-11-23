import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { chromium } from 'playwright';

const base = process.env.BASE_URL;
assert(base, 'Use npm run test:e2e for an isolated demo build.');
const screenshots = process.env.QA_SCREENSHOT_DIR;
if (screenshots) await mkdir(screenshots, { recursive: true });

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1440, height: 960 }, reducedMotion: 'reduce' });
const page = await context.newPage();
const errors = [];
const remoteRequests = [];
page.on('pageerror', (error) => errors.push(error.message));
page.on('request', (request) => {
  if (new URL(request.url()).hostname.endsWith('.supabase.co')) remoteRequests.push(new URL(request.url()).pathname);
});
page.setDefaultTimeout(12000);
const main = page.getByRole('main');
const nav = page.getByRole('navigation', { name: 'Asosiy navigatsiya' });
const click = (name, root = main) => root.getByRole('button', { name, exact: typeof name === 'string' }).click();
const heading = (name) => main.getByRole('heading', { name }).first().waitFor({ state: 'visible' });
const screenshot = async (filename) => {
  if (screenshots) await page.screenshot({ path: join(screenshots, filename), animations: 'disabled' });
};
let assertions = 0;

async function chooseLearningPlan(level) {
  await heading('Örganiş rejangizni sozlang');
  await main.getByRole('radio', { name: new RegExp(level) }).check();
}

async function switchSubject(subject) {
  await click('Fanni almaştiriş', page);
  await heading('Özingizga mos fanni tanlang');
  await click(subject);
}

async function checkWidth(view, width) {
  const sizes = await page.evaluate(() => ({
    width: document.documentElement.clientWidth,
    scroll: document.documentElement.scrollWidth,
  }));
  assert(sizes.scroll <= sizes.width + 1, view + ' overflow at ' + width + 'px: ' + JSON.stringify(sizes));
  assertions++;
}

try {
  let releaseFonts;
  const fontResponse = new Promise((resolve) => { releaseFonts = resolve; });
  await page.route('https://fonts.googleapis.com/**', async (route) => {
    await fontResponse;
    await route.fulfill({ contentType: 'text/css', body: '/* Fonts intentionally delayed by this test. */' });
  });
  await context.addInitScript(() => {
    localStorage.setItem('bilimyol_auth_session', JSON.stringify({
      isDemoMode: true, profile: { id: 'guest_user_01', role: 'student', firstName: 'Oldingi namuna' },
    }));
  });
  await page.goto(base, { waitUntil: 'domcontentloaded' });
  await heading('Qaysi dars aynan sizga mos?');
  assert.equal(await page.locator('#bilimyol-fonts').getAttribute('media'), 'print');
  releaseFonts();
  await page.waitForFunction(() => document.querySelector('#bilimyol-fonts')?.media === 'all');
  console.log('PASS delayed external fonts do not block the first-visit product tour');
  await click('Ötkazib yuboriş');
  await heading('Özingizga mos yöldan örganing.');
  await screenshot('after-welcome-1440.png');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkWidth('welcome', 390);
  await screenshot('after-welcome-390.png');
  await page.setViewportSize({ width: 1440, height: 960 });
  await click('Kiriş');
  await heading('Xuş kelibsiz!');
  await click('Parolni körsatiş');
  assert.equal(await page.getByLabel('Parol', { exact: true }).getAttribute('type'), 'text');
  await click('Parolni yaşiriş');
  assert.equal(await page.getByLabel('Parol', { exact: true }).getAttribute('type'), 'password');
  await page.getByLabel('Email manzilingiz').fill('offline@example.test');
  await page.getByLabel('Parol', { exact: true }).fill('test-password');
  await click('Kiriş');
  await main.getByRole('alert').getByText(/Hisob xizmatiga ulanib bölmadi/).waitFor();
  await heading('Xuş kelibsiz!');
  await screenshot('kiriş-1440.png');
  await click('Namuna hisobi bilan kiriş');
  await heading('Özingizga mos fanni tanlang');
  for (const course of [/Matematika/, /Ingliz tili/, /IT & Kodlaş/, /Mantiq/]) {
    assert.equal(await main.getByRole('button', { name: new RegExp(course.source + ' fanini tanlaş') }).count(), 1);
  }
  const fresh = await browser.newPage({ storageState: await context.storageState() });
  await fresh.goto(base, { waitUntil: 'domcontentloaded' });
  await fresh.getByRole('heading', { name: 'Özingizga mos yöldan örganing.' }).waitFor();
  await fresh.close();

  await click(/Mantiq fanini tanlaş/);
  await main.getByRole('region', { name: 'Boşlanğiç reja namunasi' }).getByText('Rost va yolğon gaplar', { exact: false }).waitFor();
  assert.equal(await main.locator('input[name="learning-level"]:checked').count(), 0);
  await chooseLearningPlan('Noldan boşlayman');
  const livePlan = main.getByRole('region', { name: 'Örganiş rejangiz' });
  await livePlan.getByText('Rost va yolğon gaplar', { exact: false }).waitFor();
  await livePlan.getByText('14 daqiqa', { exact: true }).first().waitFor();
  await main.getByRole('radio', { name: '30 daqiqa' }).check();
  await livePlan.getByText('28 daqiqa', { exact: true }).first().waitFor();
  await screenshot('reja-1440.png');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkWidth('learning plan preview', 390);
  await livePlan.scrollIntoViewIfNeeded();
  await screenshot('reja-390.png');
  await page.setViewportSize({ width: 1440, height: 960 });
  await main.getByRole('radio', { name: /Asoslarini bilaman/ }).check();
  await main.getByLabel('Maqsad', { exact: true }).selectOption('skills_boost');
  await click('Ta’lim yölini oçiş');
  await heading('Mening ta’lim yölim');
  await livePlan.getByText('Kuniga 30 daqiqa', { exact: true }).waitFor();
  await livePlan.getByRole('button', { name: 'Davom etiş' }).waitFor();
  await click('Rejani sozlaş');
  assert.equal(await main.getByRole('radio', { name: '30 daqiqa' }).isChecked(), true);
  assert.equal(await main.getByLabel('Maqsad', { exact: true }).inputValue(), 'skills_boost');
  await main.getByRole('radio', { name: '15 daqiqa' }).check();
  await click('Rejani saqlaş');
  await livePlan.getByText('Kuniga 15 daqiqa', { exact: true }).waitFor();
  await switchSubject(/Ingliz tili fanini tanlaş/);
  await chooseLearningPlan('Noldan boşlayman');
  assert.equal(await main.getByRole('button', { name: 'Ixtiyoriy diagnostika' }).count(), 0);
  await click('Birinçi darsni boşlaş');
  await heading('Birinçi inglizça sözlar');
  await heading('Asosiy tuşunça');
  await main.getByText(/«Hello» — salom/).first().waitFor();
  assert.equal(await main.getByRole('button', { name: 'Test', exact: true }).count(), 0);
  await page.setViewportSize({ width: 390, height: 844 });
  await screenshot('ilk-ingliz-darsi-390.png');
  await page.setViewportSize({ width: 1440, height: 960 });
  await click('Keyingi qadam');
  await heading('Birga misol köramiz');
  await click('Yölçidan söraş');
  const help = page.getByRole('dialog', { name: 'Yölçi bilan şu dars haqida' });
  await help.getByRole('textbox', { name: 'Yölçi AI ga savol yozing' }).fill('Hello qaçon işlatiladi?');
  await click('Savolni yuboriş', help);
  await help.getByRole('button', { name: 'Foydali javob' }).waitFor();
  await click('Yopiş', help);
  await heading('Birga misol köramiz');
  await page.reload({ waitUntil: 'domcontentloaded' });
  await heading('Birga misol köramiz');
  await click('Keyingi qadam');
  await heading('Iboralarni eslab qolamiz');
  await click('Keyingi qadam');
  await heading('Örganganingizni sinab köring');
  await click('Ta’lim yöliga qaytiş');
  await heading('Boşlanğiç darslar');
  console.log('PASS welcome, one-tap subject choice, beginner instruction, contextual help and reading checkpoint');

  await switchSubject(/IT & Kodlaş fanini tanlaş/);
  await chooseLearningPlan('Asoslarini bilaman');
  await click('Ta’lim yölini oçiş');
  await heading('Mening ta’lim yölim');
  await click('Boş sahifa', nav);
  await click('Davom etiş');
  await heading(/Python/);
  assert.equal(await main.getByRole('heading', { name: 'Kvadratni oçiş' }).count(), 0);
  await click('Ta’lim yöliga qaytiş');
  await switchSubject(/Matematika fanini tanlaş/);
  await chooseLearningPlan('Asoslarini bilaman');
  await click('Ta’lim yölini oçiş');
  await heading('Mening ta’lim yölim');
  await click('Boş sahifa', nav);
  await click('Davom etiş');
  await heading('Kvadratni oçiş');
  await click('Test');
  await heading(/yoyilmasida x oldidagi/);
  assert.equal(await main.getByText(/Töğri javob:/).count(), 0);
  await main.getByText('4', { exact: true }).click();
  await click(/Tekşiriş/i);
  await main.getByText('Töğri javob!', { exact: true }).waitFor();
  const dialog = page.getByRole('dialog', { name: 'Dars yakunlandi' });
  await dialog.waitFor();
  await page.keyboard.press('Tab');
  assert(await dialog.evaluate((node) => node.contains(document.activeElement)));
  await click('Ta’lim yöliga ötiş', dialog);
  await click('Natijalar', nav);
  await main.getByText('22', { exact: true }).first().waitFor();
  await switchSubject(/Ingliz tili fanini tanlaş/);
  await click('Davom etiş');
  await heading('Birinçi inglizça sözlar');
  await page.reload({ waitUntil: 'domcontentloaded' });
  await heading('Birinçi inglizça sözlar');
  await click('Ta’lim yöliga qaytiş');
  await switchSubject(/Matematika fanini tanlaş/);
  await heading(/Assalomu alaykum/);
  await screenshot('after-learn-1440.png');
  await page.setViewportSize({ width: 360, height: 844 });
  await click('Bildirişnomalar');
  await checkWidth('open reminders', 360);
  await main.getByRole('button', { name: 'Yopiş', exact: true }).click();
  await page.setViewportSize({ width: 1440, height: 960 });
  await click('Profil');
  await main.getByRole('checkbox', { name: /eslatma/i }).uncheck();
  await click('Boş sahifa', nav);
  await heading(/Assalomu alaykum/);
  await main.getByRole('button', { name: 'Bildirişnomalar' }).waitFor({ state: 'hidden' });
  await click('Profil');
  await main.getByRole('checkbox', { name: /eslatma/i }).check();
  await click('Boş sahifa', nav);
  await main.getByRole('button', { name: 'Bildirişnomalar' }).waitFor();
  console.log('PASS reminder preference and 360px notification menu');
  await click('Natijalar', nav);
  await main.getByText('22', { exact: true }).first().waitFor();
  console.log('PASS demo login, course isolation, authoritative demo scorer and completion');

  await click('Yölçi AI', nav);
  await heading('Yölçi AI');
  await page.getByRole('textbox', { name: 'Yölçi AI ga savol yozing' }).fill('Kvadratni qanday oçaman?');
  await click('Savolni yuboriş');
  await main.getByRole('button', { name: 'Foydali javob' }).waitFor();
  await click('Foydali javob');
  assert.equal(await main.getByRole('button', { name: 'Foydali javob' }).getAttribute('aria-pressed'), 'true');
  await click('Natijalar', nav);
  await heading('Ta’lim körsatkiçlari');
  await click('Yölçi AI', nav);
  await main.getByText('Kvadratni qanday oçaman?', { exact: true }).waitFor();
  await screenshot('yolchi-1440.png');
  await page.setViewportSize({ width: 390, height: 844 });
  await screenshot('yolchi-390.png');
  await page.setViewportSize({ width: 1440, height: 960 });
  console.log('PASS demo tutor, feedback and in-session conversation history');

  const views = [
    ['dashboard', /Assalomu alaykum/],
    ['course-selection', /Özingizga mos fanni tanlang/],
    ['onboarding', /Maqsad|Boşlaymiz|Örganiş/i],
    ['placement', 'Boşlanğiç diagnostika'],
    ['knowledge-map', 'Bilim xaritasi'],
    ['roadmap', 'Mening ta’lim yölim'],
    ['lesson&lessonId=lesson_math_algebra_01', 'Kvadratni oçiş'],
    ['lesson&lessonId=lesson_math_starter', 'Qöşiş va ayirişdan boşlaymiz'],
    ['ai-tutor', 'Yölçi AI'],
    ['progress', 'Ta’lim körsatkiçlari'],
    ['profile', 'Profil'],
  ];
  for (const width of [360, 390, 768, 1024, 1440, 1920]) {
    await page.setViewportSize({ width, height: width <= 390 ? 844 : 960 });
    for (const [view, title] of views) {
      await page.goto(base + '/?view=' + view, { waitUntil: 'domcontentloaded' });
      await heading(title);
      await checkWidth(view, width);
      if (width === 390 && ['dashboard', 'lesson&lessonId=lesson_math_algebra_01', 'profile'].includes(view)) {
        await screenshot((view === 'dashboard' ? 'after-learn' : view.split('&')[0]) + '-390.png');
      }
    }
    const targetNav = width < 1024
      ? page.getByRole('navigation', { name: 'Mobil navigatsiya' })
      : nav;
    await click('Natijalar', targetNav);
    await heading('Ta’lim körsatkiçlari');
    await page.goBack();
    await heading('Profil');
    console.log('PASS ' + width + 'px, ' + views.length + ' screens, navigation and browser Back');
  }

  const language = page.locator('#interface-language');
  const root = page.locator('html');
  assert.equal(await language.inputValue(), 'uz');
  assert.equal(await root.getAttribute('data-theme'), 'light');
  const lightBackground = await page.locator('body').evaluate((node) => getComputedStyle(node).backgroundColor);
  await click('Qoronği rejimni yoqiş', page);
  await language.selectOption('ru');
  await click('Включить светлую тему', page);
  assert.equal(await root.getAttribute('data-theme'), 'light');
  await click('Включить тёмную тему', page);
  assert.notEqual(await page.locator('body').evaluate((node) => getComputedStyle(node).backgroundColor), lightBackground);
  await page.reload();
  await heading('Профиль');
  assert.equal(await root.getAttribute('lang'), 'ru');
  assert.equal(await root.getAttribute('data-theme'), 'dark');
  assert.equal(await language.inputValue(), 'ru');

  const russianViews = [
    ['dashboard', /Здравствуйте/],
    ['course-selection', 'Выберите подходящий предмет'],
    ['onboarding', 'Настройте свой план обучения'],
    ['placement', 'Входная диагностика'],
    ['knowledge-map', 'Карта знаний'],
    ['roadmap', 'Мой путь обучения'],
    ['lesson&lessonId=lesson_math_algebra_01', 'Kvadratni oçiş'],
    ['ai-tutor', 'Yölçi AI'],
    ['progress', 'Результаты обучения'],
    ['profile', 'Профиль'],
  ];
  for (const width of [390, 1440]) {
    await page.setViewportSize({ width, height: 960 });
    for (const [view, title] of russianViews) {
      await page.goto(base + '/?view=' + view, { waitUntil: 'domcontentloaded' });
      await heading(title);
      assert.equal(await root.getAttribute('data-theme'), 'dark');
      await checkWidth(view + ' (ru, dark)', width);
      if (view === 'dashboard') await screenshot('dashboard-ru-dark-' + width + '.png');
    }
  }
  await page.goto(base + '/?view=ai-tutor');
  await page.getByRole('textbox', { name: 'Напишите вопрос Yölçi AI' }).fill('Как раскрыть квадрат?');
  await click('Отправить вопрос');
  await main.getByText(/Давайте разберём вопрос по шагам/).waitFor();
  await language.selectOption('uz');
  await main.getByRole('button', { name: 'Savolni yuboriş' }).waitFor();
  console.log('PASS theme and language switching, reload, Russian tutor demo and 20 Russian dark layouts');
  assert.deepEqual(remoteRequests, []);
  assert.deepEqual(errors, []);
  console.log('E2E PASSED — ' + assertions + ' layout assertions and demo journeys');
} catch (error) {
  console.error('Demo journey failed:', error.message);
  console.error('Current path:', new URL(page.url()).pathname + new URL(page.url()).search);
  console.error('Visible headings:', await main.getByRole('heading').allTextContents());
  process.exitCode = 1;
} finally {
  await browser.close();
}
