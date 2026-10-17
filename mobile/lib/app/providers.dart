import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/supabase_course_repository.dart';
import '../data/repositories/supabase_lesson_repository.dart';
import '../domain/repositories/i_course_repository.dart';
import '../domain/repositories/i_learner_repository.dart';
import '../domain/repositories/i_lesson_repository.dart';
import '../domain/usecases/select_course_use_case.dart';
import '../domain/usecases/submit_placement_test_use_case.dart';
import '../domain/usecases/get_knowledge_map_use_case.dart';
import '../domain/usecases/get_roadmap_use_case.dart';
import '../domain/usecases/start_lesson_use_case.dart';
import '../domain/usecases/submit_lesson_answer_use_case.dart';
import '../domain/usecases/submit_reinforcement_use_case.dart';
import '../domain/usecases/reset_demo_use_case.dart';
import '../domain/entities/course.dart';
import '../domain/entities/skill.dart';
import '../domain/entities/learner_profile.dart';
import '../domain/entities/question.dart';
import '../domain/entities/learning_path_node.dart';
import '../domain/entities/lesson.dart';
import '../domain/personalization/adaptive_question_selector.dart';

import '../data/services/i_ai_tutor_service.dart';
import '../data/services/supabase_ai_tutor_service.dart';
import '../data/repositories/supabase_learner_repository.dart';

// --- Singleton Service & Repository Providers ---
final aiTutorServiceProvider = Provider<IAITutorService>(
  (ref) => SupabaseAITutorService(),
);
final courseRepositoryProvider = Provider<ICourseRepository>(
  (ref) => SupabaseCourseRepository(),
);
final lessonRepositoryProvider = Provider<ILessonRepository>(
  (ref) => SupabaseLessonRepository(),
);
final learnerRepositoryProvider = Provider<ILearnerRepository>(
  (ref) => SupabaseLearnerRepository(),
);

// --- UseCase Providers ---
final selectCourseUseCaseProvider = Provider(
  (ref) => SelectCourseUseCase(
    ref.watch(courseRepositoryProvider),
    ref.watch(learnerRepositoryProvider),
  ),
);

final submitPlacementTestUseCaseProvider = Provider(
  (ref) => SubmitPlacementTestUseCase(
    ref.watch(courseRepositoryProvider),
    ref.watch(learnerRepositoryProvider),
  ),
);

final getKnowledgeMapUseCaseProvider = Provider(
  (ref) => GetKnowledgeMapUseCase(
    ref.watch(courseRepositoryProvider),
    ref.watch(learnerRepositoryProvider),
  ),
);

final getRoadmapUseCaseProvider = Provider(
  (ref) => GetRoadmapUseCase(
    ref.watch(lessonRepositoryProvider),
    ref.watch(learnerRepositoryProvider),
  ),
);

final startLessonUseCaseProvider = Provider(
  (ref) => StartLessonUseCase(ref.watch(lessonRepositoryProvider)),
);

final submitLessonAnswerUseCaseProvider = Provider(
  (ref) => SubmitLessonAnswerUseCase(
    ref.watch(aiTutorServiceProvider),
    ref.watch(learnerRepositoryProvider),
  ),
);

final submitReinforcementUseCaseProvider = Provider(
  (ref) => SubmitReinforcementUseCase(
    ref.watch(learnerRepositoryProvider),
    ref.watch(lessonRepositoryProvider),
  ),
);

final resetDemoUseCaseProvider = Provider(
  (ref) => ResetDemoUseCase(ref.watch(learnerRepositoryProvider)),
);

// --- State Notifiers ---

// 1. Learner Profile Notifier
class LearnerStateNotifier extends StateNotifier<AsyncValue<LearnerProfile>> {
  final Ref ref;
  int _loadGeneration = 0;

  LearnerStateNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  // Session-triggered refreshes must not publish after that session is replaced.
  Future<void> loadProfile({bool Function()? isCurrent}) async {
    final generation = ++_loadGeneration;
    try {
      final repo = ref.read(learnerRepositoryProvider);
      final profile = await repo.getProfile();
      if (!mounted ||
          generation != _loadGeneration ||
          isCurrent?.call() == false) {
        return;
      }
      state = AsyncValue.data(profile);
    } catch (e, st) {
      if (!mounted ||
          generation != _loadGeneration ||
          isCurrent?.call() == false) {
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateOnboarding({
    required OnboardingGoal goal,
    required int dailyMinutes,
    required InitialLevel initialLevel,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(
      goal: goal,
      dailyMinutes: dailyMinutes,
      initialLevel: initialLevel,
    );

    final repo = ref.read(learnerRepositoryProvider);
    await repo.updateProfile(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> resetAll() async {
    state = const AsyncValue.loading();
    final resetUseCase = ref.read(resetDemoUseCaseProvider);
    final resetProfile = await resetUseCase.execute();
    state = AsyncValue.data(resetProfile);
    ref.invalidate(courseStateNotifierProvider);
    ref.invalidate(roadmapStateNotifierProvider);
  }
}

final learnerStateNotifierProvider =
    StateNotifierProvider<LearnerStateNotifier, AsyncValue<LearnerProfile>>((
      ref,
    ) {
      return LearnerStateNotifier(ref);
    });

// 2. Course State Notifier
class CourseState {
  final List<Course> courses;
  final Course? activeCourse;
  final List<Skill> activeSkills;
  final bool isLoading;

  const CourseState({
    required this.courses,
    this.activeCourse,
    required this.activeSkills,
    this.isLoading = false,
  });

  CourseState copyWith({
    List<Course>? courses,
    Course? activeCourse,
    List<Skill>? activeSkills,
    bool? isLoading,
  }) {
    return CourseState(
      courses: courses ?? this.courses,
      activeCourse: activeCourse ?? this.activeCourse,
      activeSkills: activeSkills ?? this.activeSkills,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CourseStateNotifier extends StateNotifier<CourseState> {
  final Ref ref;
  int _initGeneration = 0;

  CourseStateNotifier(this.ref)
    : super(const CourseState(courses: [], activeSkills: [], isLoading: true)) {
    init();
  }

  Future<void> init() async {
    final generation = ++_initGeneration;
    final courseRepo = ref.read(courseRepositoryProvider);
    final allCourses = await courseRepo.getAllCourses();
    if (!mounted || generation != _initGeneration) return;

    // Restore the persisted course selection (server/local profile truth)
    // instead of always resetting to courses[0].
    Course? restored;
    try {
      final learnerRepo = ref.read(learnerRepositoryProvider);
      final profile = await learnerRepo.getProfile();
      if (!mounted || generation != _initGeneration) return;
      final selectedId = profile.selectedCourseId;
      if (selectedId.isNotEmpty) {
        restored = allCourses.where((c) => c.id == selectedId).firstOrNull;
      }
    } catch (_) {
      // Restore is best-effort — fall back to the first course below.
    }

    final active = restored ?? allCourses.firstOrNull;

    List<Skill> skills = [];
    if (active != null) {
      skills = await courseRepo.getSkillsByCourseId(active.id);
      if (!mounted || generation != _initGeneration) return;
    }

    state = CourseState(
      courses: allCourses,
      activeCourse: active,
      activeSkills: skills,
      isLoading: false,
    );

    if (active != null) {
      ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(active.id);
    }
  }

  Future<void> selectCourse(String courseId) async {
    if (!mounted || state.isLoading) return;
    state = state.copyWith(isLoading: true);
    final selectUseCase = ref.read(selectCourseUseCaseProvider);
    final course = await selectUseCase.execute(courseId);
    if (!mounted) return;
    final courseRepo = ref.read(courseRepositoryProvider);
    final skills = await courseRepo.getSkillsByCourseId(course.id);

    state = state.copyWith(
      activeCourse: course,
      activeSkills: skills,
      isLoading: false,
    );

    // Refresh learner & roadmap
    ref.read(learnerStateNotifierProvider.notifier).loadProfile();
    ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(course.id);
  }
}

final courseStateNotifierProvider =
    StateNotifierProvider<CourseStateNotifier, CourseState>((ref) {
      return CourseStateNotifier(ref);
    });

// 3. Placement Test State Notifier
const courseTargetSkills = <String, List<String>>{
  'course_math_01': [
    'skill_math_algebra',
    'skill_math_equations',
    'skill_math_functions',
    'skill_math_graphs',
  ],
  'course_eng_01': [
    'skill_eng_vocab',
    'skill_eng_grammar',
    'skill_eng_listening',
    'skill_eng_reading',
  ],
};

class PlacementState {
  final String courseId;
  final List<Question> allQuestions;
  final Question? currentQuestion;
  final int questionNumber;
  final int totalQuestionsToAsk;
  final List<AnswerHistoryItem> history;
  final List<QuestionAnswerSubmission> submissions;
  final bool isSubmitting;
  final AssessmentResult? result;
  final bool hasLoaded;
  final DateTime? questionStartedAt;
  final DateTime? lastSubmittedAt;

  const PlacementState({
    required this.courseId,
    required this.allQuestions,
    this.currentQuestion,
    this.questionNumber = 1,
    this.totalQuestionsToAsk = 8,
    required this.history,
    required this.submissions,
    this.isSubmitting = false,
    this.result,
    this.hasLoaded = false,
    this.questionStartedAt,
    this.lastSubmittedAt,
  });

  // Backward-compatible getters
  List<Question> get questions => allQuestions;
  int get currentIndex => questionNumber - 1;

  PlacementState copyWith({
    String? courseId,
    List<Question>? allQuestions,
    Question? currentQuestion,
    int? questionNumber,
    int? totalQuestionsToAsk,
    List<AnswerHistoryItem>? history,
    List<QuestionAnswerSubmission>? submissions,
    bool? isSubmitting,
    AssessmentResult? result,
    bool? hasLoaded,
    DateTime? questionStartedAt,
    DateTime? lastSubmittedAt,
  }) {
    return PlacementState(
      courseId: courseId ?? this.courseId,
      allQuestions: allQuestions ?? this.allQuestions,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      questionNumber: questionNumber ?? this.questionNumber,
      totalQuestionsToAsk: totalQuestionsToAsk ?? this.totalQuestionsToAsk,
      history: history ?? this.history,
      submissions: submissions ?? this.submissions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      questionStartedAt: questionStartedAt ?? this.questionStartedAt,
      lastSubmittedAt: lastSubmittedAt ?? this.lastSubmittedAt,
    );
  }
}

class PlacementStateNotifier extends StateNotifier<PlacementState> {
  final Ref ref;

  PlacementStateNotifier(this.ref)
    : super(
        const PlacementState(
          courseId: '',
          allQuestions: [],
          history: [],
          submissions: [],
        ),
      );

  Future<void> loadQuestions(String courseId) async {
    final courseRepo = ref.read(courseRepositoryProvider);
    final allQuestions = await courseRepo.getPlacementQuestions(courseId);
    final targetSkills =
        courseTargetSkills[courseId] ??
        allQuestions.map((q) => q.skillId).toSet().toList();

    final firstQ =
        AdaptiveQuestionSelector.getNextQuestion(
          allQuestions,
          targetSkills,
          [],
          2,
        ) ??
        (allQuestions.isNotEmpty ? allQuestions.first : null);

    state = PlacementState(
      courseId: courseId,
      allQuestions: allQuestions,
      currentQuestion: firstQ,
      questionNumber: 1,
      totalQuestionsToAsk: 8,
      history: [],
      submissions: [],
      isSubmitting: false,
      hasLoaded: true,
      questionStartedAt: firstQ != null ? DateTime.now() : null,
      lastSubmittedAt: null,
    );
  }

  Future<bool> submitAnswer(int selectedIndex) async {
    final currentQ = state.currentQuestion;
    if (currentQ == null || state.isSubmitting) return true;

    // Rate limiting: prevent rapid-fire submission abuse
    final now = DateTime.now();
    if (state.lastSubmittedAt != null &&
        now.difference(state.lastSubmittedAt!).inMilliseconds < 800) {
      return false;
    }

    // Input validation: selectedIndex must be within options range
    if (selectedIndex < 0 ||
        (currentQ.options.isNotEmpty && selectedIndex >= currentQ.options.length)) {
      return false;
    }

    state = state.copyWith(isSubmitting: true);
    final learnerRepository = ref.read(learnerRepositoryProvider);
    late final PlacementAnswerEvaluation evaluation;
    try {
      evaluation = await learnerRepository.evaluatePlacementAnswer(
        courseId: state.courseId,
        questionId: currentQ.id,
        selectedIndex: selectedIndex,
      );
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
    final isCorrect = evaluation.isCorrect;

    final elapsed = state.questionStartedAt != null
        ? now.difference(state.questionStartedAt!).inSeconds
        : 5;
    final timeSpentSeconds = elapsed.clamp(1, 600);

    final historyItem = AnswerHistoryItem(
      questionId: currentQ.id,
      skillId: currentQ.skillId,
      difficulty: currentQ.difficulty,
      isCorrect: isCorrect,
    );

    final submission = QuestionAnswerSubmission(
      questionId: currentQ.id,
      selectedIndex: selectedIndex,
      isCorrect: isCorrect,
      timeSpentSeconds: timeSpentSeconds,
    );

    final updatedHistory = List<AnswerHistoryItem>.from(state.history)
      ..add(historyItem);
    final updatedSubmissions = List<QuestionAnswerSubmission>.from(
      state.submissions,
    )..add(submission);

    final targetSkills =
        courseTargetSkills[state.courseId] ??
        state.allQuestions.map((q) => q.skillId).toSet().toList();

    final nextQ = AdaptiveQuestionSelector.getNextQuestion(
      state.allQuestions,
      targetSkills,
      updatedHistory,
      2,
    );

    final isDone =
        nextQ == null || state.questionNumber >= state.totalQuestionsToAsk;

    if (isDone) {
      state = state.copyWith(
        history: updatedHistory,
        submissions: updatedSubmissions,
        currentQuestion: null,
        isSubmitting: true,
        lastSubmittedAt: now,
      );

      final submitUseCase = ref.read(submitPlacementTestUseCaseProvider);
      late final AssessmentResult result;
      try {
        result = await submitUseCase.execute(
          state.courseId,
          updatedSubmissions,
        );
      } catch (_) {
        state = state.copyWith(
          currentQuestion: currentQ,
          isSubmitting: false,
        );
        rethrow;
      }

      state = state.copyWith(
        isSubmitting: false,
        result: result,
        lastSubmittedAt: DateTime.now(),
      );

      await ref.read(learnerStateNotifierProvider.notifier).loadProfile();
      await ref
          .read(roadmapStateNotifierProvider.notifier)
          .loadRoadmap(state.courseId);

      return true;
    } else {
      state = state.copyWith(
        history: updatedHistory,
        submissions: updatedSubmissions,
        currentQuestion: nextQ,
        questionNumber: state.questionNumber + 1,
        isSubmitting: false,
        questionStartedAt: DateTime.now(),
        lastSubmittedAt: now,
      );
      return false;
    }
  }

  /// Demo Fast-Calibrate shortcut
  Future<void> fastCalibrateDemo() async {
    while (state.currentQuestion != null) {
      final q = state.currentQuestion!;
      final isWeak = q.skillId == 'skill_math_functions';
      final pickIndex = isWeak
          ? (q.correctIndex + 1) % q.options.length
          : q.correctIndex;
      final isDone = await submitAnswer(pickIndex);
      if (isDone) break;
    }
  }
}

final placementStateNotifierProvider =
    StateNotifierProvider<PlacementStateNotifier, PlacementState>((ref) {
      return PlacementStateNotifier(ref);
    });

// 4. Roadmap State Notifier
class RoadmapStateNotifier extends StateNotifier<AsyncValue<LearningPath>> {
  final Ref ref;
  int _loadGeneration = 0;

  RoadmapStateNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadRoadmap(String courseId) async {
    final generation = ++_loadGeneration;
    state = const AsyncValue.loading();
    try {
      final roadmapUseCase = ref.read(getRoadmapUseCaseProvider);
      final path = await roadmapUseCase.execute(courseId);
      if (!mounted || generation != _loadGeneration) return;
      state = AsyncValue.data(path);
    } catch (e, st) {
      if (!mounted || generation != _loadGeneration) return;
      state = AsyncValue.error(e, st);
    }
  }

  void updateRoadmapDirect(LearningPath path) {
    _loadGeneration++;
    state = AsyncValue.data(path);
  }
}

final roadmapStateNotifierProvider =
    StateNotifierProvider<RoadmapStateNotifier, AsyncValue<LearningPath>>((
      ref,
    ) {
      return RoadmapStateNotifier(ref);
    });

// 5. Lesson State Notifier
class LessonSessionState {
  final Lesson? lesson;
  final bool isLoading;
  final bool isCompleted;
  final int currentStepIndex;
  final int? selectedOptionIndex;
  final LessonAnswerResult? answerResult;
  final bool isSubmittingAnswer;
  final bool showAiSheet;
  final bool showReinforcementSheet;
  final ReinforcementResult? reinforcementResult;
  final String? answerError;
  final String? lessonError;

  const LessonSessionState({
    this.lesson,
    this.isLoading = false,
    this.isCompleted = false,
    this.currentStepIndex = 0,
    this.selectedOptionIndex,
    this.answerResult,
    this.isSubmittingAnswer = false,
    this.showAiSheet = false,
    this.showReinforcementSheet = false,
    this.reinforcementResult,
    this.answerError,
    this.lessonError,
  });

  LessonSessionState copyWith({
    Lesson? lesson,
    bool? isLoading,
    bool? isCompleted,
    int? currentStepIndex,
    int? selectedOptionIndex,
    LessonAnswerResult? answerResult,
    bool? isSubmittingAnswer,
    bool? showAiSheet,
    bool? showReinforcementSheet,
    ReinforcementResult? reinforcementResult,
    String? answerError,
    String? lessonError,
    bool clearAnswerResult = false,
    bool clearAnswerError = false,
    bool clearSelectedOption = false,
    bool clearReinforcementResult = false,
  }) {
    return LessonSessionState(
      lesson: lesson ?? this.lesson,
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      selectedOptionIndex: clearSelectedOption
          ? null
          : (selectedOptionIndex ?? this.selectedOptionIndex),
      answerResult: clearAnswerResult
          ? null
          : (answerResult ?? this.answerResult),
      isSubmittingAnswer: isSubmittingAnswer ?? this.isSubmittingAnswer,
      showAiSheet: showAiSheet ?? this.showAiSheet,
      showReinforcementSheet:
          showReinforcementSheet ?? this.showReinforcementSheet,
      reinforcementResult: clearReinforcementResult
          ? null
          : (reinforcementResult ?? this.reinforcementResult),
      answerError: clearAnswerError ? null : (answerError ?? this.answerError),
      lessonError: lessonError ?? this.lessonError,
    );
  }
}

class LessonSessionNotifier extends StateNotifier<LessonSessionState> {
  final Ref ref;
  int _lessonGeneration = 0;
  int _stepGeneration = 0;
  int _answerGeneration = 0;
  final Set<String> _passedQuestionIds = {};
  ReinforcementResult? _completedReinforcement;
  String? _lastLessonId;

  int get sessionGeneration => _lessonGeneration;
  int get stepGeneration => _stepGeneration;

  LessonSessionNotifier(this.ref) : super(const LessonSessionState());

  Future<void> startLesson(String lessonId) async {
    final generation = ++_lessonGeneration;
    _stepGeneration++;
    _answerGeneration++;
    _passedQuestionIds.clear();
    _completedReinforcement = null;
    _lastLessonId = lessonId;
    state = const LessonSessionState(isLoading: true);
    final startUseCase = ref.read(startLessonUseCaseProvider);
    try {
      final lesson = await startUseCase.execute(lessonId);
      if (!mounted || generation != _lessonGeneration) return;
      state = LessonSessionState(
        lesson: lesson,
        currentStepIndex: 0,
        selectedOptionIndex: null,
        answerResult: null,
        isSubmittingAnswer: false,
        lessonError: null,
      );
    } catch (_) {
      if (!mounted || generation != _lessonGeneration) return;
      // Missing/invalid lesson: expose an empty session so the screen can show
      // a recoverable Uzbek empty-state instead of crashing or showing
      // another course's content.
      state = const LessonSessionState(
        lesson: null,
        lessonError: 'Dars ma’lumotlari yuklanmadi. Qayta urinib ko‘ring.',
      );
    }
  }

  Future<void> retryStartLesson() async {
    final lessonId = _lastLessonId;
    if (lessonId != null) await startLesson(lessonId);
  }

  Future<void> nextStep() async {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    if (state.currentStepIndex < lesson.steps.length - 1) {
      _stepGeneration++;
      _answerGeneration++;
      state = state.copyWith(
        currentStepIndex: state.currentStepIndex + 1,
        clearSelectedOption: true,
        clearAnswerResult: true,
        clearAnswerError: true,
        clearReinforcementResult: true,
        showAiSheet: false,
        showReinforcementSheet: false,
      );
      return;
    }

    final session = _lessonGeneration;
    final step = _stepGeneration;
    final answer = ++_answerGeneration;
    state = state.copyWith(isSubmittingAnswer: true, clearAnswerError: true);
    try {
      await _completeLesson(lesson, session, step, answer);
      if (!_isCurrent(session, step, answer)) return;
      state = state.copyWith(isSubmittingAnswer: false);
    } catch (_) {
      if (!_isCurrent(session, step, answer)) return;
      state = state.copyWith(
        isSubmittingAnswer: false,
        answerError: 'Darsni yakunlab bo‘lmadi. Qayta urinib ko‘ring.',
      );
    }
  }

  void previousStep() {
    if (state.isSubmittingAnswer || state.isCompleted) return;
    if (state.currentStepIndex > 0) {
      _stepGeneration++;
      _answerGeneration++;
      state = state.copyWith(
        currentStepIndex: state.currentStepIndex - 1,
        clearSelectedOption: true,
        clearAnswerResult: true,
        clearAnswerError: true,
        clearReinforcementResult: true,
        showAiSheet: false,
        showReinforcementSheet: false,
      );
    }
  }

  void selectOption(int index) {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    final question = lesson.steps[state.currentStepIndex].interactiveQuestion;
    if (question == null || index < 0 || index >= question.options.length) {
      return;
    }
    state = state.copyWith(
      selectedOptionIndex: index,
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  Future<void> submitInteractiveQuiz() async {
    if (state.lesson == null ||
        state.selectedOptionIndex == null ||
        state.isSubmittingAnswer ||
        state.isCompleted) {
      return;
    }

    final lesson = state.lesson!;
    final currentStep = lesson.steps[state.currentStepIndex];
    final question = currentStep.interactiveQuestion;
    if (question == null) return;
    final selectedIndex = state.selectedOptionIndex!;
    final session = _lessonGeneration;
    final step = _stepGeneration;

    final generation = ++_answerGeneration;
    state = state.copyWith(
      isSubmittingAnswer: true,
      clearAnswerResult: true,
      clearAnswerError: true,
    );

    try {
      if (!_isCurrent(session, step, generation)) return;
      final submitUseCase = ref.read(submitLessonAnswerUseCaseProvider);
      final result = await submitUseCase.execute(
        question: question,
        lessonId: lesson.id,
        selectedIndex: selectedIndex,
      );
      if (!_isCurrent(session, step, generation)) return;
      if (result.isCorrect) {
        _passedQuestionIds.add(question.id);
        if (state.currentStepIndex == lesson.steps.length - 1) {
          final completed = await _completeLesson(
            lesson,
            session,
            step,
            generation,
          );
          if (!_isCurrent(session, step, generation)) return;
          if (!completed) {
            state = state.copyWith(isSubmittingAnswer: false);
            return;
          }
        }
      }
      if (!_isCurrent(session, step, generation)) return;
      state = state.copyWith(
        isSubmittingAnswer: false,
        answerResult: result,
        showAiSheet: !result.isCorrect,
        clearAnswerError: true,
      );
    } catch (_) {
      if (!_isCurrent(session, step, generation)) return;
      state = state.copyWith(
        isSubmittingAnswer: false,
        answerError:
            'Javobni tekshirib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',
        showAiSheet: false,
      );
    }
  }

  void openReinforcement() {
    if (state.lesson == null || state.isSubmittingAnswer || state.isCompleted) {
      return;
    }
    state = state.copyWith(showAiSheet: false, showReinforcementSheet: true);
  }

  bool _isCurrent(int session, int step, int answer) =>
      mounted &&
      session == _lessonGeneration &&
      step == _stepGeneration &&
      answer == _answerGeneration;

  Future<bool> _completeLesson(
    Lesson lesson,
    int session,
    int step,
    int answer,
  ) async {
    if (!_isCurrent(session, step, answer)) return false;
    final requiredIds = lesson.steps
        .map((step) => step.interactiveQuestion?.id)
        .whereType<String>()
        .toSet();
    final hasInvalidAssessment = lesson.steps.any((step) {
      final question = step.interactiveQuestion;
      if (question == null) {
        return step.type == LessonStepType.interactiveQuestion;
      }
      return question.id.trim().isEmpty ||
          question.courseId != lesson.courseId ||
          question.skillId != lesson.skillId ||
          question.text.trim().isEmpty ||
          question.options.length < 2 ||
          question.options.any((option) => option.trim().isEmpty);
    });
    if (requiredIds.isEmpty ||
        hasInvalidAssessment ||
        !_passedQuestionIds.containsAll(requiredIds)) {
      state = state.copyWith(
        answerError:
            'Avval darsdagi barcha interaktiv savollarga to‘g‘ri javob bering.',
      );
      return false;
    }
    await ref
        .read(learnerRepositoryProvider)
        .markLessonCompleted(lesson.id, courseId: lesson.courseId);
    if (!_isCurrent(session, step, answer)) return false;
    state = state.copyWith(isCompleted: true);
    return true;
  }

  Future<ReinforcementResult?> submitReinforcement(int selectedIndex) async {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) {
      return null;
    }
    if (_completedReinforcement != null) return _completedReinforcement;
    final session = _lessonGeneration;
    final step = _stepGeneration;
    final generation = ++_answerGeneration;
    state = state.copyWith(isSubmittingAnswer: true);

    final courseId = lesson.courseId;
    final skillId = lesson.skillId;

    // Derive a course-scoped reinforcement node id — never hardcode another
    // course's node (the old 'reinf_node_math_func' leaked across courses).
    String reinforcementNodeId = 'reinf_${courseId}_$skillId';
    try {
      final roadmap = ref.read(roadmapStateNotifierProvider).value;
      if (roadmap != null && roadmap.courseId == courseId) {
        final node = roadmap.nodes
            .where((n) => n.isReinforcement && n.skillId == skillId)
            .firstOrNull;
        if (node != null) reinforcementNodeId = node.id;
      }
    } catch (_) {
      // Keep the deterministic scoped fallback id.
    }

    try {
      if (!_isCurrent(session, step, generation)) return null;
      final submitReinfUseCase = ref.read(submitReinforcementUseCaseProvider);
      final result = await submitReinfUseCase.execute(
        courseId: courseId,
        skillId: skillId,
        reinforcementNodeId: reinforcementNodeId,
        reinforcementQuestion: lesson.reinforcementExercise,
        selectedIndex: selectedIndex,
      );

      if (!_isCurrent(session, step, generation)) return null;

      if (result.isCorrect) _completedReinforcement = result;
      state = state.copyWith(reinforcementResult: result);
      if (!_isCurrent(session, step, generation)) return null;

      if (result.isCorrect) {
        ref
            .read(roadmapStateNotifierProvider.notifier)
            .updateRoadmapDirect(result.updatedRoadmap);
        if (!_isCurrent(session, step, generation)) return null;
        await ref
            .read(learnerStateNotifierProvider.notifier)
            .loadProfile(
              isCurrent: () => _isCurrent(session, step, generation),
            );
        if (!_isCurrent(session, step, generation)) return null;
      }

      return result;
    } catch (_) {
      if (!_isCurrent(session, step, generation)) return null;
      rethrow;
    } finally {
      if (_isCurrent(session, step, generation)) {
        state = state.copyWith(isSubmittingAnswer: false);
      }
    }
  }
}

final lessonSessionNotifierProvider =
    StateNotifierProvider<LessonSessionNotifier, LessonSessionState>((ref) {
      return LessonSessionNotifier(ref);
    });
