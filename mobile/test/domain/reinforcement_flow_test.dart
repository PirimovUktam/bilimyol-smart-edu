import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/domain/personalization/progress_engine.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_reinforcement_use_case.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';

void main() {
  group('ReinforcementFlow Tests', () {
    test('calculates new XP idempotently and prevents duplicate XP awarding', () {
      // 1. Initial completion
      final firstCalc = ProgressEngine.calculateNewXP(
        currentXP: 100,
        actionType: 'reinforcement_completion',
        actionId: 'reinf_01',
        completedActionIds: [],
      );

      expect(firstCalc.newXP, equals(130)); // +30 XP
      expect(firstCalc.wasAwarded, isTrue);

      // 2. Duplicate submission
      final duplicateCalc = ProgressEngine.calculateNewXP(
        currentXP: 130,
        actionType: 'reinforcement_completion',
        actionId: 'reinf_01',
        completedActionIds: ['reinf_01'],
      );

      expect(duplicateCalc.newXP, equals(130)); // No extra XP
      expect(duplicateCalc.wasAwarded, isFalse);
    });

    test('executes reinforcement usecase and successfully upgrades skill score from 41% to 63%', () async {
      final learnerRepo = InMemoryLearnerRepository();
      final lessonRepo = InMemoryLessonRepository();

      // Pre-seed 41% for functions
      await learnerRepo.saveSkillScores('course_math_01', {
        'skill_math_functions': const SkillScore(
          skillId: 'skill_math_functions',
          courseId: 'course_math_01',
          score: 41,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.needsRemediation,
          isWeakestFocus: true,
        ),
      });

      final useCase = SubmitReinforcementUseCase(learnerRepo, lessonRepo);
      final lesson = seedLessons['lesson_math_functions_01']!;

      // Answer correctly: Option '8' (index 1)
      final result = await useCase.execute(
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        reinforcementNodeId: 'reinf_node_math_func',
        reinforcementQuestion: lesson.reinforcementExercise,
        selectedIndex: 1,
      );

      expect(result.isCorrect, isTrue);
      expect(result.oldScore, equals(41));
      expect(result.newScore, equals(63));
      expect(result.xpAwarded, equals(30));

      final updatedProfile = await learnerRepo.getProfile();
      final updatedScore = updatedProfile.scoresByCourse['course_math_01']?['skill_math_functions'];
      expect(updatedScore?.score, equals(63));
      expect(updatedProfile.completedReinforcementIds, contains('reinf_node_math_func'));
    });
  });
}
