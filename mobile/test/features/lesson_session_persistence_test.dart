import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';

Question _question(String id) => Question(
  id: id, courseId: 'course_math_01', skillId: 'skill_math_functions',
  text: 'Q?', options: const ['A', 'B'], correctIndex: 0,
  difficulty: QuestionDifficulty.easy, explanation: '',
);

Lesson _lesson(String id, {List<String> questions = const ['first'], bool trailing = true}) => Lesson(
  id: id, courseId: 'course_math_01', skillId: 'skill_math_functions',
  title: id, estimatedMinutes: 5, summary: '',
  reinforcementExercise: _question('reinforcement'),
  steps: [
    for (final entry in questions.indexed)
      LessonStep(id: entry.$2, stepNumber: entry.$1 + 1,
        type: LessonStepType.interactiveQuestion, title: entry.$2,
        content: '', interactiveQuestion: _question(entry.$2)),
    if (trailing) LessonStep(id: 'summary', stepNumber: questions.length + 1,
      type: LessonStepType.concept, title: 'Summary', content: 'Done'),
  ],
);

class _Lessons extends InMemoryLessonRepository {
  final Map<String, Lesson> lessons;
  _Lessons(this.lessons);
  @override
  Future<Lesson?> getLessonById(String id) async => lessons[id];
}

class _Learner extends InMemoryLearnerRepository {
  Completer<AnswerAttemptRecord>? pendingAnswer;
  Completer<void>? pendingCompletion;
  bool failCompletion = false;
  int answers = 0;
  int completions = 0;

  @override
  Future<AnswerAttemptRecord> recordAnswerAttempt({
    required String courseId, required String skillId, required String lessonId,
    required String questionId, required int selectedIndex,
    required String selectedAnswer, required bool isCorrect,
  }) async {
    answers++;
    if (pendingAnswer != null) return pendingAnswer!.future;
    return _verified(courseId, skillId, lessonId, questionId);
  }

  @override
  Future<void> markLessonCompleted(String lessonId, {String? courseId}) async {
    completions++;
    if (pendingCompletion != null) await pendingCompletion!.future;
    if (failCompletion) throw StateError('offline');
    await super.markLessonCompleted(lessonId, courseId: courseId);
  }
}

AnswerAttemptRecord _verified(String course, String skill, String lesson, String question) =>
  AnswerAttemptRecord(id: 'verified', courseId: course, skillId: skill,
    lessonId: lesson, questionId: question, selectedIndex: 0,
    selectedAnswer: 'A', isCorrect: true, timestamp: 0);

void main() {
  late _Learner repository;
  late ProviderContainer container;
  late LessonSessionNotifier notifier;

  setUp(() {
    repository = _Learner();
    container = ProviderContainer(overrides: [
      learnerRepositoryProvider.overrideWithValue(repository),
      lessonRepositoryProvider.overrideWithValue(_Lessons({
        'single': _lesson('single'),
        'multi': _lesson('multi', questions: ['first', 'second']),
        'quiz': _lesson('quiz', trailing: false),
        'empty': _lesson('empty', questions: []),
      })),
      courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
      aiTutorServiceProvider.overrideWithValue(DemoAITutorService()),
    ]);
    notifier = container.read(lessonSessionNotifierProvider.notifier);
  });
  tearDown(() => container.dispose());
  LessonSessionState session() => container.read(lessonSessionNotifierProvider);
  Future<void> answer() async {
    notifier.selectOption(0);
    await notifier.submitInteractiveQuiz();
  }

  test('a correct early question cannot finish a multi-step lesson', () async {
    await notifier.startLesson('multi');
    await answer();
    expect(session().isCompleted, isFalse);
    expect(repository.completions, 0);
    expect(session().selectedOptionIndex, 0);
    await notifier.nextStep();
    expect(session().selectedOptionIndex, isNull);
    expect(session().answerResult, isNull);
    await answer();
    await notifier.nextStep();
    await notifier.nextStep();
    expect(session().isCompleted, isTrue);
    expect(repository.completions, 1);
    expect((await repository.getProfile()).completedLessonIds, contains('multi'));
  });

  test('skipping a required question cannot complete at the last step', () async {
    await notifier.startLesson('multi');
    await notifier.nextStep();
    await answer();
    await notifier.nextStep();
    await notifier.nextStep();
    expect(session().isCompleted, isFalse);
    expect(session().answerError, isNotNull);
    expect(repository.completions, 0);
  });

  test('completion write failure remains retryable with no false success', () async {
    await notifier.startLesson('single');
    await answer();
    await notifier.nextStep();
    repository.failCompletion = true;
    await notifier.nextStep();
    expect(session().isCompleted, isFalse);
    expect(session().isSubmittingAnswer, isFalse);
    expect(session().answerError, isNotNull);
    repository.failCompletion = false;
    await notifier.nextStep();
    expect(session().isCompleted, isTrue);
    expect(repository.completions, 2);
  });

  test('pending scoring blocks duplicate submission/navigation and retains selection', () async {
    await notifier.startLesson('single');
    final pending = Completer<AnswerAttemptRecord>();
    repository.pendingAnswer = pending;
    notifier.selectOption(0);
    final submission = notifier.submitInteractiveQuiz();
    await notifier.submitInteractiveQuiz();
    await notifier.nextStep();
    notifier.previousStep();
    expect(repository.answers, 1);
    expect(session().currentStepIndex, 0);
    expect(session().selectedOptionIndex, 0);
    pending.complete(_verified('course_math_01', 'skill_math_functions', 'single', 'first'));
    await submission;
    expect(session().answerResult?.isCorrect, isTrue);
    expect(session().selectedOptionIndex, 0);
  });

  test('old scoring cannot modify a newly started lesson', () async {
    await notifier.startLesson('quiz');
    final pending = Completer<AnswerAttemptRecord>();
    repository.pendingAnswer = pending;
    notifier.selectOption(0);
    final submission = notifier.submitInteractiveQuiz();
    await notifier.startLesson('multi');
    pending.complete(_verified('course_math_01', 'skill_math_functions', 'quiz', 'first'));
    await submission;
    expect(session().lesson?.id, 'multi');
    expect(session().isCompleted, isFalse);
    expect(session().answerResult, isNull);
    expect(repository.completions, 0);
  });

  test('completion failure from an old session cannot overwrite the new session', () async {
    await notifier.startLesson('single');
    await answer();
    await notifier.nextStep();
    final pending = Completer<void>();
    repository.pendingCompletion = pending;
    final completion = notifier.nextStep();
    await notifier.startLesson('multi');
    pending.completeError(StateError('old request offline'));
    await completion;
    expect(session().lesson?.id, 'multi');
    expect(session().isCompleted, isFalse);
    expect(session().answerError, isNull);
    expect(session().isSubmittingAnswer, isFalse);
  });

  test('missing required assessment cannot complete an empty-content lesson', () async {
    await notifier.startLesson('empty');
    await notifier.nextStep();
    expect(repository.completions, 0);
    expect(session().isCompleted, isFalse);
    expect(session().answerError, isNotNull);
  });
}
