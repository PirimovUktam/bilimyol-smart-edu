import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';

Future<void> _waitUntil(
  bool Function() condition, {
  int tries = 200,
  String description = 'condition',
}) async {
  for (var i = 0; i < tries; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for: $description');
}

void main() {
  ProviderContainer buildContainer(InMemoryLearnerRepository learnerRepo) {
    final container = ProviderContainer(
      overrides: [
        learnerRepositoryProvider.overrideWithValue(learnerRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  SkillScore lowScore(String courseId, String skillId) => SkillScore(
        skillId: skillId,
        courseId: courseId,
        score: 40,
        lastUpdated: 1000,
        masteryLevel: MasteryLevel.needsRemediation,
        isWeakestFocus: false,
      );

  group('Cross-course selection restore (Regression)', () {
    test('init restores persisted selectedCourseId instead of courses[0]',
        () async {
      final learnerRepo = InMemoryLearnerRepository();
      final profile = await learnerRepo.getProfile();
      await learnerRepo
          .updateProfile(profile.copyWith(selectedCourseId: 'course_eng_01'));

      final container = buildContainer(learnerRepo);
      container.read(courseStateNotifierProvider.notifier);
      await _waitUntil(
        () => !container.read(courseStateNotifierProvider).isLoading,
        description: 'course state to finish loading',
      );

      expect(
        container.read(courseStateNotifierProvider).activeCourse?.id,
        equals('course_eng_01'),
      );
    });

    test('unknown persisted course id falls back to the first course',
        () async {
      final learnerRepo = InMemoryLearnerRepository();
      final profile = await learnerRepo.getProfile();
      await learnerRepo
          .updateProfile(profile.copyWith(selectedCourseId: 'course_missing_99'));

      final container = buildContainer(learnerRepo);
      container.read(courseStateNotifierProvider.notifier);
      await _waitUntil(
        () => !container.read(courseStateNotifierProvider).isLoading,
        description: 'course state to finish loading',
      );

      expect(
        container.read(courseStateNotifierProvider).activeCourse?.id,
        equals('course_math_01'),
      );
    });
  });

  group('startLesson resilience (Regression)', () {
    test('unknown lesson id yields a null session instead of throwing',
        () async {
      final container = buildContainer(InMemoryLearnerRepository());
      final notifier = container.read(lessonSessionNotifierProvider.notifier);

      await notifier.startLesson('lesson_does_not_exist_404');

      expect(container.read(lessonSessionNotifierProvider).lesson, isNull);
    });

    test('valid lesson loads with its own course attribution', () async {
      final container = buildContainer(InMemoryLearnerRepository());
      final notifier = container.read(lessonSessionNotifierProvider.notifier);

      await notifier.startLesson('lesson_math_functions_01');

      final lesson = container.read(lessonSessionNotifierProvider).lesson;
      expect(lesson, isNotNull);
      expect(lesson!.courseId, equals('course_math_01'));
      expect(lesson.skillId, equals('skill_math_functions'));
    });
  });

  group('submitReinforcement node id derivation (Regression)', () {
    test('math lesson derives the legacy reinf_node_math_func from roadmap',
        () async {
      final learnerRepo = InMemoryLearnerRepository();
      await learnerRepo.saveSkillScores('course_math_01', {
        'skill_math_functions': lowScore('course_math_01', 'skill_math_functions'),
      });

      final container = buildContainer(learnerRepo);
      await container
          .read(roadmapStateNotifierProvider.notifier)
          .loadRoadmap('course_math_01');
      await _waitUntil(
        () => container.read(roadmapStateNotifierProvider).value != null,
        description: 'math roadmap to load',
      );

      final session = container.read(lessonSessionNotifierProvider.notifier);
      await session.startLesson('lesson_math_functions_01');
      expect(session.state.lesson, isNotNull);

      final result = await session.submitReinforcement(
        session.state.lesson!.reinforcementExercise.correctIndex,
      );
      expect(result, isNotNull);
      expect(result!.isCorrect, isTrue);

      final profile = await learnerRepo.getProfile();
      expect(
        profile.completedReinforcementIds,
        contains('reinf_node_math_func'),
      );
      expect(
        profile.completedReinforcementIds,
        isNot(contains('reinf_course_math_01_skill_math_functions')),
      );
    });

    test('english lesson derives reinf_node_eng_list and never a math id',
        () async {
      final learnerRepo = InMemoryLearnerRepository();
      await learnerRepo.saveSkillScores('course_eng_01', {
        'skill_eng_listening': lowScore('course_eng_01', 'skill_eng_listening'),
      });

      final container = buildContainer(learnerRepo);
      await container
          .read(roadmapStateNotifierProvider.notifier)
          .loadRoadmap('course_eng_01');
      await _waitUntil(
        () => container.read(roadmapStateNotifierProvider).value != null,
        description: 'english roadmap to load',
      );

      final session = container.read(lessonSessionNotifierProvider.notifier);
      await session.startLesson('lesson_eng_listening_01');
      expect(session.state.lesson, isNotNull);
      expect(session.state.lesson!.courseId, equals('course_eng_01'));

      final result = await session.submitReinforcement(
        session.state.lesson!.reinforcementExercise.correctIndex,
      );
      expect(result, isNotNull);
      expect(result!.isCorrect, isTrue);

      final profile = await learnerRepo.getProfile();
      expect(
        profile.completedReinforcementIds,
        contains('reinf_node_eng_list'),
      );
      expect(
        profile.completedReinforcementIds,
        isNot(contains('reinf_node_math_func')),
      );
      expect(
        profile.completedReinforcementIds,
        isNot(contains('reinf_course_eng_01_skill_eng_listening')),
      );
    });

    test(
        'roadmap from another course is ignored — scoped fallback id is used',
        () async {
      final learnerRepo = InMemoryLearnerRepository();
      await learnerRepo.saveSkillScores('course_eng_01', {
        'skill_eng_listening': lowScore('course_eng_01', 'skill_eng_listening'),
      });

      final container = buildContainer(learnerRepo);
      // Load the MATH roadmap on purpose, then run an ENGLISH lesson:
      // the courseId guard must reject the foreign roadmap.
      await container
          .read(roadmapStateNotifierProvider.notifier)
          .loadRoadmap('course_math_01');
      await _waitUntil(
        () => container.read(roadmapStateNotifierProvider).value != null,
        description: 'math roadmap to load',
      );

      final session = container.read(lessonSessionNotifierProvider.notifier);
      await session.startLesson('lesson_eng_listening_01');
      expect(session.state.lesson, isNotNull);

      final result = await session.submitReinforcement(
        session.state.lesson!.reinforcementExercise.correctIndex,
      );
      expect(result, isNotNull);
      expect(result!.isCorrect, isTrue);

      final profile = await learnerRepo.getProfile();
      expect(
        profile.completedReinforcementIds,
        contains('reinf_course_eng_01_skill_eng_listening'),
      );
      expect(
        profile.completedReinforcementIds,
        isNot(contains('reinf_node_eng_list')),
      );
      expect(
        profile.completedReinforcementIds,
        isNot(contains('reinf_node_math_func')),
      );
    });
  });
}
