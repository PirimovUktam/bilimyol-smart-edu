import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';

const localUrl = (key) => {
  const url = new URL(process.env[key]);
  if (url.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(url.hostname) || url.username || url.password) {
    throw new Error(key + ' must point to a disposable loopback service.');
  }
  return url.origin;
};
const app = localUrl('E2E_APP_URL');
const backend = localUrl('E2E_SUPABASE_URL');
const mail = localUrl('E2E_MAIL_URL');
const key = process.env.E2E_SUPABASE_ANON_KEY;
assert(key, 'A loopback Supabase anonymous key is required.');
const api = () => createClient(backend, key, { auth: { autoRefreshToken: false, persistSession: false } });
const learner = () => ({ email: 'qa+' + randomUUID() + '@example.test', password: 'QA-' + randomUUID() });
const waitFor = (locator) => locator.waitFor({ state: 'visible', timeout: 15000 });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 960 } });
await page.route('https://fonts.googleapis.com/**', (route) => route.abort());
await page.route('https://fonts.gstatic.com/**', (route) => route.abort());
const errors = [];
const failedRequests = [];
const placementRequests = [];
const diagnosisRequests = [];
page.on('pageerror', (error) => errors.push(error.name));
page.on('response', (response) => {
  const url = new URL(response.url());
  if (url.origin === backend && response.status() >= 400) {
    failedRequests.push(url.pathname + ' ' + response.status());
  }
});
page.on('request', (request) => {
  if (new URL(request.url()).pathname.endsWith('/rpc/advance_placement')) placementRequests.push(request.method());
  if (new URL(request.url()).pathname.endsWith('/functions/v1/yolchi-tutor') &&
      request.method() === 'POST' && request.postDataJSON()?.action === 'diagnose_mistake') {
    diagnosisRequests.push(request);
  }
});
page.setDefaultTimeout(15000);
const click = (name, root = page) => root.getByRole('button', { name, exact: typeof name === 'string' }).click();
const heading = (name) => page.getByRole('heading', { name });
const nav = page.getByRole('navigation', { name: 'Asosiy navigatsiya' });
const main = page.getByRole('main');
const first = learner();
const second = learner();

async function switchSubject(name) {
  await click('Fanni almashtirish');
  await waitFor(heading('O‘zingizga mos fanni tanlang'));
  await click(name, main);
}

async function signup(account) {
  await page.goto(app, { waitUntil: 'domcontentloaded' });
  await click('Ro‘yxatdan o‘tish');
  await page.getByLabel('Ism', { exact: true }).fill('Sinovchi');
  await page.getByLabel('Familiya', { exact: true }).fill('Oquvchi');
  await page.getByLabel('Email manzilingiz', { exact: true }).fill(account.email);
  await page.getByLabel('Parol', { exact: true }).fill(account.password);
  await page.getByLabel('Parolni takrorlang', { exact: true }).fill(account.password);
  await click('Ro‘yxatdan o‘tish');
  await waitFor(heading('O‘zingizga mos fanni tanlang'));
}

async function login(account, password = account.password) {
  await page.getByLabel('Email manzilingiz', { exact: true }).fill(account.email);
  await page.getByLabel('Parol', { exact: true }).fill(password);
  await click('Kirish');
}

async function mailLink(email) {
  for (let retry = 0; retry < 30; retry++) {
    const index = await fetch(mail + '/api/v1/messages').then((response) => response.json());
    const message = index.messages?.find((item) => item.To?.some((recipient) => recipient.Address === email));
    if (message) {
      const { HTML, Text } = await fetch(mail + '/api/v1/message/' + message.ID).then((response) => response.json());
      const link = (HTML ?? '').match(/href="([^"]+\/auth\/v1\/verify[^"]+)"/)?.[1] ??
        (Text ?? '').match(/https?:\/\/[^\s<>]+\/auth\/v1\/verify[^\s<>]+/)?.[0];
      if (link) {
        const url = new URL(link.replaceAll('&amp;', '&'));
        assert.equal(url.origin, backend, 'Recovery must stay on the disposable server.');
        return url.href;
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  throw new Error('Recovery message did not reach the local mailbox.');
}

try {
  await signup(first);
  await waitFor(main.getByRole('button', { name: /Matematika fanini tanlash/ }));
  await click('Bosh sahifa', nav);
  await waitFor(heading(/Assalomu alaykum, Sinovchi/));
  assert.equal(await page.evaluate(() => localStorage.getItem('bilimyol_auth_session')), null);
  await waitFor(main.getByRole('button', { name: 'Fan tanlash', exact: true }));
  console.log('PASS configured signup and authoritative profile');

  await switchSubject(/Ingliz tili fanini tanlash/);
  await main.getByRole('radio', { name: /Noldan boshlayman/ }).check();
  await click('Birinchi darsni boshlash', main);
  await waitFor(heading('Birinchi inglizcha so‘zlar'));
  await waitFor(heading('Asosiy tushuncha'));
  assert.deepEqual(placementRequests, [], 'Starting from zero never opens a diagnostic session.');
  assert.equal(await main.getByRole('button', { name: 'Test', exact: true }).count(), 0);
  await click('Keyingi qadam', main);
  await waitFor(heading('Birga misol ko‘ramiz'));
  await page.reload({ waitUntil: 'domcontentloaded' });
  await waitFor(heading('Birga misol ko‘ramiz'));
  await click('Ta’lim yo‘liga qaytish', main);
  await click('Bosh sahifa', nav);
  await click('Davom etish', main);
  await waitFor(heading('Birinchi inglizcha so‘zlar'));
  await page.goto(app + '/?view=lesson&lessonId=lesson_math_algebra_01', { waitUntil: 'domcontentloaded' });
  await waitFor(heading('Dars noto‘g‘ri fanda'));
  assert.equal(await heading('Kvadratni ochish').count(), 0);
  console.log('PASS configured beginner starts with English instruction, resumes after reload, and cannot open a foreign lesson');

  await click('Yo‘l xaritasiga qaytish', main);
  await switchSubject(/Matematika fanini tanlash/);
  await main.getByRole('radio', { name: /Asoslarini bilaman/ }).check();
  await click('Ta’lim yo‘lini ochish', main);
  await waitFor(heading('Mening ta’lim yo‘lim'));
  await click('Bosh sahifa', nav);
  await click('Davom etish', main);
  await waitFor(heading('Kvadratni ochish'));
  await click('Test', main);
  await waitFor(heading(/yoyilmasida x oldidagi/));
  assert.equal(await main.getByText(/To‘g‘ri javob:/).count(), 0);
  await main.getByText('4', { exact: true }).click();
  await click(/Tekshirish/i, main);
  await waitFor(main.getByText('To‘g‘ri javob: 8', { exact: true }));
  assert.equal(diagnosisRequests.length, 0, 'Scoring does not depend on AI.');
  await click('Yo‘lchi AI tahlili', main);
  const diagnosisPanel = page.getByRole('dialog', { name: 'Yo‘lchi bilan xato tahlili' });
  await waitFor(diagnosisPanel.getByText('Tayyor izoh', { exact: true }));
  assert.equal(diagnosisRequests.length, 1);
  await click('Yopish', diagnosisPanel);
  await click('Qayta urinish', main);
  console.log('PASS wrong answer feedback is independent of AI, then explicit diagnosis and retry work');
  await main.getByText('8', { exact: true }).click();
  await click(/Tekshirish/i, main);
  await waitFor(main.getByText('To‘g‘ri javob!', { exact: true }));
  await waitFor(page.getByRole('heading', { name: /Dars.*yakunlandi/i }));
  await click('Ta’lim yo‘liga o‘tish');
  await click('Natijalar', nav);
  await page.reload({ waitUntil: 'domcontentloaded' });
  await waitFor(main.getByText('22', { exact: true }).first());

  const owner = api();
  const ownerAuth = await owner.auth.signInWithPassword(first);
  assert(!ownerAuth.error && ownerAuth.data.user, 'Owner signs in through Auth.');
  const ownerId = ownerAuth.data.user.id;
  const plans = await owner.from('learner_profiles').select('course_levels').eq('user_id', ownerId).single();
  assert.deepEqual(plans.data?.course_levels, { course_eng_01: 'beginner', course_math_01: 'intermediate' });
  const completed = await owner.from('lesson_progress').select('lesson_id,status').eq('user_id', ownerId).single();
  assert.deepEqual(completed.data, { lesson_id: 'lesson_math_algebra_01', status: 'completed' });
  const stats = await owner.from('gamification_profiles').select('xp').eq('user_id', ownerId).single();
  assert.equal(stats.data?.xp, 22);
  console.log('PASS answer scored, lesson completed, XP persisted after reload');

  await switchSubject(/Ingliz tili fanini tanlash/);
  await click(/Ixtiyoriy diagnostika/, main);
  await waitFor(heading('Boshlang‘ich diagnostika'));
  const step = (number) => main.getByText(number + ' / 8 savol', { exact: true });
  const option = () => main.getByRole('radio').first();
  await waitFor(step(1));
  await option().check();
  await click('Keyingi savol', main);
  await waitFor(step(2));
  await page.reload({ waitUntil: 'domcontentloaded' });
  await waitFor(step(2));
  const unfinished = await owner.from('placement_attempts').select('id').eq('course_id', 'course_eng_01');
  assert.deepEqual(unfinished.data, []);
  assert.equal(await main.getByText('Javoblar tahlili').count(), 0);

  for (let number = 2; number <= 8; number++) {
    await waitFor(step(number));
    await option().check();
    if (number < 8) await click('Keyingi savol', main);
  }
  await click('Natijani ko‘rish', main);
  const confirmation = page.getByRole('dialog', { name: 'Javoblarni topshirasizmi?' });
  await waitFor(confirmation);
  await click('Qaytish', confirmation);
  await waitFor(step(8));
  await click('Natijani ko‘rish', main);
  await click('Topshirish', confirmation);
  await waitFor(heading('Diagnostika yakunlandi'));
  await main.getByText('Javoblar tahlili', { exact: true }).click();
  await waitFor(main.getByText(/Siz belgilagan javob/).first());

  const placement = await owner.from('placement_attempts').select('id,score,weakest_skill_id').eq('course_id', 'course_eng_01').single();
  assert(placement.data?.weakest_skill_id);
  const answers = await owner.from('placement_answers').select('is_correct').eq('attempt_id', placement.data.id);
  assert.equal(answers.data?.length, 8);
  assert.equal(placement.data.score, Math.round(answers.data.filter(({ is_correct }) => is_correct).length * 100 / 8));
  await click('Shaxsiy yo‘lni ko‘rish', main);
  await waitFor(heading('Mening ta’lim yo‘lim'));
  console.log('PASS diagnostic resumes, grades once, reveals review after submission, and opens the roadmap');

  await click('Profil', page);
  await waitFor(heading('Profil'));
  await page.getByLabel('Kunlik vaqt', { exact: true }).selectOption('30');
  await click('Sozlamalarni saqlash', main);
  await waitFor(main.getByText('O‘rganish sozlamalari saqlandi.'));
  const reminder = page.getByRole('checkbox', { name: 'Kunlik eslatmani ko‘rsatish' });
  await reminder.click();
  await page.waitForFunction(() => {
    const input = document.querySelector('main input[type=checkbox]');
    return input && !input.checked && !input.disabled;
  });
  const prefs = await owner.from('learner_profiles').select('daily_minutes').eq('user_id', ownerId).single();
  assert.equal(prefs.data?.daily_minutes, 30);
  const reminders = await owner.from('user_preferences').select('notifications_enabled').eq('user_id', ownerId).single();
  assert.equal(reminders.data?.notifications_enabled, false);
  await click('Chiqish', main);
  await waitFor(heading('Xush kelibsiz!'));
  await page.reload({ waitUntil: 'domcontentloaded' });
  await waitFor(heading('Xush kelibsiz!'));
  await login(first, 'Wrong-' + randomUUID());
  await waitFor(main.getByRole('alert').getByText('Email yoki parol xato.'));
  await waitFor(heading('Xush kelibsiz!'));
  console.log('PASS preferences and logout persisted, and invalid credentials keep the welcome screen');

  await click('Unutdingizmi?');
  await page.getByLabel('Email manzilingiz', { exact: true }).fill(first.email);
  await click('Tiklash havolasini yuborish');
  await waitFor(page.getByText('So‘rov qabul qilindi'));
  await page.goto(await mailLink(first.email), { waitUntil: 'domcontentloaded' });
  const newPassword = 'QA-new-' + randomUUID();
  await page.getByLabel('Yangi parol', { exact: true }).fill(newPassword);
  await page.getByLabel('Parolni takrorlang', { exact: true }).fill(newPassword);
  await click('Parolni saqlash');
  await waitFor(page.getByText('Parol yangilandi!'));
  await click('Kirish sahifasiga qaytish');
  await waitFor(heading('Xush kelibsiz!'));
  await login(first, newPassword);
  await waitFor(heading(/Assalomu alaykum, Sinovchi/));
  console.log('PASS real recovery email, password update and login with the new password');

  await click('Yo‘lchi AI', nav);
  await waitFor(heading('Yo‘lchi AI'));
  await page.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' }).fill('Chiziqli tenglama qanday yechiladi?');
  await click('Savolni yuborish', main);
  await waitFor(main.getByRole('button', { name: 'Qayta urinish' }));
  await click('Qayta urinish', main);
  await waitFor(main.getByRole('button', { name: 'Qayta urinish' }));
  assert.equal(await main.getByText('Chiziqli tenglama qanday yechiladi?', { exact: true }).count(), 1);
  console.log('PASS unavailable AI is retryable and does not invent a chat answer');

  const outsider = api();
  const outsiderAuth = await outsider.auth.signUp(second);
  assert(!outsiderAuth.error && outsiderAuth.data.session, 'Second disposable learner can sign up.');
  const readOther = await outsider.from('lesson_progress').select('lesson_id').eq('user_id', ownerId);
  assert.deepEqual(readOther.data, []);
  const readPlacement = await outsider.from('placement_answers').select('id').eq('attempt_id', placement.data.id);
  assert.deepEqual(readPlacement.data, []);
  const oldGrader = await outsider.rpc('evaluate_placement_answer', {
    p_course_id: 'course_eng_01', p_question_id: 'q_live_eng_vocab_context', p_selected_index: 0,
  });
  assert.equal(oldGrader.error?.code, '42501');
  const admin = await outsider.from('admin_lessons').select('id');
  assert.deepEqual(admin.data, []);
  const gradeAsOther = await outsider.rpc('submit_answer_attempt', {
    p_user_id: ownerId, p_course_id: 'course_math_01', p_skill_id: 'skill_math_algebra',
    p_lesson_id: 'lesson_math_algebra_01', p_question_id: 'q_live_math_algebra_01_quiz',
    p_selected_index: 1, p_selected_text: '8',
  });
  assert.equal(gradeAsOther.error?.code, '42501');
  const diagnosis = await outsider.functions.invoke('yolchi-tutor', { body: {
    action: 'diagnose_mistake', courseId: 'course_math_01', skillId: 'skill_math_algebra',
    questionId: 'q_live_math_algebra_01_quiz', correctOption: 'forged',
  } });
  assert.equal(diagnosis.error?.context?.status, 403);
  console.log('PASS cross-user RLS, admin isolation, impersonated scoring and pre-answer AI diagnosis denied');

  if (process.env.E2E_ADMIN_EMAIL && process.env.E2E_ADMIN_PASSWORD) {
    const staff = { email: process.env.E2E_ADMIN_EMAIL, password: process.env.E2E_ADMIN_PASSWORD };
    await page.evaluate(() => localStorage.clear());
    await page.goto(app + '/login', { waitUntil: 'domcontentloaded' });
    await login(staff);
    await waitFor(heading(/Administrator Konsoli/));
    await page.setViewportSize({ width: 390, height: 844 });
    await click(/Yangi Fan Qo‘shish/i, main);
    const editor = page.getByRole('dialog', { name: 'Fan ma’lumotlari' });
    await waitFor(editor);
    const title = 'QA kursi ' + randomUUID().slice(0, 8);
    await editor.getByLabel('Fan nomi').fill(title);
    await editor.getByLabel('Tavsifi').fill('Mahalliy administrator sinovi.');
    await editor.getByLabel('Fan turi').selectOption('logic');
    await editor.getByLabel('Holat').selectOption('false');
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
    await click('Saqlash', editor);
    await waitFor(heading(title));

    const adminClient = api();
    const auth = await adminClient.auth.signInWithPassword(staff);
    assert(!auth.error);
    const course = await adminClient.from('courses').select('subject,is_active').eq('title', title).single();
    assert.deepEqual(course.data, { subject: 'logic', is_active: false });
    const invisible = await outsider.from('courses').select('id').eq('title', title);
    assert.deepEqual(invisible.data, []);
    await click(/Darsliklar \(/, main);
    await click(/Test Banki \(/, main);
    console.log('PASS authenticated CMS creates a real inactive course with its selected subject');
  }
  assert.deepEqual(errors, [], 'No browser exceptions.');
} catch (error) {
  // Do not print request bodies, recovery URLs or auth tokens in test logs.
  console.error('Configured journey failed:', error.name, error.message.split('\n')[0]);
  console.error('Visible headings:', await main.getByRole('heading').allTextContents());
  console.error('Backend errors:', failedRequests);
  process.exitCode = 1;
} finally {
  await browser.close();
}
