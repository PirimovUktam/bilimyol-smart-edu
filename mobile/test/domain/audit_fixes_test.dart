import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_lesson_answer_use_case.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_reinforcement_use_case.dart';

class _DelayedLessonRepository extends InMemoryLessonRepository {
  final pending = <String, Completer<Lesson?>>{};

  @override
  Future<Lesson?> getLessonById(String lessonId) {
    return (pending[lessonId] ??= Completer<Lesson?>()).future;
  }
}

class _ServerScoringRepository extends InMemoryLearnerRepository {
  @override
  Future<AnswerAttemptRecord> recordAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
    required bool isCorrect,
  }) async {
    return AnswerAttemptRecord(
      id: 'server-attempt',
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      // Deliberately disagree with the local correctIndex to model RPC truth.
      isCorrect: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      correctOption: 'serverdagi to‘g‘ri javob',
    );
  }
}

class _ServerRejectedReinforcementRepository extends InMemoryLearnerRepository {
  @override
  Future<AnswerAttemptRecord> submitAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
  }) async {
    return AnswerAttemptRecord(
      id: 'server-rejected',
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      isCorrect: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

}

class _FailingReinforcementRepository extends InMemoryLearnerRepository {
  @override
  Future<ReinforcementCompletionResult?> markReinforcementCompleted({
    required String reinforcementId,
    required String courseId,
    required String skillId,
    required String questionId,
    required int beforeScore,
    required int afterScore,
    required int xpAwarded,
  }) async {
    throw StateError('remote persistence failed');
  }
}

void main() {
  test(
    'lesson answer follows repository/server scoring instead of local index',
    () async {
      final lesson = seedLessons['lesson_math_functions_01']!;
      final question = lesson.steps
          .map((step) => step.interactiveQuestion)
          .where((question) => question != null)
          .cast<Question>()
          .first;
      final repository = _ServerScoringRepository();
      final useCase = SubmitLessonAnswerUseCase(
        DemoAITutorService(),
        repository,
      );

      final result = await useCase.execute(
        question: question,
        lessonId: lesson.id,
        selectedIndex: question.correctIndex,
      );

      expect(result.isCorrect, isFalse);
      expect(result.correctOption, equals('serverdagi to‘g‘ri javob'));
    },
  );

  test(
    'reinforcement answer follows repository/server scoring instead of local index',
    () async {
      final repository = _ServerRejectedReinforcementRepository();
      final lessonRepository = InMemoryLessonRepository();
      final lesson = seedLessons['lesson_math_functions_01']!;
      final useCase = SubmitReinforcementUseCase(repository, lessonRepository);

      final result = await useCase.execute(
        courseId: lesson.courseId,
        skillId: lesson.skillId,
        reinforcementNodeId: 'reinf_node_math_func',
        reinforcementQuestion: lesson.reinforcementExercise,
        selectedIndex: lesson.reinforcementExercise.correctIndex,
      );

      expect(result.isCorrect, isFalse);
      expect(result.xpAwarded, 0);
    },
  );

  test(
    'reinforcement persistence failure is propagated instead of reported as success',
    () async {
      final repository = _FailingReinforcementRepository();
      final lessonRepository = InMemoryLessonRepository();
      final lesson = seedLessons['lesson_math_functions_01']!;
      final useCase = SubmitReinforcementUseCase(repository, lessonRepository);

      await expectLater(
        useCase.execute(
          courseId: lesson.courseId,
          skillId: lesson.skillId,
          reinforcementNodeId: 'reinf_node_math_func',
          reinforcementQuestion: lesson.reinforcementExercise,
          selectedIndex: lesson.reinforcementExercise.correctIndex,
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('stale lesson requests cannot replace the newest lesson session', () async {
    final lessonRepository = _DelayedLessonRepository();
    final container = ProviderContainer(
      overrides: [
        lessonRepositoryProvider.overrideWithValue(lessonRepository),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(lessonSessionNotifierProvider.notifier);
    final staleRequest = notifier.startLesson('lesson_math_functions_01');
    final currentRequest = notifier.startLesson('lesson_eng_listening_01');

    lessonRepository.pending['lesson_eng_listening_01']!
        .complete(seedLessons['lesson_eng_listening_01']);
    await currentRequest;
    lessonRepository.pending['lesson_math_functions_01']!
        .complete(seedLessons['lesson_math_functions_01']);
    await staleRequest;

    expect(
      container.read(lessonSessionNotifierProvider).lesson?.id,
      equals('lesson_eng_listening_01'),
    );
  });
}
