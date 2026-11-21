import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/features/placement/placement_test_screen.dart';

void main() {
  group('Placement Fast-Tap Feedback', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('PlacementStateNotifier sets notice when throttled < 800ms and clears on clearNotice', () async {
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(placementStateNotifierProvider.notifier);
      await notifier.loadQuestions('course_math_01');
      await notifier.submitAnswer(0);
      expect(container.read(placementStateNotifierProvider).submissions.length, 1);

      final throttled = await notifier.submitAnswer(0);
      expect(throttled, isFalse);
      final afterThrottle = container.read(placementStateNotifierProvider);
      expect(afterThrottle.submissions.length, 1);
      expect(afterThrottle.notice, isNotNull);
      expect(afterThrottle.notice, contains('bir lahza kuting'));

      notifier.clearNotice();
      expect(container.read(placementStateNotifierProvider).notice, isNull);
    });

    testWidgets('PlacementTestScreen surfaces visible feedback on rapid tap with no pending timers', (tester) async {
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            home: const PlacementTestScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Answer Q1
      final q1 = container.read(placementStateNotifierProvider).currentQuestion!;
      await tester.tap(find.text(q1.options.first));
      await tester.pump();
      await tester.tap(find.text('Keyingi Savol'));
      await tester.pump();

      // Immediately tap Q2 option and submit within 800ms cooldown
      final q2 = container.read(placementStateNotifierProvider).currentQuestion!;
      await tester.tap(find.text(q2.options.first));
      await tester.pump();
      await tester.tap(find.text('Keyingi Savol'));
      await tester.pump();

      expect(
        find.text(AppStrings.uz.placementFastTapNotice),
        findsWidgets,
      );

      // Let TweenAnimationBuilder cooldown finish cleanly
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    test('submitAnswer mid-await loadQuestions aborts stale loadProfile and loadRoadmap', () async {
      final repo = _PausingProfileLearnerRepo();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(placementStateNotifierProvider.notifier);
      await notifier.loadQuestions('course_it');

      // Answer until just before the final question
      while (container.read(placementStateNotifierProvider).questionNumber <
          container.read(placementStateNotifierProvider).totalQuestionsToAsk) {
        final current = container.read(placementStateNotifierProvider);
        // Bypass 800ms throttle in unit test by waiting or testing final step directly
        await Future<void>.delayed(const Duration(milliseconds: 820));
        expect(current.currentQuestion, isNotNull);
        await notifier.submitAnswer(0);
      }

      // On the final question, pause getProfile() inside loadProfile()
      await Future<void>.delayed(const Duration(milliseconds: 820));
      final gate = Completer<void>();
      repo.pauseAfterNextSave = gate;

      final submitFuture = notifier.submitAnswer(0);
      // Wait until getProfile() inside loadProfile() has been entered
      await repo.pausedEntered.future;

      // Switch placement to course_logic mid-await
      await notifier.loadQuestions('course_logic');
      expect(container.read(placementStateNotifierProvider).courseId, 'course_logic');

      // Release paused loadProfile()
      gate.complete();
      final completed = await submitFuture;

      expect(completed, isFalse);
      expect(container.read(placementStateNotifierProvider).courseId, 'course_logic');
      expect(container.read(placementStateNotifierProvider).result, isNull);
      // Stale course_it completion must not trigger loadRoadmap
      expect(container.read(roadmapStateNotifierProvider).valueOrNull, isNull);
    });

    test('submitAnswer mid-await selectCourse without loadQuestions leaves roadmap on newly selected course', () async {
      final repo = _PausingProfileLearnerRepo();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_it');
      final notifier = container.read(placementStateNotifierProvider.notifier);
      await notifier.loadQuestions('course_it');

      while (container.read(placementStateNotifierProvider).questionNumber <
          container.read(placementStateNotifierProvider).totalQuestionsToAsk) {
        await Future<void>.delayed(const Duration(milliseconds: 820));
        await notifier.submitAnswer(0);
      }

      await Future<void>.delayed(const Duration(milliseconds: 820));
      final gate = Completer<void>();
      repo.pauseAfterNextSave = gate;

      final submitFuture = notifier.submitAnswer(0);
      await repo.pausedEntered.future;

      // Switch active course directly without calling placement.loadQuestions()
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(courseStateNotifierProvider).activeCourse?.id,
        'course_eng_01',
      );
      expect(
        container.read(roadmapStateNotifierProvider).valueOrNull?.courseId,
        'course_eng_01',
      );

      gate.complete();
      await submitFuture;
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        container.read(courseStateNotifierProvider).activeCourse?.id,
        'course_eng_01',
      );
      expect(
        container.read(roadmapStateNotifierProvider).valueOrNull?.courseId,
        'course_eng_01',
      );
    });
  });
}

class _PausingProfileLearnerRepo extends InMemoryLearnerRepository {
  Completer<void>? pauseAfterNextSave;
  final Completer<void> pausedEntered = Completer<void>();
  bool _armed = false;

  @override
  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores) async {
    await super.saveSkillScores(courseId, scores);
    if (pauseAfterNextSave != null) {
      _armed = true;
    }
  }

  @override
  Future<LearnerProfile> getProfile() async {
    if (_armed && pauseAfterNextSave != null) {
      _armed = false;
      if (!pausedEntered.isCompleted) pausedEntered.complete();
      await pauseAfterNextSave!.future;
    }
    return super.getProfile();
  }
}
