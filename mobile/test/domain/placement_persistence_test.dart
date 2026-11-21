import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_placement_test_use_case.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';

void main() {
  group('Placement Persistence Tests (Flutter)', () {
    late InMemoryCourseRepository courseRepo;
    late InMemoryLearnerRepository learnerRepo;
    late SubmitPlacementTestUseCase useCase;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      courseRepo = InMemoryCourseRepository();
      learnerRepo = InMemoryLearnerRepository();
      await learnerRepo.resetAll();
      useCase = SubmitPlacementTestUseCase(courseRepo, learnerRepo);
    });

    test('executes placement test and saves attempt to repository with calculated scores', () async {
      final questions = await courseRepo.getPlacementQuestions('course_math_01');
      expect(questions.isNotEmpty, isTrue);

      final submissions = questions.take(4).map((q) {
        return QuestionAnswerSubmission(
          questionId: q.id,
          selectedIndex: q.correctIndex,
          isCorrect: true,
        );
      }).toList();

      final result = await useCase.execute('course_math_01', submissions);

      expect(result.assessmentId.isNotEmpty, isTrue);
      expect(result.submissions.length, equals(4));
      expect(result.computedScores.isNotEmpty, isTrue);

      final profile = await learnerRepo.getProfile();
      // 4 correct answers (+8 XP) + placement completion (+20 XP) = 28 XP
      expect(profile.xp, equals(28));
      expect(profile.scoresByCourse.containsKey('course_math_01'), isTrue);

      final attempts = await learnerRepo.getAnswerAttempts(10);
      expect(attempts.length, equals(4));
    });

    test('isolates course_eng_01 placement from scoresByCourse and persists placementSummary across reloads', () async {
      final engQuestions = await courseRepo.getPlacementQuestions('course_eng_01');
      final a1AndA2 = engQuestions
          .where((q) => q.difficulty != QuestionDifficulty.hard)
          .toList();
      expect(a1AndA2.length, equals(8));

      final submissions = a1AndA2
          .map(
            (q) => QuestionAnswerSubmission(
              questionId: q.id,
              selectedIndex: q.correctIndex,
              isCorrect: true,
            ),
          )
          .toList();

      final result = await useCase.execute('course_eng_01', submissions);
      expect(result.overallScore, equals(100));
      expect(result.cefrLevel, equals('B1'));

      final profile = await learnerRepo.getProfile();
      expect(profile.placementScoreByCourse['course_eng_01'], equals(100));
      expect(profile.placementCefrByCourse['course_eng_01'], equals('B1'));
      expect(profile.scoresByCourse['course_eng_01'], isNull);
      expect(profile.completedLessonIds, isEmpty);
      expect(profile.completedNodeIds, isEmpty);

      // Re-instantiate repository to verify SharedPreferences round-trip
      final reloadedRepo = InMemoryLearnerRepository();
      final reloaded = await reloadedRepo.getProfile();
      expect(reloaded.placementScoreByCourse['course_eng_01'], equals(100));
      expect(reloaded.placementCefrByCourse['course_eng_01'], equals('B1'));
      expect(reloaded.scoresByCourse['course_eng_01'], isNull);

      // Independent lesson attempt deduplicates by questionId and ignores placement_test
      await reloadedRepo.recordAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        selectedIndex: 0,
        selectedAnswer: 'Sam',
        isCorrect: false,
      );
      await reloadedRepo.recordAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        selectedIndex: 0,
        selectedAnswer: "I'm Sam",
        isCorrect: true,
      );
      final afterRetry = await reloadedRepo.getProfile();
      expect(
        afterRetry.scoresByCourse['course_eng_01']?['skill_eng_vocab']?.score,
        equals(100),
      );
    });
  });
}
