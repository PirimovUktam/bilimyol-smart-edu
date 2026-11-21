import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/lesson_media.dart';
import 'package:bilimyol_mobile/features/ai_tutor/ai_tutor_screen.dart';
import 'package:bilimyol_mobile/features/ai_tutor/yolchi_bubble.dart';
import 'package:bilimyol_mobile/features/lesson/flashcard_deck_widget.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/lesson/lesson_media_widget.dart';

import 'helpers.dart';

void registerTier2Tests() {
  group('Tier 2 — Boundary, Corner & Negative Cases (F1–F7)', () {
    // -------------------------------------------------------------------------
    // F1 Boundaries
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T2-F1-01: direct route to /lesson with course_math_01 session while course_eng_01 active is blocked by isolation guard',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_math_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        expect(find.text('Qo‘shish va ayirishdan boshlaymiz'), findsWidgets);

        await selectCourse(tester, 'course_eng_01');
        appRouter.go('/lesson');
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Ushbu dars boshqa fanga tegishli va ko‘rsatilmaydi.',
          ),
          findsOneWidget,
        );
        expect(find.text('Qo‘shish va ayirishdan boshlaymiz'), findsNothing);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F1-02: rapid course switching eng -> it -> math -> eng leaves zero stale roadmap nodes',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);

        await openEnglishRoadmapViaOnboarding(tester);
        expect(find.text('Vocabulary'), findsWidgets);
        expect(find.text('Python asoslari'), findsNothing);

        await selectCourse(tester, 'course_it');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ta’lim yo‘lini ochish');
        expect(find.text('Python asoslari'), findsWidgets);
        expect(find.text('Vocabulary'), findsNothing);

        await selectCourse(tester, 'course_math_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ta’lim yo‘lini ochish');
        expect(find.text('Algebra asoslari'), findsWidgets);
        expect(find.text('Python asoslari'), findsNothing);

        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Ta’lim yo‘li', scroll: false);
        for (final engSkill in const [
          'Vocabulary',
          'Grammar',
          'Listening',
          'Reading',
        ]) {
          await tester.scrollUntilVisible(find.text(engSkill), 150);
          expect(find.text(engSkill), findsWidgets);
        }
        expect(find.text('Algebra asoslari'), findsNothing);
        expect(find.text('Python asoslari'), findsNothing);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F1-03: demo session makes zero remote Supabase calls and stores progress locally',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester);

        await tapTooltip(tester, 'Bilim Xaritasi');
        expect(SupabaseConfig.hasRemoteConfiguration, isFalse);
        expect(SupabaseConfig.isConfigured, isFalse);
        expect(SupabaseConfig.client, isNull);

        final snapshot = await readDemoProgressSnapshot();
        expect(snapshot['profile'], isA<Map<String, dynamic>>());
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F1-04: completed course_math_01 does not skip course_eng_01 onboarding or starter flow',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_math_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(tester, '6');

        await tapText(tester, 'Profil', scroll: false);
        await tapText(tester, 'Fanni o‘zgartirish');

        await expectCourseProgressCount(tester, 'Matematika', 1);
        await expectCourseProgressCount(tester, 'Ingliz tili', 0);
        expect(find.text('Boshlash'), findsWidgets);

        await selectCourse(tester, 'course_eng_01');
        expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F1-05: draft or untrusted remote/traversal media is rejected by LessonMedia and suppressed by LessonMediaWidget',
      (tester) async {
        expect(
          LessonMedia.tryParse({
            'id': 'draft_1',
            'kind': 'audio',
            'language': 'en',
            'source': '/lesson-media/english/a1-starter-dialogue.wav',
            'title': 'Draft',
            'transcript': 'Aziza: Hi',
            'durationSeconds': 4,
            'reviewStatus': 'draft',
          }),
          isNull,
        );
        expect(
          LessonMedia.tryParse({
            'id': 'evil_url',
            'kind': 'audio',
            'language': 'en',
            'source': 'https://evil.test/a.mp3',
            'title': 'Evil',
            'transcript': 'Aziza: Hi',
            'durationSeconds': 4,
            'reviewStatus': 'approved',
          }),
          isNull,
        );
        expect(
          LessonMedia.tryParse({
            'id': 'traversal',
            'kind': 'audio',
            'language': 'en',
            'source': '/lesson-media/../secret.wav',
            'title': 'Traversal',
            'transcript': 'Aziza: Hi',
            'durationSeconds': 4,
            'reviewStatus': 'approved',
          }),
          isNull,
        );

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: LessonMediaWidget(
                  media: LessonMedia(
                    id: 'draft_widget',
                    kind: LessonMediaKind.audio,
                    language: LessonMediaLanguage.en,
                    source: '/lesson-media/english/a1-starter-dialogue.wav',
                    title: 'Unapproved Draft Audio',
                    transcript: 'Aziza: Hi',
                    durationSeconds: 5,
                    reviewStatus: LessonMediaReviewStatus.draft,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unapproved Draft Audio'), findsNothing);
        expect(find.byTooltip('Tinglash'), findsNothing);
        expect(find.text('Matnli bayon'), findsNothing);
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F2 Boundaries
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T2-F2-01: placement test cannot advance with no option selected',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        expect(find.text('Savol 1 / 8'), findsOneWidget);
        await tapText(tester, 'Keyingi Savol');

        expect(find.text('Savol 1 / 8'), findsOneWidget);
        expect(find.text('Q1'), findsOneWidget);
        expect(find.text('Savol 2 / 8'), findsNothing);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T2-F2-02: mid-placement restart handles reset/resume cleanly without corrupting course_eng_01 mastery',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        await answerCurrentPlacementQuestion(tester, preferCorrect: true);
        await answerCurrentPlacementQuestion(tester, preferCorrect: true);

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );

        // Verify mid-placement restart did not corrupt scoresByCourse or completedLessonIds.
        final midSnapshot = await readDemoProgressSnapshot();
        final midProfile =
            midSnapshot['profile'] as Map<String, dynamic>? ?? {};
        final midScores =
            (midProfile['scoresByCourse']
                as Map<String, dynamic>? ?? {})['course_eng_01']
                as Map<String, dynamic>? ??
            {};
        expect(midScores, isEmpty);
        expect(
          midProfile['completedLessonIds'] as List<dynamic>? ?? [],
          isEmpty,
        );

        await selectCourse(tester, 'course_eng_01');
        if (find.text('Ixtiyoriy diagnostika').evaluate().isNotEmpty) {
          await tapText(tester, 'Ixtiyoriy diagnostika');
        } else {
          await tapText(tester, 'Profil', scroll: false);
          await tapText(tester, 'Boshlash darajasini sozlash');
          await tapText(tester, 'Asoslarini bilaman');
          await tapText(tester, 'Ixtiyoriy diagnostika');
        }

        // Complete placement cleanly and verify independent mastery scores stay isolated.
        for (var i = 0; i < 12; i++) {
          if (find.text('Diagnostika yakunlandi').evaluate().isNotEmpty) break;
          await answerCurrentPlacementQuestion(tester, preferCorrect: true);
        }
        expect(find.text('Diagnostika yakunlandi'), findsOneWidget);

        await tapText(tester, 'Shaxsiy yo‘lni ko‘rish');
        await tapTooltip(tester, 'Bilim Xaritasi');
        expect(
          find.textContaining(RegExp(r'Bilim xaritasi', caseSensitive: false)),
          findsWidgets,
        );

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final scoresByCourse =
            profile['scoresByCourse'] as Map<String, dynamic>? ?? {};
        final engScores =
            scoresByCourse['course_eng_01'] as Map<String, dynamic>? ?? {};
        expect(
          engScores,
          isEmpty,
          reason:
              'Placement completion after mid-session restart must not overwrite independent course_eng_01 mastery.',
        );
        expect(profile['completedLessonIds'] as List<dynamic>? ?? [], isEmpty);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T2-F2-03: all-wrong placement (0%) places learner at Pre-A1/A1 foundation without crash',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        for (var step = 1; step <= 8; step++) {
          await answerCurrentPlacementQuestion(tester, preferCorrect: false);
        }

        expect(find.text('0 / 8 javob to‘g‘ri.'), findsOneWidget);
        expect(
          find.textContaining(
            RegExp(
              r'(Tavsiya etilgan bosqich|Стартовый уровень): (Pre-A1|A1)\b',
            ),
          ),
          findsOneWidget,
          reason:
              '0% placement must recommend Pre-A1 / A1 foundation rather than omitting level.',
        );
        await tapText(tester, 'Shaxsiy yo‘lni ko‘rish');
        expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T2-F2-04: completing placement does not grant fake lesson completions or independent mastery credit',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        for (var step = 1; step <= 8; step++) {
          await answerCurrentPlacementQuestion(tester, preferCorrect: true);
        }

        await tapText(tester, 'Shaxsiy yo‘lni ko‘rish');
        expect(find.text('Bajarildi (100%)'), findsNothing);

        await tapText(tester, 'Natijalar', scroll: false);
        expect(find.text('0'), findsWidgets);

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final placementCefr =
            profile['placementCefrByCourse'] as Map<String, dynamic>? ?? {};
        expect(placementCefr['course_eng_01'], 'B1');
        expect(profile['completedLessonIds'] as List<dynamic>? ?? [], isEmpty);
        final scoresByCourse =
            profile['scoresByCourse'] as Map<String, dynamic>? ?? {};
        expect(
          (scoresByCourse['course_eng_01'] as Map<String, dynamic>? ?? {}),
          isEmpty,
          reason:
              'Placement results must stay isolated from independent lesson mastery (scoresByCourse).',
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T2-F2-05: listening placement hides transcript until toggled and never auto-fails on text alternative',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ixtiyoriy diagnostika');

        var verifiedListening = false;
        for (var step = 1; step <= 12; step++) {
          if (find.text('Diagnostika yakunlandi').evaluate().isNotEmpty) break;
          expect(
            find.textContaining('Audio context:'),
            findsNothing,
            reason:
                'Listening placement item must not leak script in prompt stem.',
          );
          if (find.text('Matnli bayon').evaluate().isNotEmpty ||
              find.text('Текст').evaluate().isNotEmpty) {
            expect(
              findTextMatching(
                englishPlacementTranscriptRegex,
                findRichText: true,
              ),
              findsNothing,
            );
            await toggleAudioTranscript(tester);
            expect(
              findTextMatching(
                englishPlacementTranscriptRegex,
                findRichText: true,
              ),
              findsWidgets,
            );
            verifiedListening = true;
          }
          await answerCurrentPlacementQuestion(tester, preferCorrect: true);
        }

        expect(
          verifiedListening,
          isTrue,
          reason:
              'Listening placement must render collapsible transcript toggle on listening items.',
        );
        expect(find.text('Diagnostika yakunlandi'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F3 Boundaries
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T2-F3-01: whitespace-only free-text submission is disabled and blocked',
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

        await tester.enterText(
          find.byKey(const Key('free_text_answer_input')),
          '   ',
        );
        await tester.pump();

        final submitButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('TEKSHIRISH'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(submitButton.onPressed, isNull);
        expect(findLessonStepCounter(4, 4), findsOneWidget);
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsNothing,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F3-02: free-text normalization accepts curly apostrophe, casing, extra spaces, and trailing punctuation',
      (tester) async {
        // Variant A: "  i’m   sam! "
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester, answer: '  i\u2019m   sam! ');
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );

        // Variant B: "My name is Sam."
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester, answer: 'My name is Sam.');
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F3-03: invalid free-text answers ("Goodbye", "123", "I\'m Aziza") show guidance and allow retry to pass',
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

        for (final wrong in const ['Goodbye', '123', "I'm Aziza"]) {
          await submitFreeTextAnswer(tester, wrong);
          expect(find.text('Sizning javobingiz: $wrong'), findsOneWidget);
          if (wrong == 'Goodbye') {
            expect(
              find.textContaining('«Goodbye» xayrlashuv so‘zi'),
              findsOneWidget,
            );
          } else {
            expect(
              find.textContaining('to‘liq gap yozing'),
              findsOneWidget,
            );
          }
          expect(
            find.textContaining('To‘g‘ri javob:'),
            findsNothing,
            reason:
                'Free-text wrong feedback must NOT leak answer key after "$wrong".',
          );
          expect(find.textContaining("I'm Sam"), findsNothing);
          expect(find.textContaining('My name is Sam'), findsNothing);
          expect(findLessonStepCounter(4, 4), findsOneWidget);
        }

        await submitFreeTextAnswer(tester, "I'm Sam");
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F3-04: rapid double-tap on starter completion is idempotent for XP and lesson count',
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

        await tester.enterText(
          find.byKey(const Key('free_text_answer_input')),
          "I'm Sam",
        );
        await tester.pump();

        final submitFinder = find.text('TEKSHIRISH');
        await tester.tap(submitFinder);
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tap(submitFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final completed =
            (profile['completedLessonIds'] as List<dynamic>? ?? []);
        expect(profile['xp'], 22);
        expect(
          completed.where((id) => id == 'lesson_eng_starter').length,
          1,
        );

        await tapText(tester, 'Profil', scroll: false);
        expect(find.text('22 XP'), findsOneWidget);
        await tapText(tester, 'Fanni o‘zgartirish');
        await expectCourseProgressCount(tester, 'Ingliz tili', 1);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F3-05: starter audio load failure shows retry + transcript fallback, and broken image shows alt fallback',
      (tester) async {
        final audioHarness = AudioTestHarness(failOnLoad: true);
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          overrides: [audioHarness.buildOverride()],
        );
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);

        expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
        expect(find.text('Qayta urinish'), findsOneWidget);

        await toggleAudioTranscript(tester);
        expect(
          findTextMatching('Aziza:', findRichText: true),
          findsOneWidget,
        );

        await advanceLessonStep(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await advanceLessonStep(tester);
        await submitFreeTextAnswer(tester, "I'm Sam");
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );

        // Also verify broken image fallback renders alt text without layout collapse.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: 760,
                      child: LessonMediaWidget(
                        media: LessonMedia(
                          id: 'broken_img',
                          kind: LessonMediaKind.image,
                          language: LessonMediaLanguage.en,
                          source:
                              '/lesson-media/english/missing_illustration.png',
                          title: 'Greeting Scene',
                          alt: 'Tashkent school greeting fallback alt',
                          reviewStatus: LessonMediaReviewStatus.approved,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
        expect(
          find.text('Tashkent school greeting fallback alt'),
          findsWidgets,
        );
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F4 Boundaries
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T2-F4-01: tapping locked node_eng_read before prerequisite shows prerequisite lock notice rather than silent no-op',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        await tester.scrollUntilVisible(find.text('Reading'), 150);
        expect(find.text('Bloklangan'), findsWidgets);

        await tester.tap(find.text('Reading'));
        await tester.pumpAndSettle();

        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
        final lockNoticeFinder = find.byType(SnackBar);
        expect(
          lockNoticeFinder,
          findsOneWidget,
          reason:
              'Tapping locked node_eng_read must display a prerequisite lock notice instead of a silent no-op.',
        );
      },
    );

    testWidgets(
      '[M1] T2-F4-02: tampered reading checkpoint (-1 or 999) clamps safely within [0, exerciseStepIndex]',
      (tester) async {
        // Part A: Upper-bound clamp (999 -> Qadam 3 / 3)
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          initialPrefs: {
            'bilimyol-reading:lesson_eng_reading_01': '999',
          },
        );
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(tester, '15:15 (quarter past three)');

        await openRoadmapNodeAction(tester, RegExp(r'^Reading$'));
        expect(find.text('Asosiy g‘oya va dalil'), findsWidgets);
        expect(
          findLessonStepCounter(3, 3),
          findsOneWidget,
          reason:
              'Seeded reading checkpoint 999 must clamp to upper step Qadam 3 / 3.',
        );
        expect(findLessonStepCounter(1, 3), findsNothing);

        // Part B: Lower-bound clamp (-1 -> Qadam 1 / 3)
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          initialPrefs: {
            'bilimyol-reading:lesson_eng_reading_01': '-1',
          },
        );
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await selectMcqAndSubmit(tester, '15:15 (quarter past three)');

        await openRoadmapNodeAction(tester, RegExp(r'^Reading$'));
        expect(find.text('Asosiy g‘oya va dalil'), findsWidgets);
        expect(
          findLessonStepCounter(1, 3),
          findsOneWidget,
          reason:
              'Seeded reading checkpoint -1 must clamp safely to Qadam 1 / 3 without crashing.',
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F4-03: selecting wrong listening distractor explains afternoon 15:15 evidence',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        await selectMcqAndSubmit(tester, '15:30 (half past three)');
        expect(
          find.text('Siz tanladingiz: 15:30 (half past three)'),
          findsOneWidget,
        );
        expect(
          find.text('To‘g‘ri javob: 15:15 (quarter past three)'),
          findsOneWidget,
        );
        expect(find.textContaining('in the afternoon'), findsWidgets);
        expect(find.textContaining('15:15'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F4-04: using transcript text alternative in lesson_eng_listening_01 still permits lesson completion',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Listening$'));
        await advanceLessonStep(tester);
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
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F4-05: leaving mid-reading restores step only and never marks lesson_eng_reading_01 complete',
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
        await advanceLessonStep(tester);
        expect(findLessonStepCounter(2, 3), findsOneWidget);

        await tapTooltip(tester, 'Ta’lim yo‘liga qaytish');
        await tester.scrollUntilVisible(find.text('Reading'), 150);

        final snapshot = await readDemoProgressSnapshot();
        final completed =
            ((snapshot['profile'] as Map<String, dynamic>)['completedLessonIds']
                as List<dynamic>);
        expect(completed, isNot(contains('lesson_eng_reading_01')));

        await openRoadmapNodeAction(tester, RegExp(r'^Reading$'));
        expect(
          findLessonStepCounter(2, 3),
          findsOneWidget,
          reason:
              'Returning to lesson_eng_reading_01 must restore Qadam 2 / 3 without completing the lesson.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // F5 Boundaries
    // -------------------------------------------------------------------------
    testWidgets(
      '[M5] T2-F5-01: prerequisite guard prevents bypassing A2/B1 exit assessments and B2/C1/C2 deferred levels cannot be opened',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        for (final exitTitle in const [
          'A2 Bosqich sinovi: Yakuniy imtihon',
          'B1 Bosqich sinovi: Yakuniy imtihon',
        ]) {
          final exitCard = await findRoadmapNodeCard(tester, exitTitle);
          expect(
            find.descendant(of: exitCard, matching: find.text('Bloklangan')),
            findsWidgets,
          );
          expect(
            find.descendant(
              of: exitCard,
              matching: findTextAny(const [
                'Boshlash',
                'Mashq qilish',
                'Takrorlash',
              ]),
            ),
            findsNothing,
          );

          await tester.tap(exitCard);
          await tester.pumpAndSettle();

          expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
          expect(find.byType(InteractiveLessonScreen), findsNothing);
          expect(find.byType(SnackBar), findsOneWidget);
          expect(
            find.textContaining('Avval oldingi bosqichni yakunlang:'),
            findsOneWidget,
          );
          expect(find.textContaining('node_eng_'), findsNothing);
          await dismissSnackBarIfVisible(tester);
        }

        // Also tap locked B1 level header card.
        final b1Header = await findRoadmapNodeCard(tester, 'B1 — O‘rta daraja');
        await tester.tap(b1Header);
        await tester.pumpAndSettle();
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
        expect(find.byType(InteractiveLessonScreen), findsNothing);
        expect(
          find.textContaining(
            'B1 darajasi bloklangan. Avval oldingi bosqichni yakunlang: A2 Bosqich sinovi: Yakuniy imtihon',
          ),
          findsOneWidget,
        );
        await dismissSnackBarIfVisible(tester);

        // Verify B2/C1/C2 deferred levels cannot be opened or bypassed.
        await expectDeferredCefrLevelsRendered(tester);
        final b2Card = findDeferredCefrCard('B2');
        await tester.tap(find.descendant(of: b2Card, matching: find.text('B2')));
        await tester.pumpAndSettle();
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
        expect(find.byType(InteractiveLessonScreen), findsNothing);
        expect(
          find.textContaining('B2 bosqichi keyingi bosqichda (DEFERRED) qo‘shiladi'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T2-F5-02: weak unit checkpoint score triggers remedial practice instead of unlocking next CEFR level',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        final checkpointPattern = RegExp(
          r'(Checkpoint|Modul sinovi|Oraliq nazorat)',
          caseSensitive: false,
        );
        final checkpointFinder = find.textContaining(checkpointPattern);
        await scrollUntilFoundOrEnd(tester, checkpointFinder, maxScrolls: 60);
        expect(
          checkpointFinder,
          findsWidgets,
          reason:
              'Unit checkpoints must exist to test weak-score remedial routing.',
        );

        await openRoadmapNodeAction(tester, checkpointPattern);
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        await advanceToInteractiveExerciseStep(tester);

        // Drive checkpoint steps submitting wrong answers (< requiredScore).
        final remedialPattern = RegExp(
          r'(Qayta mashq|Mustahkamlash|Remedial|Alternate)',
          caseSensitive: false,
        );
        for (var step = 0; step < 10; step++) {
          if (find.textContaining(remedialPattern).evaluate().isNotEmpty ||
              find.text('Mening ta’lim yo‘lim').evaluate().isNotEmpty) {
            break;
          }
          if (findTextAny(const ['TEKSHIRISH', 'Проверить']).evaluate().isNotEmpty) {
            final textInputs = find.byType(TextField);
            if (textInputs.evaluate().isNotEmpty) {
              await tester.enterText(textInputs.first, 'wrong_checkpoint_xyz');
              await tester.pump();
            } else {
              for (final letter in const ['D', 'C', 'B', 'A']) {
                if (find.text(letter).evaluate().isNotEmpty) {
                  await tapText(tester, letter);
                  break;
                }
              }
            }
            await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
            if (find.textContaining(remedialPattern).evaluate().isNotEmpty) {
              break;
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
            }
            continue;
          }
          if (findTextAny(const ['Javobni ko‘rish', 'Показать ответ'])
              .evaluate()
              .isNotEmpty) {
            await revealFlashcard(tester);
            await markFlashcardNeedPractice(tester);
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

        expect(
          find.textContaining(remedialPattern),
          findsWidgets,
          reason:
              'Weak checkpoint score must trigger remedial/alternate practice prompt.',
        );

        if (find.byTooltip('Ta’lim yo‘liga qaytish').evaluate().isNotEmpty) {
          await tapTooltip(tester, 'Ta’lim yo‘liga qaytish');
        }
        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
        for (final gatedTitle in <Pattern>[
          RegExp(r'^Present Simple: Bo‘sh joyni to‘ldirish$'),
          RegExp(r'^Transport va yo‘l so‘rash$'),
        ]) {
          final gatedCard = await findRoadmapNodeCard(tester, gatedTitle);
          expect(
            find.descendant(
              of: gatedCard,
              matching: find.text('Bloklangan'),
            ),
            findsWidgets,
            reason:
                'Weak checkpoint score must keep "$gatedTitle" Bloklangan.',
          );
          expect(
            find.descendant(
              of: gatedCard,
              matching: findTextAny(const ['Boshlash', 'Mashq qilish']),
            ),
            findsNothing,
            reason:
                'Weak checkpoint score must not unlock Boshlash / Mashq qilish on "$gatedTitle".',
          );
        }
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M5] T2-F5-03: repeated identical error surfaces targeted remedial explanation/node for that skill',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        await openRoadmapNodeAction(tester, RegExp(r'^Vocabulary$'));
        expect(
          find.text('Vocabulary: Xona buyumlari va joylashuv (beside, between, behind)'),
          findsWidgets,
        );
        await advanceToInteractiveExerciseStep(tester);
        await selectMcqAndSubmit(tester, 'behind the sofa');
        await selectMcqAndSubmit(tester, 'beside the window');

        expect(
          find.textContaining(
            RegExp(
              r'(Takroriy xato|Remedial|Qayta mashq darsi|Qo‘shimcha mashq)',
              caseSensitive: false,
            ),
          ),
          findsWidgets,
          reason:
              'Consecutive identical skill errors must surface targeted remedial guidance/lesson.',
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T2-F5-04: self_assessed speaking/writing blocks empty response and never claims Official CEFR Certificate',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        final taskFinder = find.textContaining(
          RegExp(r'(Speaking|Writing|Gapirish|Yozish|O‘zini baholash)', caseSensitive: false),
        );
        await scrollUntilFoundOrEnd(tester, taskFinder);
        expect(
          taskFinder,
          findsWidgets,
          reason:
              'Self-assessed speaking/writing prompts must exist to guard empty submissions and badge honesty.',
        );

        await openRoadmapNodeAction(
          tester,
          RegExp(r'(Speaking|Writing|Gapirish|Yozish|O‘zini baholash)', caseSensitive: false),
        );
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        await advanceToInteractiveExerciseStep(tester);

        // Attempt empty submission -> button must be disabled or show validation notice.
        final submitFinder = findTextAny(const ['TEKSHIRISH', 'Yuborish', 'Saqlash']);
        expect(submitFinder, findsWidgets);
        final elevatedParent = find.ancestor(
          of: submitFinder.first,
          matching: find.byType(ElevatedButton),
        );
        if (elevatedParent.evaluate().isNotEmpty &&
            tester.widget<ElevatedButton>(elevatedParent.first).onPressed == null) {
          expect(
            tester.widget<ElevatedButton>(elevatedParent.first).onPressed,
            isNull,
          );
        } else {
          await tester.tap(submitFinder.first);
          await tester.pumpAndSettle();
          expect(find.text('Mening ta’lim yo‘lim'), findsNothing);
        }

        // Enter valid response, submit, verify rubric/model and NO Official CEFR Certificate on this screen.
        final field = find.byType(TextField);
        expect(field, findsWidgets);
        await tester.enterText(
          field.first,
          'I prefer studying in the morning because my concentration is highest.',
        );
        await tester.pump();
        await tapTextAny(tester, const ['TEKSHIRISH', 'Yuborish', 'Saqlash']);

        expect(
          find.textContaining(RegExp(r'(Namuna|Model)', caseSensitive: false)),
          findsWidgets,
        );
        expect(
          find.textContaining(RegExp(r'(Mezon|Rubric|Kriteriy)', caseSensitive: false)),
          findsWidgets,
        );
        expect(find.textContaining('Official CEFR Certificate'), findsNothing);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T2-F5-05: sentence_order / word_match partial submission gives targeted hint and allows retry',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        final modeNodeFinder = find.textContaining(
          RegExp(
            r'(So‘zlarni mosl|Gap tuz|So‘zlarni tartibl|sentence_order|word_match)',
            caseSensitive: false,
          ),
        );
        await scrollUntilFoundOrEnd(tester, modeNodeFinder);
        expect(
          modeNodeFinder,
          findsWidgets,
          reason:
              'sentence_order / word_match modules must exist for partial/misordered validation.',
        );

        await openRoadmapNodeAction(
          tester,
          RegExp(
            r'(So‘zlarni mosl|Gap tuz|So‘zlarni tartibl|sentence_order|word_match)',
            caseSensitive: false,
          ),
        );
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        await advanceToInteractiveExerciseStep(tester);

        // Tap wrong/partial token(s) to ensure grading runs (never pass on a disabled button or title text).
        final chipFinder = find.byType(ActionChip);
        final choiceFinder = find.byType(ChoiceChip);
        final filterFinder = find.byType(FilterChip);
        final outlinedFinder = find.byType(OutlinedButton);
        if (chipFinder.evaluate().isNotEmpty) {
          await tester.tap(chipFinder.last);
          await tester.pump();
        } else if (choiceFinder.evaluate().isNotEmpty) {
          await tester.tap(choiceFinder.last);
          await tester.pump();
        } else if (filterFinder.evaluate().isNotEmpty) {
          await tester.tap(filterFinder.last);
          await tester.pump();
        } else if (outlinedFinder.evaluate().isNotEmpty) {
          await tester.tap(outlinedFinder.last);
          await tester.pump();
        }

        final submitFinder = findTextAny(const ['TEKSHIRISH', 'Проверить']);
        expect(submitFinder, findsWidgets);
        final submitBtn = find.ancestor(
          of: submitFinder.first,
          matching: find.byType(ElevatedButton),
        );
        expect(submitBtn, findsOneWidget);
        if (tester.widget<ElevatedButton>(submitBtn.first).onPressed == null &&
            chipFinder.evaluate().length > 1) {
          await tester.tap(chipFinder.first);
          await tester.pump();
        }
        expect(
          tester.widget<ElevatedButton>(submitBtn.first).onPressed,
          isNotNull,
          reason:
              'TEKSHIRISH button must be enabled after partial/misordered selection so grading executes.',
        );

        await tapTextAny(tester, const ['TEKSHIRISH', 'Проверить']);
        expect(
          find.textContaining(
            RegExp(
              r'(Siz tanladingiz|Noto‘g‘ri|Xato|Tavsiya|Qayta urinib|Yo‘lchi AI tahlili|To‘g‘ri tartib)',
              caseSensitive: false,
            ),
          ),
          findsWidgets,
          reason:
              'Partial or misordered sentence_order / word_match submission must display targeted hint and allow retry.',
        );
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F6 Boundaries
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T2-F6-01: flipping flashcard 5 times without Eslab qoldim grants 0 mastery/completion credit',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        for (var i = 0; i < 5; i++) {
          await revealFlashcard(tester);
          expect(find.text('Yana mashq qilaman'), findsOneWidget);
          await markFlashcardNeedPractice(tester);
        }

        expect(find.text('Flashcard • 0/2'), findsOneWidget);
        expect(
          find.text('Barcha kartochkalar ko‘rib chiqildi!'),
          findsNothing,
        );

        await tapTooltip(tester, 'Ta’lim yo‘liga qaytish');
        await tapText(tester, 'Profil', scroll: false);
        await tapText(tester, 'Fanni o‘zgartirish');
        await expectCourseProgressCount(tester, 'Ingliz tili', 0);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F6-02: repeatedly tapping Yana mashq qilaman keeps cards cycling without crash or empty state',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        for (var i = 0; i < 6; i++) {
          if (i.isEven) {
            expect(find.text("What's your name?"), findsOneWidget);
          } else {
            expect(find.text('Nice to meet you.'), findsOneWidget);
          }
          await revealFlashcard(tester);
          await markFlashcardNeedPractice(tester);
        }

        expect(find.text('Flashcard • 0/2'), findsOneWidget);
        expect(
          find.text('Barcha kartochkalar ko‘rib chiqildi!'),
          findsNothing,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T2-F6-03: missing/broken imageSrc in Image->Word flashcard mode degrades to text/alt fallback',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [createAudioOverride()],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: FlashcardDeckWidget(
                    flashcards: [
                      LessonFlashcard(
                        id: 'fc_broken_img',
                        front: 'Boarding pass',
                        backUz: 'Samolyotga chiqish taloni',
                        backRu: 'Посадочный талон',
                        example: 'Please show your boarding pass at Gate 14.',
                        exampleUz: 'Iltimos, 14-chiqishda taloningizni ko‘rsating.',
                        exampleRu: 'Покажите посадочный талон у выхода 14.',
                        imageSrc: '/lesson-media/english/missing_flashcard.png',
                        alt: 'Airport gate boarding pass illustration',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final imageModeChip = findTextAny(const ['Image → Word', 'Image->Word']);
        expect(
          imageModeChip,
          findsOneWidget,
          reason:
              'Image->Word flashcard mode must exist to verify broken-image graceful degradation.',
        );
        await tester.tap(imageModeChip.first);
        await tester.pumpAndSettle();

        expect(
          findTextAny(const [
            'Airport gate boarding pass illustration',
            'Boarding pass',
          ]),
          findsWidgets,
          reason:
              'Broken/missing imageSrc in Image->Word mode must degrade gracefully to alt/text fallback.',
        );
        expect(find.text('Javobni ko‘rish'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F6-04: rapidly tapping flashcard audio button resets playback cleanly without errors',
      (tester) async {
        final audioHarness = AudioTestHarness();
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          overrides: [audioHarness.buildOverride()],
        );
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        final audioBtn = find.byTooltip('Talaffuzni tinglash');
        for (var i = 0; i < 5; i++) {
          await tester.tap(audioBtn);
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();

        expect(audioHarness.latestController?.replayCalls, 5);
        expect(find.text('Javobni ko‘rish'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T2-F6-05: empty/all-mastered SRS due queue displays friendly completion and Random practice option',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await advanceLessonStep(tester);

        // Complete all due starter flashcards so due queue drops to zero.
        for (var i = 0; i < 2; i++) {
          await revealFlashcard(tester);
          await markFlashcardRemembered(tester);
        }
        await tapTooltip(tester, 'Ta’lim yo‘liga qaytish');

        final srsEntryFinder = findTextAny(const [
          'SRS Takrorlash',
          'Tasodifiy mashq',
          'Flashcard Takrorlash',
          'Random',
        ]);
        await scrollUntilFoundOrEnd(tester, srsEntryFinder);
        expect(
          srsEntryFinder,
          findsWidgets,
          reason:
              'Standalone SRS review entry with Random practice fallback for empty due queue must be available.',
        );
        await tester.tap(srsEntryFinder.first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            RegExp(r'(Barcha kartochka|Navbat bo‘sh|Tasodifiy mashq|Random)', caseSensitive: false),
          ),
          findsWidgets,
        );
        verifyNoExceptions(tester);
      },
    );

    // -------------------------------------------------------------------------
    // F7 Boundaries
    // -------------------------------------------------------------------------
    testWidgets(
      '[M1] T2-F7-01: empty or whitespace-only message in Yo‘lchi AI is ignored cleanly',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await advanceLessonStep(tester);
        await tapTooltip(tester, 'Yo‘lchidan so‘rash');

        expect(find.byType(YolchiBubble), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '   \n\t  ');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
        await tester.pumpAndSettle();

        expect(find.byType(YolchiBubble), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F7-02: pressing Escape inside Yo‘lchi AI closes cleanly and returns to exact lesson step',
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

        await tapTooltip(tester, 'Yo‘lchidan so‘rash');
        expect(find.byType(AITutorScreen), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(
          find.byType(AITutorScreen),
          findsNothing,
          reason:
              'Pressing Escape inside Yo‘lchi AI must dismiss the AI overlay and return to the lesson.',
        );
        expect(findLessonStepCounter(4, 4), findsOneWidget);
        expect(
          tester.widget<TextField>(inputFinder).controller?.text,
          "I'm Sam",
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F7-03: asking "To‘g‘ri javobni ayt" during active exercise scaffolds without leaking answer key',
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

        await tapTooltip(tester, 'Yo‘lchidan so‘rash');
        await tester.enterText(
          find.byType(TextField).last,
          'To‘g‘ri javobni ayt',
        );
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
        await pumpFrames(tester, count: 25, step: const Duration(milliseconds: 50));

        expect(find.byType(YolchiBubble), findsNWidgets(3));
        expect(
          findTextMatching("I'm Sam", findRichText: true),
          findsNothing,
        );
        expect(
          findTextMatching('My name is Sam', findRichText: true),
          findsNothing,
        );
        expect(
          findTextMatching('qadam-baqadam', findRichText: true),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F7-04: very long prompt (>500 chars) in Yo‘lchi AI renders on 390px viewport without overflow',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.mobile390);
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');
        await tapTooltip(tester, 'Yo‘lchidan so‘rash');

        final longPrompt = List.filled(
          12,
          'Hello! How do I introduce myself politely in English?',
        ).join(' ');
        expect(longPrompt.length, greaterThan(500));

        await tester.enterText(find.byType(TextField).last, longPrompt);
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
        await pumpFrames(tester, count: 25, step: const Duration(milliseconds: 50));

        expect(find.byType(YolchiBubble), findsWidgets);
        expect(
          findTextMatching('qadam-baqadam', findRichText: true),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T2-F7-05: Yo‘lchi AI network failure shows friendly error + retry and preserves lesson progress',
      (tester) async {
        final aiService = FakeFailingAiTutorService(shouldFail: true);
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          overrides: [aiTutorServiceProvider.overrideWithValue(aiService)],
        );
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

        await tapTooltip(tester, 'Yo‘lchidan so‘rash');
        await tester.enterText(find.byType(TextField).last, 'Hello?');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
        await tester.pumpAndSettle();

        expect(
          findTextMatching(
            'Yo‘lchi AI xizmatiga ulanib bo‘lmadi.',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(find.text('Qayta urinish'), findsOneWidget);

        aiService.shouldFail = false;
        await tapText(tester, 'Qayta urinish', settle: false);
        await pumpFrames(tester, count: 25, step: const Duration(milliseconds: 50));
        expect(
          findTextMatching('qadam-baqadam', findRichText: true),
          findsOneWidget,
        );

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(findLessonStepCounter(4, 4), findsOneWidget);
        expect(
          tester.widget<TextField>(inputFinder).controller?.text,
          "I'm Sam",
        );
        verifyNoExceptions(tester);
      },
    );
  });
}
