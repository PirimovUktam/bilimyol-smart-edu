import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/demo_ai_tutor_service.dart';
import '../data/repositories/in_memory_course_repository.dart';
import '../data/repositories/in_memory_lesson_repository.dart';
import '../data/repositories/in_memory_learner_repository.dart';
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

// --- Singleton Service & Repository Providers ---
final aiTutorServiceProvider = Provider((ref) => DemoAITutorService());
final courseRepositoryProvider = Provider((ref) => InMemoryCourseRepository());
final lessonRepositoryProvider = Provider((ref) => InMemoryLessonRepository());
final learnerRepositoryProvider = Provider((ref) => InMemoryLearnerRepository());

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
class PlacementState {
  final String courseId;
  final List<Question> questions;
  final int currentIndex;
  final List<QuestionAnswerSubmission> submissions;
  final bool isSubmitting;
  final AssessmentResult? result;

  const PlacementState({
    required this.courseId,
    required this.questions,
    this.currentIndex = 0,
    required this.submissions,
    this.isSubmitting = false,
    this.result,
  });

  PlacementState copyWith({
    String? courseId,
    List<Question>? questions,
    int? currentIndex,
    List<QuestionAnswerSubmission>? submissions,
    bool? isSubmitting,
    AssessmentResult? result,
  }) {
    return PlacementState(
      courseId: courseId ?? this.courseId,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      submissions: submissions ?? this.submissions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
    );
  }
}

class PlacementStateNotifier extends StateNotifier<PlacementState> {
  final Ref ref;

  PlacementStateNotifier(this.ref)
      : super(const PlacementState(courseId: '', questions: [], submissions: []));

  Future<void> loadQuestions(String courseId) async {
    final courseRepo = ref.read(courseRepositoryProvider);
    final questions = await courseRepo.getPlacementQuestions(courseId);
    state = PlacementState(
      courseId: courseId,
      questions: questions,
      currentIndex: 0,
      submissions: [],
      isSubmitting: false,
    );
  }

  Future<bool> submitAnswer(int selectedIndex) async {
    if (state.currentIndex >= state.questions.length) return true;

    final currentQ = state.questions[state.currentIndex];
    final isCorrect = selectedIndex == currentQ.correctIndex;

    final submission = QuestionAnswerSubmission(
      questionId: currentQ.id,
      selectedIndex: selectedIndex,
      isCorrect: isCorrect,
    );

    final updatedSubmissions = List<QuestionAnswerSubmission>.from(state.submissions)..add(submission);

    final nextIndex = state.currentIndex + 1;
    final isDone = nextIndex >= state.questions.length;

    if (isDone) {
      state = state.copyWith(
        submissions: updatedSubmissions,
        currentIndex: nextIndex,
        isSubmitting: true,
      );

      final submitUseCase = ref.read(submitPlacementTestUseCaseProvider);
      final result = await submitUseCase.execute(state.courseId, updatedSubmissions);

      state = state.copyWith(
        isSubmitting: false,
        result: result,
      );

      // Refresh learner profile & roadmap
      await ref.read(learnerStateNotifierProvider.notifier).loadProfile();
      await ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(state.courseId);

      return true;
    } else {
      state = state.copyWith(
        submissions: updatedSubmissions,
        currentIndex: nextIndex,
      );
      return false;
    }
  }

  /// Demo Fast-Calibrate shortcut (Answers correctly except Functions / Listening)
  Future<void> fastCalibrateDemo() async {
    if (state.questions.isEmpty) return;
    for (int i = 0; i < state.questions.length; i++) {
      final q = state.questions[i];
      final shouldMiss = q.skillId == 'skill_math_functions' || q.skillId == 'skill_eng_listening';
      final pickIndex = shouldMiss ? (q.correctIndex + 1) % q.options.length : q.correctIndex;
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
      // Update roadmap and learner state
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
