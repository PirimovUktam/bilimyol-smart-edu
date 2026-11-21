import assert from 'node:assert/strict';
import {
  FAST_TIMEOUT,
  advanceLessonStep,
  advanceToExerciseStep,
  assertCleanSession,
  assertSingleCefrLevelScope,
  completeStarterLesson,
  completeVisibleFlashcardDeck,
  finishCompletionDialog,
  getCefrLevelSection,
  openDirectEnglishLesson,
  openEnglishRoadmap,
  openRoadmapNodeLesson,
  openStarterLesson,
  submitFreeTextAnswer,
  unlockEnglishRoadmapUpTo,
} from './flows.mjs';

export function registerTests() {
  return [
    {
      id: 'T3-01',
      name: 'Mobile 390px x Dark theme x Starter lesson with matched 390px/1440px screenshots',
      milestone: ['M1'],
      contextOptions: { viewport: 'mobile390', theme: 'dark', locale: 'uz' },
      async run({ page, baseUrl, session, helpers, screenshotsDir }) {
        await openStarterLesson(page, baseUrl, helpers);
        const themeAttr = await page.locator('html').getAttribute('data-theme');
        assert.equal(themeAttr, 'dark', 'Expected dark theme active on html[data-theme].');

        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        const main = page.getByRole('main');
        await main.locator('audio[src="/lesson-media/english/a1-starter-dialogue.wav"]').waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Qayta tinglash' }).click();

        const img = main.locator('img[src="/lesson-media/english/a1-starter-greeting.png"]');
        await img.waitFor({ state: 'visible' });
        assert.equal(
          await img.evaluate((el) => el.complete && el.naturalWidth > 0),
          true,
          'Expected starter illustration loaded on 390px dark mode.',
        );

        await helpers.captureViewPairScreenshots(page, 'eng-starter-dark', screenshotsDir);
        await helpers.setViewportPreset(page, 'mobile390');

        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);
        await completeVisibleFlashcardDeck(page);
        await advanceLessonStep(page, /O‘rganganingizni sinab ko‘ring/i);
        await submitFreeTextAnswer(page, "I'm Sam");
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await finishCompletionDialog(page);
        assertCleanSession(session, 'T3-01');
      },
    },
    {
      id: 'T3-02',
      name: 'Desktop 1440px x Light theme x Grouped CEFR A1-B1 active + B2-C2 DEFERRED roadmap and lesson view with matched screenshots',
      milestone: ['M2', 'M3', 'M5', 'M6'],
      contextOptions: { viewport: 'desktop1440', theme: 'light', locale: 'uz' },
      async run({ page, baseUrl, session, helpers, screenshotsDir }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const themeAttr = await page.locator('html').getAttribute('data-theme');
        assert.equal(themeAttr, 'light', 'Expected light theme active on html[data-theme].');

        const main = page.getByRole('main');
        const cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
        const activeLevels = new Set(['A1', 'A2', 'B1']);

        // 1. Verify grouped A1-B1 active + B2-C2 DEFERRED CEFR hierarchy in ascending DOM/topY order
        const positions = [];
        for (const level of cefrLevels) {
          const levelSection = getCefrLevelSection(main, level);
          await helpers.expectVisibleFast(
            levelSection,
            `T3-02: Expected grouped CEFR ${level} section on English roadmap.`,
            FAST_TIMEOUT,
          );
          await assertSingleCefrLevelScope(levelSection, level, 'T3-02');
          if (activeLevels.has(level)) {
            await helpers.expectVisibleFast(
              levelSection.getByText(/O‘quv maqsadi/i).first(),
              `T3-02: Expected O‘quv maqsadi in active ${level} section.`,
              FAST_TIMEOUT,
            );
            assert.ok(
              (await levelSection.locator('ol.learning-timeline li').count()) > 0,
              `T3-02: Expected active ${level} section to render >= 1 timeline items.`,
            );
          } else {
            await helpers.expectVisibleFast(
              levelSection.getByText(/Keyingi bosqich \(DEFERRED\)/i),
              `T3-02: Expected Keyingi bosqich (DEFERRED) in ${level} section.`,
              FAST_TIMEOUT,
            );
            await helpers.expectVisibleFast(
              levelSection.getByText('Qulflangan', { exact: true }).first(),
              `T3-02: Expected Qulflangan in deferred ${level} section.`,
              FAST_TIMEOUT,
            );
            assert.equal(
              await levelSection.locator('ol.learning-timeline li').count(),
              0,
              `T3-02: Deferred ${level} section must render 0 timeline items.`,
            );
            assert.equal(
              await levelSection.getByRole('button').count(),
              0,
              `T3-02: Deferred ${level} section must render 0 buttons.`,
            );
          }
          const topY = await levelSection.evaluate(
            (el) => el.getBoundingClientRect().top + window.scrollY,
          );
          positions.push({ level, topY });
        }
        for (let i = 1; i < positions.length; i++) {
          assert.ok(
            positions[i].topY > positions[i - 1].topY,
            `T3-02: Expected ${positions[i - 1].level} strictly before ${positions[i].level} in grouped roadmap order (topY ${positions[i - 1].topY} vs ${positions[i].topY}).`,
          );
        }

        const moduleAction = main.getByRole('button', { name: /Darsni boshlash|Qayta ko‘rish/i }).first();
        await helpers.expectVisibleFast(
          moduleAction,
          'T3-02: Expected openable module lesson inside grouped CEFR roadmap.',
          FAST_TIMEOUT,
        );

        // 2. Capture matched 390px + 1440px roadmap screenshots & assert zero horizontal overflow
        await helpers.captureViewPairScreenshots(page, 'eng-roadmap-light', screenshotsDir);
        await helpers.setViewportPreset(page, 'desktop1440');

        // 3. Open a grouped lesson view and verify light-theme layout + overflow across viewports
        await moduleAction.click();
        await main.getByText(/^Qadam\s+\d+\s*\/\s*\d+$/i).first().waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Ta’lim yo‘liga qaytish/i }).waitFor({ state: 'visible' });
        await helpers.captureViewPairScreenshots(page, 'eng-roadmap-lesson-light', screenshotsDir);

        assertCleanSession(session, 'T3-02');
      },
    },
    {
      id: 'T3-03',
      name: 'Russian UI locale x English lesson media and transcript language separation',
      milestone: ['M1'],
      contextOptions: { locale: 'ru' },
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        assert.equal(
          await page.evaluate(() => document.documentElement.lang),
          'ru',
          'Expected html[lang="ru"] when Russian UI locale is active.',
        );

        await advanceLessonStep(page, /Birga misol ko‘ramiz|Разберём пример|Посмотрим пример|Пример/i);
        const main = page.getByRole('main');
        await main.locator('audio[src="/lesson-media/english/a1-starter-dialogue.wav"]').waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Повторить' }).waitFor({ state: 'visible' });
        await main.getByLabel('Скорость воспроизведения').waitFor({ state: 'visible' });
        await main.locator('summary', { hasText: 'Текстовая расшифровка' }).click();
        await main.locator('[lang="en"]').getByText('Aziza:').waitFor({ state: 'visible' });
        await main.locator('[lang="en"]').getByText('Ben:').waitFor({ state: 'visible' });
        await main.locator('[lang="en"]').getByText(/What's your name\?/i).waitFor({ state: 'visible' });

        await helpers.openAndCloseYolchiAi(page, {
          askText: 'Когда используется Hello?',
          closeWith: 'button',
          preserveStepIndicator: /^Шаг 2 \/ 4$/i,
        });

        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_listening_01');
        await advanceLessonStep(
          page,
          /2\.\s*(Audio Xabarni Tinglash|Прослушивание аудиосообщения|Аудиосообщение|Прослушать аудио)/i,
        );
        await main.locator('summary', { hasText: 'Текстовая расшифровка' }).click();
        await main.locator('[lang="en"]').getByText(/quarter past three in the afternoon/i).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T3-03');
      },
    },
    {
      id: 'T3-04',
      name: 'Uzbek UI locale x pure keyboard-only navigation (zero pointer clicks) across starter lesson and Yo‘lchi AI',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
        const main = page.getByRole('main');

        await helpers.pressTabUntilFocused(
          page,
          page.getByRole('button', { name: 'Namuna hisobi bilan kirish' }),
          'Namuna hisobi bilan kirish',
        );
        await page.keyboard.press('Enter');

        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('button', { name: /Ingliz tili fanini tanlash/i }),
          'Ingliz tili fanini tanlash',
        );
        await page.keyboard.press('Enter');

        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('radio', { name: /Noldan boshlayman/i }),
          'Noldan boshlayman',
        );
        await page.keyboard.press('Space');

        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('button', { name: 'Birinchi darsni boshlash' }),
          'Birinchi darsni boshlash',
        );
        await page.keyboard.press('Enter');
        await main.getByRole('heading', { name: 'Birinchi inglizcha so‘zlar' }).first().waitFor({ state: 'visible' });

        // Step 1 -> Step 2
        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('button', { name: 'Keyingi qadam' }),
          'Keyingi qadam (step 1)',
        );
        await page.keyboard.press('Enter');
        await main.getByRole('heading', { name: 'Birga misol ko‘ramiz' }).first().waitFor({ state: 'visible' });

        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('button', { name: 'Qayta tinglash' }),
          'Qayta tinglash',
        );
        await page.keyboard.press('Space');

        await helpers.pressTabUntilFocused(
          page,
          main.locator('summary', { hasText: 'Matnli bayon' }),
          'Matnli bayon',
        );
        await page.keyboard.press('Enter');
        await main.locator('[lang="en"]').getByText('Aziza:').waitFor({ state: 'visible' });

        // Step 2 -> Step 3 (Flashcards)
        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('button', { name: 'Keyingi qadam' }),
          'Keyingi qadam (step 2)',
        );
        await page.keyboard.press('Enter');
        await main.getByRole('heading', { name: 'Iboralarni eslab qolamiz' }).first().waitFor({ state: 'visible' });

        for (let card = 0; card < 2; card++) {
          await helpers.pressTabUntilFocused(
            page,
            main.getByRole('button', { name: 'Javobni ko‘rish' }),
            `Javobni ko‘rish (${card + 1})`,
          );
          await page.keyboard.press('Enter');
          await helpers.pressTabUntilFocused(
            page,
            main.getByRole('button', { name: 'Eslab qoldim' }),
            `Eslab qoldim (${card + 1})`,
          );
          await page.keyboard.press('Enter');
        }
        await main.getByRole('heading', { name: 'Barcha kartochkalar ko‘rib chiqildi' }).waitFor({ state: 'visible' });

        // Step 3 -> Step 4
        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('button', { name: 'Keyingi qadam' }),
          'Keyingi qadam (step 3)',
        );
        await page.keyboard.press('Enter');
        await main.getByRole('heading', { name: 'O‘rganganingizni sinab ko‘ring' }).first().waitFor({ state: 'visible' });

        const textbox = main.getByRole('textbox', { name: /Javobingizni ingliz tilida yozing/i });
        await helpers.pressTabUntilFocused(page, textbox, 'free-text input');
        await page.keyboard.type("I'm Sam");

        // Open Yo‘lchi AI via keyboard before submitting, check Tab focus trap & Escape close
        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('button', { name: 'Yo‘lchidan so‘rash' }),
          'Yo‘lchidan so‘rash',
          120,
        );
        await page.keyboard.press('Enter');
        const dialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
        await dialog.waitFor({ state: 'visible' });

        await page.keyboard.press('Tab');
        const focusInsideDialog = await dialog.evaluate((el) => el.contains(document.activeElement));
        assert.equal(focusInsideDialog, true, 'Keyboard Tab focus must remain trapped inside Yo‘lchi AI dialog.');

        await page.keyboard.press('Escape');
        await dialog.waitFor({ state: 'hidden' });
        assert.equal(
          await textbox.inputValue(),
          "I'm Sam",
          'Expected keyboard-typed "I\'m Sam" preserved after Escape close.',
        );

        await helpers.pressTabUntilFocused(
          page,
          main.getByRole('button', { name: /^TEKSHIRISH$/i }),
          'TEKSHIRISH',
        );
        await page.keyboard.press('Enter');
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });

        await helpers.pressTabUntilFocused(
          page,
          page.getByRole('dialog', { name: 'Dars yakunlandi' }).getByRole('button', { name: 'Ta’lim yo‘liga o‘tish' }),
          'Ta’lim yo‘liga o‘tish',
        );
        await page.keyboard.press('Enter');
        await main.getByRole('heading', { name: 'Boshlang‘ich darslar' }).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T3-04');
      },
    },
    {
      id: 'T3-05',
      name: 'Slow network delayed media followed by aborted media fallback and recovery completion',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        const unthrottleSlow = await helpers.throttleNetwork(page, {
          pattern: '**/lesson-media/**',
          delayMs: 500,
        });
        try {
          await openStarterLesson(page, baseUrl, helpers);
          await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
          const img = page.getByRole('main').locator('img[src="/lesson-media/english/a1-starter-greeting.png"]');
          await img.waitFor({ state: 'visible' });
          assert.equal(
            await img.evaluate((el) => el.complete && el.naturalWidth > 0),
            true,
            'Expected illustration to load under 500ms slow network.',
          );
        } finally {
          await unthrottleSlow();
        }

        const unthrottleAbort = await helpers.throttleNetwork(page, {
          pattern: '**/lesson-media/**',
          abort: true,
        });
        const main = page.getByRole('main');
        try {
          await page.reload({ waitUntil: 'domcontentloaded' });
          await main.getByText(/Yozuv yuklanmadi/i).waitFor({ state: 'visible' });
          await main.getByRole('button', { name: 'Qayta yuklash' }).waitFor({ state: 'visible' });
          await main.getByText(/Rasm yuklanmadi\. Tavsifi:/i).waitFor({ state: 'visible' });
          await main.locator('summary', { hasText: 'Matnli bayon' }).click();
          await main.locator('[lang="en"]').getByText('Aziza:').waitFor({ state: 'visible' });
        } finally {
          await unthrottleAbort();
        }

        await main.getByRole('button', { name: 'Qayta yuklash' }).click();
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);
        await completeVisibleFlashcardDeck(page);
        await advanceLessonStep(page, /O‘rganganingizni sinab ko‘ring/i);
        await submitFreeTextAnswer(page, "I'm Sam");
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await finishCompletionDialog(page);
        assertCleanSession(session, 'T3-05');
      },
    },
    {
      id: 'T3-06',
      name: 'Course switch (course_eng_01 <-> course_math_01) combined with reload persistence',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await completeStarterLesson(page, baseUrl, helpers, "I'm Sam");
        await helpers.selectCourse(page, 'course_math_01');
        const main = page.getByRole('main');
        await main.getByRole('heading', { name: /O‘rganish rejangizni sozlang/i }).first().waitFor({ state: 'visible' });

        await helpers.selectCourse(page, 'course_eng_01');
        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          assert.equal(after.activeCourseId, 'course_eng_01');
          const completed = after.progress?.profile?.completedLessonIds ?? [];
          assert.equal(completed.includes('lesson_eng_starter'), true);
          assert.equal(completed.some((id) => id.startsWith('lesson_math_')), false);
          assert.equal(after.progress?.profile?.scoresByCourse?.course_math_01, undefined);
        });
        assertCleanSession(session, 'T3-06');
      },
    },
    {
      id: 'T3-07',
      name: 'Flashcard re-queue x mid-session Yo‘lchi AI x reload SRS persistence',
      milestone: ['M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Yana mashq qilaman' }).click();

        await helpers.openAndCloseYolchiAi(page, {
          askText: 'Nice to meet you nima degani?',
          closeWith: 'button',
          preserveStepIndicator: /^Qadam 3 \/ 4$/,
        });

        await main.getByRole('heading', { name: 'Nice to meet you.' }).waitFor({ state: 'visible' });
        await completeVisibleFlashcardDeck(page);

        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          assert.ok(
            after.progress?.profile?.flashcardSrsByCourse?.course_eng_01,
            'T3-07 (M2): Expected flashcardSrsByCourse.course_eng_01 persisted after reload.',
          );
        });
        assertCleanSession(session, 'T3-07');
      },
    },
    {
      id: 'T3-08',
      name: 'Wrong listening answer x Yo‘lchi AI mistake analysis x retry x unlocking Reading node',
      milestone: ['M1', 'M5'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await unlockEnglishRoadmapUpTo(page, 'list');

        await openRoadmapNodeLesson(page, /^Listening$/i);
        await advanceToExerciseStep(page);
        const main = page.getByRole('main');

        await main.getByRole('button', { name: /03:15|15:30 \(half past three\)/i }).first().click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('Javobni ko‘rib chiqamiz', { exact: true }).waitFor({ state: 'visible' });

        await main.getByRole('button', { name: 'Yo‘lchi AI tahlili' }).click();
        const mistakeDialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan xato tahlili' });
        await mistakeDialog.waitFor({ state: 'visible' });
        await mistakeDialog.getByRole('button', { name: 'Yopish' }).click();
        await mistakeDialog.waitFor({ state: 'hidden' });

        await main.getByRole('button', { name: 'Qayta urinish' }).click();
        await main.getByRole('button', { name: '15:15 (quarter past three)' }).click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await finishCompletionDialog(page);

        const readCard = main.locator('li').filter({
          has: page.getByRole('heading', { name: /^Reading$/i }),
        });
        await readCard.getByText(/Ochiq|Keyingi qadam/i).first().waitFor({ state: 'visible' });
        await readCard.getByRole('button', { name: 'Darsni boshlash' }).click();
        await main.getByRole('heading', { name: 'Asosiy g‘oya va dalil' }).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T3-08');
      },
    },
  ];
}

export const getTests = registerTests;
