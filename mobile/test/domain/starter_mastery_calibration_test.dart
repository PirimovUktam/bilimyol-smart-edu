import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/personalization/skill_scoring_engine.dart';

void main() {
  group('Starter Mastery Calibration', () {
    test('answering 1 starter question correctly calibrates score <= 55% (not 100%)', () async {
      final repo = InMemoryLearnerRepository();
      await repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_starter',
        questionId: 'q_lesson_math_starter_quiz',
        selectedIndex: 2,
        selectedAnswer: '6',
        isCorrect: true,
      );

      final profile = await repo.getProfile();
      final algebra = profile.scoresByCourse['course_math_01']?['skill_math_algebra'];
      expect(algebra, isNotNull);
      expect(algebra!.score, lessThanOrEqualTo(SkillScoringEngine.starterOnlyMaxScore));
      expect(algebra.score, greaterThan(0));
      expect(algebra.masteryLevel, equals(MasteryLevel.developing));
    });

    test('blends lesson attempts with prior quick-demo/diagnostic baseline without erasing it', () async {
      final repo = InMemoryLearnerRepository();
      await repo.saveSkillScores('course_math_01', {
        'skill_math_algebra': const SkillScore(
          skillId: 'skill_math_algebra',
          courseId: 'course_math_01',
          score: 82,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.mastered,
        ),
        'skill_math_functions': const SkillScore(
          skillId: 'skill_math_functions',
          courseId: 'course_math_01',
          score: 41,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.developing,
        ),
      });

      // Starter answer on already-proficient Algebra must not overwrite 82%
      await repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_starter',
        questionId: 'q_lesson_math_starter_quiz',
        selectedIndex: 2,
        selectedAnswer: '6',
        isCorrect: true,
      );
      var profile = await repo.getProfile();
      expect(
        profile.scoresByCourse['course_math_01']?['skill_math_algebra']?.score,
        equals(82),
      );

      // Regular lesson answer on 41% Functions blends gradually instead of jumping to 100%
      await repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        lessonId: 'lesson_math_functions_01',
        questionId: 'q_math_func_03_step',
        selectedIndex: 1,
        selectedAnswer: '11',
        isCorrect: true,
      );
      profile = await repo.getProfile();
      final funcScore =
          profile.scoresByCourse['course_math_01']?['skill_math_functions']?.score ?? 0;
      expect(funcScore, greaterThan(41));
      expect(funcScore, lessThan(70));
    });

    test('answering a starter question right after failing a regular lesson blends without reverting to prior high score', () async {
      final repo = InMemoryLearnerRepository();
      await repo.saveSkillScores('course_math_01', {
        'skill_math_algebra': const SkillScore(
          skillId: 'skill_math_algebra',
          courseId: 'course_math_01',
          score: 82,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.mastered,
        ),
      });

      // Fail 1 regular algebra question -> drops from 82 to 66
      await repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_algebra_01',
        questionId: 'q_math_alg_01',
        selectedIndex: 0,
        selectedAnswer: 'wrong',
        isCorrect: false,
      );
      var profile = await repo.getProfile();
      final afterWrongRegular =
          profile.scoresByCourse['course_math_01']?['skill_math_algebra']?.score;
      expect(afterWrongRegular, equals(66));

      // Answer 1 starter question right -> blends gradually (~69), never jumping back to 82
      await repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_starter',
        questionId: 'q_lesson_math_starter_quiz',
        selectedIndex: 2,
        selectedAnswer: '6',
        isCorrect: true,
      );
      profile = await repo.getProfile();
      final afterStarterRight =
          profile.scoresByCourse['course_math_01']?['skill_math_algebra']?.score;
      expect(afterStarterRight, equals(69));
      expect(afterStarterRight, lessThan(82));
    });

    test('5 starter failures drop score from 82 to 50 and a single starter pass yields 54 (not 82), while 100% starter pass keeps 82', () async {
      // 100% starter pass preserves prior baseline 82
      expect(
        SkillScoringEngine.computeCalibratedSkillScore(
          weightedCorrect: 0.5,
          weightedTotal: 0.5,
          priorScore: 82,
          hasNonStarterAttempt: false,
        ),
        equals(82),
      );

      // 5 starter failures followed by 1 starter pass via engine
      expect(
        SkillScoringEngine.computeCalibratedSkillScore(
          weightedCorrect: 0.0,
          weightedTotal: 2.5,
          priorScore: 82,
          hasNonStarterAttempt: false,
        ),
        equals(50),
      );
      expect(
        SkillScoringEngine.computeCalibratedSkillScore(
          weightedCorrect: 0.5,
          weightedTotal: 3.0,
          priorScore: 82,
          hasNonStarterAttempt: false,
        ),
        equals(54),
      );

      // Same sequence end-to-end through InMemoryLearnerRepository
      final repo = InMemoryLearnerRepository();
      await repo.saveSkillScores('course_math_01', {
        'skill_math_algebra': const SkillScore(
          skillId: 'skill_math_algebra',
          courseId: 'course_math_01',
          score: 82,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.mastered,
        ),
      });

      for (var i = 0; i < 5; i++) {
        await repo.recordAnswerAttempt(
          courseId: 'course_math_01',
          skillId: 'skill_math_algebra',
          lessonId: 'lesson_math_starter',
          questionId: 'q_lesson_math_starter_quiz',
          selectedIndex: 0,
          selectedAnswer: 'wrong',
          isCorrect: false,
        );
      }
      var profile = await repo.getProfile();
      expect(
        profile.scoresByCourse['course_math_01']?['skill_math_algebra']?.score,
        equals(50),
      );

      await repo.recordAnswerAttempt(
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        lessonId: 'lesson_math_starter',
        questionId: 'q_lesson_math_starter_quiz',
        selectedIndex: 2,
        selectedAnswer: '6',
        isCorrect: true,
      );
      profile = await repo.getProfile();
      final afterOneStarterPass =
          profile.scoresByCourse['course_math_01']?['skill_math_algebra']?.score;
      expect(afterOneStarterPass, equals(54));
      expect(afterOneStarterPass, lessThan(82));
    });

    test('priorScore < 55 caps starter-only mastery at 55 without inverting monotonicity against priorScore = 55', () async {
      final prior54OnePass = SkillScoringEngine.computeCalibratedSkillScore(
        weightedCorrect: 0.5,
        weightedTotal: 0.5,
        priorScore: 54,
        hasNonStarterAttempt: false,
      );
      final prior54TenPasses = SkillScoringEngine.computeCalibratedSkillScore(
        weightedCorrect: 5.0,
        weightedTotal: 5.0,
        priorScore: 54,
        hasNonStarterAttempt: false,
      );
      final prior55TenPasses = SkillScoringEngine.computeCalibratedSkillScore(
        weightedCorrect: 5.0,
        weightedTotal: 5.0,
        priorScore: 55,
        hasNonStarterAttempt: false,
      );

      expect(prior54OnePass, equals(SkillScoringEngine.starterOnlyMaxScore));
      expect(prior54TenPasses, equals(SkillScoringEngine.starterOnlyMaxScore));
      expect(prior54TenPasses, lessThanOrEqualTo(prior55TenPasses));

      final repo = InMemoryLearnerRepository();
      await repo.saveSkillScores('course_math_01', {
        'skill_math_algebra': const SkillScore(
          skillId: 'skill_math_algebra',
          courseId: 'course_math_01',
          score: 54,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.developing,
        ),
      });

      for (var i = 0; i < 10; i++) {
        await repo.recordAnswerAttempt(
          courseId: 'course_math_01',
          skillId: 'skill_math_algebra',
          lessonId: 'lesson_math_starter',
          questionId: 'q_lesson_math_starter_quiz',
          selectedIndex: 2,
          selectedAnswer: '6',
          isCorrect: true,
        );
      }

      final profile = await repo.getProfile();
      final algebra = profile.scoresByCourse['course_math_01']?['skill_math_algebra'];
      expect(algebra?.score, equals(SkillScoringEngine.starterOnlyMaxScore));
      expect(algebra?.masteryLevel, equals(MasteryLevel.developing));
    });
  });
}
