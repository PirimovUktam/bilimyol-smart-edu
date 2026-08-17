import 'package:flutter_test/flutter_test.dart';
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
  });
}
