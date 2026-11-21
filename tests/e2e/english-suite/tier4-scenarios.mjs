import assert from 'node:assert/strict';
import {
  FAST_TIMEOUT,
  PLACEMENT_MIN_INTERVAL_MS,
  advanceLessonStep,
  advanceToExerciseStep,
  assertCleanSession,
  assertCourseIdentity,
  assertSingleCefrLevelScope,
  completeInteractiveStepAndFinishLesson,
  completeMcqLesson,
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
    {
      id: 'T4-01',
      name: 'Absolute Beginner A1 vertical slice: starter lesson audio, illustration, flashcard requeue, Yolchi non-remount, free-text, and reload',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        const main = page.getByRole('main');

        await assertCourseIdentity(page, helpers, 'course_eng_01', 'T4-01 starter');
        await main.getByRole('heading', { name: 'Asosiy tushuncha' }).first().waitFor({ state: 'visible' });

        // Step 2: Tashkent illustration + two-voice WAV + transcript
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        const img = main.locator('img[src="/lesson-media/english/a1-starter-greeting.png"]');
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
        assert.equal(
          await img.evaluate((el) => el.complete && el.naturalWidth > 0),
          true,
          'Expected Tashkent greeting illustration loaded.',
        );
        await main.locator('audio[src="/lesson-media/english/a1-starter-dialogue.wav"]').waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Qayta tinglash' }).click();
        await main.locator('summary', { hasText: 'Matnli bayon' }).click();
        await main.locator('[lang="en"]').getByText('Aziza:').waitFor({ state: 'visible' });
        await main.locator('[lang="en"]').getByText('Ben:').waitFor({ state: 'visible' });

        // Step 3: Flashcards (re-queue card 1, complete card 2, re-review card 1)
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);
        await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Yana mashq qilaman' }).click();

        await main.getByRole('heading', { name: 'Nice to meet you.' }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Eslab qoldim' }).click();

        await main.getByRole('heading', { name: "What's your name?" }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Eslab qoldim' }).click();
        await main.getByRole('heading', { name: 'Barcha kartochkalar ko‘rib chiqildi' }).waitFor({ state: 'visible' });

        // Step 4: Free-text with Yo‘lchi AI non-remount preservation
        await advanceLessonStep(page, /O‘rganganingizni sinab ko‘ring/i);
        const input = main.getByRole('textbox', { name: /Javobingizni ingliz tilida yozing/i });
        await input.fill("I'm Sam");

        await helpers.openAndCloseYolchiAi(page, {
          askText: "What's your name qachon aytiladi?",
          closeWith: 'button',
          preserveStepIndicator: /^Qadam 4 \/ 4$/,
          preserveText: 'O‘rganganingizni sinab ko‘ring',
        });
        assert.equal(await input.inputValue(), "I'm Sam");

        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await finishCompletionDialog(page);

        // Reload persistence & lesson_eng_foundation_02 unlock
        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          const completed = after.progress?.profile?.completedLessonIds ?? [];
          assert.equal(completed.includes('lesson_eng_starter'), true);
          assert.ok((after.progress?.profile?.xp ?? 0) >= 22);
        });
        await main.getByRole('button', { name: 'Boshlang‘ich darsni ochish' }).click();
        await main.getByRole('heading', { name: 'Men, siz va oddiy gaplar' }).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T4-01');
      },
    },
    {
      id: 'T4-02',
      name: 'Placement-to-Module learner: diagnostic with real audio -> CEFR placement -> recommended module -> rich exercises & checkpoint -> mastery separation -> next lesson unlock',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');
        let sawListeningAudio = false;

        for (let step = 1; step <= 12; step++) {
          const stemText = (await main.locator('h2').first().textContent().catch(() => '')) ?? '';
          assert.equal(
            /Audio context:/i.test(stemText),
            false,
            `T4-02 (M5): Placement listening stem leaked raw script: "${stemText}"`,
          );
          if ((await main.locator('audio').count()) > 0) {
            sawListeningAudio = true;
          }
          await main.getByRole('radio').first().check();
          await page.waitForTimeout(PLACEMENT_MIN_INTERVAL_MS);
          const finishBtn = main.getByRole('button', { name: /Natijani ko‘rish/i });
          if (await finishBtn.isVisible().catch(() => false)) {
            await finishBtn.click();
            const modal = page.getByRole('dialog', { name: /Javoblarni topshirasizmi\?/i });
            await modal.getByRole('button', { name: /^Topshirish$/i }).click();
            break;
          }
          await main.getByRole('button', { name: /Keyingi savol/i }).click();
        }

        assert.equal(
          sawListeningAudio,
          true,
          'T4-02 (M5): Expected overhauled placement test to include real playable <audio> listening item.',
        );
        await main.getByRole('heading', { name: /Diagnostika yakunlandi/i }).first().waitFor({ state: 'visible' });

        const resultText = await main.innerText();
        assert.match(
          resultText,
          /(?:CEFR daraja|Уровень CEFR):\s*(Pre-A1|A1|A2|B1)\b/i,
          'T4-02 (M5): Expected calibrated CEFR tier badge (Pre-A1..B1) on placement result.',
        );

        const afterPlacementSnap = await helpers.readDemoProgressSnapshot(page);
        const placementRecord = afterPlacementSnap.progress?.profile?.placementScoreByCourse?.course_eng_01;
        assert.ok(placementRecord !== undefined, 'T4-02 (M5): Expected placementScoreByCourse.course_eng_01 recorded.');
        const preLessonCompleted = afterPlacementSnap.progress?.profile?.completedLessonIds ?? [];
        assert.equal(
          preLessonCompleted.some((id) => id.startsWith('lesson_eng_')),
          false,
          'T4-02 (M5): Placement alone must not mark English lessons completed.',
        );

        await main.getByRole('button', { name: /Shaxsiy yo‘lni ko‘rish/i }).click();
        await main
          .getByRole('heading', { name: /Mening ta’lim yo‘lim|Boshlang‘ich darslar/i })
          .first()
          .waitFor({ state: 'visible' });

        const activeNode = main.locator('li[aria-current="step"]').first();
        const openRecommendedBtn = (await activeNode.count()) > 0
          ? activeNode.getByRole('button', { name: /Darsni boshlash|Boshlang‘ich darsni ochish|Birinchi mashqni boshlash/i }).first()
          : main.getByRole('button', { name: /Darsni boshlash|Boshlang‘ich darsni ochish|Birinchi mashqni boshlash/i }).first();
        await openRecommendedBtn.click();

        await main.getByText(/^Qadam\s+\d+\s*\/\s*\d+$/i).first().waitFor({ state: 'visible' });
        const firstLessonHeading = ((await main.locator('h1').first().textContent().catch(() => '')) ?? '').trim();

        await completeInteractiveStepAndFinishLesson(page);

        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          assert.deepEqual(
            after.progress?.profile?.placementScoreByCourse?.course_eng_01,
            placementRecord,
            'T4-02 (M5): Independent lesson mastery must not overwrite placementScoreByCourse.course_eng_01.',
          );
          const completed = after.progress?.profile?.completedLessonIds ?? [];
          assert.ok(
            completed.some((id) => id.startsWith('lesson_eng_')),
            'T4-02 (M5): Expected completed module lesson recorded in completedLessonIds.',
          );
          assert.ok(
            after.progress?.profile?.scoresByCourse?.course_eng_01 &&
              Object.keys(after.progress.profile.scoresByCourse.course_eng_01).length > 0,
            'T4-02 (M5): Expected independent lesson mastery recorded in scoresByCourse.course_eng_01.',
          );
        });

        const nextStepBtn = main
          .locator('li[aria-current="step"], li')
          .filter({ hasNotText: firstLessonHeading || '__no_match__' })
          .getByRole('button', { name: /Darsni boshlash|Boshlang‘ich darsni ochish/i })
          .first();
        await helpers.expectVisibleFast(
          nextStepBtn,
          'T4-02 (M5): Expected next module lesson unlocked after completing recommended lesson & checkpoint.',
          FAST_TIMEOUT,
        );
        await nextStepBtn.click();
        await main.getByText(/^Qadam\s+1\s*\/\s*\d+$/i).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T4-02');
      },
    },
    {
      id: 'T4-03',
      name: 'Listening + Reading sequential path: node_eng_list -> unlock node_eng_read -> reading checkpoint non-completion -> completion',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await unlockEnglishRoadmapUpTo(page, 'list');

        // Complete Listening node
        const main = page.getByRole('main');
        await openRoadmapNodeLesson(page, /^Listening$/i);
        await advanceLessonStep(page, /2\. Audio Xabarni Tinglash/i);
        await main.locator('audio[src="/lesson-media/english/a1-listening-lecture-time.wav"]').waitFor({ state: 'visible' });
        await main.locator('summary', { hasText: 'Matnli bayon' }).click();
        await main.locator('[lang="en"]').getByText(/in the afternoon/i).waitFor({ state: 'visible' });
        await completeMcqLesson(page, '15:15 (quarter past three)');

        // Open newly unlocked Reading node
        const readCard = main.locator('li').filter({
          has: page.getByRole('heading', { name: /^Reading$/i }),
        });
        await readCard.getByText(/Ochiq|Keyingi qadam/i).first().waitFor({ state: 'visible' });
        await readCard.getByRole('button', { name: 'Darsni boshlash' }).click();
        await main.getByRole('heading', { name: 'Asosiy g‘oya va dalil' }).first().waitFor({ state: 'visible' });

        // Leave mid-reading -> reload -> confirm incomplete & checkpoint restored
        await advanceLessonStep(page, /Ishlangan misol/i);
        await main.getByText('Qadam 2 / 3', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Ta’lim yo‘liga qaytish' }).click();
        await main.getByRole('heading', { name: /Mening ta’lim yo‘lim/i }).first().waitFor({ state: 'visible' });

        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          const completed = after.progress?.profile?.completedLessonIds ?? [];
          assert.equal(
            completed.includes('lesson_eng_reading_01'),
            false,
            'Reading checkpoint MUST NOT mark lesson_eng_reading_01 completed after returning to roadmap and reloading.',
          );
        });

        await openRoadmapNodeLesson(page, /^Reading$/i);
        await main.getByText('Qadam 2 / 3', { exact: true }).waitFor({ state: 'visible' });
        await completeMcqLesson(page, 'To‘garak buyumlarni ta’mirlab, chiqindini kamaytiradi');

        await main.getByText('4 / 31 mavzu yakunlangan').waitFor({ state: 'visible' });
        await getCefrLevelSection(main, 'A1').getByText('4 / 15 mavzu yakunlangan').waitFor({ state: 'visible' });
        assertCleanSession(session, 'T4-03');
      },
    },
    {
      id: 'T4-04',
      name: 'Struggling learner: 2x mistake -> Yolchi AI -> remedial completion -> Uz->En & Audio->Word SRS -> alternate checkpoint -> next unit unlock',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openRoadmapNodeLesson(page, /^Vocabulary$/i);
        await advanceToExerciseStep(page);

        const main = page.getByRole('main');
        // 1. Fail exercise twice and inspect targeted feedback + remedial trigger
        for (let attempt = 0; attempt < 2; attempt++) {
          await main.getByRole('button', { name: 'behind the sofa' }).click();
          await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
          await main.getByText('Javobni ko‘rib chiqamiz', { exact: true }).waitFor({ state: 'visible' });
          if (attempt === 0) {
            await main.getByRole('button', { name: 'Qayta urinish' }).click();
          }
        }

        await helpers.expectVisibleFast(
          main.getByText(/takroriy xato|remedial|qo‘shimcha mashq/i),
          'T4-04 (M5): Expected repeated-error targeted remedial prompt after 2 identical mistakes.',
          FAST_TIMEOUT,
        );

        // 2. Open Yo‘lchi AI explanation and close without losing lesson state
        const aiBtn = main.getByRole('button', { name: /Yo‘lchi AI tahlili|Yo‘lchidan so‘rash/i }).first();
        await helpers.expectVisibleFast(
          aiBtn,
          'T4-04 (M5): Expected Yo‘lchi AI mistake explanation trigger after repeated error.',
          FAST_TIMEOUT,
        );
        await aiBtn.click();
        const aiDialog = page.getByRole('dialog', { name: /Yo‘lchi bilan xato tahlili|Yo‘lchi bilan shu dars haqida/i });
        await aiDialog.waitFor({ state: 'visible' });
        const aiText = (await aiDialog.innerText()).trim();
        assert.ok(aiText.length >= 20, `T4-04 (M5): Expected non-empty Yo‘lchi AI explanation, got "${aiText}".`);

        // 3. Complete remedial practice step
        const remedialTrigger = aiDialog
          .getByRole('button', { name: /Qo‘shimcha mashq|Mustahkamlash mashqi|Mavzuni mustahkamlash mashqi|REMEDIATSIYA/i })
          .or(main.getByRole('button', { name: /Qo‘shimcha mashq|Mustahkamlash mashqi|Mavzuni mustahkamlash mashqi|REMEDIATSIYA/i }))
          .first();
        if (await aiDialog.getByRole('button', { name: /Mavzuni mustahkamlash mashqi|Qo‘shimcha mashq/i }).first().isVisible().catch(() => false)) {
          await remedialTrigger.click();
        } else {
          await aiDialog.getByRole('button', { name: 'Yopish' }).click();
          await aiDialog.waitFor({ state: 'hidden' });
          await main.getByRole('button', { name: /Qo‘shimcha mashq|Mustahkamlash mashqi|REMEDIATSIYA/i }).first().click();
        }

        const reinfDialog = page.getByRole('dialog', { name: /Mustahkamlash mashqi|Qo‘shimcha mashq/i });
        if (await reinfDialog.isVisible().catch(() => false)) {
          const opt = reinfDialog.getByRole('button', { name: /^([A-D]\s+)?behind$/i }).first();
          await opt.click();
          await reinfDialog.getByRole('button', { name: /Javobni Tekshirish|TEKSHIRISH/i }).click();
          await reinfDialog.getByText(/Mavzu Muvaffaqiyatli Mustahkamlandi!|To‘g‘ri javob!/i).first().waitFor({ state: 'visible' });
          await reinfDialog.getByRole('button', { name: /Davom etish/i }).click();
        }
        await navigateToRoadmapFromWorkspace(page);

        // 4. Review due vocabulary flashcards in Uz->En and Audio->Word modes and reload
        const srsBtn = main.getByRole('button', { name: /Flashcard|Kartochkalar|Takrorlash/i }).first();
        await helpers.expectVisibleFast(srsBtn, 'T4-04 (M5): Expected SRS flashcard hub on roadmap.', FAST_TIMEOUT);
        await srsBtn.click();

        const cardScope = main.locator('[data-testid^="flashcard-"]').first();
        const cardHeadingLocator = ((await cardScope.count()) > 0 ? cardScope : main)
          .locator('h3, h2')
          .first();
        const defaultFrontHeading = (
          (await cardHeadingLocator.innerText().catch(() => '')) ?? ''
        ).trim();

        const uzEnBtn = main.getByRole('button', { name: /Uz\s*(?:→|->)\s*En/i });
        await helpers.expectVisibleFast(uzEnBtn, 'T4-04 (M5): Expected Uz->En SRS flashcard mode.', FAST_TIMEOUT);
        await uzEnBtn.click();

        assert.equal(
          await main.getByRole('heading', { name: "What's your name?" }).count(),
          0,
          'T4-04 (M5): Uz->En front must hide English phrase "What\'s your name?" before Javobni ko‘rish.',
        );
        const frontHeadingUz = (
          (await cardHeadingLocator.innerText().catch(() => '')) ?? ''
        ).trim();
        assert.ok(frontHeadingUz.length > 0, 'T4-04 (M5): Expected Uzbek prompt visible on Uz->En front.');
        if (defaultFrontHeading.length > 0) {
          assert.notEqual(
            frontHeadingUz.toLowerCase(),
            defaultFrontHeading.toLowerCase(),
            `T4-04 (M5): Uz->En button must flip front prompt away from English phrase "${defaultFrontHeading}".`,
          );
        }

        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        const revealedTarget = defaultFrontHeading.length > 0 ? defaultFrontHeading : "What's your name?";
        const revealedEnglishEl = main.getByText(revealedTarget, { exact: true }).first();
        await helpers.expectVisibleFast(
          revealedEnglishEl,
          `T4-04 (M5): Expected revealed English phrase "${revealedTarget}" after Javobni ko‘rish in Uz->En mode.`,
          FAST_TIMEOUT,
        );
        const revealedEnglishText = ((await revealedEnglishEl.innerText().catch(() => '')) ?? '').trim();
        assert.notEqual(
          frontHeadingUz.toLowerCase(),
          revealedEnglishText.toLowerCase(),
          `T4-04 (M5): Uz->En front heading ("${frontHeadingUz}") must differ from revealed English phrase ("${revealedEnglishText}").`,
        );
        await main.getByRole('button', { name: 'Yana mashq qilaman' }).click();

        const audioWordBtn = main.getByRole('button', { name: /Audio\s*(?:→|->)\s*(?:Word|So‘z)/i });
        await helpers.expectVisibleFast(audioWordBtn, 'T4-04 (M5): Expected Audio->Word SRS flashcard mode.', FAST_TIMEOUT);
        await audioWordBtn.click();
        await main.getByRole('button', { name: /Talaffuzni tinglash/i }).click();
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Eslab qoldim' }).click();

        for (let i = 0; i < 20; i++) {
          const reveal = main.getByRole('button', { name: 'Javobni ko‘rish' });
          if (!(await reveal.isVisible().catch(() => false))) break;
          await reveal.click();
          await main.getByRole('button', { name: 'Eslab qoldim' }).click();
        }

        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          assert.ok(
            after.progress?.profile?.flashcardSrsByCourse?.course_eng_01,
            'T4-04 (M5): Expected flashcardSrsByCourse.course_eng_01 persisted across reload.',
          );
        });
        await navigateToRoadmapFromWorkspace(page);

        // 5. Alternate checkpoint variant -> pass -> next unit unlocks
        const lockedBefore = await main.locator('[data-node-id], li, article').filter({ hasText: /Qulflangan/i }).count();
        const checkpointCard = main
          .locator('li, article, [data-node-kind="unit_checkpoint"]')
          .filter({ hasText: /Modul yakuni|Unit checkpoint|Bosqich sinovi|Checkpoint/i })
          .first();
        await helpers.expectVisibleFast(
          checkpointCard,
          'T4-04 (M5): Expected unit checkpoint node on roadmap.',
          FAST_TIMEOUT,
        );
        await checkpointCard.getByRole('button', { name: /Sinovni boshlash|Darsni boshlash|Boshlash/i }).click();

        const initialStem = ((await main.locator('h3').first().innerText().catch(() => '')) ?? '').trim();
        const altTrigger = main.getByRole('button', { name: /Qayta tekshiruv|Boshqa variant|Alternativ/i });
        if (await altTrigger.first().isVisible().catch(() => false)) {
          await altTrigger.first().click();
          const altStem = ((await main.locator('h3').first().innerText().catch(() => '')) ?? '').trim();
          assert.notEqual(altStem, initialStem, 'T4-04 (M5): Alternate checkpoint variant must differ from initial question.');
        }

        await completeInteractiveStepAndFinishLesson(page);
        const lockedAfter = await main.locator('[data-node-id], li, article').filter({ hasText: /Qulflangan/i }).count();
        assert.ok(
          lockedAfter < lockedBefore,
          `T4-04 (M5): Expected next unit to unlock after alternate checkpoint (locked before=${lockedBefore}, after=${lockedAfter}).`,
        );
        assertCleanSession(session, 'T4-04');
      },
    },
    {
      id: 'T4-05',
      name: 'B1 Intermediate productive task journey: placement unlock, travel audio + speaking rubric, Unit 1 checkpoint, B1 exit assessment, and DEFERRED B2-C2 check',
      milestone: ['M3', 'M5', 'M6'],
      async run({ page, baseUrl, session, helpers }) {
        // 1. Unlock B1 via high-accuracy English placement
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');
        const { correct, total } = await solveEnglishPlacement(page, { accuracy: 'high' });
        assert.ok(total > 0 && correct === total, `T4-05: Expected full B1 placement score, got ${correct}/${total}.`);
        assert.match(await main.innerText(), /(?:CEFR daraja|Уровень CEFR):\s*B1\b/i);

        await main.getByRole('button', { name: /Shaxsiy yo‘lni ko‘rish|Посмотреть свой план/i }).click();
        await main
          .getByRole('heading', { name: /Mening ta’lim yo‘lim|Мой путь обучения/i })
          .first()
          .waitFor({ state: 'visible' });

        // 2. Open B1 Module 1 travel lesson (node_eng_b1_m1_travel)
        const b1Section = getCefrLevelSection(main, 'B1');
        await helpers.expectVisibleFast(b1Section, 'T4-05: Expected grouped B1 section on English roadmap.', FAST_TIMEOUT);
        await assertSingleCefrLevelScope(b1Section, 'B1', 'T4-05');

        const travelNode = b1Section.locator('[data-node-id="node_eng_b1_m1_travel"]');
        await travelNode.getByRole('button', { name: /Darsni boshlash/i }).click();
        await main.getByText(/^Qadam 1 \/ 6$/i).first().waitFor({ state: 'visible' });

        // Step 1 -> Step 2: real WAV audio + speaker transcript
        await advanceLessonStep(page);
        await main
          .locator('audio[src="/lesson-media/english/b1/b1-m1-travel-dialogue.wav"]')
          .waitFor({ state: 'visible' });
        await main.locator('summary', { hasText: 'Matnli bayon' }).click();
        await main.locator('[lang="en"]').getByText('Sardor:').first().waitFor({ state: 'visible' });
        await main.locator('[lang="en"]').getByText('Agent:').first().waitFor({ state: 'visible' });

        // Step 3: 4 B1 flashcards
        await advanceLessonStep(page);
        await completeVisibleFlashcardDeck(page);

        // Step 4: Listening MCQ (q_eng_b1_m1_listen_mcq)
        await advanceLessonStep(page);
        await main
          .getByRole('button', { name: /11:15 da 19-darvozadan; turar joy tasdiq xati hali kelmagan edi/i })
          .click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Keyingi savol/i }).click();

        // Step 5: fill_blank ('left')
        await main.getByRole('textbox').first().fill('left');
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Keyingi savol/i }).click();

        // Step 6: speaking_prompt (self_assessed) — empty guard, model response, 3 rubric checkboxes, no fake cert
        await helpers.expectVisibleFast(
          main.getByText(/O‘zini baholash · Mustaqil mashq/i),
          'T4-05: Expected self-assessment badge on B1 speaking prompt.',
          FAST_TIMEOUT,
        );
        assert.equal(
          /Official CEFR Certificate|Rasmiy CEFR sertifikati|Официальный сертификат CEFR/i.test(
            await page.locator('body').innerText(),
          ),
          false,
          'T4-05: B1 productive task MUST NOT claim Official CEFR Certificate before submit.',
        );

        const responseBox = main.getByRole('textbox').first();
        await responseBox.fill('');
        const checkBtn = main.getByRole('button', { name: /^TEKSHIRISH$/i }).first();
        await checkBtn.click();
        await main.getByRole('alert').waitFor({ state: 'visible' });
        assert.equal(await main.getByText(/Namuna javob/i).count(), 0);

        await responseBox.fill(
          'I have already printed my boarding pass, and the airline rescheduled our departure to 11:15. I checked the updated itinerary ten minutes ago, and my accommodation email has not arrived yet.',
        );
        await checkBtn.click();

        await helpers.expectVisibleFast(main.getByText(/Namuna javob/i), 'T4-05: Expected model response.', FAST_TIMEOUT);
        await helpers.expectVisibleFast(main.getByText(/Baholash mezoni/i), 'T4-05: Expected rubric criteria.', FAST_TIMEOUT);
        const rubricCount = await main.getByRole('checkbox').count();
        assert.equal(rubricCount, 3, `T4-05: Expected 3 rubric checkboxes, got ${rubricCount}.`);
        await main.getByRole('checkbox').first().check();
        assert.equal(
          /Official CEFR Certificate|Rasmiy CEFR sertifikati|Официальный сертификат CEFR/i.test(
            await page.locator('body').innerText(),
          ),
          false,
          'T4-05: B1 productive task MUST NOT claim Official CEFR Certificate after submit.',
        );

        await main.getByRole('button', { name: /Darsni yakunlash/i }).click();
        await finishCompletionDialog(page);

        // 3. Verify node_eng_b1_u1_checkpoint unlocked on roadmap and complete it
        const u1Checkpoint = b1Section.locator('[data-node-id="node_eng_b1_u1_checkpoint"]');
        const u1Btn = u1Checkpoint.getByRole('button', { name: /Sinovni boshlash|Darsni boshlash/i });
        await helpers.expectVisibleFast(
          u1Btn,
          'T4-05: Expected node_eng_b1_u1_checkpoint unlocked after B1 Module 1 completion.',
          FAST_TIMEOUT,
        );
        await u1Btn.click();
        await advanceLessonStep(page);
        await main
          .locator('audio[src="/lesson-media/english/b1/b1-u1-cp-hotel-dialogue.wav"]')
          .waitFor({ state: 'visible' });
        await advanceLessonStep(page);
        await main
          .getByRole('button', { name: /I have updated your booking to Room 412 on the quiet courtyard side\./i })
          .click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await finishCompletionDialog(page);

        // 4. Complete integrated B1 exit assessment (listening + reading + text_input + sentence_order)
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_b1_exit');
        await main.locator('audio[src="/lesson-media/english/b1/b1-exit-dialogue.wav"]').waitFor({ state: 'visible' });
        await main.locator('summary', { hasText: 'Matnli bayon' }).click();
        await main.locator('[lang="en"]').getByText('Malika:').first().waitFor({ state: 'visible' });
        await advanceLessonStep(page);

        // Step 2: B1 exit listening MCQ
        await main
          .getByRole('button', {
            name: /Proyektor kabeli uzildi; slayd havolasini ulashib, savol-javobni 15 daqiqa ertaroq boshlashadi/i,
          })
          .click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Keyingi savol/i }).click();

        // Step 3: B1 exit reading MCQ
        await main
          .getByRole('button', {
            name: /Inshoni qayta yuklamaydi, lekin dushanba tongidan oldin qabul bo‘limi bilan bog‘lanishi kerak/i,
          })
          .click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Keyingi savol/i }).click();

        // Step 4: B1 exit text_input
        await main.getByRole('textbox').first().fill('I have already downloaded my e-ticket');
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: /Keyingi savol/i }).click();

        // Step 5: B1 exit sentence_order (final step -> completion dialog)
        const orderGroup = main.getByRole('group', { name: /Gap tuzing|Sentence order/i });
        for (const token of ['The mentor', 'said that', 'we ought', 'to test', 'our backup', 'plan today.']) {
          await orderGroup.locator(`[data-word-token="${token}"]`).click();
        }
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        const completionDialog = page.getByRole('dialog', { name: /Dars yakunlandi/i });
        await completionDialog.waitFor({ state: 'visible' });
        assert.equal(
          /Official CEFR Certificate|Rasmiy CEFR sertifikati|Официальный сертификат CEFR/i.test(
            await page.locator('body').innerText(),
          ),
          false,
          'T4-05: B1 exit completion dialog MUST NOT claim Official CEFR Certificate.',
        );
        await finishCompletionDialog(page);

        // 5. Confirm B2–C2 remain DEFERRED with 0 openable buttons and reload persistence holds
        await navigateToRoadmapFromWorkspace(page);
        for (const deferredLevel of ['B2', 'C1', 'C2']) {
          const defSection = getCefrLevelSection(main, deferredLevel);
          await helpers.expectVisibleFast(
            defSection.getByText(/Keyingi bosqich \(DEFERRED\)/i),
            `T4-05: Expected ${deferredLevel} to remain DEFERRED even after B1 exit completion.`,
            FAST_TIMEOUT,
          );
          assert.equal(
            await defSection.getByRole('button').count(),
            0,
            `T4-05: Deferred ${deferredLevel} section must keep 0 buttons after B1 exit.`,
          );
        }

        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          const completed = after.progress?.profile?.completedLessonIds ?? [];
          for (const requiredId of [
            'lesson_eng_b1_m1_travel',
            'lesson_eng_b1_u1_checkpoint',
            'lesson_eng_b1_exit',
          ]) {
            assert.equal(
              completed.includes(requiredId),
              true,
              `T4-05: Expected ${requiredId} persisted in completedLessonIds, got ${JSON.stringify(completed)}`,
            );
          }
          assert.ok(
            after.progress?.profile?.scoresByCourse?.course_eng_01,
            'T4-05: Expected scoresByCourse.course_eng_01 persisted after B1 journey.',
          );
        });
        assertCleanSession(session, 'T4-05');
      },
    },
    {
      id: 'T4-06',
      name: 'Bilingual multi-course power user (ru locale + 390px mobile + dark mode) isolates English and Math progress across reload',
      milestone: ['M1', 'M2'],
      contextOptions: { viewport: 'mobile390', theme: 'dark', locale: 'ru' },
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        assert.equal(await page.evaluate(() => document.documentElement.lang), 'ru');
        assert.equal(await page.locator('html').getAttribute('data-theme'), 'dark');
        await helpers.assertNoHorizontalOverflow(page, 'T4-06-eng-390-dark-ru');

        await advanceLessonStep(page, /Birga misol ko‘ramiz|Разберём пример|Посмотрим пример|Пример/i);
        const main = page.getByRole('main');
        await main.locator('audio[src="/lesson-media/english/a1-starter-dialogue.wav"]').waitFor({ state: 'visible' });
        await advanceLessonStep(page, /Iboralarni eslab qolamiz|Запоминаем фразы|Карточки/i);
        await advanceToExerciseStep(page);
        await submitFreeTextAnswer(page, "I'm Sam");
        await main.getByText('Верно!', { exact: true }).waitFor({ state: 'visible' });
        await finishCompletionDialog(page);

        await helpers.selectCourse(page, 'course_math_01');
        await main.getByRole('radio', { name: /Начинаю с нуля/i }).check();
        await main.getByRole('button', { name: 'Начать первый урок' }).click();
        await completeMcqLesson(page, /^([A-D]\s+)?6$/i);

        await helpers.assertNoHorizontalOverflow(page, 'T4-06-math-390-dark-ru');
        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          const completed = after.progress?.profile?.completedLessonIds ?? [];
          assert.equal(completed.includes('lesson_eng_starter'), true);
          assert.equal(completed.includes('lesson_math_starter'), true);
          assert.ok(after.progress?.profile?.scoresByCourse?.course_eng_01);
          assert.ok(after.progress?.profile?.scoresByCourse?.course_math_01);
          assert.equal(after.progress?.profile?.scoresByCourse?.course_it, undefined);
          assert.equal(after.progress?.profile?.scoresByCourse?.course_logic, undefined);
        });
        assertCleanSession(session, 'T4-06');
      },
    },
  ];
}

export const getTests = registerTests;
