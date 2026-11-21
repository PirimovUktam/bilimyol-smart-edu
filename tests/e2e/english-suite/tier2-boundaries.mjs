import assert from 'node:assert/strict';
import {
  FAST_TIMEOUT,
  PLACEMENT_MIN_INTERVAL_MS,
  advanceLessonStep,
  advanceToExerciseStep,
  assertCleanSession,
  clickFirstVisibleButton,
  completeMcqLesson,
  getCefrLevelSection,
  openDirectEnglishLesson,
  openEnglishRoadmap,
  openRoadmapNodeLesson,
  openStarterLesson,
  startEnglishPlacement,
  submitFreeTextAnswer,
} from './flows.mjs';

export function registerTests() {
  return [
    // =========================================================================
    // F1 Boundaries (T2-F1-01 .. T2-F1-05)
    // =========================================================================
    {
      id: 'T2-F1-01',
      name: 'Direct URL navigation to a course_math_01 lesson while course_eng_01 is active triggers cross-course isolation guard',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await page.goto(`${baseUrl}/?view=lesson&lessonId=lesson_math_algebra_01`, {
          waitUntil: 'domcontentloaded',
          timeout: 15000,
        });

        const main = page.getByRole('main');
        await main
          .getByRole('heading', { name: /Dars noto‘g‘ri fanda/i })
          .first()
          .waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Yo‘l xaritasiga qaytish' }).waitFor({ state: 'visible' });

        const mainText = await main.innerText();
        assert.equal(
          /Kvadratni ochish|Qisqa ko‘paytirish/i.test(mainText),
          false,
          `T2-F1-01: Math algebra content leaked under English cross-course guard: ${mainText}`,
        );
        assertCleanSession(session, 'T2-F1-01');
      },
    },
    {
      id: 'T2-F1-02',
      name: 'Rapidly switching course_eng_01 -> course_it -> course_math_01 -> course_eng_01 leaves zero stale nodes',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await helpers.launchDemoSession(page, baseUrl);
        const main = page.getByRole('main');

        await helpers.selectCourse(page, 'course_eng_01');
        await main.getByRole('radio', { name: /Asoslarini bilaman/i }).check();
        await main.getByRole('button', { name: 'Ta’lim yo‘lini ochish' }).click();

        await helpers.selectCourse(page, 'course_it');
        await main.getByRole('radio', { name: /Asoslarini bilaman/i }).check();
        await main.getByRole('button', { name: 'Ta’lim yo‘lini ochish' }).click();

        await helpers.selectCourse(page, 'course_math_01');
        await main.getByRole('radio', { name: /Asoslarini bilaman/i }).check();
        await main.getByRole('button', { name: 'Ta’lim yo‘lini ochish' }).click();

        await helpers.selectCourse(page, 'course_eng_01');
        await clickFirstVisibleButton(page, /^Ta’lim yo‘li$/i);
        await main
          .getByRole('heading', { name: /Mening ta’lim yo‘lim/i })
          .first()
          .waitFor({ state: 'visible' });

        const roadmapText = await main.innerText();
        assert.match(roadmapText, /Vocabulary/i);
        assert.match(roadmapText, /Reading/i);
        assert.equal(
          /\b(Python|Algebra|Tenglamalar|Funksiyalar|Grafiklar|Mantiqiy boshqotirmalar|Qonuniyatlar)\b/i.test(roadmapText),
          false,
          `T2-F1-02: Stale non-English nodes appeared after rapid course switching: ${roadmapText}`,
        );
        const nodeTitles = await main.locator('li[data-node-id] h3, ol.learning-timeline h3').allInnerTexts();
        for (const title of nodeTitles) {
          assert.equal(
            /\b(Python|Algebra|Tenglamalar|Funksiyalar|Grafiklar|Mantiqiy|Qonuniyatlar|Veb sahifa)\b/i.test(title),
            false,
            `T2-F1-02: Non-English roadmap node heading leaked after switching: "${title}"`,
          );
        }
        const nodeIds = await main
          .locator('li[data-node-id]')
          .evaluateAll((els) => els.map((el) => el.getAttribute('data-node-id') ?? ''));
        for (const id of nodeIds) {
          assert.equal(
            /^(node_math_|node_it_|node_logic_)/i.test(id),
            false,
            `T2-F1-02: Non-English data-node-id leaked into English roadmap: "${id}"`,
          );
        }
        const headerText = await main.locator('header').first().innerText();
        assert.match(headerText, /Ingliz tili/i, `T2-F1-02: Expected English course header, got "${headerText}".`);
        assert.equal(
          /\b(Matematika|IT & Kodlash|Mantiq)\b/i.test(headerText),
          false,
          `T2-F1-02: Non-English course title leaked into header: "${headerText}"`,
        );
        assertCleanSession(session, 'T2-F1-02');
      },
    },
    {
      id: 'T2-F1-03',
      name: 'Demo session emits zero Supabase/remote requests across courses, lessons, media, AI, results, and profile',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await page.getByRole('main').getByRole('button', { name: 'Qayta tinglash' }).click();
        await helpers.openAndCloseYolchiAi(page, {
          askText: 'Hello so‘zi haqida qisqa izoh bering',
          closeWith: 'button',
        });

        await clickFirstVisibleButton(page, /Ta’lim yo‘liga qaytish/i);
        await clickFirstVisibleButton(page, /^Natijalar$/i);
        await page.getByRole('main').waitFor({ state: 'visible' });
        await clickFirstVisibleButton(page, /^Profil$/i);
        await page.getByRole('main').waitFor({ state: 'visible' });

        assertCleanSession(session, 'T2-F1-03');
      },
    },
    {
      id: 'T2-F1-04',
      name: 'Completed course_math_01 starter lessons never skip onboarding or starter flow in course_eng_01',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await helpers.launchDemoSession(page, baseUrl);
        await helpers.selectCourse(page, 'course_math_01');
        const main = page.getByRole('main');

        await main.getByRole('radio', { name: /Noldan boshlayman/i }).check();
        await main.getByRole('button', { name: 'Birinchi darsni boshlash' }).click();
        await completeMcqLesson(page, /^([A-D]\s+)?6$/i);

        await main.getByRole('button', { name: 'Boshlang‘ich darsni ochish' }).click();
        await completeMcqLesson(page, /^([A-D]\s+)?6$/i);

        await helpers.selectCourse(page, 'course_eng_01');
        await main
          .getByRole('heading', { name: /O‘rganish rejangizni sozlang/i })
          .first()
          .waitFor({ state: 'visible' });
        await main.getByRole('radio', { name: /Noldan boshlayman/i }).check();
        await main.getByRole('button', { name: 'Birinchi darsni boshlash' }).click();
        await main
          .getByRole('heading', { name: 'Birinchi inglizcha so‘zlar' })
          .first()
          .waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F1-04');
      },
    },
    {
      id: 'T2-F1-05',
      name: 'Media path validation refuses external/tampered URLs and degrades aborted media safely',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        const previewOrigin = new URL(baseUrl).origin;
        const externalRequests = [];
        const onReq = (req) => {
          try {
            const parsed = new URL(req.url());
            if (
              parsed.protocol.startsWith('http') &&
              parsed.origin !== previewOrigin &&
              parsed.hostname !== 'fonts.googleapis.com' &&
              parsed.hostname !== 'fonts.gstatic.com'
            ) {
              externalRequests.push(req.url());
            }
          } catch {
            // Ignore non-URL schemes
          }
        };
        page.on('request', onReq);

        try {
          await openStarterLesson(page, baseUrl, helpers);
          await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

          const main = page.getByRole('main');
          const mediaAudit = await main.evaluate(() => {
            const els = [...document.querySelectorAll('main audio, main img, main video, main track')];
            return els.map((el) => ({
              tag: el.tagName.toLowerCase(),
              src: el.getAttribute('src') ?? '',
              alt: el.tagName.toLowerCase() === 'img' ? (el.getAttribute('alt') ?? '') : null,
            }));
          });
          assert.ok(mediaAudit.length >= 2, 'Expected starter audio & image elements.');
          for (const item of mediaAudit) {
            assert.match(
              item.src,
              /^\/lesson-media\/[a-z0-9_/-]+\.(png|jpg|jpeg|webp|svg|wav|mp3|ogg|m4a|mp4|webm|vtt)$/i,
              `Untrusted or unexpected media source detected on <${item.tag}>: "${item.src}"`,
            );
            if (item.tag === 'img') {
              assert.ok(item.alt && item.alt.trim().length > 0, 'Expected non-empty alt text on starter image.');
            }
          }
          assert.deepEqual(externalRequests, [], 'Expected zero requests to untrusted external host.');

          const unthrottle = await helpers.throttleNetwork(page, {
            pattern: '**/lesson-media/**',
            abort: true,
          });
          try {
            await page.reload({ waitUntil: 'domcontentloaded' });
            await main.getByText(/Yozuv yuklanmadi/i).waitFor({ state: 'visible' });
            await main.getByText(/Rasm yuklanmadi\. Tavsifi:/i).waitFor({ state: 'visible' });
          } finally {
            await unthrottle();
          }
          assertCleanSession(session, 'T2-F1-05');
        } finally {
          page.off('request', onReq);
        }
      },
    },

    // =========================================================================
    // F2 Boundaries (T2-F2-01 .. T2-F2-05)
    // =========================================================================
    {
      id: 'T2-F2-01',
      name: 'Placement submit button stays disabled when no option is selected',
      milestone: ['M1', 'M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const nextBtn = main.getByRole('button', { name: /Keyingi savol|Natijani ko‘rish/i });
        await nextBtn.waitFor({ state: 'visible' });
        assert.equal(
          await nextBtn.isDisabled(),
          true,
          'Expected placement advance button disabled when no radio option is selected.',
        );
        await main.getByText(/^1\s*\/\s*\d+\s+savol$/i).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F2-01');
      },
    },
    {
      id: 'T2-F2-02',
      name: 'Reloading mid-placement handles reset/resume cleanly without corrupting English mastery scores',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');

        await main.getByRole('radio').first().check();
        await page.waitForTimeout(PLACEMENT_MIN_INTERVAL_MS);
        await main.getByRole('button', { name: /Keyingi savol/i }).click();
        await main.getByText(/^2\s*\/\s*\d+\s+savol$/i).first().waitFor({ state: 'visible' });

        await helpers.reloadAndVerifyPersistence(page, async ({ after }) => {
          const engScores = after.progress?.profile?.scoresByCourse?.course_eng_01;
          assert.equal(
            engScores,
            undefined,
            'Incomplete placement reload must not write partial scores into scoresByCourse.course_eng_01.',
          );
        });
        assertCleanSession(session, 'T2-F2-02');
      },
    },
    {
      id: 'T2-F2-03',
      name: 'All-wrong placement submission (0%) routes learner to A1 foundation without crash or negative score',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const knownWrongByStem = new Map();
        const knownCorrectByStem = new Map();
        let correctCount = -1;
        let totalCount = 0;
        let resultText = '';

        for (let attempt = 1; attempt <= 4; attempt++) {
          for (let step = 1; step <= 16; step++) {
            const stem = ((await main.locator('h2').first().textContent()) ?? '').trim();
            const optionLabels = (await main.locator('fieldset label').allInnerTexts()).map((s) => s.trim());
            assert.ok(optionLabels.length >= 2, `T2-F2-03: Expected >= 2 placement options at step ${step}.`);

            let chosenIdx = optionLabels.length - 1;
            const knownWrong = knownWrongByStem.get(stem);
            const knownRight = knownCorrectByStem.get(stem);
            if (knownWrong && optionLabels.indexOf(knownWrong) !== -1) {
              chosenIdx = optionLabels.indexOf(knownWrong);
            } else if (knownRight) {
              const altIdx = optionLabels.findIndex((opt) => opt !== knownRight);
              if (altIdx !== -1) chosenIdx = altIdx;
            }

            await main.getByRole('radio').nth(chosenIdx).check();
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

          await main.getByRole('heading', { name: /Diagnostika yakunlandi/i }).first().waitFor({ state: 'visible' });
          resultText = await main.innerText();
          const scoreMatch = resultText.match(/(\d+)\s*\/\s*(\d+)\s*javob to‘g‘ri/i);
          assert.ok(scoreMatch, `T2-F2-03: Could not parse placement score from: ${resultText}`);
          correctCount = Number(scoreMatch[1]);
          totalCount = Number(scoreMatch[2]);

          if (correctCount === 0 || attempt === 4) break;

          await main.locator('details summary', { hasText: /Javoblar tahlili/i }).click();
          const items = main.locator('details ol > li');
          const count = await items.count();
          for (let i = 0; i < count; i++) {
            const liText = await items.nth(i).innerText();
            const qMatch = liText.match(/^\s*\d+\.\s+(.+)$/m);
            const selMatch = liText.match(/Siz belgilagan javob —\s*(.+)$/m);
            const rightMatch = liText.match(/To‘g‘ri javob —\s*(.+)$/m);
            const qStem = qMatch?.[1]?.trim();
            const selectedOpt = selMatch?.[1]?.trim();
            if (!qStem || !selectedOpt) continue;
            if (/^\s*To‘g‘ri\s*$/m.test(liText)) {
              knownCorrectByStem.set(qStem, selectedOpt);
            } else {
              knownWrongByStem.set(qStem, selectedOpt);
              if (rightMatch?.[1]?.trim()) {
                knownCorrectByStem.set(qStem, rightMatch[1].trim());
              }
            }
          }

          await main.getByRole('button', { name: /Qayta topshirish/i }).click();
          await main.getByText(/^1\s*\/\s*\d+\s+savol$/i).first().waitFor({ state: 'visible' });
        }

        assert.equal(
          correctCount,
          0,
          `T2-F2-03 (M5): Expected 0 / ${totalCount} (0%) all-wrong placement score, got ${correctCount} / ${totalCount}.`,
        );
        assert.match(
          resultText,
          /\b(Pre-A1|A1)\b/i,
          `T2-F2-03 (M5): Expected 0% placement to recommend Pre-A1/A1 foundation, got: ${resultText}`,
        );

        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const engScores = Object.values(snapshot.progress?.profile?.scoresByCourse?.course_eng_01 ?? {});
        for (const s of engScores) {
          assert.ok(typeof s.score === 'number' && s.score >= 0, `T2-F2-03: Negative skill score detected: ${JSON.stringify(s)}`);
        }
        const placementScore = snapshot.progress?.profile?.placementScoreByCourse?.course_eng_01;
        if (placementScore != null) {
          const numericPlacement = typeof placementScore === 'number' ? placementScore : placementScore.score;
          assert.ok(numericPlacement >= 0 && numericPlacement === 0, `T2-F2-03: Expected placementScore 0, got ${JSON.stringify(placementScore)}`);
        }

        await main.getByRole('button', { name: /Shaxsiy yo‘lni ko‘rish/i }).click();
        await helpers.expectVisibleFast(
          main.getByText(/\bA1\b|Birinchi inglizcha so‘zlar|1-boshlang‘ich dars/i),
          'T2-F2-03 (M5): Expected 0% placement handoff to route learner to A1 / lesson_eng_starter.',
          FAST_TIMEOUT,
        );
        assertCleanSession(session, 'T2-F2-03');
      },
    },
    {
      id: 'T2-F2-04',
      name: 'Completing placement test never adds fake entries to course_eng_01 completedLessonIds',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');

        for (let step = 1; step <= 12; step++) {
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

        await main
          .getByRole('heading', { name: /Diagnostika yakunlandi/i })
          .first()
          .waitFor({ state: 'visible' });

        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const completed = snapshot.progress?.profile?.completedLessonIds ?? [];
        assert.equal(
          completed.some((id) => id.startsWith('lesson_eng_')),
          false,
          `T2-F2-04 (M5): Placement alone must not mark English lessons completed, got: ${JSON.stringify(completed)}`,
        );
        assert.ok(
          snapshot.progress?.profile?.placementScoreByCourse?.course_eng_01 !== undefined,
          'T2-F2-04 (M5): Expected placementScoreByCourse.course_eng_01 populated separately.',
        );
        assertCleanSession(session, 'T2-F2-04');
      },
    },
    {
      id: 'T2-F2-05',
      name: 'Listening placement item hides transcript until explicitly toggled and alternative never auto-fails',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await startEnglishPlacement(page, baseUrl, helpers);
        const main = page.getByRole('main');
        let checkedListening = false;

        for (let step = 1; step <= 12; step++) {
          const audioCount = await main.locator('audio').count();
          if (audioCount > 0) {
            const audioSrc = (await main.locator('audio').first().getAttribute('src')) ?? '';
            assert.match(
              audioSrc,
              /^\/lesson-media\/english\/placement\/q_eng_place_listening_.*\.wav$/i,
              `T2-F2-05 (M5): Expected real placement WAV src, got "${audioSrc}"`,
            );
            const details = main.locator('details');
            await helpers.expectVisibleFast(
              details.locator('summary'),
              'T2-F2-05 (M5): Expected collapsible transcript toggle on placement listening item.',
              FAST_TIMEOUT,
            );
            assert.equal(
              await details.first().evaluate((el) => el.hasAttribute('open')),
              false,
              'T2-F2-05 (M5): Placement listening transcript must stay closed until learner toggles it.',
            );
            await details.first().locator('summary').click();
            await main.locator('[lang="en"]').first().waitFor({ state: 'visible' });
            const firstOption = main.getByRole('radio').first();
            await firstOption.check();
            assert.equal(
              await firstOption.isChecked(),
              true,
              'T2-F2-05 (M5): Opening transcript alternative must leave answer options selectable without auto-failing.',
            );
            checkedListening = true;
            break;
          }
          const nextBtn = main.getByRole('button', { name: /Keyingi savol/i });
          if (!(await nextBtn.isVisible().catch(() => false))) break;
          await main.getByRole('radio').first().check();
          await page.waitForTimeout(PLACEMENT_MIN_INTERVAL_MS);
          await nextBtn.click();
        }

        assert.equal(
          checkedListening,
          true,
          'T2-F2-05 (M5): Expected real <audio> listening item inside English placement test.',
        );
        assertCleanSession(session, 'T2-F2-05');
      },
    },

    // =========================================================================
    // F3 Boundaries (T2-F3-01 .. T2-F3-05)
    // =========================================================================
    {
      id: 'T2-F3-01',
      name: 'Empty or whitespace-only text in lesson_eng_starter free-text input is rejected with guidance',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceToExerciseStep(page);

        const main = page.getByRole('main');
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByRole('alert').waitFor({ state: 'visible' });

        await submitFreeTextAnswer(page, '   ');
        await main.getByRole('alert').waitFor({ state: 'visible' });
        assert.equal(await main.getByText('To‘g‘ri javob!').count(), 0);
        await main.getByText('Qadam 4 / 4', { exact: true }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F3-01');
      },
    },
    {
      id: 'T2-F3-02',
      name: 'Free-text normalization accepts curly apostrophe, casing, extra spaces, and trailing punctuation',
      milestone: ['M1'],
      async run({ browser, page, baseUrl, session, helpers, screenshotsDir }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceToExerciseStep(page);
        await submitFreeTextAnswer(page, '  i’m   sam! ');
        await page.getByRole('main').getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        await page.getByRole('dialog', { name: 'Dars yakunlandi' }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F3-02-a');

        await helpers.runWithContext(
          browser,
          { defaultTimeout: 5000 },
          async (sub) => {
            await openStarterLesson(sub.page, baseUrl, helpers);
            await advanceToExerciseStep(sub.page);
            await submitFreeTextAnswer(sub.page, 'My name is Sam.');
            await sub.page
              .getByRole('main')
              .getByText('To‘g‘ri javob!', { exact: true })
              .waitFor({ state: 'visible' });
            await sub.page.getByRole('dialog', { name: 'Dars yakunlandi' }).waitFor({ state: 'visible' });
            assertCleanSession(sub, 'T2-F3-02-b');
          },
          { id: 'T2-F3-02-b', screenshotsDir },
        );
      },
    },
    {
      id: 'T2-F3-03',
      name: 'Wrong free-text answers ("Goodbye", "123", "I\'m Aziza") are rejected without leaking answer key and allow retry',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceToExerciseStep(page);
        const main = page.getByRole('main');

        for (const wrong of ['Goodbye', '123', "I'm Aziza"]) {
          await submitFreeTextAnswer(page, wrong);
          await main.getByText('Javobni ko‘rib chiqamiz', { exact: true }).waitFor({ state: 'visible' });
          assert.equal(
            await main.getByText(/To‘g‘ri javob:/i).count(),
            0,
            `Free-text wrong feedback must NOT spoil answer key after "${wrong}".`,
          );
          await main.getByRole('button', { name: 'Qayta urinish' }).click();
        }

        await submitFreeTextAnswer(page, "I'm Sam");
        await main.getByText('To‘g‘ri javob!', { exact: true }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F3-03');
      },
    },
    {
      id: 'T2-F3-04',
      name: 'Double-clicking TEKSHIRISH on lesson_eng_starter completion is idempotent for completion and XP',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceToExerciseStep(page);

        const main = page.getByRole('main');
        const input = main.getByRole('textbox', { name: /Javobingizni ingliz tilida yozing/i });
        await input.fill("I'm Sam");
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).dblclick();

        await page.getByRole('dialog', { name: 'Dars yakunlandi' }).waitFor({ state: 'visible' });
        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const completed = snapshot.progress?.profile?.completedLessonIds ?? [];
        assert.equal(
          completed.filter((id) => id === 'lesson_eng_starter').length,
          1,
          `Expected exactly 1 entry for lesson_eng_starter, got: ${JSON.stringify(completed)}`,
        );
        assert.equal(
          snapshot.progress?.profile?.xp,
          22,
          `Expected single XP award (22), got: ${snapshot.progress?.profile?.xp}`,
        );
        assertCleanSession(session, 'T2-F3-04');
      },
    },
    {
      id: 'T2-F3-05',
      name: 'Media failure/offline fallback renders retry + transcript + image alt text without layout collapse',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        const unthrottle = await helpers.throttleNetwork(page, {
          pattern: '**/lesson-media/**',
          abort: true,
        });
        try {
          await openStarterLesson(page, baseUrl, helpers);
          await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

          const main = page.getByRole('main');
          await main.getByText(/Yozuv yuklanmadi/i).waitFor({ state: 'visible' });
          await main.getByRole('button', { name: 'Qayta yuklash' }).waitFor({ state: 'visible' });
          await main.getByText(/Rasm yuklanmadi\. Tavsifi:/i).waitFor({ state: 'visible' });

          await main.locator('summary', { hasText: 'Matnli bayon' }).click();
          await main.locator('[lang="en"]').getByText('Aziza:').waitFor({ state: 'visible' });
          await helpers.assertNoHorizontalOverflow(page, 'T2-F3-05-media-fallback');
        } finally {
          await unthrottle();
        }
        assertCleanSession(session, 'T2-F3-05');
      },
    },

    // =========================================================================
    // F4 Boundaries (T2-F4-01 .. T2-F4-05)
    // =========================================================================
    {
      id: 'T2-F4-01',
      name: 'Locked node_eng_read before prerequisites displays lock notice and refuses opening',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const readCard = main.locator('li').filter({
          has: page.getByRole('heading', { name: /^Reading$/i }),
        });
        await readCard.waitFor({ state: 'visible' });
        await readCard.getByText('Qulflangan', { exact: true }).waitFor({ state: 'visible' });
        await readCard.getByText(/Avval yakunlang/i).waitFor({ state: 'visible' });
        assert.equal(
          await readCard.getByRole('button', { name: /Darsni boshlash/i }).count(),
          0,
          'Locked Reading node must not expose Darsni boshlash button.',
        );

        await readCard.click();
        await main.getByRole('heading', { name: /Mening ta’lim yo‘lim/i }).first().waitFor({ state: 'visible' });
        assert.equal(page.url().includes('lesson_eng_reading_01'), false);
        assertCleanSession(session, 'T2-F4-01');
      },
    },
    {
      id: 'T2-F4-02',
      name: 'Out-of-bounds reading checkpoint indices (-1, 999) clamp safely to [0, exerciseStepIndex]',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_reading_01');
        const main = page.getByRole('main');

        await helpers.writeReadingCheckpoint(page, 'lesson_eng_reading_01', -1);
        await page.reload({ waitUntil: 'domcontentloaded' });
        await main.getByText('Qadam 1 / 3', { exact: true }).waitFor({ state: 'visible' });

        await helpers.writeReadingCheckpoint(page, 'lesson_eng_reading_01', 999);
        await page.reload({ waitUntil: 'domcontentloaded' });
        await main.getByText('Qadam 3 / 3', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('heading', { name: 'Bilimingizni tekshiring' }).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F4-02');
      },
    },
    {
      id: 'T2-F4-03',
      name: 'lesson_eng_listening_01 rejects 03:15 distractor and explains "in the afternoon" (15:15) evidence',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_listening_01');
        await advanceToExerciseStep(page);

        const main = page.getByRole('main');
        const distractor0315 = main.getByRole('button', { name: /03:15/i });
        await helpers.expectVisibleFast(
          distractor0315,
          'T2-F4-03: Expected "03:15" AM/PM distractor option in lesson_eng_listening_01 (requires "in the afternoon" disambiguation).',
          FAST_TIMEOUT,
        );

        await distractor0315.first().click();
        await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
        await main.getByText('Javobni ko‘rib chiqamiz', { exact: true }).waitFor({ state: 'visible' });
        await helpers.expectVisibleFast(
          main.getByText(/in the afternoon/i),
          'T2-F4-03: Expected listening feedback explanation to reference "in the afternoon" evidence for 15:15.',
          FAST_TIMEOUT,
        );
        assertCleanSession(session, 'T2-F4-03');
      },
    },
    {
      id: 'T2-F4-04',
      name: 'Using transcript text alternative in lesson_eng_listening_01 still permits lesson completion',
      milestone: ['M1', 'M5'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_listening_01');
        await advanceLessonStep(page, /2\. Audio Xabarni Tinglash/i);

        const main = page.getByRole('main');
        await main.locator('summary', { hasText: 'Matnli bayon' }).click();
        await main.locator('[lang="en"]').getByText(/in the afternoon/i).waitFor({ state: 'visible' });

        await completeMcqLesson(page, '15:15 (quarter past three)');
        const snapshot = await helpers.readDemoProgressSnapshot(page);
        assert.equal(
          (snapshot.progress?.profile?.completedLessonIds ?? []).includes('lesson_eng_listening_01'),
          true,
          'Expected lesson_eng_listening_01 completable after viewing transcript text alternative.',
        );
        assertCleanSession(session, 'T2-F4-04');
      },
    },
    {
      id: 'T2-F4-05',
      name: 'Navigating away mid-reading (lesson_eng_reading_01) restores step ONLY and does not mark lesson completed',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_reading_01');
        await advanceLessonStep(page, /Ishlangan misol/i);

        const main = page.getByRole('main');
        await main.getByText('Qadam 2 / 3', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('button', { name: 'Ta’lim yo‘liga qaytish' }).click();

        await main.getByRole('heading', { name: /Mening ta’lim yo‘lim/i }).first().waitFor({ state: 'visible' });
        const snapshot = await helpers.readDemoProgressSnapshot(page);
        assert.equal(
          (snapshot.progress?.profile?.completedLessonIds ?? []).includes('lesson_eng_reading_01'),
          false,
          'Navigating away mid-reading must NOT mark lesson_eng_reading_01 completed.',
        );

        await openDirectEnglishLesson(page, baseUrl, 'lesson_eng_reading_01');
        await main.getByText('Qadam 2 / 3', { exact: true }).waitFor({ state: 'visible' });
        await main.getByRole('heading', { name: 'Ishlangan misol' }).first().waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F4-05');
      },
    },

    // =========================================================================
    // F5 Boundaries (T2-F5-01 .. T2-F5-05)
    // =========================================================================
    {
      id: 'T2-F5-01',
      name: 'Locked A2/B1 prerequisite guards and DEFERRED B2/C1/C2 sections cannot be opened or bypassed',
      milestone: ['M3', 'M5', 'M6'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        // 1. Verify locked A2 and B1 exit prerequisite guards
        for (const [level, nodeId] of [
          ['A2', 'node_eng_a2_exit'],
          ['B1', 'node_eng_b1_exit'],
        ]) {
          const section = getCefrLevelSection(main, level);
          const exitNode = section.locator(`[data-node-id="${nodeId}"]`);
          await helpers.expectVisibleFast(
            exitNode,
            `T2-F5-01: Expected locked ${level} exit node (${nodeId}) on grouped English roadmap.`,
            FAST_TIMEOUT,
          );
          await helpers.expectVisibleFast(
            exitNode.getByText('Qulflangan', { exact: true }),
            `T2-F5-01: Expected ${nodeId} to display Qulflangan status before prerequisites.`,
            FAST_TIMEOUT,
          );
          await helpers.expectVisibleFast(
            exitNode.getByText(/Avval yakunlang\s*·/i),
            `T2-F5-01: Expected prerequisite notice on ${nodeId}.`,
            FAST_TIMEOUT,
          );
          assert.equal(
            await exitNode.getByRole('button', { name: /Darsni boshlash|Sinovni boshlash/i }).count(),
            0,
            `T2-F5-01: Locked ${nodeId} must not expose start/open lesson button.`,
          );

          const urlBefore = page.url();
          await exitNode.getByRole('button', { name: /Qulf sharti/i }).click();
          await helpers.expectVisibleFast(
            exitNode.locator('[role="status"]').filter({ hasText: /Bu bosqich hali ochilmagan\. Avval yakunlang:/i }),
            `T2-F5-01: Expected inline lock notice on ${nodeId} after clicking Qulf sharti.`,
            FAST_TIMEOUT,
          );
          assert.equal(page.url(), urlBefore, `T2-F5-01: Locked ${nodeId} must not change URL.`);
          assert.equal(
            await main.getByRole('button', { name: /^TEKSHIRISH$/i }).count(),
            0,
            `T2-F5-01: Locked ${nodeId} must not render any exercise.`,
          );
        }

        // 2. Verify B2, C1, C2 DEFERRED sections have 0 openable buttons and cannot be navigated into
        for (const level of ['B2', 'C1', 'C2']) {
          const deferredSection = getCefrLevelSection(main, level);
          await helpers.expectVisibleFast(
            deferredSection.getByText(/Keyingi bosqich \(DEFERRED\)/i),
            `T2-F5-01: Expected Keyingi bosqich (DEFERRED) in ${level} section.`,
            FAST_TIMEOUT,
          );
          await helpers.expectVisibleFast(
            deferredSection.getByText('Qulflangan', { exact: true }).first(),
            `T2-F5-01: Expected Qulflangan status in ${level} section.`,
            FAST_TIMEOUT,
          );
          assert.equal(
            await deferredSection.getByRole('button').count(),
            0,
            `T2-F5-01: Deferred ${level} section must render 0 interactive buttons.`,
          );
          const urlBeforeClick = page.url();
          await deferredSection.click();
          assert.equal(page.url(), urlBeforeClick, `T2-F5-01: Clicking deferred ${level} section must not navigate.`);
          assert.equal(
            await main.getByRole('button', { name: /^TEKSHIRISH$/i }).count(),
            0,
            `T2-F5-01: Clicking deferred ${level} section must not open any exercise.`,
          );
        }

        // 3. Verify direct route/hash bypass attempts cannot open B2/C1/C2 content
        for (const bypassPath of [
          '/?view=roadmap#b2',
          '/#b2',
          '/?view=lesson&lessonId=lesson_eng_b2_m1_interview',
          '/?view=lesson&lessonId=lesson_eng_c1_exit',
        ]) {
          await page.goto(`${baseUrl}${bypassPath}`, { waitUntil: 'domcontentloaded', timeout: 15000 });
          assert.equal(
            await main.getByRole('button', { name: /^TEKSHIRISH$/i }).count(),
            0,
            `T2-F5-01: Bypass attempt "${bypassPath}" must not render any B2/C1/C2 exercise.`,
          );
          if (bypassPath.includes('lessonId=')) {
            await helpers.expectVisibleFast(
              main.getByText(/Dars topilmadi|topilmadi/i),
              `T2-F5-01: Direct deferred lesson bypass "${bypassPath}" must show Dars topilmadi fallback.`,
              FAST_TIMEOUT,
            );
          }
        }
        assertCleanSession(session, 'T2-F5-01');
      },
    },
    {
      id: 'T2-F5-02',
      name: 'Weak unit checkpoint score (< requiredScore) triggers remedial practice/alternate variant without unlocking next CEFR level',
      milestone: ['M2', 'M3', 'M5'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const checkpointCard = main
          .locator('li, article, [data-node-id]')
          .filter({ hasText: /Modul yakuni|Unit checkpoint|Bosqich sinovi|Checkpoint/i })
          .first();

        await helpers.expectVisibleFast(
          checkpointCard,
          'T2-F5-02 (M2-M3, M5): Expected unit checkpoint node on English roadmap.',
          FAST_TIMEOUT,
        );

        const startBtn = checkpointCard.getByRole('button', {
          name: /Darsni boshlash|Sinovni boshlash|Boshlash/i,
        });
        await helpers.expectVisibleFast(
          startBtn,
          'T2-F5-02 (M2-M3, M5): Expected openable unit checkpoint trigger button.',
          FAST_TIMEOUT,
        );
        await startBtn.click();

        for (let step = 0; step < 12; step++) {
          const checkBtn = main.getByRole('button', { name: /^TEKSHIRISH$|^Topshirish$/i });
          if (await checkBtn.first().isVisible().catch(() => false)) {
            const textInput = main.getByRole('textbox');
            const options = main.locator('button[aria-pressed], fieldset label, [role="radio"]');
            if ((await textInput.count()) > 0 && (await textInput.first().isVisible().catch(() => false))) {
              await textInput.first().fill('__weak_incorrect_answer__');
            } else if ((await options.count()) > 0) {
              await options.last().click();
            }
            await checkBtn.first().click();

            const nextQ = main.getByRole('button', { name: /Keyingi savol|Keyingi qadam|Darsni yakunlash/i });
            if (await nextQ.first().isVisible().catch(() => false)) {
              await nextQ.first().click();
            }
          } else {
            const nextStepBtn = main.getByRole('button', { name: /Keyingi qadam|Sinovni yakunlash/i });
            if (!(await nextStepBtn.first().isVisible().catch(() => false))) break;
            await nextStepBtn.first().click();
          }

          const weakOutcome = await main
            .getByText(/qayta mashq|remedial|boshqa variant|qo‘shimcha mashq|yetarli emas|qayta topshirish/i)
            .first()
            .isVisible()
            .catch(() => false);
          if (weakOutcome) break;
        }

        await helpers.expectVisibleFast(
          main.getByText(/qayta mashq|remedial|boshqa variant|qo‘shimcha mashq|yetarli emas|qayta topshirish/i),
          'T2-F5-02 (M2-M5): Expected remedial practice / alternate variant notice after weak checkpoint score.',
          FAST_TIMEOUT,
        );

        const backBtn = main.getByRole('button', { name: /Ta’lim yo‘liga qaytish/i });
        if (await backBtn.first().isVisible().catch(() => false)) {
          await backBtn.first().click();
          await main
            .getByRole('heading', {
              name: /Mening ta’lim yo‘lim|Мой путь обучения|Ingliz tili|O‘quv yo‘li|Yo‘l xaritasi|Дорожная карта/i,
            })
            .first()
            .waitFor({ state: 'visible', timeout: 5000 })
            .catch(() => {});
        }
        const a2Section = getCefrLevelSection(main, 'A2');
        if ((await a2Section.count()) > 0) {
          assert.equal(
            await a2Section.getByRole('button', { name: /Darsni boshlash/i }).count(),
            0,
            'T2-F5-02 (M2-M5): Next CEFR level (A2) must remain locked after weak checkpoint score.',
          );
        }
        assertCleanSession(session, 'T2-F5-02');
      },
    },
    {
      id: 'T2-F5-03',
      name: 'Repeated identical errors across consecutive exercises surface targeted remedial explanation/lesson',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        await openRoadmapNodeLesson(page, /^Vocabulary$/i);
        await advanceToExerciseStep(page);

        const main = page.getByRole('main');
        for (let attempt = 0; attempt < 2; attempt++) {
          await main.getByRole('button', { name: 'behind the sofa' }).click();
          await main.getByRole('button', { name: /^TEKSHIRISH$/i }).click();
          if (attempt === 0) {
            await main.getByRole('button', { name: 'Qayta urinish' }).click();
          }
        }

        await helpers.expectVisibleFast(
          main.getByText(/takroriy xato|remedial|qo‘shimcha mashq/i),
          'T2-F5-03 (M5): Expected repeated-error targeted remedial trigger after consecutive identical errors.',
          FAST_TIMEOUT,
        );
        assertCleanSession(session, 'T2-F5-03');
      },
    },
    {
      id: 'T2-F5-04',
      name: 'Self-assessed speaking/writing prompt blocks empty submission, renders model+rubric+badge, and never claims Official CEFR Certificate',
      milestone: ['M2', 'M3'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const taskNode = main
          .locator('li, article, [data-node-id]')
          .filter({ hasText: /Speaking|Writing|Gapirish|Yozish|O‘zini baholash/i })
          .first();

        await helpers.expectVisibleFast(
          taskNode,
          'T2-F5-04 (M2-M3): Expected speaking/writing self_assessed node on English roadmap.',
          FAST_TIMEOUT,
        );
        await helpers.expectVisibleFast(
          taskNode.getByRole('button', { name: /Darsni boshlash|Boshlash/i }),
          'T2-F5-04 (M2-M3): Expected openable speaking/writing lesson button.',
          FAST_TIMEOUT,
        );
        await taskNode.getByRole('button', { name: /Darsni boshlash|Boshlash/i }).click();

        await advanceToExerciseStep(page);

        const responseBox = main.getByRole('textbox');
        await helpers.expectVisibleFast(
          responseBox,
          'T2-F5-04 (M2-M3): Expected free-response textbox for self_assessed speaking/writing task.',
          FAST_TIMEOUT,
        );

        const submitBtn = main.getByRole('button', {
          name: /^TEKSHIRISH$|Topshirish|Namunani ko‘rish|Baholash/i,
        }).first();

        for (const blank of ['', '   ']) {
          await responseBox.first().fill(blank);
          if (await submitBtn.isDisabled().catch(() => false)) {
            assert.equal(await submitBtn.isDisabled(), true);
          } else {
            await submitBtn.click();
            await helpers.expectVisibleFast(
              main.getByRole('alert'),
              'T2-F5-04 (M2-M3): Expected validation alert when submitting blank self_assessed response.',
              FAST_TIMEOUT,
            );
          }
          assert.equal(
            await main.getByText(/Namuna javob|Model response|Model answer/i).count(),
            0,
            'T2-F5-04 (M2-M3): Empty self_assessed submission must not unlock model/rubric.',
          );
        }

        await responseBox.first().fill('Hello! My name is Aziz. I study English every morning to speak confidently.');
        await submitBtn.click();

        await helpers.expectVisibleFast(
          main.getByText(/Namuna javob|Model response|Model answer/i),
          'T2-F5-04 (M2-M3): Expected model response after submitting valid speaking/writing answer.',
          FAST_TIMEOUT,
        );
        await helpers.expectVisibleFast(
          main.getByText(/Baholash mezoni|Rubric|Mezonlar/i),
          'T2-F5-04 (M2-M3): Expected self-assessment rubric criteria after valid submission.',
          FAST_TIMEOUT,
        );
        await helpers.expectVisibleFast(
          main.getByText(/O‘zini baholash|Mustaqil mashq|Self-assessment/i),
          'T2-F5-04 (M2-M3): Expected explicit self-assessment badge.',
          FAST_TIMEOUT,
        );

        const bodyText = await page.locator('body').innerText();
        assert.equal(
          /Official CEFR Certificate|Rasmiy CEFR sertifikati|Официальный сертификат CEFR/i.test(bodyText),
          false,
          `T2-F5-04 (M2-M3): Self-assessed task MUST NEVER display Official CEFR Certificate claim: ${bodyText}`,
        );
        assertCleanSession(session, 'T2-F5-04');
      },
    },
    {
      id: 'T2-F5-05',
      name: 'Partial or misordered sentence_order/word_match submission displays targeted hint and allows retry without lockout',
      milestone: ['M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const structuredNode = main
          .locator('li, article, [data-node-id]')
          .filter({ hasText: /Gap tuzish|So‘zlarni moslash|sentence_order|word_match|Tartib|Moslash/i })
          .first();

        await helpers.expectVisibleFast(
          structuredNode,
          'T2-F5-05 (M2): Expected sentence_order or word_match node on grouped A1 roadmap (without vacuous A1 match).',
          FAST_TIMEOUT,
        );
        await structuredNode.getByRole('button', { name: /Darsni boshlash|Boshlash/i }).click();
        await advanceToExerciseStep(page);

        const tokens = main.locator('[data-word-token], [data-match-item], [data-question-mode] button');
        const tokenCount = await tokens.count();
        assert.ok(tokenCount >= 2, 'T2-F5-05 (M2): Expected >= 2 interactive order/match tokens inside exercise.');

        const checkBtn = main.getByRole('button', { name: /^TEKSHIRISH$/i });
        assert.equal(
          await checkBtn.isDisabled(),
          true,
          'T2-F5-05 (M2): TEKSHIRISH must remain disabled when 0 pairs/tokens are selected.',
        );

        const leftColumn = main.locator('[data-match-side="left"] button[data-match-item]');
        const rightColumn = main.locator('[data-match-side="right"] button[data-match-item]');
        if ((await leftColumn.count()) > 0 && (await rightColumn.count()) > 0) {
          const leftFirst = leftColumn.first();
          const leftPairId = await leftFirst.getAttribute('data-pair-id');
          await leftFirst.click();
          const rightCount = await rightColumn.count();
          let targetRight = rightColumn.first();
          for (let r = 0; r < rightCount; r++) {
            const candidate = rightColumn.nth(r);
            if ((await candidate.getAttribute('data-pair-id')) !== leftPairId) {
              targetRight = candidate;
              break;
            }
          }
          await targetRight.click();
        } else {
          await tokens.last().click();
        }
        assert.equal(
          await checkBtn.isDisabled(),
          false,
          'T2-F5-05 (M2): TEKSHIRISH must enable for >= 1 partial/misordered selection.',
        );
        await checkBtn.click();

        await helpers.expectVisibleFast(
          main.getByText(/Javobni ko‘rib chiqamiz|tartib|mos|izoh/i),
          'T2-F5-05 (M2): Expected targeted error hint after partial/misordered sentence_order or word_match submission.',
          FAST_TIMEOUT,
        );
        assert.equal(await main.getByText('To‘g‘ri javob!').count(), 0);

        const retryBtn = main.getByRole('button', { name: /Qayta urinish|Tozalash/i }).first();
        await helpers.expectVisibleFast(
          retryBtn,
          'T2-F5-05 (M2): Expected retry/reset button without locking out learner.',
          FAST_TIMEOUT,
        );
        await retryBtn.click();
        assert.equal(
          await tokens.first().isEnabled(),
          true,
          'T2-F5-05 (M2): Exercise controls must remain interactive after retry.',
        );
        assertCleanSession(session, 'T2-F5-05');
      },
    },

    // =========================================================================
    // F6 Boundaries (T2-F6-01 .. T2-F6-05)
    // =========================================================================
    {
      id: 'T2-F6-01',
      name: 'Flipping flashcard 5 times without clicking Eslab qoldim awards zero mastery and does not complete lesson',
      milestone: ['M1', 'M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        for (let i = 0; i < 5; i++) {
          await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
          await main.getByRole('button', { name: 'Oldingi' }).click();
          await main.getByRole('heading', { name: 'Birga misol ko‘ramiz' }).first().waitFor({ state: 'visible' });
          await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);
        }

        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const completed = snapshot.progress?.profile?.completedLessonIds ?? [];
        assert.equal(
          completed.includes('lesson_eng_starter'),
          false,
          'Flipping flashcards 5 times without rating/exercise MUST NOT complete lesson.',
        );
        assert.equal(snapshot.progress?.profile?.xp ?? 0, 0, 'Expected 0 XP from flip-only card views.');
        assertCleanSession(session, 'T2-F6-01');
      },
    },
    {
      id: 'T2-F6-02',
      name: 'Repeatedly clicking Yana mashq qilaman keeps card in active queue without crash until resolved',
      milestone: ['M1', 'M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        for (let cycle = 0; cycle < 4; cycle++) {
          await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
          await main.getByRole('button', { name: 'Yana mashq qilaman' }).click();
          await main.getByText('0 / 2', { exact: true }).waitFor({ state: 'visible' });
        }

        for (let finish = 0; finish < 2; finish++) {
          await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
          await main.getByRole('button', { name: 'Eslab qoldim' }).click();
        }
        await main
          .getByRole('heading', { name: 'Barcha kartochkalar ko‘rib chiqildi' })
          .waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F6-02');
      },
    },
    {
      id: 'T2-F6-03',
      name: 'Missing or broken flashcard image in Image->Word mode degrades gracefully to text/alt fallback',
      milestone: ['M2'],
      async run({ page, baseUrl, session, helpers }) {
        const unthrottle = await helpers.throttleNetwork(page, {
          pattern: '**/*.{png,jpg,jpeg,webp,svg}',
          abort: true,
        });
        try {
          await openStarterLesson(page, baseUrl, helpers);
          await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
          await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

          const main = page.getByRole('main');
          const imageModeBtn = main.getByRole('button', {
            name: /Image\s*→\s*Word|Image->Word|Rasm\s*→\s*So‘z/i,
          });
          await helpers.expectVisibleFast(
            imageModeBtn,
            'T2-F6-03 (M2): Expected Image->Word flashcard mode button.',
            FAST_TIMEOUT,
          );
          await imageModeBtn.click();

          assert.equal(
            await main.getByRole('heading', { name: "What's your name?" }).count(),
            0,
            'T2-F6-03 (M2): Image->Word mode must hide written English target before Javobni ko‘rish.',
          );
          assert.equal(
            await main.locator('[data-testid^="flashcard-"]').getByText("What's your name?").count(),
            0,
            'T2-F6-03 (M2): Image->Word front must switch polarity and not display written target phrase before reveal.',
          );

          await helpers.expectVisibleFast(
            main.getByText(/Rasm yuklanmadi\. Tavsifi:|Не удалось загрузить изображение|Tasvir tavsifi:|Image description:|Alt:/i),
            'T2-F6-03 (M2): Expected visible alt/text fallback when flashcard image fails or is missing in Image->Word mode.',
            FAST_TIMEOUT,
          );

          const cardText = (await main.locator('[data-testid^="flashcard-"]').first().innerText()).trim();
          assert.ok(cardText.length > 0, 'T2-F6-03 (M2): Flashcard must render readable text/alt fallback.');

          await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
          await main.getByText("What's your name?", { exact: true }).waitFor({ state: 'visible' });
          await main.getByRole('button', { name: 'Eslab qoldim' }).waitFor({ state: 'visible' });
        } finally {
          await unthrottle();
        }
        assertCleanSession(session, 'T2-F6-03');
      },
    },
    {
      id: 'T2-F6-04',
      name: 'Rapidly tapping flashcard pronunciation audio button causes zero uncaught rejections or glitches',
      milestone: ['M1', 'M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);
        await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);

        const main = page.getByRole('main');
        const audioBtn = main.getByRole('button', { name: /Talaffuzni tinglash/i });
        for (let i = 0; i < 5; i++) {
          await audioBtn.click();
        }
        await main.getByRole('button', { name: 'Javobni ko‘rish' }).click();
        await main.getByRole('button', { name: 'Yana mashq qilaman' }).click();
        await main.getByRole('button', { name: /Talaffuzni tinglash/i }).click();
        assertCleanSession(session, 'T2-F6-04');
      },
    },
    {
      id: 'T2-F6-05',
      name: 'Empty/all-mastered SRS due queue displays friendly completion and random-practice option instead of blank screen',
      milestone: ['M2'],
      async run({ page, baseUrl, session, helpers }) {
        await openEnglishRoadmap(page, baseUrl, helpers);
        const main = page.getByRole('main');

        const srsBtn = main.getByRole('button', { name: /Flashcard|Kartochkalar|Takrorlash/i }).first();
        await helpers.expectVisibleFast(
          srsBtn,
          'T2-F6-05 (M2): Expected SRS flashcard review hub button on English roadmap.',
          FAST_TIMEOUT,
        );
        await srsBtn.click();

        for (let i = 0; i < 30; i++) {
          const revealBtn = main.getByRole('button', { name: /Javobni ko‘rish/i });
          if (!(await revealBtn.isVisible().catch(() => false))) break;
          await revealBtn.click();
          await main.getByRole('button', { name: /Eslab qoldim/i }).click();
        }

        const hubText = (await main.innerText()).trim();
        assert.ok(hubText.length > 20, 'T2-F6-05 (M2): Empty/all-mastered SRS due queue rendered a blank screen.');
        await helpers.expectVisibleFast(
          main.getByText(/Barcha kartochkalar|Bugungi takrorlash yakunlandi|Hozircha.*yo‘q|All caught up/i),
          'T2-F6-05 (M2): Expected friendly completion state when SRS due queue is empty/all-mastered.',
          FAST_TIMEOUT,
        );

        const randomBtn = main.getByRole('button', {
          name: /Tasodifiy mashq|Random|Kartochkalarni qayta ko‘rish|Barchasini takrorlash/i,
        }).first();
        await helpers.expectVisibleFast(
          randomBtn,
          'T2-F6-05 (M2): Expected random-practice/restart action when SRS due queue is empty.',
          FAST_TIMEOUT,
        );
        await randomBtn.click();
        await main.getByRole('button', { name: /Javobni ko‘rish/i }).waitFor({ state: 'visible' });
        assertCleanSession(session, 'T2-F6-05');
      },
    },

    // =========================================================================
    // F7 Boundaries (T2-F7-01 .. T2-F7-05)
    // =========================================================================
    {
      id: 'T2-F7-01',
      name: 'Empty and whitespace-only prompts in Yo‘lchi AI keep send disabled and emit zero messages',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

        await page.getByRole('button', { name: 'Yo‘lchidan so‘rash' }).click();
        const dialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
        await dialog.waitFor({ state: 'visible' });

        const sendBtn = dialog.getByRole('button', { name: 'Savolni yuborish' });
        assert.equal(await sendBtn.isDisabled(), true, 'Send button must be disabled when input is empty.');

        const textbox = dialog.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' });
        await textbox.fill('   ');
        assert.equal(await sendBtn.isDisabled(), true, 'Send button must remain disabled for whitespace.');
        await textbox.press('Enter');

        assert.equal(
          await dialog.getByRole('button', { name: 'Foydali javob' }).count(),
          0,
          'Whitespace Enter must not send a Yo‘lchi AI message.',
        );
        assertCleanSession(session, 'T2-F7-01');
      },
    },
    {
      id: 'T2-F7-02',
      name: 'Pressing Escape closes Yo‘lchi AI dialog cleanly and returns to exact lesson step',
      milestone: ['M1'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

        await helpers.openAndCloseYolchiAi(page, {
          closeWith: 'escape',
          preserveStepIndicator: /^Qadam 2 \/ 4$/,
          preserveText: 'Birga misol ko‘ramiz',
        });
        assertCleanSession(session, 'T2-F7-02');
      },
    },
    {
      id: 'T2-F7-03',
      name: 'Asking Yo‘lchi AI for direct answer mid-exercise scaffolds instead of leaking raw answer key',
      milestone: ['M1', 'M5'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceToExerciseStep(page);

        await page.getByRole('button', { name: 'Yo‘lchidan so‘rash' }).click();
        const dialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
        await dialog.waitFor({ state: 'visible' });
        await dialog.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' }).fill('To‘g‘ri javobni ayt');
        await dialog.getByRole('button', { name: 'Savolni yuborish' }).click();
        await dialog.getByRole('button', { name: 'Foydali javob' }).first().waitFor({ state: 'visible' });

        const replyText = await dialog.innerText();
        assert.equal(
          /\b(I'm Sam|My name is Sam|My name's Sam)\b/i.test(replyText),
          false,
          `T2-F7-03: Yo‘lchi AI leaked the target answer key: ${replyText}`,
        );
        await dialog.getByRole('button', { name: 'Yopish' }).click();
        await dialog.waitFor({ state: 'hidden' });
        assertCleanSession(session, 'T2-F7-03');
      },
    },
    {
      id: 'T2-F7-04',
      name: 'Very long prompt (>500 chars) in Yo‘lchi AI wraps cleanly on 390px mobile without horizontal overflow',
      milestone: ['M1'],
      contextOptions: { viewport: 'mobile390' },
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceLessonStep(page, /Birga misol ko‘ramiz/i);

        await page.getByRole('button', { name: 'Yo‘lchidan so‘rash' }).click();
        const dialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
        await dialog.waitFor({ state: 'visible' });

        const longPrompt = 'Hello! '.repeat(90).trim();
        assert.ok(longPrompt.length > 500);
        await dialog.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' }).fill(longPrompt);
        await dialog.getByRole('button', { name: 'Savolni yuborish' }).click();
        await dialog.getByRole('button', { name: 'Foydali javob' }).first().waitFor({ state: 'visible' });

        await helpers.assertNoHorizontalOverflow(page, 'T2-F7-04-mobile390-long-prompt');
        assertCleanSession(session, 'T2-F7-04');
      },
    },
    {
      id: 'T2-F7-05',
      name: 'Yo‘lchi AI network failure/timeout renders localized error and retry without erasing lesson progress',
      milestone: ['M5'],
      async run({ page, baseUrl, session, helpers }) {
        await openStarterLesson(page, baseUrl, helpers);
        await advanceToExerciseStep(page);

        const main = page.getByRole('main');
        const input = main.getByRole('textbox', { name: /Javobingizni ingliz tilida yozing/i });
        await input.fill("I'm Sam");

        const unthrottle = await helpers.throttleNetwork(page, {
          pattern: '**/functions/v1/yolchi-tutor',
          abort: true,
        });
        await page.context().setOffline(true);
        try {
          assert.equal(await page.evaluate(() => navigator.onLine), false, 'Expected navigator.onLine === false.');

          await page.getByRole('button', { name: 'Yo‘lchidan so‘rash' }).click();
          const dialog = page.getByRole('dialog', { name: 'Yo‘lchi bilan shu dars haqida' });
          await dialog.waitFor({ state: 'visible' });
          await dialog.getByRole('textbox', { name: 'Yo‘lchi AI ga savol yozing' }).fill('Salom?');
          await dialog.getByRole('button', { name: 'Savolni yuborish' }).click();

          const alertBox = dialog.getByRole('alert');
          await helpers.expectVisibleFast(
            alertBox,
            'T2-F7-05 (M5): Expected localized Yo‘lchi AI offline/network error alert when navigator.onLine is false / Edge aborted.',
            FAST_TIMEOUT,
          );
          const alertText = await alertBox.innerText();
          assert.match(
            alertText,
            /ulanish uzildi|internet|xatolik|javob olinmadi|qayta urinib/i,
            `T2-F7-05 (M5): Expected localized offline/network error message, got: "${alertText}"`,
          );
          const retryBtn = dialog.getByRole('button', { name: /Qayta urinish/i });
          await helpers.expectVisibleFast(
            retryBtn,
            'T2-F7-05 (M5): Expected retry button inside Yo‘lchi AI failure alert.',
            FAST_TIMEOUT,
          );

          await page.context().setOffline(false);
          await unthrottle();
          await retryBtn.click();
          await dialog.getByRole('button', { name: 'Foydali javob' }).first().waitFor({ state: 'visible' });
          await dialog.getByRole('button', { name: 'Yopish' }).click();
          await dialog.waitFor({ state: 'hidden' });
        } finally {
          await page.context().setOffline(false);
          await unthrottle();
        }

        await main.getByText('Qadam 4 / 4', { exact: true }).waitFor({ state: 'visible' });
        assert.equal(
          await input.inputValue(),
          "I'm Sam",
          'T2-F7-05 (M5): Yo‘lchi AI failure/retry must not erase active lesson exercise input.',
        );
        const snapshot = await helpers.readDemoProgressSnapshot(page);
        assert.ok(snapshot.sessionRaw, 'T2-F7-05 (M5): Demo progress session must remain intact after AI failure.');
        assertCleanSession(session, 'T2-F7-05');
      },
    },
  ];
}

export const getTests = registerTests;
