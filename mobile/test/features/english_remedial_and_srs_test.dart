import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a2_lessons_data.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/features/lesson/flashcard_deck_widget.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/reinforcement/reinforcement_sheet.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('isFlashcardRecordDue respects nextReviewAt and intervalBucket', () {
    final now = DateTime.utc(2026, 11, 20, 12, 0);
    expect(isFlashcardRecordDue(null, now: now), isTrue);
    expect(
      isFlashcardRecordDue(
        const FlashcardSrsRecord(status: 'need_practice', intervalBucket: 0),
        now: now,
      ),
      isTrue,
    );

    final notDue = FlashcardSrsRecord(
      status: 'remembered',
      reviewCount: 1,
      intervalBucket: 1,
      lastReviewedAt: now.toIso8601String(),
      nextReviewBucket: 'daily',
      nextReviewAt: now.add(const Duration(hours: 20)).toIso8601String(),
    );
    expect(isFlashcardRecordDue(notDue, now: now), isFalse);

    final dueNow = FlashcardSrsRecord(
      status: 'remembered',
      reviewCount: 1,
      intervalBucket: 1,
      lastReviewedAt: now.subtract(const Duration(days: 2)).toIso8601String(),
      nextReviewBucket: 'daily',
      nextReviewAt: now.subtract(const Duration(minutes: 1)).toIso8601String(),
    );
    expect(isFlashcardRecordDue(dueNow, now: now), isTrue);
  });

  testWidgets(
    '2 consecutive wrong submissions surface remedial banner and open ReinforcementSheet in UZ and RU',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_vocab_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InteractiveLessonScreen()),
        ),
      );
      await tester.pumpAndSettle();

      while (find.text('TEKSHIRISH').evaluate().isEmpty) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }

      final q = container
          .read(lessonSessionNotifierProvider)
          .lesson!
          .steps[container.read(lessonSessionNotifierProvider).currentStepIndex]
          .interactiveQuestion!;
      final wrongIdx = (q.correctIndex + 1) % q.options.length;
      final wrongOption = find.text(q.options[wrongIdx]);

      // 1st wrong answer -> no repeated mistake banner yet
      await tester.ensureVisible(wrongOption);
      await tester.tap(wrongOption);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      expect(find.text('Takroriy xato aniqlandi'), findsNothing);

      // 2nd consecutive wrong answer -> remedial banner appears
      await tester.ensureVisible(wrongOption);
      await tester.tap(wrongOption);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();

      expect(find.text('Takroriy xato aniqlandi'), findsOneWidget);
      expect(find.text('Qo‘shimcha mashq'), findsOneWidget);

      await tester.ensureVisible(find.text('Qo‘shimcha mashq'));
      await tester.tap(find.text('Qo‘shimcha mashq'));
      await tester.pumpAndSettle();
      expect(find.byType(ReinforcementSheet), findsOneWidget);
    },
  );

  testWidgets(
    'InteractiveLessonScreen localizes repeated-mistake banner in Russian',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('ru');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_vocab_01', uiLocale: 'ru');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InteractiveLessonScreen()),
        ),
      );
      await tester.pumpAndSettle();

      while (find.text('Проверить').evaluate().isEmpty) {
        await tester.tap(find.text('Следующий шаг'));
        await tester.pumpAndSettle();
      }

      final q = container
          .read(lessonSessionNotifierProvider)
          .lesson!
          .steps[container.read(lessonSessionNotifierProvider).currentStepIndex]
          .interactiveQuestion!;
      final wrongIdx = (q.correctIndex + 1) % q.options.length;
      final wrongOption = find.text(q.options[wrongIdx]);

      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.ensureVisible(wrongOption);
        await tester.tap(wrongOption);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Проверить'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Повторная ошибка'), findsOneWidget);
      expect(find.text('Дополнительное упражнение'), findsOneWidget);
    },
  );

  testWidgets(
    'RoadmapScreen shows CEFR A1-B1, DEFERRED B2-C2 without raw IDs, targeted practice badge, and filters SRS to unlocked lessons',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await container.read(learnerRepositoryProvider).saveSkillScores(
        'course_eng_01',
        const {
          'skill_eng_vocab': SkillScore(
            skillId: 'skill_eng_vocab',
            courseId: 'course_eng_01',
            score: 60,
            lastUpdated: 1000,
            masteryLevel: MasteryLevel.proficient,
          ),
        },
      );
      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container
          .read(roadmapStateNotifierProvider.notifier)
          .loadRoadmap('course_eng_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RoadmapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CEFR A1–B1 marshruti'), findsOneWidget);
      expect(find.text('CEFR A1–C2 marshruti'), findsNothing);
      expect(find.text('Maqsadli mashq'), findsWidgets);

      // Open SRS modal while A2/B1 are locked -> A2/B1 flashcards must be excluded
      await tester.tap(find.text('SRS Takrorlash'));
      await tester.pumpAndSettle();
      final deckFinder = find.byType(FlashcardDeckWidget);
      expect(deckFinder, findsOneWidget);
      final deckWidget = tester.widget<FlashcardDeckWidget>(deckFinder);
      final a2FirstId = a2AllFlashcards.first.id;
      expect(
        deckWidget.allCourseFlashcards.any((c) => c.id == a2FirstId),
        isFalse,
      );
      expect(
        deckWidget.allCourseFlashcards.length,
        lessThan(a1AllFlashcards.length + a2AllFlashcards.length),
      );
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Scroll to B2-C2 DEFERRED tiles and tap B2 -> no raw 'node_eng_b1_exit' leaked
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('B2 — O‘rtadan yuqori daraja'),
        300,
        scrollable: scrollable,
        maxScrolls: 80,
      );
      expect(find.text('Keyingi bosqich (DEFERRED)'), findsWidgets);
      await tester.tap(find.text('B2 — O‘rtadan yuqori daraja'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('node_eng_b1_exit'), findsNothing);
      expect(find.textContaining('DEFERRED'), findsWidgets);
    },
  );

  testWidgets(
    'Immediate TEKSHIRISH tap after correct Step 2 in lesson_eng_a1_exit is not blocked by SnackBar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_a1_exit');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InteractiveLessonScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Advance Step 1 (audio) -> Step 2 (listening MCQ)
      await tester.tap(find.text('Keyingi qadam'));
      await tester.pumpAndSettle();
      expect(find.text('Qadam 2 / 5'), findsOneWidget);

      // Answer Step 2 correctly and submit
      await tester.ensureVisible(find.text('20:30'));
      await tester.tap(find.text('20:30'));
      await tester.pump();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Immediately on Step 3 (NO 5s delay): feedback is visible and does not obscure TEKSHIRISH
      expect(find.text('Qadam 3 / 5'), findsOneWidget);
      expect(find.text('To‘g‘ri javob!'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('free_text_answer_input')),
        'open',
      );
      await tester.pump();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        container
            .read(lessonSessionNotifierProvider)
            .consecutiveMistakesBySkill['skill_eng_grammar'],
        equals(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
