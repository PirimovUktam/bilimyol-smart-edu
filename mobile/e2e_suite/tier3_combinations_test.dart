import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/core/widgets/app_card.dart';
import 'package:bilimyol_mobile/domain/entities/lesson_media.dart';
import 'package:bilimyol_mobile/features/ai_tutor/ai_tutor_screen.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/lesson/lesson_media_widget.dart';

import 'helpers.dart';

void registerTier3Tests() {
  group('Tier 3 — Pairwise Cross-Feature Combinations', () {
    testWidgets(
      '[M1] T3-01: mobile390 x dark theme x lesson_eng_starter with zero overflow',
      (tester) async {
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.mobile390,
          brightness: Brightness.dark,
        );
        await enterDemoMode(tester);
        await selectCourse(tester, 'course_eng_01');
        await tapText(tester, 'Noldan boshlayman');
        await tapText(tester, 'Birinchi darsni boshlash');

        final lessonElement = tester.element(
          find.byType(InteractiveLessonScreen),
        );
        expect(
          Theme.of(lessonElement).brightness,
          Brightness.dark,
          reason:
              'BilimYolApp must configure darkTheme so Brightness.dark applies at 390px.',
        );

        await advanceLessonStep(tester);
        await advanceLessonStep(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        await advanceLessonStep(tester);
        await submitFreeTextAnswer(tester, "I'm Sam");

        expect(find.text('Mening ta’lim yo‘lim'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T3-02: desktop1440 & mobile390 x light theme x grouped CEFR A1-B1 + B2-C2 DEFERRED roadmap with zero overflow',
      (tester) async {
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          brightness: Brightness.light,
        );
        await enterDemoMode(tester);
        await openEnglishRoadmapViaOnboarding(tester);

        final roadmapContext = tester.element(
          find.text('Mening ta’lim yo‘lim'),
        );
        expect(Theme.of(roadmapContext).brightness, Brightness.light);
        expect(find.text('CEFR A1–B1 marshruti'), findsOneWidget);

        for (final levelTitle in const [
          'A1 — Elementar daraja',
          'A2 — Boshlang‘ichdan yuqori daraja',
          'B1 — O‘rta daraja',
        ]) {
          final finder = find.text(levelTitle);
          await scrollUntilFoundOrEnd(tester, finder, maxScrolls: 60);
          expect(
            finder,
            findsOneWidget,
            reason:
                'Desktop 1440px roadmap must display active CEFR group "$levelTitle".',
          );
        }
        await expectDeferredCefrLevelsRendered(tester);
        verifyNoExceptions(tester);

        // Switch to mobile390 in light theme, scroll back up, and open an active lesson cleanly.
        await setSurfaceSize(tester, ViewportPreset.mobile390);
        await tester.pumpAndSettle();
        verifyNoExceptions(tester);

        final scrollable = find.byType(Scrollable);
        for (var i = 0; i < 20; i++) {
          if (find.text('CEFR A1–B1 marshruti').evaluate().isNotEmpty) break;
          if (scrollable.evaluate().isEmpty) break;
          await tester.drag(scrollable.first, const Offset(0, 600));
          await tester.pump();
        }
        await openRoadmapNodeAction(
          tester,
          'Salomlashish va so‘zlarni moslash',
        );
        expect(find.byType(InteractiveLessonScreen), findsOneWidget);
        final lessonContext = tester.element(
          find.byType(InteractiveLessonScreen),
        );
        expect(Theme.of(lessonContext).brightness, Brightness.light);
        expect(find.textContaining('Qadam 1 /'), findsOneWidget);
        expect(find.byTooltip('Ta’lim yo‘liga qaytish'), findsOneWidget);
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T3-03: ru UI locale x en media audio language keeps lesson speech English',
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

        expect(find.byType(LessonMediaWidget), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(
          find.text('Диалог знакомства Азизы и Бена'),
          findsOneWidget,
          reason:
              'Russian locale must propagate to BilimYolApp so LessonMediaWidget renders Russian title/controls.',
        );
        expect(
          find.text('Текст'),
          findsOneWidget,
          reason: 'Russian locale must localize transcript toggle to "Текст".',
        );
        expect(
          find.text('Шаг 2 / 4'),
          findsOneWidget,
          reason: 'Russian locale must localize step counter to "Шаг 2 / 4".',
        );

        await toggleAudioTranscript(tester);
        expect(
          findTextMatching('Aziza:', findRichText: true),
          findsOneWidget,
        );
        expect(
          findTextMatching('Ben:', findRichText: true),
          findsOneWidget,
        );

        // Verify Russian Yo‘lchi AI UI chrome and response inside ru mode.
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
          'Когда используется Hello?',
        );
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
        await pumpFrames(tester, count: 25, step: const Duration(milliseconds: 50));
        expect(
          findTextMatching('шаг за шагом', findRichText: true),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Part B: Verify lesson_eng_listening_01 in ru UI mode with en audio & transcript.
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          locale: AppLocalePreset.ru,
        );
        await enterDemoMode(tester);
        await completeEnglishPathThroughGrammar(tester);
        await openRoadmapNodeAction(tester, RegExp(r'^Аудирование$'));
        await advanceLessonStep(tester);

        expect(find.text('English'), findsOneWidget);
        expect(find.text('Текст'), findsOneWidget);
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
      '[M1] T3-04: uz UI locale x keyboard-only navigation (Tab/Enter/Space/Escape, zero pointer taps)',
      (tester) async {
        await pumpBilimYolApp(
          tester,
          viewport: ViewportPreset.desktop1440,
          locale: AppLocalePreset.uz,
        );

        // 1. Welcome -> Enter demo
        await pressTabUntilFocused(
          tester,
          find.text('Namuna hisobi bilan kirish'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // 2. Course selection -> Ingliz tili
        await pressTabUntilFocused(tester, find.text('Ingliz tili'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // 3. Onboarding -> Noldan boshlayman -> Birinchi darsni boshlash
        await pressTabUntilFocused(tester, find.text('Noldan boshlayman'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        await pressTabUntilFocused(
          tester,
          find.text('Birinchi darsni boshlash'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // 4. Step 1 -> Step 2
        await pressTabUntilFocused(tester, find.text('Keyingi qadam'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // 5. Step 2 audio play + replay + Step 3
        await pressTabUntilFocused(tester, find.byTooltip('Tinglash'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await pressTabUntilFocused(tester, find.byTooltip('Qayta tinglash'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await pressTabUntilFocused(tester, find.text('Keyingi qadam'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // 6. Step 3 flashcard reveal & complete
        await pressTabUntilFocused(tester, find.text('Javobni ko‘rish'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await pressTabUntilFocused(tester, find.text('Eslab qoldim'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        await pressTabUntilFocused(tester, find.text('Javobni ko‘rish'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await pressTabUntilFocused(tester, find.text('Eslab qoldim'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        await pressTabUntilFocused(tester, find.text('Keyingi qadam'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // 7. Step 4 free text -> Yo‘lchi Escape close -> submit
        final inputFinder = find.byKey(const Key('free_text_answer_input'));
        await pressTabUntilFocused(tester, inputFinder);
        tester.testTextInput.enterText("I'm Sam");
        await tester.pump();

        await pressTabUntilFocused(tester, find.byTooltip('Yo‘lchidan so‘rash'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(AITutorScreen), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          find.byType(AITutorScreen),
          findsNothing,
          reason:
              'Keyboard-only Escape must close AITutorScreen and return to lesson Step 4.',
        );

        await pressTabUntilFocused(tester, find.text('TEKSHIRISH'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T3-05: delayed/failed audio load shows retry + transcript fallback and recovers cleanly',
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
        expect(
          findTextAny(const [
            'Audio faylni yuklab bo‘lmadi.',
            'Audioni ijro etib bo‘lmadi. Pastdagi matnli bayondan foydalaning.',
          ]),
          findsOneWidget,
        );
        expect(find.text('Qayta urinish'), findsOneWidget);

        await toggleAudioTranscript(tester);
        expect(
          findTextMatching('Aziza:', findRichText: true),
          findsOneWidget,
        );

        audioHarness.failOnLoad = false;
        await tapText(tester, 'Qayta urinish', settle: false);
        expect(find.byTooltip('Tinglash'), findsOneWidget);

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

        // Also verify image fallback rendering (Icons.image_not_supported_outlined + alt text) without collapse.
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
                          id: 't3_broken_img',
                          kind: LessonMediaKind.image,
                          language: LessonMediaLanguage.en,
                          source: '/lesson-media/english/missing_t3_05.png',
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

    testWidgets(
      '[M1] T3-06: course switch (eng <-> math) x simulateAppRestart keeps progress isolated and persistent',
      (tester) async {
        await pumpBilimYolApp(tester, viewport: ViewportPreset.desktop1440);
        await enterDemoMode(tester);
        await completeStarterLessonFlow(tester);

        await selectCourse(tester, 'course_math_01');
        expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);

        await tapText(tester, 'Asoslarini bilaman');
        await tapText(tester, 'Ta’lim yo‘lini ochish');
        await selectCourse(tester, 'course_eng_01');

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );

        await expectCourseProgressCount(tester, 'Ingliz tili', 1);
        await expectCourseProgressCount(tester, 'Matematika', 0);

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final completed =
            (profile['completedLessonIds'] as List<dynamic>? ?? []);
        expect(completed, contains('lesson_eng_starter'));
        expect(completed, isNot(contains('lesson_math_starter')));
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M2] T3-07: flashcard re-queue x Yo‘lchi AI mid-session x restart SRS persistence',
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

        await openAndCloseYolchiAi(
          tester,
          askText: 'What is your name?',
          preserveText: 'Nice to meet you.',
        );

        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);
        expect(find.text("What's your name?"), findsOneWidget);

        await revealFlashcard(tester);
        await markFlashcardRemembered(tester);

        await simulateAppRestart(
          tester,
          viewport: ViewportPreset.desktop1440,
          keepDemoSession: true,
        );

        final snapshot = await readDemoProgressSnapshot();
        final profile = snapshot['profile'] as Map<String, dynamic>? ?? {};
        final srs = profile['flashcardSrsByCourse'] as Map<String, dynamic>?;
        expect(
          srs?['course_eng_01'],
          isNotNull,
          reason:
              'SRS review progress from flashcard session must persist across restart.',
        );
        verifyNoExceptions(tester);
      },
    );

    testWidgets(
      '[M1] T3-08: wrong listening answer -> mistake feedback -> retry 15:15 unlocks Reading node',
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
        expect(find.text('Yo‘lchi AI tahlili'), findsOneWidget);
        await tapText(tester, 'Yo‘lchi AI tahlili');
        expect(find.text('Yo‘lchi bilan xato tahlili'), findsOneWidget);
        await tapText(tester, 'Darsga qaytish');
        expect(find.text('Yo‘lchi bilan xato tahlili'), findsNothing);

        await selectMcqAndSubmit(tester, '15:15 (quarter past three)');
        expect(
          find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          findsOneWidget,
        );

        await tester.scrollUntilVisible(find.text('Reading'), 150);
        expect(find.text('Reading'), findsOneWidget);
        final readingCard = find.ancestor(
          of: find.text('Reading'),
          matching: find.byType(AppCard),
        );
        final startReading = find.descendant(
          of: readingCard.first,
          matching: findTextAny(const ['Boshlash', 'Mashq qilish']),
        );
        expect(
          startReading,
          findsOneWidget,
          reason:
              'Unlocked node_eng_read must expose Boshlash/Mashq qilish and open lesson_eng_reading_01 after Listening.',
        );
        await tester.tap(startReading.first);
        await tester.pumpAndSettle();
        expect(find.text('Asosiy g‘oya va dalil'), findsWidgets);
        verifyNoExceptions(tester);
      },
    );
  });
}
