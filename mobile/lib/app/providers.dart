import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/in_memory_course_repository.dart';
import '../data/repositories/in_memory_lesson_repository.dart';
import '../domain/repositories/i_learner_repository.dart';
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
final aiTutorServiceProvider = Provider<IAITutorService>((ref) => SupabaseAITutorService());
final courseRepositoryProvider = Provider((ref) => InMemoryCourseRepository());
final lessonRepositoryProvider = Provider((ref) => InMemoryLessonRepository());
final learnerRepositoryProvider = Provider<ILearnerRepository>((ref) => SupabaseLearnerRepository());

// --- UseCase Providers ---
final selectCourseUseCaseProvider = Provider((ref) => SelectCourseUseCase(
      ref.watch(courseRepositoryProvider),
      ref.watch(learnerRepositoryProvider),
    ));

final submitPlacementTestUseCaseProvider = Provider((ref) => SubmitPlacementTestUseCase(
      ref.watch(courseRepositoryProvider),
      ref.watch(learnerRepositoryProvider),
    ));

final getKnowledgeMapUseCaseProvider = Provider((ref) => GetKnowledgeMapUseCase(
      ref.watch(courseRepositoryProvider),
      ref.watch(learnerRepositoryProvider),
    ));

final getRoadmapUseCaseProvider = Provider((ref) => GetRoadmapUseCase(
      ref.watch(lessonRepositoryProvider),
      ref.watch(learnerRepositoryProvider),
    ));

final startLessonUseCaseProvider = Provider((ref) => StartLessonUseCase(
      ref.watch(lessonRepositoryProvider),
    ));

final submitLessonAnswerUseCaseProvider = Provider((ref) => SubmitLessonAnswerUseCase(
      ref.watch(aiTutorServiceProvider),
    ));

final submitReinforcementUseCaseProvider = Provider((ref) => SubmitReinforcementUseCase(
      ref.watch(learnerRepositoryProvider),
      ref.watch(lessonRepositoryProvider),
    ));

final resetDemoUseCaseProvider = Provider((ref) => ResetDemoUseCase(
      ref.watch(learnerRepositoryProvider),
    ));

// --- State Notifiers ---

// 1. Learner Profile Notifier
class LearnerStateNotifier extends StateNotifier<AsyncValue<LearnerProfile>> {
  final Ref ref;

  LearnerStateNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final repo = ref.read(learnerRepositoryProvider);
      final profile = await repo.getProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
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
    StateNotifierProvider<LearnerStateNotifier, AsyncValue<LearnerProfile>>((ref) {
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

  CourseStateNotifier(this.ref)
      : super(const CourseState(courses: [], activeSkills: [], isLoading: true)) {
    init();
  }

  Future<void> init() async {
    final courseRepo = ref.read(courseRepositoryProvider);
    final allCourses = await courseRepo.getAllCourses();
    final firstCourse = allCourses.firstOrNull;

    List<Skill> skills = [];
    if (firstCourse != null) {
      skills = await courseRepo.getSkillsByCourseId(firstCourse.id);
    }

    state = CourseState(
      courses: allCourses,
      activeCourse: firstCourse,
      activeSkills: skills,
      isLoading: false,
    );
  }

  Future<void> selectCourse(String courseId) async {
    state = state.copyWith(isLoading: true);
    final selectUseCase = ref.read(selectCourseUseCaseProvider);
    final course = await selectUseCase.execute(courseId);
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
const targetSkillsMath = [
  'skill_math_algebra',
  'skill_math_equations',
  'skill_math_functions',
  'skill_math_graphs',
];

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
    );
  }
}

class PlacementStateNotifier extends StateNotifier<PlacementState> {
  final Ref ref;

  PlacementStateNotifier(this.ref)
      : super(const PlacementState(
          courseId: '',
          allQuestions: [],
          history: [],
          submissions: [],
        ));

  Future<void> loadQuestions(String courseId) async {
    final courseRepo = ref.read(courseRepositoryProvider);
    final allQuestions = await courseRepo.getPlacementQuestions(courseId);

    final firstQ = AdaptiveQuestionSelector.getNextQuestion(
          allQuestions,
          targetSkillsMath,
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
    );
  }

  Future<bool> submitAnswer(int selectedIndex) async {
    final currentQ = state.currentQuestion;
    if (currentQ == null || state.isSubmitting) return true;

    final isCorrect = selectedIndex == currentQ.correctIndex;

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
    );

    final updatedHistory = List<AnswerHistoryItem>.from(state.history)..add(historyItem);
    final updatedSubmissions = List<QuestionAnswerSubmission>.from(state.submissions)..add(submission);

    final nextQ = AdaptiveQuestionSelector.getNextQuestion(
      state.allQuestions,
      targetSkillsMath,
      updatedHistory,
      2,
    );

    final isDone = nextQ == null || state.questionNumber >= state.totalQuestionsToAsk;

    if (isDone) {
      state = state.copyWith(
        history: updatedHistory,
        submissions: updatedSubmissions,
        currentQuestion: null,
        isSubmitting: true,
      );

      final submitUseCase = ref.read(submitPlacementTestUseCaseProvider);
      final result = await submitUseCase.execute(state.courseId, updatedSubmissions);

      state = state.copyWith(
        isSubmitting: false,
        result: result,
      );

      await ref.read(learnerStateNotifierProvider.notifier).loadProfile();
      await ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(state.courseId);

      return true;
    } else {
      state = state.copyWith(
        history: updatedHistory,
        submissions: updatedSubmissions,
        currentQuestion: nextQ,
        questionNumber: state.questionNumber + 1,
      );
      return false;
    }
  }

  /// Demo Fast-Calibrate shortcut
  Future<void> fastCalibrateDemo() async {
    while (state.currentQuestion != null) {
      final q = state.currentQuestion!;
      final isWeak = q.skillId == 'skill_math_functions';
      final pickIndex = isWeak ? (q.correctIndex + 1) % q.options.length : q.correctIndex;
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

  RoadmapStateNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadRoadmap(String courseId) async {
    try {
      final roadmapUseCase = ref.read(getRoadmapUseCaseProvider);
      final path = await roadmapUseCase.execute(courseId);
      state = AsyncValue.data(path);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateRoadmapDirect(LearningPath path) {
    state = AsyncValue.data(path);
  }
}

final roadmapStateNotifierProvider =
    StateNotifierProvider<RoadmapStateNotifier, AsyncValue<LearningPath>>((ref) {
  return RoadmapStateNotifier(ref);
});

// 5. Lesson State Notifier
class LessonSessionState {
  final Lesson? lesson;
  final int currentStepIndex;
  final int? selectedOptionIndex;
  final LessonAnswerResult? answerResult;
  final bool isSubmittingAnswer;
  final bool showAiSheet;
  final bool showReinforcementSheet;
  final ReinforcementResult? reinforcementResult;

  const LessonSessionState({
    this.lesson,
    this.currentStepIndex = 0,
    this.selectedOptionIndex,
    this.answerResult,
    this.isSubmittingAnswer = false,
    this.showAiSheet = false,
    this.showReinforcementSheet = false,
    this.reinforcementResult,
  });

  LessonSessionState copyWith({
    Lesson? lesson,
    int? currentStepIndex,
    int? selectedOptionIndex,
    LessonAnswerResult? answerResult,
    bool? isSubmittingAnswer,
    bool? showAiSheet,
    bool? showReinforcementSheet,
    ReinforcementResult? reinforcementResult,
  }) {
    return LessonSessionState(
      lesson: lesson ?? this.lesson,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      selectedOptionIndex: selectedOptionIndex,
      answerResult: answerResult ?? this.answerResult,
      isSubmittingAnswer: isSubmittingAnswer ?? this.isSubmittingAnswer,
      showAiSheet: showAiSheet ?? this.showAiSheet,
      showReinforcementSheet: showReinforcementSheet ?? this.showReinforcementSheet,
      reinforcementResult: reinforcementResult ?? this.reinforcementResult,
    );
  }
}

class LessonSessionNotifier extends StateNotifier<LessonSessionState> {
  final Ref ref;

  LessonSessionNotifier(this.ref) : super(const LessonSessionState());

  Future<void> startLesson(String lessonId) async {
    final startUseCase = ref.read(startLessonUseCaseProvider);
    final lesson = await startUseCase.execute(lessonId);
    state = LessonSessionState(
      lesson: lesson,
      currentStepIndex: 0,
      selectedOptionIndex: null,
      answerResult: null,
      isSubmittingAnswer: false,
    );
  }

  void nextStep() {
    if (state.lesson != null && state.currentStepIndex < state.lesson!.steps.length - 1) {
      state = state.copyWith(
        currentStepIndex: state.currentStepIndex + 1,
        selectedOptionIndex: null,
      );
    }
  }

  void previousStep() {
    if (state.currentStepIndex > 0) {
      state = state.copyWith(
        currentStepIndex: state.currentStepIndex - 1,
        selectedOptionIndex: null,
      );
    }
  }

  void selectOption(int index) {
    state = state.copyWith(selectedOptionIndex: index);
  }

  Future<void> submitInteractiveQuiz() async {
    if (state.lesson == null || state.selectedOptionIndex == null) return;

    final currentStep = state.lesson!.steps[state.currentStepIndex];
    final question = currentStep.interactiveQuestion;
    if (question == null) return;

    state = state.copyWith(isSubmittingAnswer: true);

    final submitUseCase = ref.read(submitLessonAnswerUseCaseProvider);
    final result = await submitUseCase.execute(
      question: question,
      selectedIndex: state.selectedOptionIndex!,
    );

    state = state.copyWith(
      isSubmittingAnswer: false,
      answerResult: result,
      showAiSheet: !result.isCorrect,
    );
  }

  void openReinforcement() {
    state = state.copyWith(
      showAiSheet: false,
      showReinforcementSheet: true,
    );
  }

  Future<ReinforcementResult?> submitReinforcement(int selectedIndex) async {
    if (state.lesson == null) return null;

    final submitReinfUseCase = ref.read(submitReinforcementUseCaseProvider);
    final result = await submitReinfUseCase.execute(
      courseId: state.lesson!.courseId,
      skillId: state.lesson!.skillId,
      reinforcementNodeId: 'reinf_node_math_func',
      reinforcementQuestion: state.lesson!.reinforcementExercise,
      selectedIndex: selectedIndex,
    );

    state = state.copyWith(
      reinforcementResult: result,
    );

    if (result.isCorrect) {
      ref.read(roadmapStateNotifierProvider.notifier).updateRoadmapDirect(result.updatedRoadmap);
      await ref.read(learnerStateNotifierProvider.notifier).loadProfile();
    }

    return result;
  }
}

final lessonSessionNotifierProvider =
    StateNotifierProvider<LessonSessionNotifier, LessonSessionState>((ref) {
  return LessonSessionNotifier(ref);
});
