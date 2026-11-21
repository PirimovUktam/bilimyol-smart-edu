import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/core/widgets/app_card.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';

import 'helpers.dart';

void registerTier4Tests() {
  group('Tier 4 — Realistic End-to-End Learner Scenarios', () {
    testWidgets(
      '[M1] T4-01: absolute beginner completes A1 starter vertical slice and resumes lesson_eng_foundation_02 after restart',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.mobile390);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');

        // Step 1
        expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
        expect(findLessonStepCounter(1, 4), findsOneWidget);
        await advanceLessonStep(tester);

        // Step 2: Two-voice audio, illustration, replay & speaker transcript
        expect(find.text('English'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp('Toshkentdagi maktab oldida Aziza va Ben'),
          ),
          findsWidgets,
        );
        await tapAudioPlayPause(tester, settle: false);
        expect(find.byTooltip('Pauza'), findsOneWidget);
        await tapAudioPlayPause(tester, settle: false);
        await tapAudioReplay(tester, settle: false);
        await toggleAudioTranscript(tester);
        expect(
          findTextMatching('Aziza:', findRichText: true),
          findsOneWidget,
        );
        expect(
          findTextMatching('Ben:', findRichText: true),
          findsOneWidget,
        );
        await advanceLessonStep(tester);

        // Step 3: Flashcard re-queue + completion
        await revealFlashcard(tester);
        await markFlashcardNeedPractice(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        expect(
          find.text('Barcha kartochkalar ko‘rib chiqildi!'),
          findsOneWidget,
        );
        await advanceLessonStep(tester);

        // Step 4: Type answer -> Yo‘lchi AI non-remount -> submit
        final inputFinder = find.byKey(const Key('free_text_answer_input'));
        await tester.enterText(inputFinder, "I'm Sam");
        await tester.pump();
        await openAndCloseYolchiAi(
          tester,
          askText: 'Hello qachon ishlatiladi?',
          preserveFinder: inputFinder,
          preserveText: "I'm Sam",
        );
        await tapText(tester, 'TEKSHIRISH');
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);

        // Restart & verify restored progress unlocks lesson_eng_foundation_02
        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.mobile390,
          keepDemoSession: true,
        );
        await expectCourseProgressCount(tester, 'Ingliz tili', 1);

        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Birinchi darsni ochish');
        expect(find.text('Men, siz va oddiy gaplar'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T4-02: placement-to-module learner finishes audio placement, gets CEFR tier, and keeps mastery separate',
      (tester) async {
        final audioHarness = AudioTestHarness();
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          overrides: [audioHarness.buildOverride()],
        );
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        var sawListeningPlayer = false;
        for (var step = 1; step <= 12; step++) {
          if (find.text('Diagnostika yakunlandi').evaluate().isNotEmpty) break;
          expect(
            find.textContaining('Audio context:'),
            findsNothing,
            reason:
                'Placement listening question must render audio player without leaking script.',
          );
          if (find.byTooltip('Tinglash').evaluate().isNotEmpty ||
              find.byTooltip('Слушать').evaluate().isNotEmpty) {
            sawListeningPlayer = true;
            expect(find.text('English'), findsOneWidget);
            expect(find.text('Audio'), findsOneWidget);
            expect(
              findTextMatching(
                englishPlacementTranscriptRegex,
                findRichText: true,
              ),
              findsNothing,
            );
            await tapAudioPlayPause(tester, settle: false);
            expect(find.byTooltip('Pauza'), findsOneWidget);
            await tapAudioPlayPause(tester, settle: false);
            expect(
              audioHarness.latestController?.loadedAssets.any(
                (p) =>
                    p.startsWith('assets/lesson_media/english/placement/') &&
                    p.endsWith('.wav'),
              ),
              isTrue,
            );
          }
          await answerCurrentPlacementQuestion(
            tester,
            preferCorrect: true,
            settle: step == 8,
          );
        }

        expect(
          sawListeningPlayer,
          isTrue,
          reason:
              'Placement must include a real playable listening audio question.',
        );
        expect(find.text('Diagnostika yakunlandi'), findsOneWidget);
        expect(find.text('8 / 8 javob to‘g‘ri.'), findsOneWidget);
        expect(
          find.text('Tavsiya etilgan bosqich: B1 (100%)'),
          findsOneWidget,
          reason: 'Placement completion must display B1 (100%) recommendation.',
        );
        expect(find.textContaining('B2–C2'), findsOneWidget);

        final snapshotAfterPlacement = await readDemoProgressSnapshot();
        final profileAfterPlacement =
            snapshotAfterPlacement['profile'] as Map<String, dynamic>? ?? {};
        final scoresAfterPlacement =
            (profileAfterPlacement['scoresByCourse']
                as Map<String, dynamic>? ?? {})['course_eng_01']
                as Map<String, dynamic>? ??
            {};
        final placementCefrAfterPlacement =
            profileAfterPlacement['placementCefrByCourse']
                as Map<String, dynamic>? ??
            {};
        final placementScoreAfterPlacement =
            profileAfterPlacement['placementScoreByCourse']
                as Map<String, dynamic>? ??
            {};
        expect(placementCefrAfterPlacement['course_eng_01'], 'B1');
        expect(placementScoreAfterPlacement['course_eng_01'], 100);
        expect(
          scoresAfterPlacement,
          isEmpty,
          reason: 'Placement must not pollute independent lesson skill mastery.',
        );
        expect(
          profileAfterPlacement['completedLessonIds'] as List<dynamic>? ?? [],
          isEmpty,
        );

        await tapText(tester, 'Shaxsiy yo‘lni ko‘rish');
        expect(
          find.text('Tavsiya etilgan boshlanish • B1'),
          findsOneWidget,
        );
        await tapText(tester, 'Darsni boshlash');
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        expect(
          find.text('Travel Logistics & Experiences (Present Perfect vs Past Simple)'),
          findsWidgets,
        );

        await advanceLessonStep(tester); // Step 1 -> Step 2
        await advanceLessonStep(tester); // Step 2 -> Step 3
        for (var i = 0; i < 4; i++) {
          await revealFlashcard(tester);
          await markFlashcardRemembered(tester);
        }
        await advanceLessonStep(tester); // Step 3 -> Step 4
        await selectMcqAndSubmit(
          tester,
          '11:15 da 19-darvozadan; turar joy tasdiq xati hali kelmagan edi',
        );
        await submitFreeTextAnswer(tester, 'left'); // Step 5 -> Step 6

        final speakingField = find.byKey(const Key('self_assessed_text_input'));
        await tester.enterText(
          speakingField,
          'I have already printed my boarding pass. I checked the itinerary ten minutes ago.',
        );
        await tester.pump();
        await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
        await advanceLessonStep(tester); // Yakunlash

        final snapshotAfterLesson = await readDemoProgressSnapshot();
        final profileAfterLesson =
            snapshotAfterLesson['profile'] as Map<String, dynamic>? ?? {};
        final completedAfterLesson =
            (profileAfterLesson['completedLessonIds'] as List<dynamic>? ?? []);
        final scoresAfterLesson =
            (profileAfterLesson['scoresByCourse']
                as Map<String, dynamic>? ?? {})['course_eng_01']
                as Map<String, dynamic>? ??
            {};
        final placementScoreAfterLesson =
            profileAfterLesson['placementScoreByCourse']
                as Map<String, dynamic>? ??
            {};
        expect(completedAfterLesson, contains('lesson_eng_b1_m1_travel'));
        expect(scoresAfterLesson, isNotEmpty);
        expect(placementScoreAfterLesson['course_eng_01'], 100);

        final nextCheckpointCard = await findRoadmapNodeCard(
          tester,
          'B1 1-bo‘lim sinovi: Mehmonxona va bron',
        );
        expect(
          find.descendant(
            of: nextCheckpointCard,
            matching: findTextAny(const ['Boshlash', 'Mashq qilish']),
          ),
          findsWidgets,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T4-03: listening -> reading sequential path with mid-reading checkpoint and 390px roadmap integrity',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.mobile390);
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        // Open Listening via roadmap
        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        expect(
          find.text('Listening: Audio xabarlar va vaqt ko‘rsatkichlari'),
          findsWidgets,
        );
        await advanceLessonStep(tester);
        expect(find.text('English'), findsOneWidget);
        await toggleAudioTranscript(tester);
        expect(
          findTextMatching(
            'quarter past three in the afternoon',
            findRichText: true,
          ),
          findsOneWidget,
        );
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(tester, '15:15 (quarter past three)');

        // Back on RoadmapScreen at 390px: verify Reading unlocked & zero overflow
        await tester.scrollUntilVisible(find.text('Reading'), 150);
        verifyNoExceptions(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Reading$'));
        expect(find.text('Asosiy g‘oya va dalil'), findsWidgets);
        await advanceLessonStep(tester);
        expect(findLessonStepCounter(2, 3), findsOneWidget);

        // Leave mid-reading -> must NOT complete Reading
        await tapTooltip(tester, 'Ta’lim yo‘liga qaytish');
        final midSnapshot = await readDemoProgressSnapshot();
        final midCompleted =
            ((midSnapshot['profile']
                    as Map<String, dynamic>)['completedLessonIds']
                as List<dynamic>);
        expect(midCompleted, isNot(contains('lesson_eng_reading_01')));

        // Return -> checkpoint restored -> finish reading comprehension
        await openRoadmapNodeAction(tester, RegExp(r'^Reading$'));
        expect(
          findLessonStepCounter(2, 3),
          findsOneWidget,
          reason:
              'Mid-reading checkpoint must restore Step 2 / 3 upon returning.',
        );
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(
          tester,
          'To‘garak buyumlarni ta’mirlab, chiqindini kamaytiradi',
        );
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T4-04: struggling learner remediation + SRS Uz->En/Audio->Word cycle -> alternate checkpoint pass',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Vocabulary$'));
        expect(
          find.text(
            'Vocabulary: Xona buyumlari va joylashuv (beside, between, behind)',
          ),
          findsWidgets,
        );
        await advanceToInteractiveExerciseStep(tester);
        await selectMcqAndSubmit(tester, 'behind the sofa');
        expect(find.text('Siz tanladingiz: behind the sofa'), findsOneWidget);
        await selectMcqAndSubmit(tester, 'beside the window');

        expect(
          find.text('Takroriy xato aniqlandi'),
          findsOneWidget,
          reason:
              'Repeated errors must trigger adaptive remedial practice alongside SRS review.',
        );
        expect(find.text('Qo‘shimcha mashq'), findsOneWidget);

        // Exercise Yo‘lchi AI contextual explanation & close without remount.
        await tapText(tester, 'Yo‘lchi AI tahlili');
        expect(find.text('Yo‘lchi bilan xato tahlili'), findsOneWidget);
        await tapText(tester, 'Darsga qaytish');
        expect(findLessonStepCounter(4, 4), findsOneWidget);
        expect(find.text('Qo‘shimcha mashq'), findsOneWidget);

        await openAndCloseYolchiAi(
          tester,
          askText: 'between bilan behind farqi nima?',
          preserveFinder: find.text('Qo‘shimcha mashq'),
        );

        // Complete remedial exercise and return to roadmap.
        await tapText(tester, 'Qo‘shimcha mashq');
        await tapText(tester, 'behind');
        await tapText(tester, 'Javobni Tekshirish');
        expect(find.text('Ajoyib Natija!'), findsOneWidget);
        await tapText(tester, 'Dashboardga O‘tish');
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);

        // Drive learner through Uz -> En & Audio -> Word SRS flashcard review.
        final srsEntryFinder = findTextAny(const [
          'SRS Takrorlash',
          'Tasodifiy mashq',
          'Flashcard Takrorlash',
        ]);
        await scrollUntilFoundOrEnd(tester, srsEntryFinder);
        expect(
          srsEntryFinder,
          findsWidgets,
          reason:
              'Struggling learner must be able to enter SRS flashcard review.',
        );
        await tester.tap(srsEntryFinder.first);
        await tester.pumpAndSettle();

        final uzToEnChip = findTextAny(const ['Uz → En', 'Uz->En']);
        expect(uzToEnChip, findsOneWidget);
        await tester.tap(uzToEnChip.first);
        await tester.pumpAndSettle();
        expect(find.text('Ismingiz nima?'), findsOneWidget);
        expect(find.textContaining("What's your name?"), findsNothing);
        await revealFlashcard(tester);
        expect(find.text("What's your name?"), findsWidgets);
        await markFlashcardRemembered(tester);

        final audioModeChip = findTextAny(const [
          'Audio → Word',
          'Audio->Word',
        ]);
        expect(audioModeChip, findsOneWidget);
        await tester.tap(audioModeChip.first);
        await tester.pumpAndSettle();
        expect(find.text('Audioni tinglab so‘zni toping'), findsOneWidget);
        expect(find.byTooltip('Talaffuzni tinglash'), findsOneWidget);
        expect(find.textContaining("What's your name?"), findsNothing);
        await revealFlashcard(tester);
        expect(find.textContaining("What's your name?"), findsWidgets);
        await markFlashcardRemembered(tester);

        await tester.tap(find.byIcon(Icons.close_rounded).last);
        await tester.pumpAndSettle();
        await pumpFrames(tester, count: 5);

        final srsSnapshot = await readDemoProgressSnapshot();
        final srsProfile =
            srsSnapshot['profile'] as Map<String, dynamic>? ?? {};
        final srsByCourse =
            srsProfile['flashcardSrsByCourse'] as Map<String, dynamic>? ?? {};
        final engSrs =
            srsByCourse['course_eng_01'] as Map<String, dynamic>? ?? {};
        expect(
          engSrs.containsKey('fc_eng_starter_1'),
          isTrue,
          reason:
              'SRS review must persist fc_eng_starter_1 under flashcardSrsByCourse["course_eng_01"].',
        );
        expect(
          (engSrs['fc_eng_starter_1'] as Map<String, dynamic>)['status'],
          'remembered',
        );

        // Fail Unit 1 checkpoint once -> verify remedial/alternate option -> pass alternate & checkpoint -> verify next unit unlock.
        await openRoadmapNodeAction(
          tester,
          RegExp(r'^Modul yakuni: 1-bo‘lim sinovi$'),
        );
        await advanceToInteractiveExerciseStep(tester);
        await selectMcqAndSubmit(tester, 'Good night, Miss Nilufar. Goodbye.');
        expect(
          find.text('Siz tanladingiz: Good night, Miss Nilufar. Goodbye.'),
          findsOneWidget,
        );
        expect(find.text('Qayta mashq'), findsOneWidget);
        expect(find.text('Mavzuni mustahkamlash'), findsOneWidget);
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);

        final midCpSnapshot = await readDemoProgressSnapshot();
        final midCpProfile =
            midCpSnapshot['profile'] as Map<String, dynamic>? ?? {};
        final midCpCompleted =
            midCpProfile['completedLessonIds'] as List<dynamic>? ?? const [];
        expect(
          midCpCompleted,
          isNot(contains('lesson_eng_a1_u1_checkpoint')),
          reason:
              'Failing Unit 1 checkpoint must NOT mark lesson_eng_a1_u1_checkpoint completed.',
        );

        await tapText(tester, 'Qayta mashq');
        expect(
          find.textContaining('Murabbiy Rustam Layloning tanishuviga'),
          findsOneWidget,
        );
        await tapText(tester, 'Nice to meet you, Laylo!');
        await tapText(tester, 'Javobni Tekshirish');
        expect(find.text('Ajoyib Natija!'), findsOneWidget);
        await tapText(tester, 'Dashboardga O‘tish');
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);

        await openRoadmapNodeAction(
          tester,
          RegExp(r'^Modul yakuni: 1-bo‘lim sinovi$'),
        );
        await advanceToInteractiveExerciseStep(tester);
        await selectMcqAndSubmit(
          tester,
          'Good afternoon, Miss Nilufar. My name is Anvar.',
        );
        final finishBtn = findTextAny(const ['Yakunlash', 'Завершить']);
        if (finishBtn.evaluate().isNotEmpty) {
          await advanceLessonStep(tester);
        }

        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
        final postCpSnapshot = await readDemoProgressSnapshot();
        final postCpProfile =
            postCpSnapshot['profile'] as Map<String, dynamic>? ?? {};
        final postCpCompleted =
            postCpProfile['completedLessonIds'] as List<dynamic>? ?? const [];
        expect(
          postCpCompleted,
          contains('lesson_eng_a1_u1_checkpoint'),
          reason:
              'Passing Unit 1 checkpoint must persist lesson_eng_a1_u1_checkpoint in completedLessonIds.',
        );

        final nextUnitCard = await findRoadmapNodeCard(
          tester,
          'Present Simple: Bo‘sh joyni to‘ldirish',
        );
        expect(
          find.descendant(
            of: nextUnitCard,
            matching: findTextAny(const ['Boshlash', 'Mashq qilish']),
          ),
          findsOneWidget,
          reason:
              'Passing Unit 1 checkpoint must unlock node_eng_a1_m2_daily_life (Present Simple: Bo‘sh joyni to‘ldirish) on /roadmap.',
        );

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );
        final restartSnapshot = await readDemoProgressSnapshot();
        final restartProfile =
            restartSnapshot['profile'] as Map<String, dynamic>? ?? {};
        final restartSrs =
            (restartProfile['flashcardSrsByCourse'] as Map<String, dynamic>? ??
                    {})['course_eng_01']
                as Map<String, dynamic>? ??
            {};
        expect(restartSrs.containsKey('fc_eng_starter_1'), isTrue);
        expect(
          restartProfile['completedLessonIds'] as List<dynamic>? ?? const [],
          contains('lesson_eng_a1_u1_checkpoint'),
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M3] T4-05: B1 intermediate productive task journey (listening/reading, speaking & writing self_assessed rubrics, B1 exit assessment, and B2-C2 DEFERRED)',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPlacementToB1(tester);

        expect(find.text('CEFR A1–B1 marshruti'), findsOneWidget);
        expect(
          find.text('Tavsiya etilgan boshlanish • B1'),
          findsOneWidget,
        );
        await expectDeferredCefrLevelsRendered(tester);

        // 1. B1 Module 1: Listening + speaking_prompt (self_assessed)
        await openRoadmapNodeAction(
          tester,
          'Sayohat logistikasi: Present Perfect vs Past Simple',
        );
        await advanceLessonStep(tester); // concept -> audio
        expect(find.text('English'), findsOneWidget);
        await toggleAudioTranscript(tester);
        expect(
          findTextMatching('Gate nineteen', findRichText: true),
          findsWidgets,
        );
        await advanceLessonStep(tester); // audio -> flashcards
        for (var i = 0; i < 4; i++) {
          await revealFlashcard(tester);
          await markFlashcardRemembered(tester);
        }
        await advanceLessonStep(tester); // flashcards -> MCQ
        await selectMcqAndSubmit(
          tester,
          '11:15 da 19-darvozadan; turar joy tasdiq xati hali kelmagan edi',
        );
        await submitFreeTextAnswer(tester, 'left'); // fill_blank -> speaking

        // Empty self_assessed submission must stay disabled.
        final submitSpeakingBtn = find.ancestor(
          of: findTextAny(const ['TEKSHIRISH', 'Проверить']).first,
          matching: find.byType(ElevatedButton),
        );
        if (submitSpeakingBtn.evaluate().isNotEmpty) {
          expect(
            tester.widget<ElevatedButton>(submitSpeakingBtn.first).onPressed,
            isNull,
          );
        }
        final speakingField = find.byKey(const Key('self_assessed_text_input'));
        await tester.enterText(
          speakingField,
          'I have already printed my boarding pass, and I checked the itinerary ten minutes ago. My hotel confirmation has not arrived yet.',
        );
        await tester.pump();
        await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
        expect(find.text('Namuna javob:'), findsOneWidget);
        expect(find.text('O‘zini tekshirish mezoni:'), findsOneWidget);
        expect(
          find.textContaining('O‘zini baholash (mustaqil nutq mashqi)'),
          findsOneWidget,
        );
        expect(find.textContaining('Official CEFR Certificate'), findsNothing);
        final rubricChecks = find.byType(CheckboxListTile);
        if (rubricChecks.evaluate().isNotEmpty) {
          await tester.ensureVisible(rubricChecks.first);
          await tester.tap(rubricChecks.first);
          await tester.pumpAndSettle();
        }
        await advanceLessonStep(tester); // Yakunlash

        // 2. B1 Unit 1 Checkpoint
        await openRoadmapNodeAction(
          tester,
          'B1 1-bo‘lim sinovi: Mehmonxona va bron',
        );
        await advanceLessonStep(tester); // concept -> audio
        await advanceLessonStep(tester); // audio -> conversationCompletion
        await selectMcqAndSubmit(
          tester,
          'I have updated your booking to Room 412 on the quiet courtyard side.',
        );

        // 3. B1 Module 2: Work & Study (First Conditional)
        await openRoadmapNodeAction(
          tester,
          'Ish, o‘qish va muammolar: First Conditional',
        );
        await advanceLessonStep(tester); // concept -> audio
        await advanceLessonStep(tester); // audio -> flashcards
        for (var i = 0; i < 4; i++) {
          await revealFlashcard(tester);
          await markFlashcardRemembered(tester);
        }
        await advanceLessonStep(tester); // flashcards -> MCQ
        await selectMcqAndSubmit(
          tester,
          'Server texnik xizmati portalni to‘xtatdi; PDF ni pochta orqali yuborib, jonli taqdimotni payshanbaga ko‘chirishadi',
        );
        await submitFreeTextAnswer(tester, "doesn't work");

        // 4. B1 Unit 2 Checkpoint (Reading)
        await openRoadmapNodeAction(
          tester,
          'B1 2-bo‘lim sinovi: IT bildirishnomasi',
        );
        await advanceLessonStep(tester); // concept -> reading MCQ
        await selectMcqAndSubmit(
          tester,
          'Soat 17:00 gacha; o‘quv materiallarini 13:00 dan oldin yuklab olish kerak',
        );

        // 5. B1 Module 3: Narrative (word_match + writing_prompt self_assessed)
        await openRoadmapNodeAction(
          tester,
          'Writing: Izchil hikoya va nisbiy gaplar',
        );
        await advanceLessonStep(tester); // concept -> audio
        await advanceLessonStep(tester); // audio -> flashcards
        for (var i = 0; i < 4; i++) {
          await revealFlashcard(tester);
          await markFlashcardRemembered(tester);
        }
        await advanceLessonStep(tester); // flashcards -> MCQ
        await selectMcqAndSubmit(
          tester,
          'Ustaxonada sensor prototipini sinovdan o‘tkazayotgan edi; qo‘shni stoldagi talaba ko‘chma batareya berib turdi',
        );
        for (final pair in const [
          ('meanwhile', 'shu paytda (ayni vaqtda)'),
          ('eventually', 'oxir-oqibat'),
          ('where', 'qaysi joyda (joy bog‘lovchisi)'),
          ('who', 'kimki (shaxs bog‘lovchisi)'),
        ]) {
          await tapText(tester, pair.$1);
          final rightChip = find.descendant(
            of: find.byType(ActionChip),
            matching: find.text(pair.$2),
          );
          await tester.ensureVisible(rightChip.first);
          await tester.tap(rightChip.first);
          await tester.pumpAndSettle();
        }
        await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);

        expect(find.text('Yozma ish'), findsOneWidget);
        expect(find.text('O‘z-o‘zini baholash'), findsOneWidget);
        final writingField = find.byKey(const Key('self_assessed_text_input'));
        await tester.enterText(
          writingField,
          'Last month, I was preparing my slides in the library where our team meets. Suddenly, the screen froze, and a colleague who sat nearby helped me recover the draft. Eventually, we submitted on time.',
        );
        await tester.pump();
        await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
        expect(find.text('Namuna javob:'), findsOneWidget);
        expect(find.text('O‘zini tekshirish mezoni:'), findsOneWidget);
        expect(find.textContaining('Official CEFR Certificate'), findsNothing);
        await advanceLessonStep(tester); // Yakunlash

        // 6. B1 Unit 3 Checkpoint (Reading)
        await openRoadmapNodeAction(
          tester,
          'B1 3-bo‘lim sinovi: Hikoya va nisbiy olmosh',
        );
        await advanceLessonStep(tester); // concept -> reading MCQ
        await selectMcqAndSubmit(
          tester,
          'Skanerlash paytida planshet qotib qoldi; hamkasbi bosma mehmonlar ro‘yxatini olib keldi',
        );

        // 7. B1 Module 4: Decisions (writing_prompt self_assessed)
        await openRoadmapNodeAction(
          tester,
          'Writing: Muhokama, tavsiya va o‘zlashtirma gap',
        );
        await advanceLessonStep(tester); // concept -> audio
        await advanceLessonStep(tester); // audio -> flashcards
        for (var i = 0; i < 4; i++) {
          await revealFlashcard(tester);
          await markFlashcardRemembered(tester);
        }
        await advanceLessonStep(tester); // flashcards -> conversationCompletion
        await selectMcqAndSubmit(
          tester,
          'No, sign-in access is our top priority, so you must fix the timeout bug before Friday.',
        );
        final m4Field = find.byKey(const Key('self_assessed_text_input'));
        await tester.enterText(
          m4Field,
          'Aziz told us that testers could not finish sign-in. Fixing that bug is our priority before Friday. We ought to postpone design changes and should retest on Saturday.',
        );
        await tester.pump();
        await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
        await advanceLessonStep(tester); // Yakunlash

        // 8. B1 Exit Assessment (lesson_eng_b1_exit)
        await openRoadmapNodeAction(
          tester,
          'B1 Bosqich sinovi: Yakuniy imtihon',
        );
        await advanceLessonStep(tester); // Step 1 audio -> Step 2 listen MCQ
        await selectMcqAndSubmit(
          tester,
          'Proyektor kabeli uzildi; slayd havolasini ulashib, savol-javobni 15 daqiqa ertaroq boshlashadi',
        );
        await selectMcqAndSubmit(
          tester,
          'Inshoni qayta yuklamaydi, lekin dushanba tongidan oldin qabul bo‘limi bilan bog‘lanishi kerak',
        );
        await submitFreeTextAnswer(
          tester,
          'I have already downloaded my e-ticket',
        );
        for (final token in const [
          'The mentor',
          'said that',
          'we ought',
          'to test',
          'our backup',
          'plan today.',
        ]) {
          final tokenChip = find.descendant(
            of: find.byType(ActionChip),
            matching: find.text(token),
          );
          await tester.ensureVisible(tokenChip.first);
          await tester.tap(tokenChip.first);
          await tester.pumpAndSettle();
        }
        await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
        expect(find.textContaining('Official CEFR Certificate'), findsNothing);

        // Post-B1-exit guard: B2-C2 must still be upcoming/DEFERRED.
        await expectDeferredCefrLevelsRendered(tester);

        // Restart persistence check with zero b2/c1/c2 IDs.
        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );
        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final completed =
            (profile['completedLessonIds'] as List<dynamic>? ?? []);
        final scores =
            (profile['scoresByCourse'] as Map<String, dynamic>? ?? {})[
                'course_eng_01'] as Map<String, dynamic>? ??
            {};
        expect(completed, contains('lesson_eng_b1_m1_travel'));
        expect(completed, contains('lesson_eng_b1_m3_narrative'));
        expect(completed, contains('lesson_eng_b1_exit'));
        expect(
          completed.where(
            (id) => RegExp(r'_(b2|c1|c2)_').hasMatch(id.toString()),
          ),
          isEmpty,
        );
        expect(scores, isNotEmpty);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T4-06: bilingual multi-course power user (ru locale + dark mode + 390px + eng & math isolation)',
      (tester) async {
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.mobile390,
          brightness: Brightness.dark,
          locale: AppLocalePreset.ru,
        );
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapTextAny(tester, const ['Noldan boshlayman', 'Начать с нуля']);
        await tapTextAny(
          tester,
          const ['Birinchi darsni boshlash', 'Начать первый урок'],
        );

        final lessonElement = tester.element(
          find.byType(InteractiveLessonScreen),
        );
        expect(
          Theme.of(lessonElement).brightness,
          Brightness.dark,
          reason: 'Dark theme must be active in bilingual 390px power-user flow.',
        );

        await advanceLessonStep(tester);
        expect(find.text('English'), findsOneWidget);
        expect(
          find.text('Текст'),
          findsOneWidget,
          reason: 'Russian locale must localize media transcript toggle to Текст.',
        );

        await advanceLessonStep(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await advanceLessonStep(tester);
        await submitFreeTextAnswer(tester, "I'm Sam");

        await selectCourse(tester, 'course_math_01');
        await tapTextAny(tester, const ['Noldan boshlayman', 'Начать с нуля']);
        await tapTextAny(
          tester,
          const ['Birinchi darsni boshlash', 'Начать первый урок'],
        );
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(tester, '6');

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.mobile390,
          brightness: Brightness.dark,
          locale: AppLocalePreset.ru,
          keepDemoSession: true,
        );

        final engCard = find.ancestor(
          of: findTextAny(const ['Ingliz tili', 'Английский язык', 'Английский']).first,
          matching: find.byType(AppCard),
        );
        expect(
          find.descendant(
            of: engCard.first,
            matching: find.textContaining(RegExp(r'^1 / \d+')),
          ),
          findsOneWidget,
        );
        final mathCard = find.ancestor(
          of: findTextAny(const ['Matematika', 'Математика']).first,
          matching: find.byType(AppCard),
        );
        expect(
          find.descendant(
            of: mathCard.first,
            matching: find.textContaining(RegExp(r'^1 / \d+')),
          ),
          findsOneWidget,
        );

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final completed =
            (profile['completedLessonIds'] as List<dynamic>? ?? []);
        final scores =
            profile['scoresByCourse'] as Map<String, dynamic>? ?? {};
        expect(completed, contains('lesson_eng_starter'));
        expect(completed, contains('lesson_math_starter'));
        expect(scores['course_eng_01'], isNotNull);
        expect(scores['course_math_01'], isNotNull);
        expect(scores['course_it'], isNull);
        expect(scores['course_logic'], isNull);
        verifyNoExceptions(tester);
      },
    );
  });
}
