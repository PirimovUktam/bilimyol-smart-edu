import assert from 'node:assert/strict';
import { rm } from 'node:fs/promises';
import { chromium } from 'playwright';

const port = Number(process.env.ENGLISH_E2E_PORT ?? '5200');
const host = '127.0.0.1';
const outDir = 'dist-english-starter-e2e';
const mode = 'e2e-offline';

process.env.VITE_SUPABASE_URL = '';
process.env.VITE_SUPABASE_ANON_KEY = '';

const { build, preview } = await import('vite');
await build({ mode, build: { outDir } });
const server = await preview({ mode, build: { outDir }, preview: { host, port, strictPort: true } });
const base = `http://${host}:${port}`;

const browser = await chromium.launch();
let assertions = 0;

async function checkNoOverflow(page, label, width) {
  const sizes = await page.evaluate(() => ({
    width: document.documentElement.clientWidth,
    scroll: document.documentElement.scrollWidth,
  }));
  assert(
    sizes.scroll <= sizes.width + 1,
    `${label} overflow at ${width}px: ${JSON.stringify(sizes)}`
  );
  assertions++;
}

async function checkThemeSwitchAndContrast(page, label) {
  const root = page.locator('html');
  assert.equal(await root.getAttribute('data-theme'), 'light');
  const lightColors = await page.evaluate(() => {
    const bodyBg = getComputedStyle(document.body).backgroundColor;
    const card = document.querySelector('.edtech-card');
    const cardStyle = card ? getComputedStyle(card) : null;
    return {
      bodyBg,
      cardBg: cardStyle?.backgroundColor ?? null,
      cardColor: cardStyle?.color ?? null,
    };
  });

  await page.getByRole('button', { name: 'Qorong‘i rejimni yoqish' }).click();
  assert.equal(await root.getAttribute('data-theme'), 'dark');
  const darkColors = await page.evaluate(() => {
    const bodyBg = getComputedStyle(document.body).backgroundColor;
    const card = document.querySelector('.edtech-card');
    const cardStyle = card ? getComputedStyle(card) : null;
    return {
      bodyBg,
      cardBg: cardStyle?.backgroundColor ?? null,
      cardColor: cardStyle?.color ?? null,
    };
  });
  assert.notEqual(darkColors.bodyBg, lightColors.bodyBg, `${label}: dark background must differ from light background`);
  if (lightColors.cardBg && darkColors.cardBg) {
    assert.notEqual(darkColors.cardBg, lightColors.cardBg, `${label}: dark card surface must differ from light surface`);
    assert.notEqual(darkColors.cardColor, darkColors.cardBg, `${label}: dark card text must contrast with card surface`);
  }
  assertions++;

  // Switch back to light so subsequent selectors keep a predictable baseline
  await page.getByRole('button', { name: 'Yorug‘ rejimni yoqish' }).click();
  assert.equal(await root.getAttribute('data-theme'), 'light');
}

async function verifyAudioPlayPauseReplay(page, main, src, { keyboardReplay = false } = {}) {
  const audio = main.locator(`audio[src="${src}"]`);
  await audio.waitFor({ state: 'visible' });
  await page.waitForFunction((targetSrc) => {
    const el = document.querySelector(`audio[src="${targetSrc}"]`);
    return Boolean(el && Number.isFinite(el.duration) && el.duration > 5);
  }, src);

  // Genuine audio playback
  await audio.evaluate(async (el) => {
    el.muted = true;
    await el.play();
  });
  await page.waitForFunction((targetSrc) => {
    const el = document.querySelector(`audio[src="${targetSrc}"]`);
    return Boolean(el && !el.paused && el.currentTime > 0);
  }, src);
  const playingState = await audio.evaluate((el) => ({
    paused: el.paused,
    currentTime: el.currentTime,
    duration: el.duration,
  }));
  assert(
    !playingState.paused && playingState.currentTime > 0 && playingState.duration > 5,
    `Audio must actively play with duration > 5s, got ${JSON.stringify(playingState)}`
  );
  assertions++;

  // Genuine pause transition
  await audio.evaluate((el) => el.pause());
  const pausedState = await audio.evaluate((el) => ({ paused: el.paused }));
  assert.equal(pausedState.paused, true, 'Audio must transition to paused === true after pause()');
  assertions++;

  // Seek mid-track and verify Replay resets near 0s AND actively resumes playback
  await audio.evaluate((el) => {
    el.currentTime = 1.5;
  });
  const replayBtn = main.getByRole('button', { name: 'Qayta tinglash' });
  if (keyboardReplay) {
    await replayBtn.focus();
    await page.keyboard.press('Enter');
  } else {
    await replayBtn.click();
  }
  await page.waitForFunction((targetSrc) => {
    const el = document.querySelector(`audio[src="${targetSrc}"]`);
    return Boolean(el && !el.paused && el.currentTime < 0.5);
  }, src);
  const replayedState = await audio.evaluate((el) => ({
    paused: el.paused,
    currentTime: el.currentTime,
  }));
  assert(
    replayedState.currentTime < 0.5 && !replayedState.paused,
    `Replay must reset audio < 0.5s and actively resume playback, got ${JSON.stringify(replayedState)}`
  );
  assertions++;

  await audio.evaluate((el) => el.pause());
}

async function enterEnglishStarter(context) {
  const page = await context.newPage();
  const errors = [];
  const remoteRequests = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('request', (request) => {
    const hostname = new URL(request.url()).hostname;
    if (hostname.endsWith('.supabase.co')) remoteRequests.push(request.url());
  });
  page.setDefaultTimeout(15000);

  // Slow network simulation for English lesson media assets
  await page.route('**/lesson-media/english/**', async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 350));
    await route.continue();
  });

  await page.goto(base, { waitUntil: 'domcontentloaded' });
  const main = page.getByRole('main');
  const click = (name, root = main) =>
    root.getByRole('button', { name, exact: typeof name === 'string' }).click();
  const heading = (name) =>
    main.getByRole('heading', { name }).first().waitFor({ state: 'visible' });

  await click('Kirish');
  await heading('Xush kelibsiz!');
  await click('Namuna hisobi bilan kirish');
  await heading('O‘zingizga mos fanni tanlang');
  await click(/Ingliz tili fanini tanlash/);
  await heading('O‘rganish rejangizni sozlang');
  await main.getByRole('radio', { name: /Noldan boshlayman/ }).check();
  await click('Birinchi darsni boshlash');
  await heading('Birinchi inglizcha so‘zlar');

  return { page, main, click, heading, errors, remoteRequests };
}

async function completeMcqLesson(page, main, click, optionText) {
  for (let guard = 0; guard < 6; guard++) {
    const stepBadge = main.getByText(/^Qadam \d+ \/ \d+$/).first();
    await stepBadge.waitFor({ state: 'visible' });
    const badgeText = (await stepBadge.textContent())?.trim() || '';
    const match = badgeText.match(/^Qadam (\d+) \/ (\d+)$/);
    if (match && Number(match[1]) >= Number(match[2])) {
      break;
    }
    const checkBtn = main.getByRole('button', { name: /Tekshirish/i });
    if (await checkBtn.isVisible().catch(() => false)) {
      break;
    }
    const curStep = match ? Number(match[1]) : 1;
    await click('Keyingi qadam');
    // Wait for AnimatePresence mode="wait" to finish exiting the previous card and mount the next step card
    await main
      .locator('.edtech-card span.highlight', { hasText: new RegExp(`^Qadam ${curStep + 1}$`) })
      .waitFor({ state: 'visible' });
  }
  const checkBtn = main.getByRole('button', { name: /Tekshirish/i });
  await checkBtn.waitFor({ state: 'visible' });
  await main.getByText(optionText, { exact: true }).first().click();
  await checkBtn.click();
  await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor();
  const dialog = page.getByRole('dialog', { name: 'Dars yakunlandi' });
  await dialog.waitFor();
  await click('Ta’lim yo‘liga o‘tish', dialog);
  await dialog.waitFor({ state: 'hidden' });
}

try {
  // =========================================================================
  // Flow 1: Full Starter Lesson E2E ("I'm Sam"), Media, Flashcards, Broken Nodes & Isolation
  // =========================================================================
  const context = await browser.newContext({
    viewport: { width: 1440, height: 960 },
    reducedMotion: 'reduce',
  });
  const { page, main, click, heading, errors, remoteRequests } = await enterEnglishStarter(context);

  // Step 1: Concept
  await heading('Asosiy tushuncha');
  await main.getByText(/«Hello» — salom/).first().waitFor();
  await checkNoOverflow(page, 'starter-step-1', 1440);
  await page.setViewportSize({ width: 390, height: 844 });
  await checkNoOverflow(page, 'starter-step-1', 390);
  await page.setViewportSize({ width: 1440, height: 960 });

  // Step 2: Real two-voice WAV audio + Tashkent greeting illustration + Replay + Transcript
  await click('Keyingi qadam');
  await heading('Birga misol ko‘ramiz');

  const img = main.locator('img[src="/lesson-media/english/a1-starter-greeting.png"]');
  await img.waitFor({ state: 'visible' });
  const imgMeta = await img.evaluate((el) => ({
    complete: el.complete,
    naturalWidth: el.naturalWidth,
    alt: el.getAttribute('alt') || '',
  }));
  assert(imgMeta.complete && imgMeta.naturalWidth > 0, 'Starter illustration must load cleanly');
  assert(imgMeta.alt.trim().length > 10, 'Starter illustration must have meaningful alt text');
  assertions += 2;

  await verifyAudioPlayPauseReplay(page, main, '/lesson-media/english/a1-starter-dialogue.wav', {
    keyboardReplay: true,
  });

  // Open & verify speaker-labeled collapsible transcript via keyboard Space
  const transcriptSummary = main.locator('summary', { hasText: 'Matnli bayon' });
  await transcriptSummary.focus();
  await page.keyboard.press('Space');
  await main.getByText('Aziza:').waitFor({ state: 'visible' });
  await main.getByText('Ben:').waitFor({ state: 'visible' });
  assertions += 2;

  // Responsive & dark mode check on Step 2
  await checkThemeSwitchAndContrast(page, 'starter-step-2');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkNoOverflow(page, 'starter-step-2', 390);
  await page.getByRole('button', { name: 'Qorong‘i rejimni yoqish' }).click();
  await checkNoOverflow(page, 'starter-step-2-dark', 390);
  await page.getByRole('button', { name: 'Yorug‘ rejimni yoqish' }).click();
  await page.setViewportSize({ width: 1440, height: 960 });

  // Open & close Yo'lchi AI help modal before advancing, then verify reload restores Step 2
  await click('Yo‘lchidan so‘rash');
  const helpDialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
  await helpDialog.waitFor({ state: 'visible' });
  await click('Yopish', helpDialog);
  await heading('Birga misol ko‘ramiz');
  await page.reload({ waitUntil: 'domcontentloaded' });
  await heading('Birga misol ko‘ramiz');
  assertions++;

  // Step 3: Flashcards (390px + Dark Mode + Audio + Keyboard + Re-queue + Non-mastery check)
  await click('Keyingi qadam');
  await heading('Iboralarni eslab qolamiz');
  await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
  assert.equal(await main.getByText('Ismingiz nima?').count(), 0, 'Answer must stay hidden before reveal');

  await checkThemeSwitchAndContrast(page, 'starter-step-3-front');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkNoOverflow(page, 'starter-step-3', 390);
  await page.getByRole('button', { name: 'Qorong‘i rejimni yoqish' }).click();
  await checkNoOverflow(page, 'starter-step-3-dark', 390);
  await page.getByRole('button', { name: 'Yorug‘ rejimni yoqish' }).click();
  await page.setViewportSize({ width: 1440, height: 960 });

  // Keyboard activation of flashcard audio ("Talaffuzni tinglash")
  const fcAudioBtn1 = main.getByRole('button', { name: /Talaffuzni tinglash/ });
  await fcAudioBtn1.waitFor({ state: 'visible' });
  const fcAudio1Promise = page.waitForResponse(
    (res) =>
      res.url().includes('/lesson-media/english/a1-starter-whats-your-name.wav') &&
      (res.status() === 200 || res.status() === 206)
  );
  await fcAudioBtn1.focus();
  await page.keyboard.press('Enter');
  await fcAudio1Promise;
  assertions++;

  // Keyboard activation of "Javobni ko‘rish"
  const revealBtn = main.getByRole('button', { name: 'Javobni ko‘rish' });
  await revealBtn.focus();
  await page.keyboard.press('Enter');
  await main.getByText('Ismingiz nima?', { exact: true }).waitFor({ state: 'visible' });
  await main.getByText('/wɒts jɔː neɪm/', { exact: true }).waitFor({ state: 'visible' });
  assertions += 3;

  await checkThemeSwitchAndContrast(page, 'starter-step-3-revealed');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkNoOverflow(page, 'starter-step-3-revealed', 390);
  await page.setViewportSize({ width: 1440, height: 960 });

  // Flipping alone MUST NOT complete the lesson
  const progressAfterFlip = await page.evaluate(() =>
    JSON.parse(sessionStorage.getItem('bilimyol_demo_progress') || '{}')
  );
  assert(!progressAfterFlip?.profile?.completedLessonIds?.includes('lesson_eng_starter'));
  assertions++;

  // Keyboard Space on "Yana mashq qilaman" -> moves to fc_eng_starter_2 ("Nice to meet you.")
  const needPracticeBtn = main.getByRole('button', { name: 'Yana mashq qilaman' });
  await needPracticeBtn.focus();
  await page.keyboard.press('Space');
  await main.getByRole('heading', { name: 'Nice to meet you.' }).waitFor({ state: 'visible' });
  const fcAudio2Promise = page.waitForResponse(
    (res) =>
      res.url().includes('/lesson-media/english/a1-starter-nice-to-meet-you.wav') &&
      (res.status() === 200 || res.status() === 206)
  );
  await click(/Talaffuzni tinglash/);
  await fcAudio2Promise;
  await click('Javobni ko‘rish');
  await main.getByText('Tanishganimdan xursandman.', { exact: true }).waitFor({ state: 'visible' });
  const rememberedBtn = main.getByRole('button', { name: 'Eslab qoldim' });
  await rememberedBtn.focus();
  await page.keyboard.press('Enter');

  // Re-queued card 1 ("What's your name?") must return!
  await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
  await click('Javobni ko‘rish');
  await click('Eslab qoldim');
  await main.getByRole('heading', { name: 'Barcha kartochkalar ko‘rib chiqildi' }).waitFor({ state: 'visible' });
  assertions += 4;

  // Step 4: Free-Text Exercise (390px + Dark Mode + Anti-spoiler + Wrong Feedback + Keyboard Submit)
  await click('Keyingi qadam');
  await heading('O‘rganganingizni sinab ko‘ring');

  const step4Text = await main.innerText();
  assert(!step4Text.includes("I'm Sam"), 'Step 4 prompt must NOT leak "I\'m Sam"');
  assert(!step4Text.includes('My name is Sam'), 'Step 4 prompt must NOT leak "My name is Sam"');
  assertions += 2;

  await checkThemeSwitchAndContrast(page, 'starter-step-4');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkNoOverflow(page, 'starter-step-4', 390);
  await page.setViewportSize({ width: 1440, height: 960 });

  // Empty submit shows inline validation error
  await click(/Tekshirish/i);
  await main.getByText(/Javob maydoni bo‘sh/).waitFor({ state: 'visible' });

  const input = main.getByRole('textbox', { name: /Javobingizni ingliz tilida yozing/ });
  // Wrong attempt 1: "Sam"
  await input.fill('Sam');
  await click(/Tekshirish/i);
  await main.getByText(/Faqat ismning o‘zi yetarli emas/).waitFor({ state: 'visible' });
  assert.equal(await main.getByText(/To‘g‘ri javob:/).count(), 0, 'Must NOT reveal answer on text_input mistake');
  assert.equal(await main.getByRole('button', { name: 'Keyingi savol' }).count(), 0, 'Must NOT allow advancing on mistake');
  await checkThemeSwitchAndContrast(page, 'starter-step-4-wrong-feedback');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkNoOverflow(page, 'starter-step-4-wrong-feedback', 390);
  await page.getByRole('button', { name: 'Qorong‘i rejimni yoqish' }).click();
  await checkNoOverflow(page, 'starter-step-4-wrong-feedback-dark', 390);
  await page.getByRole('button', { name: 'Yorug‘ rejimni yoqish' }).click();
  await page.setViewportSize({ width: 1440, height: 960 });
  assertions += 3;

  // Wrong attempt 2: "Goodbye"
  await input.fill('Goodbye');
  await click(/Tekshirish/i);
  await main.getByText(/xayrlashuv so‘zi/).waitFor({ state: 'visible' });
  assert.equal(await main.getByText(/To‘g‘ri javob:/).count(), 0);
  assertions += 2;

  // Correct attempt via keyboard Enter: "I'm Sam"
  await input.fill("I'm Sam");
  await input.press('Enter');
  await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
  const completionDialog = page.getByRole('dialog', { name: 'Dars yakunlandi' });
  await completionDialog.waitFor({ state: 'visible' });
  await click('Ta’lim yo‘liga o‘tish', completionDialog);
  assertions += 2;

  // Reload persistence check after completion
  await heading('Boshlang‘ich darslar');
  await page.reload({ waitUntil: 'domcontentloaded' });
  await heading('Boshlang‘ich darslar');
  const savedAfterStarter = await page.evaluate(() =>
    JSON.parse(sessionStorage.getItem('bilimyol_demo_progress') || '{}')
  );
  assert(
    savedAfterStarter?.profile?.completedLessonIds?.includes('lesson_eng_starter'),
    'lesson_eng_starter must persist in completedLessonIds after reload'
  );
  assert(savedAfterStarter?.profile?.xp >= 22, 'XP must persist after reload');
  assertions += 2;

  // Complete lesson_eng_foundation_02 -> unlocks English Roadmap -> open node_eng_read!
  await click('Boshlang‘ich darsni ochish');
  await heading('Men, siz va oddiy gaplar');
  await completeMcqLesson(page, main, click, 'am');

  await heading('Mening ta’lim yo‘lim');
  await checkNoOverflow(page, 'english-roadmap', 1440);

  // Node 1: Vocabulary
  const vocabCard = main.locator('li').filter({ has: page.getByRole('heading', { name: 'Vocabulary', exact: true }) });
  await vocabCard.getByRole('button', { name: 'Darsni boshlash' }).click();
  await completeMcqLesson(page, main, click, 'between the chair and the shelf');

  // Node 2: Grammar
  await heading('Mening ta’lim yo‘lim');
  const gramCard = main.locator('li').filter({ has: page.getByRole('heading', { name: 'Grammar', exact: true }) });
  await gramCard.getByRole('button', { name: 'Darsni boshlash' }).click();
  await completeMcqLesson(page, main, click, 'does');

  // Node 3: Listening (also verify real WAV play/pause/replay, duration > 5s, and "in the afternoon"!)
  await heading('Mening ta’lim yo‘lim');
  const listCard = main.locator('li').filter({ has: page.getByRole('heading', { name: 'Listening', exact: true }) });
  await listCard.getByRole('button', { name: 'Darsni boshlash' }).click();
  await heading('1. Tinglab tushunish strategiyasi');
  await click('Keyingi qadam');
  await heading('2. Audio Xabarni Tinglash');
  await verifyAudioPlayPauseReplay(page, main, '/lesson-media/english/a1-listening-lecture-time.wav');
  await main.locator('summary', { hasText: 'Matnli bayon' }).click();
  await main.getByText(/in the afternoon/).waitFor({ state: 'visible' });
  assertions += 2;
  await completeMcqLesson(page, main, click, '15:15 (quarter past three)');

  // Node 4: Reading (formerly broken node_eng_read!)
  await heading('Mening ta’lim yo‘lim');
  const readCard = main.locator('li').filter({ has: page.getByRole('heading', { name: 'Reading', exact: true }) });
  assert.equal(await readCard.getByText('Bu mavzu uchun dars mavjud emas.').count(), 0);
  await readCard.getByRole('button', { name: 'Darsni boshlash' }).click();
  await heading('Asosiy g‘oya va dalil');
  await page.setViewportSize({ width: 390, height: 844 });
  await checkNoOverflow(page, 'reading-lesson', 390);
  await page.setViewportSize({ width: 1440, height: 960 });
  await completeMcqLesson(page, main, click, 'To‘garak buyumlarni ta’mirlab, chiqindini kamaytiradi');
  assertions += 2;

  // Course isolation check: switch to Mathematics -> course_math_01 remains uncompleted & untouched
  await click('Fanni almashtirish', page);
  await heading('O‘zingizga mos fanni tanlang');
  await click(/Matematika fanini tanlash/);
  await heading('O‘rganish rejangizni sozlang');
  const isolationState = await page.evaluate(() =>
    JSON.parse(sessionStorage.getItem('bilimyol_demo_progress') || '{}')
  );
  assert(!isolationState?.profile?.completedLessonIds?.includes('lesson_math_starter'));
  assert(!isolationState?.profile?.completedLessonIds?.includes('lesson_math_algebra_01'));
  assert(
    !(isolationState?.profile?.completedNodeIds || []).some((id) => String(id).startsWith('node_math_')),
    'completedNodeIds must not contain any node_math_* entries'
  );
  assert.equal(isolationState?.profile?.scoresByCourse?.course_math_01, undefined);
  assert.equal(isolationState?.profile?.courseLevels?.course_math_01, undefined);
  assertions += 5;

  assert.deepEqual(remoteRequests, []);
  assert.deepEqual(errors, []);
  await context.close();

  // =========================================================================
  // Flow 2: Fresh Context Verifies "My name is Sam" Variant Acceptance
  // =========================================================================
  const context2 = await browser.newContext({
    viewport: { width: 1440, height: 960 },
    reducedMotion: 'reduce',
  });
  const ctx2 = await enterEnglishStarter(context2);
  await ctx2.heading('Asosiy tushuncha');
  await ctx2.click('Keyingi qadam'); // Step 2
  await ctx2.heading('Birga misol ko‘ramiz');
  await ctx2.click('Keyingi qadam'); // Step 3
  await ctx2.heading('Iboralarni eslab qolamiz');
  await ctx2.click('Keyingi qadam'); // Step 4
  await ctx2.heading('O‘rganganingizni sinab ko‘ring');
  await ctx2.main.getByRole('textbox', { name: /Javobingizni ingliz tilida yozing/ }).fill('My name is Sam.');
  await ctx2.click(/Tekshirish/i);
  await ctx2.main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
  await ctx2.page.getByRole('dialog', { name: 'Dars yakunlandi' }).waitFor({ state: 'visible' });
  assertions += 2;
  assert.deepEqual(ctx2.remoteRequests, []);
  assert.deepEqual(ctx2.errors, []);
  await context2.close();

  console.log(`ENGLISH STARTER E2E PASSED — ${assertions} assertions verified`);
} catch (error) {
  console.error('English starter E2E failed:', error?.stack || error?.message || error);
  process.exitCode = 1;
} finally {
  await browser.close();
  server.httpServer.closeAllConnections?.();
  await new Promise((resolve) => server.httpServer.close(resolve));
  await rm(outDir, { recursive: true, force: true });
}
