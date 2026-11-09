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
  await heading('O‘rganish rejangizni sozlang');
  await main.getByRole('radio', { name: new RegExp(level) }).check();
}

async function switchSubject(subject) {
  await click('Fanni almashtirish', page);
  await heading('O‘zingizga mos fanni tanlang');
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
  await context.addInitScript(() => {
    localStorage.setItem('bilimyol_auth_session', JSON.stringify({
      isDemoMode: true, profile: { id: 'guest_user_01', role: 'student', firstName: 'Oldingi namuna' },
    }));
  });
  await page.goto(base, { waitUntil: 'domcontentloaded' });
  await heading('O‘zingizga mos yo‘ldan o‘rganing.');
  await screenshot('after-welcome-1440.png');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkWidth('welcome', 390);
  await screenshot('after-welcome-390.png');
  await page.setViewportSize({ width: 1440, height: 960 });
  await click('Kirish');
  await heading('Xush kelibsiz!');
  await click('Parolni ko‘rsatish');
  assert.equal(await page.getByLabel('Parol', { exact: true }).getAttribute('type'), 'text');
  await click('Parolni yashirish');
  assert.equal(await page.getByLabel('Parol', { exact: true }).getAttribute('type'), 'password');
  await page.getByLabel('Email manzilingiz').fill('offline@example.test');
  await page.getByLabel('Parol', { exact: true }).fill('test-password');
  await click('Kirish');
  await main.getByRole('alert').getByText(/Hisob xizmatiga ulanib bo‘lmadi/).waitFor();
  await heading('Xush kelibsiz!');
  await screenshot('kirish-1440.png');
  await click('Namuna hisobi bilan kirish');
  await heading('O‘zingizga mos fanni tanlang');
  for (const course of [/Matematika/, /Ingliz tili/, /IT & Kodlash/, /Mantiq/]) {
    assert.equal(await main.getByRole('button', { name: new RegExp(course.source + ' fanini tanlash') }).count(), 1);
  }
  const fresh = await browser.newPage({ storageState: await context.storageState() });
  await fresh.goto(base, { waitUntil: 'domcontentloaded' });
  await fresh.getByRole('heading', { name: 'O‘zingizga mos yo‘ldan o‘rganing.' }).waitFor();
  await fresh.close();

  await click(/Ingliz tili fanini tanlash/);
  await chooseLearningPlan('Noldan boshlayman');
  assert.equal(await main.getByRole('button', { name: 'Ixtiyoriy diagnostika' }).count(), 0);
  await click('Birinchi darsni boshlash');
  await heading('Birinchi inglizcha so‘zlar');
  await heading('Asosiy tushuncha');
  await main.getByText(/«Hello» — salom/).first().waitFor();
  assert.equal(await main.getByRole('button', { name: 'Test', exact: true }).count(), 0);
  await page.setViewportSize({ width: 390, height: 844 });
  await screenshot('ilk-ingliz-darsi-390.png');
  await page.setViewportSize({ width: 1440, height: 960 });
  await click('Keyingi qadam');
  await heading('Birga misol ko‘ramiz');
  await click('Yo‘lchidan so‘rash');
  const help = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
  await help.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' }).fill('Hello qachon ishlatiladi?');
  await click('Savolni yuborish', help);
  await help.getByRole('button', { name: 'Foydali javob' }).waitFor();
  await click('Yopish', help);
  await heading('Birga misol ko‘ramiz');
  await page.reload({ waitUntil: 'domcontentloaded' });
  await heading('Birga misol ko‘ramiz');
  await click('Keyingi qadam');
  await heading('O‘rganganingizni sinab ko‘ring');
  await click('Ta’lim yo‘liga qaytish');
  await heading('Boshlang‘ich darslar');
  console.log('PASS welcome, one-tap subject choice, beginner instruction, contextual help and reading checkpoint');

  await switchSubject(/IT & Kodlash fanini tanlash/);
  await chooseLearningPlan('Asoslarini bilaman');
  await click('Ta’lim yo‘lini ochish');
  await heading('Mening ta’lim yo‘lim');
  await click('Bosh sahifa', nav);
  await click('Davom etish');
  await heading(/Python/);
  assert.equal(await main.getByRole('heading', { name: 'Kvadratni ochish' }).count(), 0);
  await click('Ta’lim yo‘liga qaytish');
  await switchSubject(/Matematika fanini tanlash/);
  await chooseLearningPlan('Asoslarini bilaman');
  await click('Ta’lim yo‘lini ochish');
  await heading('Mening ta’lim yo‘lim');
  await click('Bosh sahifa', nav);
  await click('Davom etish');
  await heading('Kvadratni ochish');
  await click('Test');
  await heading(/yoyilmasida x oldidagi/);
  assert.equal(await main.getByText(/To‘g‘ri javob:/).count(), 0);
  await main.getByText('4', { exact: true }).click();
  await click(/Tekshirish/i);
  await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor();
  const dialog = page.getByRole('dialog', { name: 'Dars yakunlandi' });
  await dialog.waitFor();
  await page.keyboard.press('Tab');
  assert(await dialog.evaluate((node) => node.contains(document.activeElement)));
  await click('Ta’lim yo‘liga o‘tish', dialog);
  await click('Natijalar', nav);
  await main.getByText('22', { exact: true }).first().waitFor();
  await switchSubject(/Ingliz tili fanini tanlash/);
  await click('Davom etish');
  await heading('Birinchi inglizcha so‘zlar');
  await page.reload({ waitUntil: 'domcontentloaded' });
  await heading('Birinchi inglizcha so‘zlar');
  await click('Ta’lim yo‘liga qaytish');
  await switchSubject(/Matematika fanini tanlash/);
  await heading(/Assalomu alaykum/);
  await screenshot('after-learn-1440.png');
  await click('Natijalar', nav);
  await main.getByText('22', { exact: true }).first().waitFor();
  console.log('PASS demo login, course isolation, authoritative demo scorer and completion');

  await click('Yo‘lchi AI', nav);
  await heading('Yo‘lchi AI');
  await page.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' }).fill('Kvadratni qanday ochaman?');
  await click('Savolni yuborish');
  await main.getByRole('button', { name: 'Foydali javob' }).waitFor();
  await click('Foydali javob');
  assert.equal(await main.getByRole('button', { name: 'Foydali javob' }).getAttribute('aria-pressed'), 'true');
  await click('Natijalar', nav);
  await heading('Ta’lim ko‘rsatkichlari');
  await click('Yo‘lchi AI', nav);
  await main.getByText('Kvadratni qanday ochaman?', { exact: true }).waitFor();
  await screenshot('yolchi-1440.png');
  console.log('PASS demo tutor, feedback and in-session conversation history');

  const views = [
    ['dashboard', /Assalomu alaykum/],
    ['course-selection', /O‘zingizga mos fanni tanlang/],
    ['onboarding', /Maqsad|Boshlaymiz|O‘rganish/i],
    ['placement', 'Boshlang‘ich diagnostika'],
    ['knowledge-map', 'Bilim xaritasi'],
    ['roadmap', 'Mening ta’lim yo‘lim'],
    ['lesson&lessonId=lesson_math_algebra_01', 'Kvadratni ochish'],
    ['lesson&lessonId=lesson_math_starter', 'Qo‘shish va ayirishdan boshlaymiz'],
    ['ai-tutor', 'Yo‘lchi AI'],
    ['progress', 'Ta’lim ko‘rsatkichlari'],
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
    await heading('Ta’lim ko‘rsatkichlari');
    await page.goBack();
    await heading('Profil');
    console.log('PASS ' + width + 'px, ' + views.length + ' screens, navigation and browser Back');
  }

  const language = page.locator('#interface-language');
  const root = page.locator('html');
  assert.equal(await language.inputValue(), 'uz');
  assert.equal(await root.getAttribute('data-theme'), 'light');
  const lightBackground = await page.locator('body').evaluate((node) => getComputedStyle(node).backgroundColor);
  await click('Qorong‘i rejimni yoqish', page);
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
    ['lesson&lessonId=lesson_math_algebra_01', 'Kvadratni ochish'],
    ['ai-tutor', 'Yo‘lchi AI'],
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
  await page.getByRole('textbox', { name: 'Напишите вопрос Yo‘lchi AI' }).fill('Как раскрыть квадрат?');
  await click('Отправить вопрос');
  await main.getByText(/Давайте разберём вопрос по шагам/).waitFor();
  await language.selectOption('uz');
  await main.getByRole('button', { name: 'Savolni yuborish' }).waitFor();
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
