import assert from 'node:assert/strict';
import {
  FAST_TIMEOUT,
  PLACEMENT_MIN_INTERVAL_MS,
  advanceLessonStep,
  advanceToExerciseStep,
  assertCleanSession,
  assertCourseIdentity,
  assertSingleCefrLevelScope,
  clickFirstVisibleButton,
  completeMcqLesson,
  completeRichExerciseStep,
  completeStarterLesson,
  completeVisibleFlashcardDeck,
  finishCompletionDialog,
  getCefrLevelSection,
  navigateToRoadmapFromWorkspace,
  openDirectEnglishLesson,
  openEnglishRoadmap,
  openRoadmapNodeLesson,
  openStarterLesson,
  solveEnglishPlacement,
  startEnglishPlacement,
  submitFreeTextAnswer,
  unlockEnglishRoadmapUpTo,
} from './flows.mjs';

export function registerTests() {
  return [
    // =========================================================================
    // F1: Course Selection & Isolation (T1-F1-01 .. T1-F1-05)
    // =========================================================================
    {
      id: 'T1-F1-01',
      name: 'Select course_eng_01 and confirm English course identity across selector, onboarding, and starter lesson',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await helpers.launchDemoSession(page, baseUrl);
        await helpers.selectCourse(page, 'course_eng_01');

        await assertCourseIdentity(page, helpers, 'course_eng_01', 'T1-F1-01 onboarding');
        const main = page.getByRole('main');
        const onboardingText = await main.innerText();
        assert.equal(
          /\b(Matematika|Algebra|Mantiq|IT & Kodlash)\b/i.test(onboardingText),
          false,
          `T1-F1-01: non-English course labels leaked into English onboarding: ${onboardingText}`,
        );

        await main.getByRole('radio', { name: /Noldan boshlayman/i }).check();
        await main.getByRole('button', { name: 'Birinchi darsni boshlash' }).click();
        await main
          .getByRole('heading', { name: 'Birinchi inglizcha so‘zlar' })
          .first()
          .waitFor({ state: 'visible' });

        await assertCourseIdentity(page, helpers, 'course_eng_01', 'T1-F1-01 starter lesson');
        assertCleanSession(session, 'T1-F1-01');
      },
    },
    {
      id: 'T1-F1-02',
      name: 'English roadmap displays English skills (Vocabulary, Grammar, Listening, Reading) and zero math nodes',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        for (const title of ['Vocabulary', 'Grammar', 'Listening', 'Reading']) {
          await main
            .getByRole('heading', { name: new RegExp(`^${title}$`, 'i') })
            .first()
            .waitFor({ state: 'visible' });
        }

        const roadmapText = await main.innerText();
        assert.equal(
          /\b(Algebra|Tenglamalar|Funksiyalar|Grafiklar)\b/i.test(roadmapText),
          false,
          `T1-F1-02: Math roadmap nodes leaked into English roadmap: ${roadmapText}`,
        );
        assertCleanSession(session, 'T1-F1-02');
      },
    },
    {
      id: 'T1-F1-03',
      name: 'Completing English starter lesson does not mutate course_math_01 completion or scores',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await completeStarterLesson(page, baseUrl, helpers, "I'm Sam");
        await helpers.selectCourse(page, 'course_math_01');

        const main = page.getByRole('main');
        await main
          .getByRole('heading', { name: /O‘rganish rejangizni sozlang/i })
          .first()
          .waitFor({ state: 'visible' });

        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const completed = snapshot.progress?.profile?.completedLessonIds ?? [];
        assert.equal(
          completed.includes('lesson_eng_starter'),
          true,
          'Expected lesson_eng_starter in completedLessonIds.',
        );
        assert.equal(
          completed.some((id) => id.startsWith('lesson_math_')),
          false,
          `Expected zero math lesson completions, got: ${JSON.stringify(completed)}`,
        );
        assert.equal(
          snapshot.progress?.profile?.scoresByCourse?.course_math_01,
          undefined,
          'Expected scoresByCourse.course_math_01 to remain untouched.',
        );
        assertCleanSession(session, 'T1-F1-03');
      },
    },
    {
      id: 'T1-F1-04',
      name: 'Switching from course_math_01 back to course_eng_01 preserves English progress and avoids math mastery lock',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await completeStarterLesson(page, baseUrl, helpers, "I'm Sam");
        await helpers.selectCourse(page, 'course_math_01');
        const main = page.getByRole('main');
        await main.getByRole('radio', { name: /Asoslarini bilaman/i }).check();
        await main.getByRole('button', { name: 'Ta’lim yo‘lini ochish' }).click();
        await main
          .getByRole('heading', { name: /Mening ta’lim yo‘lim/i })
          .first()
          .waitFor({ state: 'visible' });

        await helpers.selectCourse(page, 'course_eng_01');
        const snapshot = await assertCourseIdentity(page, helpers, 'course_eng_01', 'T1-F1-04 return');
        const completed = snapshot.progress?.profile?.completedLessonIds ?? [];
        assert.equal(
          completed.includes('lesson_eng_starter'),
          true,
          'Expected lesson_eng_starter to stay completed after switching via course_math_01.',
        );
        const vocabScore = snapshot.progress?.profile?.scoresByCourse?.course_eng_01?.skill_eng_vocab?.score ?? 0;
        assert.ok(
          vocabScore >= 50 && vocabScore <= 55,
          `Expected calibrated starter English vocab score (50..55) preserved after switching courses, got ${vocabScore}.`,
        );

        await navigateToRoadmapFromWorkspace(page);
        await main.getByRole('button', { name: 'Boshlang‘ich darsni ochish' }).click();
        await main
          .getByRole('heading', { name: 'Men, siz va oddiy gaplar' })
          .first()
          .waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F1-04');
      },
    },
    {
      id: 'T1-F1-05',
      name: 'English lesson media and English transcripts (language: en) load cleanly inside course_eng_01',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

        const main = page.getByRole('main');
        const starterAudio = main.locator('audio[src="/lesson-media/english/a1-starter-dialogue.wav"]');
        await starterAudio.waitFor({ state: 'visible' });
        const starterLangCount = await main.locator('[lang="en"]').count();
        assert.ok(starterLangCount >= 1, 'Expected [lang="en"] transcript block in starter lesson.');

        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_listening_01');
        await advanceLessonStep(page, /2\. Audio Xabarni Tinglash/i);
        await main
          .locator('audio[src="/lesson-media/english/a1-listening-lecture-time.wav"]')
          .waitFor({ state: 'visible' });
        await main.locator('details summary', { hasText: 'Matnli bayon' }).click();
        await main.locator('[lang="en"]', { hasText: /in the afternoon/i }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F1-05');
      },
    },

    // =========================================================================
    // F2: Placement Test (T1-F2-01 .. T1-F2-05)
    // =========================================================================
    {
      id: 'T1-F2-01',
      name: 'Course English placement path renders first course_eng_01 diagnostic question with zero math items',
      milestone: ['M1', 'M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');

        await assertCourseIdentity(page, helpers, 'course_eng_01', 'T1-F2-01');
        await main.getByText(/^1\s*\/\s*\d+\s+savol$/i).first().waitFor({ state: 'visible' });
        const optionCount = await main.getByRole('radio').count();
        assert.ok(optionCount >= 3, `Expected >= 3 placement radio options, got ${optionCount}.`);

        const text = await main.innerText();
        assert.equal(
          /\b(parabola|tenglama|kvadrat|funksiya)\b/i.test(text),
          false,
          `T1-F2-01: Math placement text leaked into English placement: ${text}`,
        );
        assertCleanSession(session, 'T1-F2-01');
      },
    },
    {
      id: 'T1-F2-02',
      name: 'Placement test adapts across English skills (vocab, grammar, listening, reading) and finishes with CEFR level',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const counterText = (await main.getByText(/^\d+\s*\/\s*\d+\s+savol$/i).first().textContent()) ?? '';
        const totalMatch = counterText.match(/\/\s*(\d+)/);
        const total = totalMatch ? Number(totalMatch[1]) : 8;

        for (let step = 1; step <= total; step++) {
          await main.getByRole('radio').first().check();
          const isLast = step === total;
          const nextBtn = main.getByRole('button', {
            name: isLast ? /Natijani ko‘rish/i : /Keyingi savol/i,
          });
          await page.waitForTimeout(PLACEMENT_MIN_INTERVAL_MS);
          await nextBtn.click();
          if (isLast) {
            const modal = page.getByRole('dialog', { name: /Javoblarni topshirasizmi\?/i });
            await modal.waitFor({ state: 'visible' });
            await modal.getByRole('button', { name: /^Topshirish$/i }).click();
          } else {
            await main
              .getByText(new RegExp(`^${step + 1}\\s*/\\s*${total}\\s+savol$`, 'i'))
              .first()
              .waitFor({ state: 'visible' });
          }
        }

        await main
          .getByRole('heading', { name: /Diagnostika yakunlandi/i })
          .first()
          .waitFor({ state: 'visible' });

        const resultText = await main.innerText();
        assert.match(
          resultText,
          /(?:CEFR daraja|Уровень CEFR):\s*(Pre-A1|A1|A2|B1)\b/i,
          'T1-F2-02 (M5): Expected calibrated CEFR level badge (Pre-A1..B1) on English placement completion.',
        );
        assert.match(
          resultText,
          /Keyingi bosqich \(DEFERRED\)|B2–C2/i,
          'T1-F2-02 (M5): Expected B2–C2 deferred note on English placement completion.',
        );
        assertCleanSession(session, 'T1-F2-02');
      },
    },
    {
      id: 'T1-F2-03',
      name: 'English listening placement item provides playable audio player without leaking Audio context text in stem',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');
        let foundAudioPlayer = false;

        for (let step = 1; step <= 12; step++) {
          const stemText = (await main.locator('h2').first().textContent().catch(() => '')) ?? '';
          assert.equal(
            /Audio context:/i.test(stemText),
            false,
            `T1-F2-03 (M5): Placement listening question leaked raw "Audio context:" script in stem: "${stemText}"`,
          );

          const audioLocator = main.locator('audio');
          if ((await audioLocator.count()) > 0) {
            await audioLocator.first().waitFor({ state: 'visible' });
            const audioSrc = (await audioLocator.first().getAttribute('src')) ?? '';
            assert.match(
              audioSrc,
              /^\/lesson-media\/english\/placement\/q_eng_place_listening_.*\.wav$/i,
              `T1-F2-03 (M5): Expected real offline placement WAV src, got "${audioSrc}"`,
            );
            await page.waitForFunction(() => {
              const el = document.querySelector('main audio');
              return Boolean(el && Number.isFinite(el.duration) && el.duration > 1);
            });
            const details = main.locator('details');
            await details.first().waitFor({ state: 'visible' });
            assert.equal(
              await details.first().evaluate((el) => el.hasAttribute('open')),
              false,
              'T1-F2-03 (M5): Placement listening transcript <details> must start collapsed.',
            );
            await details.first().locator('summary').click();
            await main.locator('[lang="en"]').first().waitFor({ state: 'visible' });
            foundAudioPlayer = true;
            break;
          }

          const nextBtn = main.getByRole('button', { name: /Keyingi savol/i });
          if (!(await nextBtn.isVisible().catch(() => false))) {
            break;
          }
          await main.getByRole('radio').first().check();
          await page.waitForTimeout(PLACEMENT_MIN_INTERVAL_MS);
          await nextBtn.click();
        }

        assert.equal(
          foundAudioPlayer,
          true,
          'T1-F2-03 (M5): Expected English listening placement item to render a real <audio> player instead of plain text.',
        );
        assertCleanSession(session, 'T1-F2-03');
      },
    },
    {
      id: 'T1-F2-04',
      name: 'High-accuracy placement assigns CEFR level (A2/B1), unlocks roadmap entry, and isolates placementScoreByCourse',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const { correct, total } = await solveEnglishPlacement(page, { accuracy: 'high' });
        assert.ok(
          total > 0 && correct / total >= 0.75,
          `T1-F2-04 (M5): Expected high-accuracy placement (>= 75%), got ${correct}/${total}.`,
        );

        const resultText = await main.innerText();
        assert.match(
          resultText,
          /(?:CEFR daraja|Уровень CEFR):\s*(A2|B1)\b/i,
          `T1-F2-04 (M5): Expected assigned CEFR level badge A2/B1 after high-accuracy placement, got: ${resultText}`,
        );
        assert.match(
          resultText,
          /Keyingi bosqich \(DEFERRED\)|B2–C2/i,
          'T1-F2-04 (M5): Expected B2–C2 deferred note on capped B1 placement result.',
        );

        await main.getByRole('button', { name: /Shaxsiy yo‘lni ko‘rish|Посмотреть свой план/i }).click();
        await main
          .getByRole('heading', { name: /Mening ta’lim yo‘lim|Мой путь обучения/i })
          .first()
          .waitFor({ state: 'visible' });

        const unlockedLevelEntry = main
          .locator('[data-cefr-level="A2"], [data-cefr-level="B1"], li, article')
          .filter({ hasText: /\b(A2|B1)\b/ })
          .filter({ has: page.getByRole('button', { name: /Darsni boshlash|Начать урок/i }) });
        await helpers.expectVisibleFast(
          unlockedLevelEntry,
          'T1-F2-04 (M5): Expected A2/B1 roadmap entry unlocked after high-accuracy placement.',
          FAST_TIMEOUT,
        );

        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const profile = snapshot.progress?.profile;
        assert.ok(
          profile?.placementScoreByCourse?.course_eng_01 !== undefined,
          'T1-F2-04 (M5): Expected placementScoreByCourse.course_eng_01 persisted.',
        );
        const engCompletedLessons = (profile?.completedLessonIds ?? []).filter((id) =>
          id.startsWith('lesson_eng_'),
        );
        const engCompletedNodes = (profile?.completedNodeIds ?? []).filter((id) =>
          id.startsWith('node_eng_'),
        );
        assert.deepEqual(
          engCompletedLessons,
          [],
          `T1-F2-04 (M5): Placement MUST NOT fabricate completedLessonIds, got ${JSON.stringify(engCompletedLessons)}`,
        );
        assert.deepEqual(
          engCompletedNodes,
          [],
          `T1-F2-04 (M5): Placement MUST NOT fabricate independent node mastery, got ${JSON.stringify(engCompletedNodes)}`,
        );
        assertCleanSession(session, 'T1-F2-04');
      },
    },
    {
      id: 'T1-F2-05',
      name: 'Beginner-accuracy placement routes learner to Pre-A1/A1 without B1-hard or C1/C2 spikes',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const { correct, total, stems } = await solveEnglishPlacement(page, { accuracy: 'low' });
        assert.equal(
          correct,
          0,
          `T1-F2-05 (M5): Expected deterministic 0/${total} on low-accuracy placement, got ${correct}/${total}.`,
        );
        for (const stemText of stems) {
          assert.equal(
            /contradictory|subsequent rigorous trials|Rarely have I seen|traffic jams|Dilshod has lived|morning session|City Bike Pass/i.test(stemText),
            false,
            `T1-F2-05 (M5): Beginner placement trajectory served advanced B1/C1/C2 question: "${stemText}"`,
          );
        }

        const resultText = await main.innerText();
        assert.match(
          resultText,
          /(?:CEFR daraja|Уровень CEFR):\s*(Pre-A1|A1)\b/i,
          `T1-F2-05 (M5): Expected beginner placement result badge Pre-A1/A1, got: ${resultText}`,
        );
        await main.getByRole('button', { name: /Shaxsiy yo‘lni ko‘rish|Посмотреть свой план/i }).click();
        await helpers.expectVisibleFast(
          main.getByText(/\bA1\b|Birinchi inglizcha so‘zlar|1-boshlang‘ich dars/i),
          'T1-F2-05 (M5): Expected beginner placement handoff to route to A1 / lesson_eng_starter.',
          FAST_TIMEOUT,
        );
        assertCleanSession(session, 'T1-F2-05');
      },
    },

    // =========================================================================
    // F3: Starter Lesson (T1-F3-01 .. T1-F3-05)
    // =========================================================================
    {
      id: 'T1-F3-01',
      name: 'Starter lesson renders Aziza & Ben two-voice audio player with Replay, speed control, and collapsible transcript',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

        const main = page.getByRole('main');
        const audio = main.locator('audio[src="/lesson-media/english/a1-starter-dialogue.wav"]');
        await audio.waitFor({ state: 'visible' });
        await page.waitForFunction(() => {
          const el = document.querySelector('audio[src="/lesson-media/english/a1-starter-dialogue.wav"]');
          return Boolean(el && Number.isFinite(el.duration) && el.duration > 4);
        });

        await main.getByLabel(/Ijro tezligi/i).waitFor({ state: 'visible' });
        await audio.evaluate((el) => {
          el.currentTime = 1.5;
          el.pause();
        });
        await main.getByRole('button', { name: 'Qayta tinglash' }).click();
        const currentTime = await audio.evaluate((el) => el.currentTime);
        assert.ok(currentTime < 0.5, `Expected Replay to reset audio currentTime < 0.5s, got ${currentTime}`);

        const details = main.locator('details');
        await details.waitFor({ state: 'visible' });
        const isOpenInitially = await details.evaluate((el) => el.hasAttribute('open'));
        assert.equal(isOpenInitially, false, 'Expected starter transcript <details> collapsed initially.');

        await details.locator('summary', { hasText: 'Matnli bayon' }).click();
        await main.locator('[lang="en"]').getByText('Aziza:').waitFor({ state: 'visible' });
        await main.locator('[lang="en"]').getByText('Ben:').waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F3-01');
      },
    },
    {
      id: 'T1-F3-02',
      name: 'Starter dialogue visual renders Tashkent school greeting illustration with non-empty alt and naturalWidth > 0',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

        const img = page
          .getByRole('main')
          .locator('img[src="/lesson-media/english/a1-starter-greeting.png"]');
        await img.waitFor({ state: 'visible' });
        await page
          .waitForFunction(
            () => {
              const el = document.querySelector('main img[src="/lesson-media/english/a1-starter-greeting.png"]');
              return Boolean(el && el.complete && el.naturalWidth > 0);
            },
            null,
            { timeout: FAST_TIMEOUT },
          )
          .catch(() => {});
        const meta = await img.evaluate((el) => ({
          complete: el.complete,
          naturalWidth: el.naturalWidth,
          alt: el.getAttribute('alt') ?? '',
        }));
        assert.equal(meta.complete, true, 'Expected starter illustration image to finish loading.');
        assert.ok(meta.naturalWidth > 0, `Expected naturalWidth > 0, got ${meta.naturalWidth}`);
        assert.ok(meta.alt.trim().length >= 10, `Expected meaningful alt text, got "${meta.alt}"`);
        assertCleanSession(session, 'T1-F3-02');
      },
    },
    {
      id: 'T1-F3-03',
      name: 'Starter flashcard step hides meaning before reveal, shows IPA/audio/example on reveal, and completes with Eslab qoldim',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
        assert.equal(
          await main.getByText('Ismingiz nima?').count(),
          0,
          'Card meaning must stay hidden before Javobni ko‘rish is clicked.',
        );

        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByText('Ismingiz nima?', { exact: true }).waitFor({ state: 'visible' });
        await main.getByText('/wɒts jɔː neɪm/', { exact: true }).waitFor({ state: 'visible' });
        await main.getByText("Hi, I'm Aziza. What's your name?", { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Talaffuzni tinglash/i }).waitFor({ state: 'visible' });

        await main.getByRole('button', { name: 'Eslab qoldim' }).click();
        await main.getByText('1 / 2', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('heading', { name: 'Nice to meet you.' }).waitFor({ state: 'visible' });

        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Eslab qoldim' }).click();
        await main
          .getByRole('heading', { name: 'Barcha kartochkalar ko‘rib chiqildi' })
          .waitFor({ state: 'visible' });
        await main.getByText('2 / 2', { exact: true }).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F3-03');
      },
    },
    {
      id: 'T1-F3-04',
      name: 'Starter free-text exercise accepts both "I\'m Sam" and "My name is Sam" with positive feedback',
      milestone: ['M1'],
      async run({ browser, page, baseUrl, session, helpers, screenshotsDir }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceToExerciseStep(page);
        await submitFreeTextAnswer(page, "I'm Sam");
        const main = page.getByRole('main');
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await main.getByText('+2 XP', { exact: true }).waitFor({ state: 'visible' });
        await page.getByRole('dialog', { name: 'Dars yakunlandi' }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F3-04-a');

        await helpers.runWithContext(
          browser,
          { defaultTimeout: 5000 },
          async (sub) => {
            await openStarterLesson(sub.page, baseUrl, helpers);
            await advanceToExerciseStep(sub.page);
            await submitFreeTextAnswer(sub.page, 'My name is Sam');
            const subMain = sub.page.getByRole('main');
            await subMain.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
            await sub.page.getByRole('dialog', { name: 'Dars yakunlandi' }).waitFor({ state: 'visible' });
            assertCleanSession(sub, 'T1-F3-04-b');
          },
          { id: 'T1-F3-04-b', screenshotsDir },
        );
      },
    },
    {
      id: 'T1-F3-05',
      name: 'Completing lesson_eng_starter persists completion, XP, and unlocks lesson_eng_foundation_02 after reload',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await completeStarterLesson(page, baseUrl, helpers, "I'm Sam");
        const main = page.getByRole('main');

        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          const completed = after.progress?.profile?.completedLessonIds ?? [];
          assert.equal(
            completed.includes('lesson_eng_starter'),
            true,
            'Expected lesson_eng_starter in completedLessonIds after reload.',
          );
          assert.ok(
            (after.progress?.profile?.xp ?? 0) >= 22,
            `Expected xp >= 22 after starter completion, got ${after.progress?.profile?.xp}`,
          );
        });

        await main.getByRole('heading', { name: 'Boshlang‘ich darslar' }).first().waitFor({ state: 'visible' });
        await main.getByText(/1\s*\/\s*2\s*dars tugallangan/i).first().waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Boshlang‘ich darsni ochish' }).click();
        await main
          .getByRole('heading', { name: 'Men, siz va oddiy gaplar' })
          .first()
          .waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F3-05');
      },
    },

    // =========================================================================
    // F4: Reading & Listening (T1-F4-01 .. T1-F4-05)
    // =========================================================================
    {
      id: 'T1-F4-01',
      name: 'Unlocking and clicking node_eng_read (Reading) on English roadmap opens lesson_eng_reading_01 cleanly',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await unlockEnglishRoadmapUpTo(page, 'read');

        const main = page.getByRole('main');
        const readCard = main.locator('li').filter({
          has: page.getByRole('heading', { name: /^Reading$/i }),
        });
        await readCard.getByText(/Ochiq|Keyingi qadam/i).first().waitFor({ state: 'visible' });
        await readCard.getByRole('button', { name: 'Darsni boshlash' }).click();

        await main
          .getByRole('heading', { name: 'Asosiy g‘oya va dalil' })
          .first()
          .waitFor({ state: 'visible' });
        assert.match(page.url(), /lessonId=lesson_eng_reading_01/);
        assertCleanSession(session, 'T1-F4-01');
      },
    },
    {
      id: 'T1-F4-02',
      name: 'Completing lesson_eng_reading_01 with passage evidence marks lesson and node_eng_read completed',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_reading_01');
        const main = page.getByRole('main');

        await advanceLessonStep(page, /Ishlangan misol/i);
        await main.getByText(/repair club/i).first().waitFor({ state: 'visible' });
        await completeMcqLesson(page, 'To‘garak buyumlarni ta’mirlab, chiqindini kamaytiradi');

        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const completedLessons = snapshot.progress?.profile?.completedLessonIds ?? [];
        const completedNodes = snapshot.progress?.profile?.completedNodeIds ?? [];
        assert.equal(
          completedLessons.includes('lesson_eng_reading_01'),
          true,
          'Expected lesson_eng_reading_01 in completedLessonIds.',
        );
        assert.equal(
          completedNodes.includes('node_eng_read'),
          true,
          `Expected node_eng_read in completedNodeIds, got: ${JSON.stringify(completedNodes)}`,
        );

        const readCard = main.locator('li').filter({
          has: page.getByRole('heading', { name: /^Reading$/i }),
        });
        await readCard.first().waitFor({ state: 'visible' });
        await readCard.first().getByText('Yakunlangan', { exact: true }).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F4-02');
      },
    },
    {
      id: 'T1-F4-03',
      name: 'lesson_eng_listening_01 renders audio player with collapsed optional transcript containing "quarter past three in the afternoon"',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_listening_01');
        await advanceLessonStep(page, /2\. Audio Xabarni Tinglash/i);

        const main = page.getByRole('main');
        await main
          .locator('audio[src="/lesson-media/english/a1-listening-lecture-time.wav"]')
          .waitFor({ state: 'visible' });

        const details = main.locator('details');
        await details.waitFor({ state: 'visible' });
        assert.equal(
          await details.evaluate((el) => el.hasAttribute('open')),
          false,
          'Expected listening transcript collapsed by default unless requested by learner.',
        );

        await details.locator('summary', { hasText: 'Matnli bayon' }).click();
        await main
          .locator('[lang="en"]')
          .getByText(/quarter past three in the afternoon/i)
          .waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F4-03');
      },
    },
    {
      id: 'T1-F4-04',
      name: 'lesson_eng_listening_01 accepts 15:15 (quarter past three) and reinforcement accepts 16:30',
      milestone: ['M1'],
      async run({ browser, page, baseUrl, session, helpers, screenshotsDir }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_listening_01');
        await completeMcqLesson(page, '15:15 (quarter past three)');

        const snapshot = await helpers.readDemoProgressSnapshot(page);
        assert.equal(
          (snapshot.progress?.profile?.completedLessonIds ?? []).includes('lesson_eng_listening_01'),
          true,
          'Expected lesson_eng_listening_01 completed on 15:15 answer.',
        );
        assertCleanSession(session, 'T1-F4-04-main');

        await helpers.runWithContext(
          browser,
          { defaultTimeout: 5000 },
          async (sub) => {
            await openEnglishRoadmap(sub.page, baseUrl, helpers);
            await openDirectEnglishLesson(sub.page, baseUrl, 'lesson_eng_listening_01');
            await advanceToExerciseStep(sub.page);
            const subMain = sub.page.getByRole('main');
            await subMain.getByRole('button', { name: '15:30 (half past three)' }).click();
            await subMain.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
            await subMain.getByRole('button', { name: 'Mavzuni mustahkamlash mashqi' }).click();

            const reinfDialog = sub.page.getByRole('dialog', { name: 'Mustahkamlash mashqi' });
            await reinfDialog.waitFor({ state: 'visible' });
            await reinfDialog.getByRole('button', { name: '16:30' }).click();
            await reinfDialog.getByRole('button', { name: 'Javobni Tekshirish' }).click();
            await reinfDialog
              .getByRole('heading', { name: 'Mavzu Muvaffaqiyatli Mustahkamlandi!' })
              .waitFor({ state: 'visible' });
            await reinfDialog.getByRole('button', { name: 'Davom etish' }).click();
            assertCleanSession(sub, 'T1-F4-04-reinf');
          },
          { id: 'T1-F4-04-reinf', screenshotsDir },
        );
      },
    },
    {
      id: 'T1-F4-05',
      name: 'Reading checkpoint (bilimyol-reading:*) restores step index on reload without marking lesson completed',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_reading_01');
        await advanceLessonStep(page, /Ishlangan misol/i);

        const main = page.getByRole('main');
        await main.getByText('Qadam 2 / 3', { exact: true }).waitFor({ state: 'visible' });

        const checkpointsBefore = await helpers.readReadingCheckpoints(page);
        const readingKey = Object.keys(checkpointsBefore).find((k) =>
          k.includes('lesson_eng_reading_01'),
        );
        assert.ok(readingKey, 'Expected bilimyol-reading:* checkpoint key for lesson_eng_reading_01.');
        assert.equal(checkpointsBefore[readingKey], '1', 'Expected checkpoint step index "1".');

        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          const completed = after.progress?.profile?.completedLessonIds ?? [];
          assert.equal(
            completed.includes('lesson_eng_reading_01'),
            false,
            'Reading checkpoint MUST NOT mark lesson_eng_reading_01 completed.',
          );
        });

        await main.getByText('Qadam 2 / 3', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('heading', { name: 'Ishlangan misol' }).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F4-05');
      },
    },

    // =========================================================================
    // F5: CEFR Progression (A1–B1 Active; B2–C2 DEFERRED), Checkpoints & Rubrics
    // =========================================================================
    {
      id: 'T1-F5-01',
      name: 'English roadmap displays active A1->B1 grouped modules and DEFERRED B2->C2 placeholders with distinct foundation_02 exercise',
      milestone: ['M2', 'M3', 'M5', 'M6'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        // 1. Verify all 6 CEFR sections render in ascending section[data-cefr-level] DOM/topY order
        const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
        const activeLevels = new Set(['A1', 'A2', 'B1']);
        const domOrder = await main
          .locator('section[data-cefr-level]')
          .evaluateAll((els) => els.map((el) => el.getAttribute('data-cefr-level')));
        assert.deepEqual(
          domOrder,
          levels,
          `T1-F5-01: Expected ascending section[data-cefr-level] order ${JSON.stringify(levels)}, got ${JSON.stringify(domOrder)}.`,
        );

        const topPositions = [];
        for (const level of levels) {
          const section = getCefrLevelSection(main, level);
          await helpers.expectVisibleFast(
            section,
            `T1-F5-01: Expected grouped CEFR ${level} section with module heading on English roadmap.`,
            FAST_TIMEOUT,
          );
          await assertSingleCefrLevelScope(section, level, 'T1-F5-01');
          const sectionText = (await section.innerText()).trim();
          assert.ok(
            sectionText.length >= 30 && !/^(A1|A2|B1|B2|C1|C2)$/i.test(sectionText),
            `T1-F5-01: Expected module & can-do objective inside ${level} section, got "${sectionText}".`,
          );
          const topY = await section.evaluate((el) => el.getBoundingClientRect().top + window.scrollY);
          topPositions.push({ level, topY });

          if (activeLevels.has(level)) {
            assert.match(
              sectionText,
              /O‘quv maqsadi/i,
              `T1-F5-01: Expected active ${level} section to show O‘quv maqsadi.`,
            );
            const timelineItemCount = await section.locator('ol.learning-timeline li').count();
            assert.ok(
              timelineItemCount > 0,
              `T1-F5-01: Expected active ${level} section to render >= 1 <ol class="learning-timeline"> items, got ${timelineItemCount}.`,
            );
          } else {
            assert.match(
              sectionText,
              /Keyingi bosqich \(DEFERRED\)/i,
              `T1-F5-01: Expected deferred ${level} section to render Keyingi bosqich (DEFERRED).`,
            );
            assert.match(
              sectionText,
              /Qulflangan/i,
              `T1-F5-01: Expected deferred ${level} section to render Qulflangan.`,
            );
            assert.match(
              sectionText,
              /Ushbu CEFR bosqichi \(B2–C2\)/i,
              `T1-F5-01: Expected deferred ${level} section to render B2–C2 deferred notice.`,
            );
            assert.equal(
              await section.locator('ol.learning-timeline li').count(),
              0,
              `T1-F5-01: Deferred ${level} section must render 0 timeline <li> items.`,
            );
            assert.equal(
              await section.getByRole('button').count(),
              0,
              `T1-F5-01: Deferred ${level} section must render 0 interactive buttons.`,
            );
          }
        }
        for (let i = 1; i < topPositions.length; i++) {
          assert.ok(
            topPositions[i].topY > topPositions[i - 1].topY,
            `T1-F5-01: Expected ascending visual topY order (${topPositions[i - 1].level} < ${topPositions[i].level}), got ${JSON.stringify(topPositions)}.`,
          );
        }

        // 2. Verify lesson_eng_foundation_02 practice & reinforcement prompts are distinct (no duplicate prompt)
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_foundation_02');
        await advanceToExerciseStep(page);
        const lessonQuestionText = (await main.locator('h3').first().innerText()).trim();
        await main.getByRole('button', { name: /^([A-D]\s+)?is$/i }).click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByRole('button', { name: /Mavzuni mustahkamlash mashqi/i }).click();

        const reinfDialog = page.getByRole('dialog', { name: /Mustahkamlash mashqi/i });
        await reinfDialog.waitFor({ state: 'visible' });
        const reinfQuestionText = (await reinfDialog.innerText()).trim();
        assert.notEqual(
          reinfQuestionText.includes(lessonQuestionText),
          true,
          `T1-F5-01: lesson_eng_foundation_02 reinforcement duplicated lesson prompt "${lessonQuestionText}".`,
        );
        await reinfDialog.getByRole('button', { name: /^([A-D]\s+)?is$/i }).click();
        await reinfDialog.getByRole('button', { name: /Javobni Tekshirish/i }).click();
        await reinfDialog.getByRole('button', { name: /Davom etish/i }).click();
        assertCleanSession(session, 'T1-F5-01');
      },
    },
    {
      id: 'T1-F5-02',
      name: 'Grouped A1 module lesson executes rich exercise mode (fill_blank/word_match/sentence_order) with deterministic feedback',
      milestone: ['M2', 'M3'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const a1Section = getCefrLevelSection(main, 'A1');
        await helpers.expectVisibleFast(
          a1Section,
          'T1-F5-02 (M2): Expected grouped CEFR A1 level section and modules on English roadmap.',
          FAST_TIMEOUT,
        );
        await assertSingleCefrLevelScope(a1Section, 'A1', 'T1-F5-02 (M2)');
        const a1Objective = a1Section.getByText(/Can-Do|Maqsad|Tanishuv|O‘zini tanishtir|kundalik/i);
        await helpers.expectVisibleFast(
          a1Objective,
          'T1-F5-02 (M2): Expected module can-do objective inside grouped A1 section.',
          FAST_TIMEOUT,
        );

        const openableFilter = { has: page.getByRole('button', { name: /Darsni boshlash/i }) };
        const explicitRichNode = a1Section
          .locator('[data-has-rich-exercise="true"]')
          .filter(openableFilter);
        const nonMcqFallbackNode = a1Section
          .locator('li, article')
          .filter(openableFilter)
          .filter({ hasNotText: /Vocabulary|Grammar|Listening|Reading/i });
        const targetRichNode = (await explicitRichNode.count()) > 0
          ? explicitRichNode.first()
          : (await nonMcqFallbackNode.count()) > 0
            ? nonMcqFallbackNode.first()
            : a1Section.locator('li, article').filter(openableFilter).first();
        const richLessonBtn = targetRichNode.getByRole('button', { name: /Darsni boshlash/i });
        await helpers.expectVisibleFast(
          richLessonBtn,
          'T1-F5-02 (M2): Expected openable A1 module lesson trigger inside grouped A1 section.',
          FAST_TIMEOUT,
        );
        await richLessonBtn.click();

        await main.getByText(/^(Qadam|Шаг)\s+\d+\s*\/\s*\d+$/i).first().waitFor({ state: 'visible' });
        await advanceToExerciseStep(page);
        await completeRichExerciseStep(page);
        await finishCompletionDialog(page);
        assertCleanSession(session, 'T1-F5-02');
      },
    },
    {
      id: 'T1-F5-03',
      name: 'A1/A2 unit checkpoint assessment uses non-cloned contextual questions and unlocks next unit',
      milestone: ['M2', 'M3'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const checkpointCard = main
          .locator('[data-node-kind="unit_checkpoint"], [data-assessment-kind="unit_checkpoint"], li, article')
          .filter({ hasText: /Modul yakuni|Unit checkpoint|Bosqich sinovi|Checkpoint/i })
          .first();
        await helpers.expectVisibleFast(
          checkpointCard,
          'T1-F5-03 (M2-M3): Expected unit checkpoint node inside grouped A1/A2 roadmap.',
          FAST_TIMEOUT,
        );

        const lockedUnitsLocator = main
          .locator('[data-node-id], li, article')
          .filter({ hasText: /Qulflangan/i });
        await helpers.expectVisibleFast(
          lockedUnitsLocator.first(),
          'T1-F5-03 (M2-M3): Expected subsequent unit to start locked before unit checkpoint passes.',
          FAST_TIMEOUT,
        );
        const lockedCountBefore = await lockedUnitsLocator.count();

        const startCheckpointBtn = checkpointCard.getByRole('button', {
          name: /Sinovni boshlash|Darsni boshlash|Checkpoint/i,
        });
        await helpers.expectVisibleFast(
          startCheckpointBtn,
          'T1-F5-03 (M2-M3): Expected interactive trigger to open unit checkpoint assessment.',
          FAST_TIMEOUT,
        );
        await startCheckpointBtn.click();

        await main.getByText(/^(Qadam|Шаг)\s+\d+\s*\/\s*\d+$/i).first().waitFor({ state: 'visible' });
        await advanceToExerciseStep(page);

        const checkpointPrompt = (await main.locator('h3').first().innerText()).trim();
        assert.ok(
          checkpointPrompt.length >= 10 &&
            !/What's your name\?|quarter past three|repair club/i.test(checkpointPrompt),
          `T1-F5-03: Checkpoint must use fresh contextual question, got "${checkpointPrompt}".`,
        );

        await main.locator('button[aria-pressed]').first().click().catch(async () => {
          await main.locator('button').filter({ hasText: /^[A-D]\s+/ }).first().click();
        });
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await finishCompletionDialog(page);

        const checkpointBadge = checkpointCard.getByText(/Yakunlangan|O‘zlashtirilgan/i);
        await checkpointBadge.first().waitFor({ state: 'visible' });
        const lockedCountAfter = await lockedUnitsLocator.count();
        assert.ok(
          lockedCountAfter < lockedCountBefore,
          `T1-F5-03 (M2-M3): Expected next unit to unlock after unit checkpoint completion (locked before=${lockedCountBefore}, after=${lockedCountAfter}).`,
        );
        assertCleanSession(session, 'T1-F5-03');
      },
    },
    {
      id: 'T1-F5-04',
      name: 'B1 speaking_prompt self_assessed task displays model response, 3 rubric criteria, and self-assessment badge without fake CEFR certificate',
      milestone: ['M3', 'M5', 'M6'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');
        const { correct, total } = await solveEnglishPlacement(page, { accuracy: 'high' });
        assert.ok(total > 0 && correct === total, `T1-F5-04: Expected full B1 placement score, got ${correct}/${total}.`);

        await main.getByRole('button', { name: /Shaxsiy yo‘lni ko‘rish|Посмотреть свой план/i }).click();
        await main
          .getByRole('heading', { name: /Mening ta’lim yo‘lim|Мой путь обучения/i })
          .first()
          .waitFor({ state: 'visible' });

        const targetSection = getCefrLevelSection(main, 'B1');
        await helpers.expectVisibleFast(
          targetSection,
          'T1-F5-04: Expected grouped B1 section on English roadmap.',
          FAST_TIMEOUT,
        );

        const b1TravelNode = targetSection.locator('[data-node-id="node_eng_b1_m1_travel"]');
        const productiveBtn = b1TravelNode.getByRole('button', { name: /Darsni boshlash|Mashqni boshlash/i });
        await helpers.expectVisibleFast(
          productiveBtn,
          'T1-F5-04: Expected unlocked node_eng_b1_m1_travel speaking_prompt lesson after B1 placement.',
          FAST_TIMEOUT,
        );
        await productiveBtn.click();

        // Advance cleanly through Steps 1-5 to Step 6 (speaking_prompt)
        await main.getByText(/^Qadam 1 \/ 6$/i).first().waitFor({ state: 'visible' });
        await advanceLessonStep(page);
        await advanceLessonStep(page);
        await completeVisibleFlashcardDeck(page);
        await advanceLessonStep(page);

        // Step 4: listening MCQ (q_eng_b1_m1_listen_mcq)
        await main
          .getByRole('button', { name: /11:15 da 19-darvozadan; turar joy tasdiq xati hali kelmagan edi/i })
          .click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Keyingi savol/i }).click();

        // Step 5: fill_blank (q_eng_b1_m1_fill)
        await main.getByRole('textbox').first().fill('left');
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Keyingi savol/i }).click();

        // Step 6: speaking_prompt (q_eng_b1_m1_speaking, self_assessed)
        await helpers.expectVisibleFast(
          main.getByText(/O‘zini baholash · Mustaqil mashq/i),
          'T1-F5-04: Expected explicit self-assessment badge before submitting B1 speaking prompt.',
          FAST_TIMEOUT,
        );
        const responseInput = main.getByRole('textbox').first();
        await helpers.expectVisibleFast(
          responseInput,
          'T1-F5-04: Expected response input on B1 speaking_prompt step.',
          FAST_TIMEOUT,
        );
        await responseInput.fill(
          'I have already printed my boarding pass, and the airline rescheduled our flight to 11:15. I checked the updated itinerary ten minutes ago, and my accommodation email has not arrived yet.',
        );
        await main
          .getByRole('button', { name: /^TEKSHIRISH$/i })
          .first()
          .click();

        await helpers.expectVisibleFast(
          main.getByText(/Namuna javob/i),
          'T1-F5-04: Expected model response panel after submitting self_assessed prompt.',
          FAST_TIMEOUT,
        );
        await helpers.expectVisibleFast(
          main.getByText(/Baholash mezoni/i),
          'T1-F5-04: Expected self-assessment rubric criteria.',
          FAST_TIMEOUT,
        );
        const rubricCount = await main.getByRole('checkbox').count();
        assert.equal(rubricCount, 3, `T1-F5-04: Expected 3 self-assessment rubric checkboxes, got ${rubricCount}.`);
        await main.getByRole('checkbox').first().check();
        await helpers.expectVisibleFast(
          main.getByText(/Mustaqil amaliyot natijasi.*xalqaro daraja hujjati hisoblanmaydi/i),
          'T1-F5-04: Expected non-certification self-assessment disclaimer.',
          FAST_TIMEOUT,
        );

        const fullText = await main.innerText();
        assert.equal(
          /Official CEFR Certificate|Rasmiy CEFR sertifikati|Официальный сертификат CEFR/i.test(fullText),
          false,
          `T1-F5-04: Self-assessed task MUST NOT claim official CEFR certification: ${fullText}`,
        );
        assertCleanSession(session, 'T1-F5-04');
      },
    },
    {
      id: 'T1-F5-05',
      name: 'Deferred B2, C1, and C2 sections render cleanly as upcoming/DEFERRED with zero clickable lesson nodes or b2/c1/c2 media leaks',
      milestone: ['M5', 'M6'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        for (const level of ['B2', 'C1', 'C2']) {
          const section = getCefrLevelSection(main, level);
          await helpers.expectVisibleFast(
            section,
            `T1-F5-05: Expected deferred ${level} CEFR section on English roadmap.`,
            FAST_TIMEOUT,
          );
          await assertSingleCefrLevelScope(section, level, 'T1-F5-05');
          const sectionText = await section.innerText();
          assert.match(
            sectionText,
            /Keyingi bosqich \(DEFERRED\)/i,
            `T1-F5-05: Expected Keyingi bosqich (DEFERRED) badge in ${level} section.`,
          );
          assert.match(
            sectionText,
            /Qulflangan/i,
            `T1-F5-05: Expected Qulflangan status in ${level} section.`,
          );
          assert.match(
            sectionText,
            /Rejalashtirilgan grammatika va lug‘at qamrovi/i,
            `T1-F5-05: Expected planned grammar/vocabulary scope in ${level} section.`,
          );
          assert.equal(
            await section.locator('ol.learning-timeline li').count(),
            0,
            `T1-F5-05: Deferred ${level} section must have 0 <ol.learning-timeline li> nodes.`,
          );
          assert.equal(
            await section.getByRole('button').count(),
            0,
            `T1-F5-05: Deferred ${level} section must have 0 clickable <button> elements.`,
          );
        }

        const leakedNodes = await main.locator('[data-node-id*="_b2_"], [data-node-id*="_c1_"], [data-node-id*="_c2_"]').count();
        assert.equal(leakedNodes, 0, `T1-F5-05: Found ${leakedNodes} leaked B2/C1/C2 node IDs on roadmap.`);
        const leakedMedia = await main
          .locator('audio[src*="/b2/"], audio[src*="/c1/"], audio[src*="/c2/"], img[src*="/b2/"], img[src*="/c1/"], img[src*="/c2/"]')
          .count();
        assert.equal(leakedMedia, 0, `T1-F5-05: Found ${leakedMedia} leaked B2/C1/C2 media elements.`);

        for (const deferredLessonId of ['lesson_eng_b2_m1_interview', 'lesson_eng_c1_m1_seminar']) {
          await page.goto(`${baseUrl}/?view=lesson&lessonId=${encodeURIComponent(deferredLessonId)}`, {
            waitUntil: 'domcontentloaded',
            timeout: 15000,
          });
          await helpers.expectVisibleFast(
            main.getByText(/Dars topilmadi|topilmadi/i),
            `T1-F5-05: Expected missing/deferred fallback for ${deferredLessonId}.`,
            FAST_TIMEOUT,
          );
          assert.equal(
            await main.getByRole('button', { name: /^TEKSHIRISH$/i }).count(),
            0,
            `T1-F5-05: Deferred lesson ${deferredLessonId} must render 0 TEKSHIRISH buttons.`,
          );
          assert.equal(
            await main.locator('audio[src*="/b2/"], audio[src*="/c1/"], audio[src*="/c2/"]').count(),
            0,
            `T1-F5-05: Deferred lesson ${deferredLessonId} must emit 0 B2/C1/C2 media elements.`,
          );
        }
        assertCleanSession(session, 'T1-F5-05');
      },
    },

    // =========================================================================
    // F6: Flashcards & SRS Review (T1-F6-01 .. T1-F6-05)
    // =========================================================================
    {
      id: 'T1-F6-01',
      name: 'Flashcard deck hides meaning until Javobni ko‘rish is tapped, then reveals meaning, IPA, and example',
      milestone: ['M1', 'M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Talaffuzni tinglash/i }).waitFor({ state: 'visible' });
        assert.equal(await main.getByText('Ismingiz nima?').count(), 0);
        assert.equal(await main.getByText('/wɒts jɔː neɪm/').count(), 0);

        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByText('Ismingiz nima?', { exact: true }).waitFor({ state: 'visible' });
        await main.getByText('/wɒts jɔː neɪm/', { exact: true }).waitFor({ state: 'visible' });
        await main.getByText("Hi, I'm Aziza. What's your name?", { exact: true }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F6-01');
      },
    },
    {
      id: 'T1-F6-02',
      name: 'Clicking Yana mashq qilaman re-queues flashcard in active session before deck completion',
      milestone: ['M1', 'M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Yana mashq qilaman' }).click();

        await main.getByText('0 / 2', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('heading', { name: 'Nice to meet you.' }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Eslab qoldim' }).click();

        await main.getByText('1 / 2', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
        await main.getByText('Yana mashq qilaman', { exact: true }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F6-02');
      },
    },
    {
      id: 'T1-F6-03',
      name: 'Flashcard practice modes (En->Uz, Uz->En, Audio->Word, Image->Word, Random) flip prompt and reveal polarity',
      milestone: ['M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        const modeSelectors = {
          enUz: main.getByRole('button', { name: /En\s*(?:→|->)\s*Uz/i }),
          uzEn: main.getByRole('button', { name: /Uz\s*(?:→|->)\s*En/i }),
          audioWord: main.getByRole('button', { name: /Audio\s*(?:→|->)\s*(?:Word|So‘z)/i }),
          imageWord: main.getByRole('button', { name: /(?:Image|Rasm)\s*(?:→|->)\s*(?:Word|So‘z)/i }),
          random: main.getByRole('button', { name: /Random|Tasodifiy/i }),
        };

        for (const [key, btn] of Object.entries(modeSelectors)) {
          await helpers.expectVisibleFast(
            btn,
            `T1-F6-03 (M2): Expected flashcard practice mode button "${key}".`,
            FAST_TIMEOUT,
          );
        }

        // 1. En -> Uz: English prompt on front, Uzbek hidden until reveal
        await modeSelectors.enUz.click();
        await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
        assert.equal(
          await main.getByText('Ismingiz nima?').count(),
          0,
          'En->Uz front must hide Uzbek meaning before Javobni ko‘rish.',
        );
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByText('Ismingiz nima?', { exact: true }).waitFor({ state: 'visible' });

        // 2. Uz -> En: Polarity flips! Uzbek prompt on front, English hidden until reveal
        await modeSelectors.uzEn.click();
        await main.getByRole('heading', { name: 'Ismingiz nima?' }).waitFor({ state: 'visible' });
        assert.equal(
          await main.getByRole('heading', { name: "What's your name?" }).count(),
          0,
          'Uz->En front must hide English phrase before Javobni ko‘rish.',
        );
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByText("What's your name?", { exact: true }).waitFor({ state: 'visible' });

        // 3. Audio -> Word: Audio prompt visible, written English & Uzbek hidden until reveal
        await modeSelectors.audioWord.click();
        await main.getByRole('button', { name: /Talaffuzni tinglash/i }).waitFor({ state: 'visible' });
        assert.equal(
          await main.getByRole('heading', { name: "What's your name?" }).count(),
          0,
          'Audio->Word front must hide written English target before Javobni ko‘rish.',
        );
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByText("What's your name?", { exact: true }).waitFor({ state: 'visible' });

        // 4. Image -> Word: Visual cue visible, target word hidden until reveal
        await modeSelectors.imageWord.click();
        await main.locator('figure img, [role="img"]').first().waitFor({ state: 'visible' });
        assert.equal(
          await main.getByRole('heading', { name: "What's your name?" }).count(),
          0,
          'Image->Word front must hide written target word before Javobni ko‘rish.',
        );
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByText("What's your name?", { exact: true }).waitFor({ state: 'visible' });

        // 5. Random: Active card renders and reveals answer cleanly
        await modeSelectors.random.click();
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Eslab qoldim' }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F6-03');
      },
    },
    {
      id: 'T1-F6-04',
      name: 'SRS ratings (Eslab qoldim vs Yana mashq qilaman) persist distinct flashcardSrsByCourse[course_eng_01] buckets across reload',
      milestone: ['M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        // Card 1 ("What's your name?") -> "Yana mashq qilaman"
        await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Yana mashq qilaman' }).click();

        // Card 2 ("Nice to meet you.") -> "Eslab qoldim"
        await main.getByRole('heading', { name: 'Nice to meet you.' }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Eslab qoldim' }).click();

        const beforeSnap = await helpers.readDemoProgressSnapshot(page);
        const beforeSrs = beforeSnap.progress?.profile?.flashcardSrsByCourse?.course_eng_01;
        assert.ok(
          beforeSrs && Object.keys(beforeSrs).length >= 2,
          `T1-F6-04 (M2): Expected >= 2 flashcardSrsByCourse.course_eng_01 entries before reload, got: ${JSON.stringify(beforeSrs)}`,
        );

        await helpers.reloadAndVerifyPersistence(page, async ({ before, after }) => {
          const srsAfter = after.progress?.profile?.flashcardSrsByCourse?.course_eng_01;
          assert.deepEqual(
            srsAfter,
            before.progress?.profile?.flashcardSrsByCourse?.course_eng_01,
            'T1-F6-04 (M2): Expected flashcardSrsByCourse.course_eng_01 to persist identically across reload.',
          );
          const card1 = srsAfter.fc_eng_starter_1;
          const card2 = srsAfter.fc_eng_starter_2;
          assert.ok(card1 && card2, 'Expected both fc_eng_starter_1 and fc_eng_starter_2 in persisted SRS map.');
          assert.equal(
            card1.bucket === 'need_practice' || card1.status === 'need_practice' || (card1.intervalDays ?? 0) === 0,
            true,
            `Expected card1 (Yana mashq qilaman) in need_practice bucket, got: ${JSON.stringify(card1)}`,
          );
          assert.equal(
            card2.bucket !== 'need_practice' && card2.status !== 'need_practice' && (card2.intervalDays ?? card2.interval ?? 0) >= 1,
            true,
            `Expected card2 (Eslab qoldim) scheduled out of need_practice with interval >= 1, got: ${JSON.stringify(card2)}`,
          );
        });
        assertCleanSession(session, 'T1-F6-04');
      },
    },
    {
      id: 'T1-F6-05',
      name: 'Completing full flashcard deck with Eslab qoldim advances SRS intervals forward out of need_practice',
      milestone: ['M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        let rememberedCount = 0;
        for (let i = 0; i < 12; i++) {
          const doneHeading = main.getByRole('heading', { name: 'Barcha kartochkalar ko‘rib chiqildi' });
          if (await doneHeading.isVisible().catch(() => false)) break;
          await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
          await main.getByRole('button', { name: 'Eslab qoldim' }).click();
          rememberedCount++;
        }

        assert.ok(rememberedCount >= 2, `Expected >= 2 cards completed in deck, got ${rememberedCount}.`);
        await main.getByRole('heading', { name: 'Barcha kartochkalar ko‘rib chiqildi' }).waitFor({ state: 'visible' });

        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const srsRecord = snapshot.progress?.profile?.flashcardSrsByCourse?.course_eng_01;
        assert.ok(
          srsRecord && Object.keys(srsRecord).length >= rememberedCount,
          `T1-F6-05 (M2): Expected >= ${rememberedCount} SRS entries after completing deck, got: ${JSON.stringify(srsRecord)}`,
        );

        const nowMs = Date.now();
        for (const [cardId, entry] of Object.entries(srsRecord)) {
          const interval = entry?.intervalDays ?? entry?.interval ?? 0;
          const rawNext = entry?.nextReviewAt ?? entry?.dueAt ?? 0;
          const nextReviewAt = typeof rawNext === 'string' ? Date.parse(rawNext) : Number(rawNext);
          assert.notEqual(
            entry?.bucket,
            'need_practice',
            `T1-F6-05 (M2): Card ${cardId} stuck in need_practice after Eslab qoldim.`,
          );
          assert.notEqual(
            entry?.status,
            'need_practice',
            `T1-F6-05 (M2): Card ${cardId} status stuck in need_practice after Eslab qoldim.`,
          );
          assert.ok(
            interval >= 1,
            `T1-F6-05 (M2): Expected card ${cardId} SRS interval >= 1 day, got ${interval}.`,
          );
          assert.ok(
            Number.isFinite(nextReviewAt) && nextReviewAt > nowMs + 12 * 3600 * 1000,
            `T1-F6-05 (M2): Expected card ${cardId} scheduled forward (>= 12h ahead), got nextReviewAt=${rawNext}.`,
          );
        }
        assertCleanSession(session, 'T1-F6-05');
      },
    },

    // =========================================================================
    // F7: Yo‘lchi AI Contextual Help (T1-F7-01 .. T1-F7-05)
    // =========================================================================
    {
      id: 'T1-F7-01',
      name: 'Clicking Yo‘lchidan so‘rash inside lesson_eng_starter opens contextual Yo‘lchi AI dialog',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

        await page.getByRole('button', { name: 'Yo‘lchidan so‘rash' }).click();
        const dialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
        await dialog.waitFor({ state: 'visible' });
        await dialog.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' }).waitFor({ state: 'visible' });
        await dialog.getByRole('button', { name: 'Savolni yuborish' }).waitFor({ state: 'visible' });
        await dialog.getByText('Qaysi mavzuni ko‘rib chiqamiz?').first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F7-01');
      },
    },
    {
      id: 'T1-F7-02',
      name: 'Submitting a question in Yo‘lchi AI returns localized response and Foydali javob feedback works in demo',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

        await page.getByRole('button', { name: 'Yo‘lchidan so‘rash' }).click();
        const dialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
        await dialog.waitFor({ state: 'visible' });
        await dialog.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' }).fill('Hello qachon ishlatiladi?');
        await dialog.getByRole('button', { name: 'Savolni yuborish' }).click();

        const helpfulBtn = dialog.getByRole('button', { name: 'Foydali javob' }).first();
        await helpfulBtn.waitFor({ state: 'visible' });
        await helpfulBtn.click();
        assert.equal(
          await helpfulBtn.getAttribute('aria-pressed'),
          'true',
          'Expected Foydali javob feedback button to toggle aria-pressed="true".',
        );
        assertCleanSession(session, 'T1-F7-02');
      },
    },
    {
      id: 'T1-F7-03',
      name: 'Opening and closing Yo‘lchi AI mid-exercise preserves step and typed free-text input without remounting',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceToExerciseStep(page);

        const main = page.getByRole('main');
        const input = main.getByRole('textbox', { name: /Javobingizni ingliz tilida yozing/i });
        await input.fill("I'm Sam");

        await helpers.openAndCloseYolchiAi(page, {
          askText: "What's your name?",
          closeWith: 'button',
          preserveStepIndicator: /^Qadam 4 \/ 4$/,
          preserveText: 'O‘rganganingizni sinab ko‘ring',
        });

        assert.equal(
          await input.inputValue(),
          "I'm Sam",
          'Expected typed exercise input "I\'m Sam" to be preserved after closing Yo‘lchi AI.',
        );
        assertCleanSession(session, 'T1-F7-03');
      },
    },
    {
      id: 'T1-F7-04',
      name: 'Wrong exercise answer displays mistake-specific feedback, opens Yo‘lchi AI analysis, and allows retry',
      milestone: ['M1', 'M5'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openRoadmapNodeLesson(page, /^Vocabulary$/i);
        await advanceToExerciseStep(page);

        const main = page.getByRole('main');
        await main.getByRole('button', { name: 'behind the sofa' }).click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();

        await main.getByText('Javobni ko‘rib chiqamiz', { exact: true }).waitFor({ state: 'visible' });
        await main.getByText(/Siz tanladingiz:\s*behind the sofa/i).waitFor({ state: 'visible' });
        await main.getByText(/To‘g‘ri javob:\s*between the chair and the shelf/i).waitFor({ state: 'visible' });
        await main.getByText(/kreslo orqasida ryukzak turibdi/i).first().waitFor({ state: 'visible' });

        await main.getByRole('button', { name: 'Yo‘lchi AI tahlili' }).click();
        const mistakeDialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan xato tahlili' });
        await mistakeDialog.waitFor({ state: 'visible' });
        await mistakeDialog.getByText(/kreslo orqasida ryukzak turibdi/i).first().waitFor({ state: 'visible' });
        await mistakeDialog.getByRole('button', { name: 'Mavzuni mustahkamlash mashqi' }).waitFor({ state: 'visible' });
        await mistakeDialog.getByRole('button', { name: 'Yopish' }).click();
        await mistakeDialog.waitFor({ state: 'hidden' });

        await main.getByRole('button', { name: 'Qayta urinish' }).click();
        await main.getByRole('button', { name: 'between the chair and the shelf' }).click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T1-F7-04');
      },
    },
    {
      id: 'T1-F7-05',
      name: 'Russian UI locale renders Yo‘lchi AI in Russian while keeping English lesson audio and transcript in English',
      milestone: ['M1', 'M5'],
      contextOptions: { locale: 'ru' },
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Разберём пример вместе/i);

        const main = page.getByRole('main');
        await main.locator('audio[src="/lesson-media/english/a1-starter-dialogue.wav"]').waitFor({ state: 'visible' });
        await main.locator('summary', { hasText: 'Текстовая расшифровка' }).click();
        await main.locator('[lang="en"]').getByText('Aziza:').waitFor({ state: 'visible' });

        await clickFirstVisibleButton(page, /Спросить Yo‘lchi/i);
        const dialog = page.getByRole('dialog', { name: 'Обсудить урок с Yo‘lchi' });
        await dialog.waitFor({ state: 'visible' });
        await dialog.getByRole('textbox', { name: 'Напишите вопрос Yo‘lchi AI' }).fill('Когда говорят Hello?');
        await dialog.getByRole('button', { name: 'Отправить вопрос' }).click();
        await dialog.getByRole('button', { name: 'Полезный ответ' }).first().waitFor({ state: 'visible' });
        await dialog.getByText(/Давайте разберём вопрос по шагам/i).first().waitFor({ state: 'visible' });
        const replyText = await dialog.innerText();
        assert.equal(
          /qadam-baqadam/i.test(replyText),
          false,
          `T1-F7-05: Russian Yo‘lchi reply leaked Uzbek phrase "qadam-baqadam": ${replyText}`,
        );
        assertCleanSession(session, 'T1-F7-05');
      },
    },
  ];
}

export const getTests = registerTests;
