import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/core/widgets/app_card.dart';
import 'package:bilimyol_mobile/features/ai_tutor/ai_tutor_screen.dart';
import 'package:bilimyol_mobile/features/lesson/flashcard_deck_widget.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/lesson/lesson_media_widget.dart';
import 'package:bilimyol_mobile/features/reinforcement/reinforcement_sheet.dart';

import 'helpers.dart';

void registerTier1Tests() {
  group('Tier 1 — Feature Coverage (F1–F7)', () {
    // -------------------------------------------------------------------------
    // F1: Course Selection & Isolation
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T1-F1-01: selecting course_eng_01 confirms Ingliz tili identity across onboarding, lesson, and profile',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');

        expect(find.text('Ingliz tili'), findsWidgets);
        expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);
        expect(find.text('Matematika'), findsNothing);
        expect(find.text('IT & Kodlash'), findsNothing);
        expect(find.text('Mantiq'), findsNothing);

        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);

        await tapTooltip(tester, 'Ta’lim yo‘liga qaytish');
        await tapText(tester, 'Profil', scroll: false);
        expect(find.text('Ingliz tili'), findsWidgets);
        expect(find.text('Joriy fan'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F1-02: English roadmap displays English skills and zero Math nodes',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        for (final engSkill in const [
          'Vocabulary',
          'Grammar',
          'Listening',
          'Reading',
        ]) {
          await tester.scrollUntilVisible(find.text(engSkill), 150);
          expect(find.text(engSkill), findsWidgets);
        }

        for (final mathSkill in const [
          'Algebra asoslari',
          'Tenglamalar',
          'Funksiyalar',
          'Grafiklar',
        ]) {
          expect(find.text(mathSkill), findsNothing);
        }
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F1-03: completing English starter does not mutate course_math_01 progress or mastery',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester);

        await tapText(tester, 'Profil', scroll: false);
        await tapText(tester, 'Fanni o‘zgartirish');

        await expectCourseProgressCount(tester, 'Ingliz tili', 1);
        await expectCourseProgressCount(tester, 'Matematika', 0);

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final scoresByCourse =
            profile['scoresByCourse'] as Map<String, dynamic>? ?? {};
        expect(scoresByCourse['course_math_01'], isNull);

        await selectCourse(tester, 'course_math_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ta’lim yo‘lini ochish');

        expect(find.text('Bajarildi (100%)'), findsNothing);
        await tapTooltip(tester, 'Bilim Xaritasi');
        expect(find.text('0%'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F1-04: switching back from course_math_01 preserves course_eng_01 state and starter progression',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester);

        await selectCourse(tester, 'course_math_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ta’lim yo‘lini ochish');

        await tapText(tester, 'Profil', scroll: false);
        await tapText(tester, 'Fanni o‘zgartirish');

        expect(find.text('Tanlangan'), findsWidgets);
        expect(find.text('Davom etish'), findsWidgets);
        await expectCourseProgressCount(tester, 'Ingliz tili', 1);

        await selectCourse(tester, 'course_eng_01');
        expect(find.text('Birinchi darsni ochish'), findsOneWidget);

        await tapText(tester, 'Birinchi darsni ochish');
        expect(find.text('Men, siz va oddiy gaplar'), findsWidgets);

        await tapTooltip(tester, 'Ta’lim yo‘liga qaytish');
        await tapTooltip(tester, 'Bilim Xaritasi');
        expect(find.text('Vocabulary'), findsWidgets);
        expect(find.text('100%'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F1-05: English lesson media with language en loads inside course_eng_01 without math-only gating',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);

        expect(find.byType(LessonMediaWidget), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.text('Aziza va Ben tanishuv dialogi'), findsOneWidget);
        expect(find.byTooltip('Tinglash'), findsOneWidget);
        expect(find.byTooltip('Qayta tinglash'), findsOneWidget);
        expect(find.text('Matnli bayon'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F2: Placement Test
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T1-F2-01: course_eng_01 placement renders first diagnostic question for Ingliz tili',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        expect(find.text('Diagnostika · Ingliz tili'), findsOneWidget);
        expect(find.text('Savol 1 / 8'), findsOneWidget);
        expect(find.text('Q1'), findsOneWidget);
        expect(find.text('A1'), findsOneWidget);
        for (final letter in const ['A', 'B', 'C', 'D']) {
          expect(find.text(letter), findsOneWidget);
        }
        expect(find.text('Keyingi Savol'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T1-F2-02: completing English placement advances step counter and finishes with CEFR level recommendation',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        for (var step = 1; step <= 8; step++) {
          expect(find.text('Savol $step / 8'), findsOneWidget);
          await answerCurrentPlacementQuestion(tester, preferCorrect: true);
        }

        expect(find.text('Diagnostika yakunlandi'), findsOneWidget);
        expect(
          find.textContaining(
            RegExp(
              r'(Tavsiya etilgan bosqich|Стартовый уровень): (Pre-A1|A1|A2|B1)\b',
            ),
          ),
          findsOneWidget,
          reason:
              'English placement completion screen must display a CEFR level recommendation.',
        );
        expect(find.textContaining('DEFERRED'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T1-F2-03: English listening placement renders audio player instead of leaking Audio context script',
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
        for (var step = 1; step <= 8; step++) {
          expect(
            find.textContaining('Audio context:'),
            findsNothing,
            reason:
                'Listening placement questions must use playable audio media rather than leaking "Audio context:" text.',
          );
          if (find.byType(LessonMediaWidget).evaluate().isNotEmpty) {
            sawListeningPlayer = true;
            expect(find.text('English'), findsOneWidget);
            expect(find.text('Audio'), findsOneWidget);
            expect(find.byTooltip('Tinglash'), findsOneWidget);
            expect(find.byTooltip('Qayta tinglash'), findsOneWidget);
            expect(find.text('Matnli bayon'), findsOneWidget);
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
              'At least one listening placement question must render a playable audio control.',
        );
        final loadedPlacementWavs = audioHarness.controllers
            .expand((c) => c.loadedAssets)
            .where(
              (p) =>
                  p.startsWith('assets/lesson_media/english/placement/') &&
                  p.endsWith('.wav'),
            )
            .toSet();
        expect(loadedPlacementWavs.length, greaterThanOrEqualTo(2));
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T1-F2-04: high-accuracy placement assigns A2/B1 CEFR tier while keeping independent lesson mastery at 0%',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        for (var step = 1; step <= 8; step++) {
          await answerCurrentPlacementQuestion(tester, preferCorrect: true);
        }

        expect(find.text('Diagnostika yakunlandi'), findsOneWidget);
        expect(
          find.textContaining(
            RegExp(
              r'(Tavsiya etilgan bosqich|Стартовый уровень): (A2|B1)\b',
            ),
          ),
          findsOneWidget,
          reason: 'High-accuracy placement must recommend A2/B1 CEFR tier.',
        );
        expect(find.textContaining('B2–C2'), findsOneWidget);

        await tapText(tester, 'Shaxsiy yo‘lni ko‘rish');
        expect(
          find.text('Tavsiya etilgan boshlanish • B1'),
          findsOneWidget,
        );
        await tapText(tester, 'Natijalar', scroll: false);
        expect(find.text('Mening natijalarim'), findsOneWidget);

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final completedLessons =
            (profile['completedLessonIds'] as List<dynamic>? ?? []);
        final scoresByCourse =
            profile['scoresByCourse'] as Map<String, dynamic>? ?? {};
        final engScores =
            scoresByCourse['course_eng_01'] as Map<String, dynamic>? ?? {};
        final placementCefr =
            profile['placementCefrByCourse'] as Map<String, dynamic>? ?? {};
        final placementScores =
            profile['placementScoreByCourse'] as Map<String, dynamic>? ?? {};

        expect(placementCefr['course_eng_01'], 'B1');
        expect(placementScores['course_eng_01'], 100);
        expect(completedLessons, isEmpty);
        expect(
          engScores,
          isEmpty,
          reason:
              'Placement scores must be stored separately from independent lesson/module skill mastery.',
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T1-F2-05: beginner misses during placement route learner to Pre-A1/A1 without B1/hard escalation',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        for (var step = 1; step <= 8; step++) {
          expect(
            find.text('B1'),
            findsNothing,
            reason:
                'Adaptive placement must not escalate to B1 items after beginner misses.',
          );
          expect(find.text('Qiyin'), findsNothing);
          expect(find.textContaining('traffic jams'), findsNothing);
          expect(find.textContaining('Samarkand'), findsNothing);
          expect(find.textContaining('morning session'), findsNothing);
          expect(find.textContaining('City Bike Pass'), findsNothing);
          await answerCurrentPlacementQuestion(tester, preferCorrect: false);
        }

        expect(
          find.textContaining(
            RegExp(
              r'(Tavsiya etilgan bosqich|Стартовый уровень): (Pre-A1|A1)\b',
            ),
          ),
          findsOneWidget,
          reason: 'Zero-accuracy placement must place learner at Pre-A1/A1.',
        );

        await tapText(tester, 'Shaxsiy yo‘lni ko‘rish');
        expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F3: Starter Lesson (lesson_eng_starter)
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T1-F3-01: lesson_eng_starter renders Aziza & Ben two-voice audio player, replay, and speaker transcript',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);

        expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Aziza va Ben tanishuv dialogi'), findsOneWidget);
        expect(find.text('0:05'), findsOneWidget);

        await tapAudioPlayPause(tester, settle: false);
        expect(find.byTooltip('Pauza'), findsOneWidget);

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
        expect(
          findTextMatching('Nice to meet you', findRichText: true),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F3-02: lesson_eng_starter renders Tashkent school greeting illustration with semantic alt text',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);

        expect(find.byType(Image), findsOneWidget);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
        expect(
          find.bySemanticsLabel(
            RegExp('Toshkentdagi maktab oldida Aziza va Ben'),
          ),
          findsWidgets,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F3-03: starter flashcard reveals Uzbek meaning, IPA, audio, and example on Javobni ko‘rish',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        expect(find.byType(FlashcardDeckWidget), findsOneWidget);
        expect(find.text("What's your name?"), findsOneWidget);
        expect(find.textContaining('Ismingiz nima?'), findsNothing);

        await tapTooltip(tester, 'Talaffuzni tinglash', settle: false);
        await revealFlashcard(tester);

        expect(find.textContaining('Ismingiz nima?'), findsWidgets);
        expect(find.text('/wɒts jɔːr neɪm/'), findsOneWidget);
        expect(find.text("Hi, I'm Aziza. What's your name?"), findsOneWidget);
        expect(find.text('Yana mashq qilaman'), findsOneWidget);
        expect(find.text('Eslab qoldim'), findsOneWidget);

        await markFlashcardRemembered(tester);
        expect(find.text('Nice to meet you.'), findsOneWidget);
        expect(find.text('Flashcard • 1/2'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F3-04: starter free-text exercise accepts both "I\'m Sam" and "My name is Sam"',
      (tester) async {
        // Part A: "I'm Sam"
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester, answer: "I'm Sam");
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);

        // Part B: "My name is Sam" in fresh isolated session
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester, answer: 'My name is Sam');
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F3-05: completing lesson_eng_starter persists across simulateAppRestart and unlocks lesson_eng_foundation_02',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester, answer: "I'm Sam");

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final completed =
            (profile['completedLessonIds'] as List<dynamic>? ?? []);
        expect(completed, contains('lesson_eng_starter'));

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );

        await expectCourseProgressCount(tester, 'Ingliz tili', 1);
        expect(find.text('Davom etish'), findsWidgets);

        await selectCourse(tester, 'course_eng_01');
        expect(find.text('Birinchi darsni ochish'), findsOneWidget);
        await tapText(tester, 'Birinchi darsni ochish');
        expect(find.text('Men, siz va oddiy gaplar'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F4: Reading & Listening
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T1-F4-01: unlocked node_eng_read on RoadmapScreen opens lesson_eng_reading_01 cleanly',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        // Complete Listening via roadmap so Reading unlocks.
        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        expect(
          find.text('Listening: Audio xabarlar va vaqt ko‘rsatkichlari'),
          findsWidgets,
        );
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(tester, '15:15 (quarter past three)');

        // Back on RoadmapScreen: Reading node must expose an interactive action button.
        await tester.scrollUntilVisible(find.text('Reading'), 150);
        expect(find.text('Reading'), findsOneWidget);

        final readingCard = find.ancestor(
          of: find.text('Reading'),
          matching: find.byType(AppCard),
        );
        final startInReading = find.descendant(
          of: readingCard.first,
          matching: findTextAny(const ['Boshlash', 'Mashq qilish']),
        );
        expect(
          startInReading,
          findsOneWidget,
          reason:
              'Unlocked node_eng_read must expose an action button on RoadmapScreen even when skill_eng_reading score is 0.',
        );
        await tester.tap(startInReading.first);
        await tester.pumpAndSettle();
        expect(find.text('Asosiy g‘oya va dalil'), findsWidgets);
      },
    );

    testWidgets(
      '[M1] T1-F4-02: completing lesson_eng_reading_01 marks Reading completed and updates progress',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(tester, '15:15 (quarter past three)');

        await openRoadmapNodeAction(tester, RegExp(r'^Reading$'));
        expect(find.text('Asosiy g‘oya va dalil'), findsWidgets);

        await advanceLessonStep(tester); // Step 1 -> Step 2
        await advanceLessonStep(tester); // Step 2 -> Step 3
        expect(
          find.textContaining('The school opened a repair club.'),
          findsOneWidget,
        );
        await selectMcqAndSubmit(
          tester,
          'To‘garak buyumlarni ta’mirlab, chiqindini kamaytiradi',
        );

        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        final snapshot = await readDemoProgressSnapshot();
        final completed =
            ((snapshot['profile'] as Map<String, dynamic>)['completedLessonIds']
                as List<dynamic>);
        expect(completed, contains('lesson_eng_reading_01'));
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F4-03: lesson_eng_listening_01 hides transcript initially and reveals quarter past three in the afternoon on toggle',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        expect(
          find.text('Listening: Audio xabarlar va vaqt ko‘rsatkichlari'),
          findsWidgets,
        );
        await advanceLessonStep(tester); // Step 2

        expect(find.text('English'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.text('0:05'), findsOneWidget);
        expect(find.byTooltip('Tinglash'), findsOneWidget);
        expect(find.text('Matnli bayon'), findsOneWidget);
        expect(
          findTextMatching(
            'quarter past three in the afternoon',
            findRichText: true,
          ),
          findsNothing,
        );

        await toggleAudioTranscript(tester);
        expect(
          findTextMatching(
            'quarter past three in the afternoon',
            findRichText: true,
          ),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F4-04: lesson_eng_listening_01 afternoon disambiguation (15:15) and reinforcement (16:30) complete lesson',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        await advanceLessonStep(tester);
        await advanceLessonStep(tester); // Step 3

        await selectMcqAndSubmit(tester, '15:30 (half past three)');
        expect(find.textContaining('in the afternoon'), findsWidgets);
        expect(find.textContaining('15:15'), findsWidgets);

        await tapText(tester, 'Mavzuni mustahkamlash');
        expect(find.textContaining('Half past four'), findsOneWidget);
        await tapText(tester, '16:30');
        await tapText(tester, 'Javobni Tekshirish');
        expect(find.text('Ajoyib Natija!'), findsOneWidget);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await selectMcqAndSubmit(tester, '15:15 (quarter past three)');
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F4-05: reading checkpoint restores step across simulateAppRestart without marking lesson complete',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(tester, '15:15 (quarter past three)');

        await openRoadmapNodeAction(tester, RegExp(r'^Reading$'));
        expect(findLessonStepCounter(1, 3), findsOneWidget);
        await advanceLessonStep(tester); // Step 2 (Ishlangan misol)
        expect(findLessonStepCounter(2, 3), findsOneWidget);

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );
        await selectCourse(tester, 'course_eng_01');
        if (findTextAny(const ['Ta’lim yo‘li', 'Учебный путь', 'Маршрут'])
            .evaluate()
            .isNotEmpty) {
          await tapTextAny(
            tester,
            const ['Ta’lim yo‘li', 'Учебный путь', 'Маршрут'],
            scroll: false,
          );
        } else if (findTextAny(const ['Asoslarini bilaman', 'Знаю основы'])
            .evaluate()
            .isNotEmpty) {
          await tapTextAny(tester, const ['Asoslarini bilaman', 'Знаю основы']);
          await tapTextAny(
            tester,
            const ['Ta’lim yo‘lini ochish', 'Открыть маршрут обучения'],
          );
        }
        await openRoadmapNodeAction(tester, RegExp(r'^Reading$'));

        expect(
          findLessonStepCounter(2, 3),
          findsOneWidget,
          reason:
              'Mid-reading checkpoint must restore step 2 / 3 across restart without marking lesson_eng_reading_01 completed.',
        );
        final snapshot = await readDemoProgressSnapshot();
        final completed =
            ((snapshot['profile'] as Map<String, dynamic>)['completedLessonIds']
                as List<dynamic>);
        expect(completed, isNot(contains('lesson_eng_reading_01')));
      },
    );

    // -------------------------------------------------------------------------
    // F5: CEFR Progression (A1 -> B1 + B2..C2 DEFERRED), Checkpoints & Rubrics
    // -------------------------------------------------------------------------
    testWidgets(
      '[M5] T1-F5-01: English roadmap displays grouped A1..B1 CEFR hierarchy, B2..C2 upcoming/DEFERRED, and distinct lesson_eng_foundation_02',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester);

        // Open lesson_eng_foundation_02 and verify main quiz & reinforcement are distinct.
        await openNextLessonViaDashboard(tester);
        expect(find.text('Men, siz va oddiy gaplar'), findsWidgets);
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        expect(find.textContaining('I ___ a student.'), findsOneWidget);
        await selectMcqAndSubmit(tester, 'is');
        await tapText(tester, 'Mavzuni mustahkamlash');
        final sheet = find.byType(ReinforcementSheet);
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(
            of: sheet,
            matching: find.textContaining('She ___ a teacher.'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.textContaining('I ___ a student.'),
          ),
          findsNothing,
        );
        final sheetOptionIs = find.descendant(
          of: sheet,
          matching: find.text('is'),
        );
        await tester.ensureVisible(sheetOptionIs.first);
        await tester.tap(sheetOptionIs.first);
        await tester.pumpAndSettle();
        await tapText(tester, 'Javobni Tekshirish');
        expect(find.text('Ajoyib Natija!'), findsOneWidget);
        await tapText(tester, 'Dashboardga O‘tish');
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);

        expect(find.text('CEFR A1–B1 marshruti'), findsOneWidget);
        for (final entry in const [
          (
            'A1',
            'A1 — Elementar daraja',
            'Tanishuv, salomlashish va ilk muloqot',
            'O‘zini tanishtiradi, kun vaqtiga qarab salomlashadi va qisqa suhbat boshlaydi.',
          ),
          (
            'A2',
            'A2 — Boshlang‘ichdan yuqori daraja',
            'Transport va yo‘l so‘rash',
            'Shahar xaritasida manzilni tushuntiradi va burilish yo‘nalishlarini ajratadi.',
          ),
          (
            'B1',
            'B1 — O‘rta daraja',
            'Sayohat va kundalik tajribalar',
            'Safar taassurotlari va tajribani Present Perfect yordamida bayon qiladi.',
          ),
        ]) {
          final levelTitleFinder = find.text(entry.$2);
          await scrollUntilFoundOrEnd(tester, levelTitleFinder, maxScrolls: 60);
          expect(
            levelTitleFinder,
            findsOneWidget,
            reason:
                'English roadmap must display active CEFR level "${entry.$1}" group.',
          );
          expect(find.text(entry.$1), findsWidgets);

          final moduleTitleFinder = find.text(entry.$3);
          await scrollUntilFoundOrEnd(tester, moduleTitleFinder, maxScrolls: 60);
          expect(
            moduleTitleFinder,
            findsWidgets,
            reason:
                'Grouped roadmap must display active ${entry.$1} module header "${entry.$3}".',
          );

          final canDoFinder = find.text(entry.$4);
          await scrollUntilFoundOrEnd(tester, canDoFinder, maxScrolls: 60);
          expect(
            canDoFinder,
            findsOneWidget,
            reason:
                'Grouped roadmap must display active ${entry.$1} can-do objective "${entry.$4}".',
          );
        }

        await expectDeferredCefrLevelsRendered(tester);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T1-F5-02: A1/A2 module supports rich exercise modes (fill_blank/word_match/sentence_order) with grading and feedback',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        final a1Header = find.textContaining(RegExp(r'\b(A1|A2)\b'));
        await scrollUntilFoundOrEnd(tester, a1Header);
        expect(
          a1Header,
          findsWidgets,
          reason:
              'English roadmap must group A1/A2 modules containing rich exercise modes.',
        );

        final richNodeFinder = find.textContaining(
          RegExp(
            r'(Bo‘sh joyni|So‘zlarni mosl|Gap tuz|So‘zlarni tartibl|fill_blank|word_match|sentence_order)',
            caseSensitive: false,
          ),
        );
        await scrollUntilFoundOrEnd(tester, richNodeFinder, maxScrolls: 60);
        expect(richNodeFinder, findsWidgets);

        await openRoadmapNodeAction(
          tester,
          RegExp(
            r'(Bo‘sh joyni|So‘zlarni mosl|Gap tuz|So‘zlarni tartibl|fill_blank|word_match|sentence_order)',
            caseSensitive: false,
          ),
        );
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);

        await advanceToInteractiveExerciseStep(tester);
        expect(
          findTextAny(const [
            'Bo‘sh joyni to‘ldiring',
            'So‘zlarni moslang',
            'Gap tuzing',
            'So‘zlarni tartiblang',
          ]),
          findsWidgets,
          reason:
              'A1/A2 module lesson must render interactive fill_blank / word_match / sentence_order exercise controls.',
        );

        // Submit wrong / partial input across both TextField and non-TextField rich controls.
        final textInputs = find.byType(TextField);
        if (textInputs.evaluate().isNotEmpty) {
          await tester.enterText(textInputs.first, 'wrong_token_xyz');
          await tester.pump();
        } else {
          final actionChips = find.byType(ActionChip);
          final choiceChips = find.byType(ChoiceChip);
          final filterChips = find.byType(FilterChip);
          final outlinedButtons = find.byType(OutlinedButton);
          if (actionChips.evaluate().isNotEmpty) {
            await tester.tap(actionChips.last);
            await tester.pump();
            final submitBtn = find.ancestor(
              of: findTextAny(const ['TEKSHIRISH', 'Проверить']).first,
              matching: find.byType(ElevatedButton),
            );
            expect(submitBtn, findsOneWidget);
            if (tester.widget<ElevatedButton>(submitBtn.first).onPressed == null &&
                actionChips.evaluate().length > 1) {
              await tester.tap(actionChips.first);
              await tester.pump();
            }
          } else if (choiceChips.evaluate().isNotEmpty) {
            await tester.tap(choiceChips.last);
            await tester.pump();
          } else if (filterChips.evaluate().isNotEmpty) {
            await tester.tap(filterChips.last);
            await tester.pump();
          } else if (outlinedButtons.evaluate().isNotEmpty) {
            await tester.tap(outlinedButtons.last);
            await tester.pump();
          }
        }
        await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
        expect(
          find.textContaining(
            RegExp(
              r'(Siz tanladingiz|Noto‘g‘ri|Xato|Izoh|Qayta urinib|Yo‘lchi AI tahlili)',
              caseSensitive: false,
            ),
          ),
          findsWidgets,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T1-F5-03: completing an A1/A2 unit checkpoint assessment unlocks the next unit with fresh questions',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        final checkpointPattern = RegExp(
          r'(Checkpoint|Modul sinovi|Oraliq nazorat)',
          caseSensitive: false,
        );
        final checkpointNode = find.textContaining(checkpointPattern);
        await scrollUntilFoundOrEnd(tester, checkpointNode, maxScrolls: 60);
        expect(
          checkpointNode,
          findsWidgets,
          reason:
              'English roadmap must expose unit checkpoint assessments for A1/A2 modules.',
        );

        await openRoadmapNodeAction(tester, checkpointPattern);
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        await advanceToInteractiveExerciseStep(tester);

        // Checkpoint questions must be fresh (not cloned from starter/foundation_02).
        expect(find.textContaining("What's your name?"), findsNothing);
        expect(find.textContaining('I ___ a student.'), findsNothing);

        for (var step = 0; step < 10; step++) {
          if (find.text('Mening ta’lim yo‘lim').evaluate().isNotEmpty) {
            break;
          }
          final checkBtn = findTextAny(const ['TEKSHIRISH', 'Проверить']);
          if (checkBtn.evaluate().isNotEmpty) {
            final textInputs = find.byType(TextField);
            if (textInputs.evaluate().isNotEmpty) {
              await tester.enterText(textInputs.first, 'answer');
              await tester.pump();
              await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
            } else {
              for (final letter in const ['A', 'B', 'C', 'D']) {
                if (find.text('Mening ta’lim yo‘lim').evaluate().isNotEmpty) {
                  break;
                }
                if (findTextAny(const ['TEKSHIRISH', 'Проверить'])
                    .evaluate()
                    .isEmpty) {
                  break;
                }
                final letterFinder = find.text(letter);
                if (letterFinder.evaluate().isEmpty) continue;
                await tapText(tester, letter);
                await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
                final revealFinder = find.textContaining('To‘g‘ri javob: ');
                if (revealFinder.evaluate().isNotEmpty) {
                  final revealText =
                      tester.widget<Text>(revealFinder.first).data ?? '';
                  final answerText = revealText
                      .replaceFirst('To‘g‘ri javob: ', '')
                      .trim();
                  if (answerText.isNotEmpty &&
                      find.text(answerText).evaluate().isNotEmpty) {
                    await tapText(tester, answerText);
                    await tapTextAny(
                      tester,
                      const ['TEKSHIRISH', 'Проверить'],
                    );
                    break;
                  }
                }
              }
            }
            continue;
          }
          if (findTextAny(const ['Javobni ko‘rish', 'Показать ответ'])
              .evaluate()
              .isNotEmpty) {
            await revealFlashcard(tester);
            await markFlashcardRemembered(tester);
            continue;
          }
          if (findTextAny(const [
                'Keyingi qadam',
                'Yakunlash',
                'Следующий шаг',
                'Завершить',
              ])
              .evaluate()
              .isNotEmpty) {
            await advanceLessonStep(tester);
            continue;
          }
          break;
        }

        expect(find.text('Mening ta’lim yo‘lim'), findsWidgets);
        final unlockedDailyLifeCard = await findRoadmapNodeCard(
          tester,
          'Present Simple: Bo‘sh joyni to‘ldirish',
        );
        expect(
          find.descendant(
            of: unlockedDailyLifeCard,
            matching: findTextAny(const ['Boshlash', 'Mashq qilish']),
          ),
          findsWidgets,
          reason:
              'Completing node_eng_a1_u1_checkpoint must unlock node_eng_a1_m2_daily_life (Present Simple: Bo‘sh joyni to‘ldirish).',
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M3] T1-F5-04: B1 speaking_prompt shows model answer, rubric criteria, and explicit self-assessment badge',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPlacementToB1(tester);

        await openRoadmapNodeAction(
          tester,
          'Sayohat logistikasi: Present Perfect vs Past Simple',
        );
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        expect(
          find.text('Travel Logistics & Experiences (Present Perfect vs Past Simple)'),
          findsWidgets,
        );

        await advanceLessonStep(tester); // Step 1 concept -> Step 2 audio
        await advanceLessonStep(tester); // Step 2 audio -> Step 3 flashcards
        for (var i = 0; i < 4; i++) {
          await revealFlashcard(tester);
          await markFlashcardRemembered(tester);
        }
        await advanceLessonStep(tester); // Step 3 -> Step 4 MCQ
        await selectMcqAndSubmit(
          tester,
          '11:15 da 19-darvozadan; turar joy tasdiq xati hali kelmagan edi',
        );
        await submitFreeTextAnswer(tester, 'left'); // Step 5 fill_blank -> Step 6

        expect(find.text('Speaking: Travel Update Report'), findsOneWidget);
        expect(find.text('B1'), findsWidgets);
        expect(find.text('Og‘zaki nutq'), findsOneWidget);
        expect(find.text('O‘z-o‘zini baholash'), findsOneWidget);

        final responseField = find.byKey(const Key('self_assessed_text_input'));
        expect(
          responseField,
          findsOneWidget,
          reason: 'B1 speaking_prompt must provide self_assessed_text_input.',
        );
        await tester.enterText(
          responseField,
          'I have already printed my boarding pass, and I checked the itinerary ten minutes ago. My hotel confirmation has not arrived yet.',
        );
        await tester.pump();
        await tapTextAny(tester, const ['TEKSHIRISH', 'Yuborish', 'Saqlash']);

        expect(find.text('Namuna javob:'), findsOneWidget);
        expect(find.text('O‘zini tekshirish mezoni:'), findsOneWidget);
        expect(
          find.textContaining('O‘zini baholash (mustaqil nutq mashqi)'),
          findsOneWidget,
        );
        expect(
          find.textContaining('rasmiy CEFR sertifikati bermaydi'),
          findsWidgets,
        );
        expect(find.textContaining('Official CEFR Certificate'), findsNothing);

        await advanceLessonStep(tester); // Yakunlash
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T1-F5-05: B2, C1 & C2 sections render on English roadmap as upcoming/DEFERRED (non-openable, zero b2/c1/c2 leaks)',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapTextAny(
          tester,
          const ['Mustahkam bilimim bor', 'У меня крепкие знания'],
        );
        await tapTextAny(
          tester,
          const ['Ta’lim yo‘lini ochish', 'Открыть маршрут обучения'],
        );

        expect(find.text('CEFR A1–B1 marshruti'), findsOneWidget);
        expect(find.textContaining('CEFR A1–C2'), findsNothing);

        final sectionHeading = find.text('Keyingi darajalar (B2–C2)');
        await scrollUntilFoundOrEnd(tester, sectionHeading, maxScrolls: 60);
        expect(sectionHeading, findsOneWidget);

        for (final spec in const [
          ('B2', 'B2 — O‘rtadan yuqori daraja', 4),
          ('C1', 'C1 — Yuqori professional daraja', 3),
          ('C2', 'C2 — Mukammal egallash darajasi', 3),
        ]) {
          final card = findDeferredCefrCard(spec.$1);
          await scrollUntilFoundOrEnd(tester, card, maxScrolls: 60);
          expect(card, findsOneWidget);
          expect(
            find.descendant(of: card, matching: find.text(spec.$2)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text('${spec.$3} modul • Keyingi bosqichda ochiladi'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: findTextAny(const [
                'Boshlash',
                'Mashq qilish',
                'Takrorlash',
                'Darsni boshlash',
                'Faol dars',
              ]),
            ),
            findsNothing,
            reason:
                'Deferred ${spec.$1} card must not expose any openable lesson buttons.',
          );

          await tester.tap(find.descendant(of: card, matching: find.text(spec.$1)));
          await tester.pumpAndSettle();
          expect(find.byType(InteractiveLessonScreen), findsNothing);
          expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
          expect(
            find.textContaining(
              '${spec.$1} bosqichi keyingi bosqichda (DEFERRED) qo‘shiladi',
            ),
            findsOneWidget,
          );
        }

        expect(find.textContaining('TBD'), findsNothing);
        expect(find.textContaining('Placeholder'), findsNothing);
        expect(find.textContaining('node_eng_b1_exit'), findsNothing);
        expect(
          find.textContaining(
            RegExp(r'lesson_eng_(b2|c1|c2)', caseSensitive: false),
          ),
          findsNothing,
        );

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        expect(profile['completedLessonIds'] as List<dynamic>? ?? [], isEmpty);
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F6: Flashcards & SRS Review
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T1-F6-01: flashcard front hides meaning/IPA until Javobni ko‘rish reveals meaning, example, and IPA',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        expect(find.text("What's your name?"), findsOneWidget);
        expect(find.byTooltip('Talaffuzni tinglash'), findsOneWidget);
        expect(find.text('/wɒts jɔːr neɪm/'), findsNothing);
        expect(find.textContaining('Ismingiz nima?'), findsNothing);

        await revealFlashcard(tester);
        expect(find.text('/wɒts jɔːr neɪm/'), findsOneWidget);
        expect(find.textContaining('Ismingiz nima?'), findsWidgets);
        expect(find.text("Hi, I'm Aziza. What's your name?"), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F6-02: tapping Yana mashq qilaman re-queues flashcard before deck completion',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        await revealFlashcard(tester);
        await markFlashcardNeedPractice(tester);
        expect(find.text('Nice to meet you.'), findsOneWidget);
        expect(find.text('Flashcard • 0/2'), findsOneWidget);

        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        expect(find.text('Flashcard • 1/2'), findsOneWidget);
        expect(find.text("What's your name?"), findsOneWidget);

        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        expect(
          find.text('Barcha kartochkalar ko‘rib chiqildi!'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T1-F6-03: flashcard mode switching supports En->Uz, Uz->En, Audio->Word, Image->Word, and Random',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        // Default En -> Uz: English target visible, Uzbek meaning hidden before reveal.
        expect(find.text("What's your name?"), findsOneWidget);
        expect(find.textContaining('Ismingiz nima?'), findsNothing);

        final uzToEnChip = findTextAny(const ['Uz → En', 'Uz->En']);
        expect(
          uzToEnChip,
          findsOneWidget,
          reason:
              'Flashcard deck must expose practice mode switchers (En->Uz, Uz->En, Audio->Word, Image->Word, Random).',
        );
        await tester.tap(uzToEnChip.first);
        await tester.pumpAndSettle();

        // Uz -> En: Uzbek meaning on front, English target hidden until reveal.
        expect(find.textContaining('Ismingiz nima?'), findsWidgets);
        expect(find.text("What's your name?"), findsNothing);
        await revealFlashcard(tester);
        expect(find.text("What's your name?"), findsWidgets);

        final audioModeChip = findTextAny(const ['Audio → Word', 'Audio->Word']);
        expect(audioModeChip, findsOneWidget);
        await tester.tap(audioModeChip.first);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Talaffuzni tinglash'), findsOneWidget);
        expect(find.text("What's your name?"), findsNothing);

        final imageModeChip = findTextAny(const ['Image → Word', 'Image->Word']);
        expect(imageModeChip, findsOneWidget);
        await tester.tap(imageModeChip.first);
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsWidgets);
        expect(find.text("What's your name?"), findsNothing);

        final randomChip = findTextAny(const ['Random', 'Tasodifiy']);
        expect(randomChip, findsOneWidget);
        await tester.tap(randomChip.first);
        await tester.pumpAndSettle();
        expect(find.text('Javobni ko‘rish'), findsOneWidget);

        final enToUzChip = findTextAny(const ['En → Uz', 'En->Uz']);
        expect(enToUzChip, findsOneWidget);
        await tester.tap(enToUzChip.first);
        await tester.pumpAndSettle();
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T1-F6-04: SRS review state (Eslab qoldim vs Yana mashq qilaman) persists in flashcardSrsByCourse across restart',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await revealFlashcard(tester);
        await markFlashcardNeedPractice(tester);

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final srs = profile['flashcardSrsByCourse'] as Map<String, dynamic>?;
        final engSrs = srs?['course_eng_01'] as Map<String, dynamic>?;
        expect(
          engSrs,
          isNotNull,
          reason:
              'Flashcard SRS intervals and need_practice buckets must persist under flashcardSrsByCourse["course_eng_01"].',
        );
        expect(engSrs!.length, greaterThanOrEqualTo(2));
        final encodedSrs = jsonEncode(engSrs).toLowerCase();
        expect(
          encodedSrs,
          contains('remembered'),
          reason: 'Persisted SRS map must record remembered status for fc_eng_starter_1.',
        );
        expect(
          encodedSrs,
          contains('need_practice'),
          reason: 'Persisted SRS map must record need_practice status for fc_eng_starter_2.',
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T1-F6-05: completing flashcard deck with Eslab qoldim schedules cards forward and drops due count to zero',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);

        expect(
          find.text('Barcha kartochkalar ko‘rib chiqildi!'),
          findsOneWidget,
        );
        expect(
          find.textContaining(RegExp(r'(Keyingi takrorlash|SRS)')),
          findsWidgets,
          reason:
              'Completing flashcard deck must surface updated forward SRS schedule.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // F7: Yo‘lchi AI Contextual Help
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T1-F7-01: tapping Yo‘lchidan so‘rash from lesson_eng_starter Step 2 opens AITutorScreen with lesson context',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);

        expect(findLessonStepCounter(2, 4), findsOneWidget);
        await tapTooltip(tester, 'Yo‘lchidan so‘rash');

        expect(find.byType(AITutorScreen), findsOneWidget);
        expect(find.text('Yo‘lchi AI'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F7-02: submitting question in Yo‘lchi AI renders localized reply and Foydali javob feedback button',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await tapTooltip(tester, 'Yo‘lchidan so‘rash');

        await tester.enterText(
          find.byType(TextField).last,
          'Hello qachon ishlatiladi?',
        );
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
        await pumpFrames(tester, count: 25, step: const Duration(milliseconds: 50));

        expect(
          findTextMatching('Birinchi inglizcha so‘zlar', findRichText: true),
          findsWidgets,
        );
        expect(
          findTextMatching('qadam-baqadam', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.text('Foydali javob'),
          findsOneWidget,
          reason:
              'Yo‘lchi AI bubble must provide the "Foydali javob" feedback button.',
        );
        await tapText(tester, 'Foydali javob', settle: false);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F7-03: opening and closing Yo‘lchi AI mid-exercise does not reset or remount typed input',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await advanceLessonStep(tester);

        final inputFinder = find.byKey(const Key('free_text_answer_input'));
        await tester.enterText(inputFinder, "I'm Sam");
        await tester.pump();

        await openAndCloseYolchiAi(
          tester,
          askText: 'Hello qachon ishlatiladi?',
          preserveFinder: inputFinder,
          preserveText: "I'm Sam",
        );

        expect(findLessonStepCounter(4, 4), findsOneWidget);
        final field = tester.widget<TextField>(inputFinder);
        expect(field.controller?.text, "I'm Sam");
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T1-F7-04: wrong answer displays mistake-specific feedback, Yolchi AI tahlili, and allows retry',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await advanceLessonStep(tester);

        await submitFreeTextAnswer(tester, 'Goodbye');
        expect(find.text('Sizning javobingiz: Goodbye'), findsOneWidget);
        expect(
          find.textContaining('«Goodbye» xayrlashuv so‘zi'),
          findsOneWidget,
        );

        await tapText(tester, 'Yo‘lchi AI tahlili');
        expect(find.text('Yo‘lchi bilan xato tahlili'), findsOneWidget);
        await tapText(tester, 'Darsga qaytish');

        await submitFreeTextAnswer(tester, "I'm Sam");
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T1-F7-05: Russian UI locale uses Russian Yo‘lchi UI & response while keeping English media/examples',
      (tester) async {
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          locale: AppLocalePreset.ru,
        );
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapTextAny(tester, const ['Noldan boshlayman', 'Начать с нуля']);
        await tapTextAny(
          tester,
          const ['Birinchi darsni boshlash', 'Начать первый урок'],
        );
        await advanceLessonStep(tester);

        expect(find.text('English'), findsOneWidget);
        expect(
          find.text('Диалог знакомства Азизы и Бена'),
          findsOneWidget,
          reason:
              'Russian locale must propagate to LessonMediaWidget localized title and Russian UI chrome.',
        );

        await tapTooltipAny(
          tester,
          const ['Yo‘lchidan so‘rash', 'Спросить Yo‘lchi'],
        );
        expect(
          findTextMatching('Salom, men Yo‘lchi AI!', findRichText: true),
          findsNothing,
          reason: 'Yo‘lchi AI welcome bubble must be localized in Russian.',
        );

        await tester.enterText(
          find.byType(TextField).last,
          'Когда использовать Hello?',
        );
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
        await pumpFrames(tester, count: 25, step: const Duration(milliseconds: 50));

        expect(
          findTextMatching('шаг за шагом', findRichText: true),
          findsOneWidget,
          reason: 'Yo‘lchi AI reply must be localized to Russian.',
        );
      },
    );
  });
}
