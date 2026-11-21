import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/starter_lessons_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
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
  Completer<ReinforcementCompletionResult?>? pendingReinforcement;
  bool failCompletion = false;
  int answers = 0;
  int completions = 0;
  int profileLoads = 0;

  @override
  Future<LearnerProfile> getProfile() {
    profileLoads++;
    return super.getProfile();
  }

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
    if (pendingReinforcement != null) {
      return pendingReinforcement!.future;
    }
    return super.markReinforcementCompleted(
      reinforcementId: reinforcementId,
      courseId: courseId,
      skillId: skillId,
      questionId: questionId,
      beforeScore: beforeScore,
      afterScore: afterScore,
      xpAwarded: xpAwarded,
    );
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
        'lesson_math_functions_01': seedLessons['lesson_math_functions_01']!,
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

  test('completing a lesson and submitting quiz refresh learnerStateNotifierProvider & roadmapStateNotifierProvider', () async {
    await container.read(courseStateNotifierProvider.notifier).init();
    await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
    final initialXp = container.read(learnerStateNotifierProvider).valueOrNull?.xp ?? 0;

    await notifier.startLesson('single');
    final loadsBeforeAnswer = repository.profileLoads;
    await answer();

    expect(repository.profileLoads, greaterThan(loadsBeforeAnswer));

    final loadsBeforeComplete = repository.profileLoads;
    await notifier.nextStep();
    await notifier.nextStep();
    expect(session().isCompleted, isTrue);

    expect(repository.profileLoads, greaterThan(loadsBeforeComplete));
    final afterCompleteProfile = container.read(learnerStateNotifierProvider).valueOrNull;
    expect(afterCompleteProfile, isNotNull);
    expect(afterCompleteProfile!.completedLessonIds, contains('single'));
    expect(afterCompleteProfile.xp, greaterThanOrEqualTo(initialXp + 20));
    expect(container.read(roadmapStateNotifierProvider).valueOrNull?.courseId, equals('course_math_01'));
  });

  test('submitReinforcement mid-await selectCourse does not overwrite new course roadmap', () async {
    await container.read(courseStateNotifierProvider.notifier).init();
    await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
    await notifier.startLesson('lesson_math_functions_01');

    final pendingReinf = Completer<ReinforcementCompletionResult?>();
    repository.pendingReinforcement = pendingReinf;

    // Submit correct reinforcement (index 1 matches lesson_math_functions_01)
    final reinfFuture = notifier.submitReinforcement(1);
    await Future<void>.delayed(Duration.zero);

    // Switch course mid-await while submitReinforcement is still pending
    await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(courseStateNotifierProvider).activeCourse?.id, 'course_eng_01');
    expect(container.read(roadmapStateNotifierProvider).valueOrNull?.courseId, 'course_eng_01');

    // Complete reinforcement after course switch
    pendingReinf.complete(null);
    await reinfFuture;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(container.read(courseStateNotifierProvider).activeCourse?.id, 'course_eng_01');
    expect(container.read(roadmapStateNotifierProvider).valueOrNull?.courseId, 'course_eng_01');
  });

  test('PROBE_1B: final-step quiz retry after _completeLesson failure skips duplicate recordAnswerAttempt and refreshes profile', () async {
    final storage = _SelectiveFailSetStorage(failOnWriteNumbers: {2});
    final realRepo = InMemoryLearnerRepository(storage: storage);
    final realContainer = ProviderContainer(overrides: [
      learnerRepositoryProvider.overrideWithValue(realRepo),
      lessonRepositoryProvider.overrideWithValue(_Lessons({
        'lesson_math_starter': starterLessons['lesson_math_starter']!,
      })),
      courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
      aiTutorServiceProvider.overrideWithValue(DemoAITutorService()),
    ]);
    addTearDown(realContainer.dispose);

    await realContainer.read(courseStateNotifierProvider.notifier).init();
    await realContainer.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
    await realContainer.read(learnerStateNotifierProvider.notifier).loadProfile();

    final sessionNotifier = realContainer.read(lessonSessionNotifierProvider.notifier);
    await sessionNotifier.startLesson('lesson_math_starter');
    // Step 1 -> Step 2 -> Step 3 (interactiveQuestion on final step)
    await sessionNotifier.nextStep();
    await sessionNotifier.nextStep();
    sessionNotifier.selectOption(2); // '6' is correct for lesson_math_starter

    storage.resetWriteCount();
    // 1st write (recordAnswerAttempt) succeeds, 2nd write (markLessonCompleted) throws
    await sessionNotifier.submitInteractiveQuiz();

    final afterFail = realContainer.read(lessonSessionNotifierProvider);
    expect(afterFail.isCompleted, isFalse);
    expect(afterFail.isSubmittingAnswer, isFalse);
    expect(afterFail.answerError, isNotNull);
    expect(await realRepo.getAnswerAttempts(), hasLength(1));
    // Profile provider was refreshed even though _completeLesson failed
    expect(
      realContainer.read(learnerStateNotifierProvider).valueOrNull?.xp,
      equals((await realRepo.getProfile()).xp),
    );

    // Retry submitInteractiveQuiz: must NOT duplicate recordAnswerAttempt or +2 XP
    await sessionNotifier.submitInteractiveQuiz();

    final afterRetry = realContainer.read(lessonSessionNotifierProvider);
    expect(afterRetry.isCompleted, isTrue);
    expect(afterRetry.answerError, isNull);
    expect(afterRetry.answerResult?.isCorrect, isTrue);
    expect(await realRepo.getAnswerAttempts(), hasLength(1));
    expect((await realRepo.getProfile()).xp, equals(22));
    expect((await realRepo.getProfile()).completedLessonIds, contains('lesson_math_starter'));
    expect(realContainer.read(learnerStateNotifierProvider).valueOrNull?.xp, equals(22));

    // Verify cold reload matches exact xp=22 and attempts=1
    final reloaded = InMemoryLearnerRepository(storage: storage);
    expect((await reloaded.getProfile()).xp, equals(22));
    expect(await reloaded.getAnswerAttempts(), hasLength(1));

    // Also verify when markLessonCompleted throws before mutating (e.g. RPC failure)
    final rpcRepo = _PreMutationFailCompletionRepo();
    final rpcContainer = ProviderContainer(overrides: [
      learnerRepositoryProvider.overrideWithValue(rpcRepo),
      lessonRepositoryProvider.overrideWithValue(_Lessons({
        'lesson_math_starter': starterLessons['lesson_math_starter']!,
      })),
      courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
      aiTutorServiceProvider.overrideWithValue(DemoAITutorService()),
    ]);
    addTearDown(rpcContainer.dispose);

    await rpcContainer.read(courseStateNotifierProvider.notifier).init();
    await rpcContainer.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
    await rpcContainer.read(learnerStateNotifierProvider.notifier).loadProfile();

    final rpcSession = rpcContainer.read(lessonSessionNotifierProvider.notifier);
    await rpcSession.startLesson('lesson_math_starter');
    await rpcSession.nextStep();
    await rpcSession.nextStep();
    rpcSession.selectOption(2);

    rpcRepo.failCompletion = true;
    await rpcSession.submitInteractiveQuiz();

    expect(rpcContainer.read(lessonSessionNotifierProvider).isCompleted, isFalse);
    expect(rpcContainer.read(lessonSessionNotifierProvider).answerError, isNotNull);
    expect(await rpcRepo.getAnswerAttempts(), hasLength(1));
    expect((await rpcRepo.getProfile()).xp, equals(2));
    expect(rpcContainer.read(learnerStateNotifierProvider).valueOrNull?.xp, equals(2));

    rpcRepo.failCompletion = false;
    await rpcSession.submitInteractiveQuiz();

    expect(rpcContainer.read(lessonSessionNotifierProvider).isCompleted, isTrue);
    expect(await rpcRepo.getAnswerAttempts(), hasLength(1));
    expect((await rpcRepo.getProfile()).xp, equals(22));
    expect(rpcContainer.read(learnerStateNotifierProvider).valueOrNull?.xp, equals(22));
  });

  test('PROBE_1B_6: previousStep/reviewWorkedExample -> nextStep after _completeLesson failure skips duplicate recordAnswerAttempt and +2 XP', () async {
    // 1) previousStep() -> nextStep() after _completeLesson failure on final step
    final rpcRepo = _PreMutationFailCompletionRepo();
    final rpcContainer = ProviderContainer(overrides: [
      learnerRepositoryProvider.overrideWithValue(rpcRepo),
      lessonRepositoryProvider.overrideWithValue(_Lessons({
        'lesson_math_starter': starterLessons['lesson_math_starter']!,
        'multi_final': _lesson('multi_final', questions: ['first', 'second'], trailing: false),
      })),
      courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
      aiTutorServiceProvider.overrideWithValue(DemoAITutorService()),
    ]);
    addTearDown(rpcContainer.dispose);

    await rpcContainer.read(courseStateNotifierProvider.notifier).init();
    await rpcContainer.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
    await rpcContainer.read(learnerStateNotifierProvider.notifier).loadProfile();

    final session = rpcContainer.read(lessonSessionNotifierProvider.notifier);
    await session.startLesson('lesson_math_starter');
    await session.nextStep();
    await session.nextStep();
    session.selectOption(2);

    rpcRepo.failCompletion = true;
    await session.submitInteractiveQuiz();

    expect(rpcContainer.read(lessonSessionNotifierProvider).isCompleted, isFalse);
    expect(rpcContainer.read(lessonSessionNotifierProvider).answerError, isNotNull);
    expect(await rpcRepo.getAnswerAttempts(), hasLength(1));
    expect((await rpcRepo.getProfile()).xp, equals(2));

    // Step backward then forward before retrying
    session.previousStep();
    await session.nextStep();
    session.selectOption(2);
    rpcRepo.failCompletion = false;
    await session.submitInteractiveQuiz();

    expect(rpcContainer.read(lessonSessionNotifierProvider).isCompleted, isTrue);
    expect(rpcContainer.read(lessonSessionNotifierProvider).answerError, isNull);
    expect(await rpcRepo.getAnswerAttempts(), hasLength(1));
    expect((await rpcRepo.getProfile()).xp, equals(22));
    expect(rpcContainer.read(learnerStateNotifierProvider).valueOrNull?.xp, equals(22));

    // 2) reviewWorkedExample() -> nextStep() after storage write #2 failure
    final storage = _SelectiveFailSetStorage(failOnWriteNumbers: {2});
    final realRepo = InMemoryLearnerRepository(storage: storage);
    final realContainer = ProviderContainer(overrides: [
      learnerRepositoryProvider.overrideWithValue(realRepo),
      lessonRepositoryProvider.overrideWithValue(_Lessons({
        'lesson_math_starter': starterLessons['lesson_math_starter']!,
      })),
      courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
      aiTutorServiceProvider.overrideWithValue(DemoAITutorService()),
    ]);
    addTearDown(realContainer.dispose);

    await realContainer.read(courseStateNotifierProvider.notifier).init();
    await realContainer.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
    await realContainer.read(learnerStateNotifierProvider.notifier).loadProfile();

    final realSession = realContainer.read(lessonSessionNotifierProvider.notifier);
    await realSession.startLesson('lesson_math_starter');
    await realSession.nextStep();
    await realSession.nextStep();
    realSession.selectOption(2);

    storage.resetWriteCount();
    await realSession.submitInteractiveQuiz();
    expect(realContainer.read(lessonSessionNotifierProvider).isCompleted, isFalse);
    expect(await realRepo.getAnswerAttempts(), hasLength(1));

    realSession.reviewWorkedExample();
    await realSession.nextStep();
    realSession.selectOption(2);
    await realSession.submitInteractiveQuiz();

    expect(realContainer.read(lessonSessionNotifierProvider).isCompleted, isTrue);
    expect(await realRepo.getAnswerAttempts(), hasLength(1));
    expect((await realRepo.getProfile()).xp, equals(22));

    // 3) Skipped earlier question returns false -> go back, answer step 0, return to step 1 and retry
    await session.startLesson('multi_final');
    await session.nextStep(); // skip step 0 ('first'), land on step 1 ('second')
    session.selectOption(0);
    await session.submitInteractiveQuiz();
    expect(rpcContainer.read(lessonSessionNotifierProvider).isCompleted, isFalse);
    expect(rpcContainer.read(lessonSessionNotifierProvider).answerError, isNotNull);
    expect(await rpcRepo.getAnswerAttempts(), hasLength(2)); // 1 from starter + 1 from 'second'

    session.previousStep(); // back to step 0 ('first')
    session.selectOption(0);
    await session.submitInteractiveQuiz();
    expect(await rpcRepo.getAnswerAttempts(), hasLength(3)); // +1 for 'first'

    await session.nextStep(); // forward to step 1 ('second')
    session.selectOption(0);
    await session.submitInteractiveQuiz();
    expect(rpcContainer.read(lessonSessionNotifierProvider).isCompleted, isTrue);
    // Must NOT re-submit 'second'
    expect(await rpcRepo.getAnswerAttempts(), hasLength(3));
  });
}

class _PreMutationFailCompletionRepo extends InMemoryLearnerRepository {
  bool failCompletion = false;

  @override
  Future<void> markLessonCompleted(String lessonId, {String? courseId}) async {
    if (failCompletion) throw StateError('rpc completion failed');
    await super.markLessonCompleted(lessonId, courseId: courseId);
  }
}

class _SelectiveFailSetStorage extends LocalStorageService {
  final Set<int> failOnWriteNumbers;
  int _writeCount = 0;
  String? _snapshot;

  _SelectiveFailSetStorage({required this.failOnWriteNumbers});

  void resetWriteCount() {
    _writeCount = 0;
  }

  @override
  Future<String?> getDemoLearnerSnapshot() async => _snapshot;

  @override
  Future<void> setDemoLearnerSnapshot(String json) async {
    _writeCount++;
    if (failOnWriteNumbers.contains(_writeCount)) {
      throw StateError('injected failure on write $_writeCount');
    }
    _snapshot = json;
  }

  @override
  Future<void> clearDemoLearnerSnapshot() async {
    _snapshot = null;
  }
}
