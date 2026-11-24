import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio/lesson_audio_controller.dart';
import '../core/auth/demo_session.dart';
import '../core/config/supabase_config.dart';
import '../core/l10n/app_strings.dart';
import '../core/storage/local_storage_service.dart';
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
import '../domain/entities/skill_score.dart';
import '../domain/personalization/skill_scoring_engine.dart';
import '../domain/entities/learner_profile.dart';
import '../domain/entities/placement_session.dart';
import '../domain/entities/question.dart';
import '../domain/entities/learning_path_node.dart';
import '../domain/entities/lesson.dart';
import '../domain/personalization/adaptive_question_selector.dart';
import '../domain/personalization/learning_start.dart';

import '../data/datasources/english/placement_questions_data.dart';
import '../data/services/i_ai_tutor_service.dart';
import '../data/services/demo_ai_tutor_service.dart';
import '../data/services/supabase_ai_tutor_service.dart';
import '../data/repositories/supabase_learner_repository.dart';
import '../features/lesson/reading_position.dart';

// --- App Storage & Settings ---
final localStorageServiceProvider = Provider<LocalStorageService>(
  (ref) => LocalStorageService(),
);

class AppSettingsState {
  final String localeCode;
  final ThemeMode themeMode;
  final bool productTourCompleted;

  const AppSettingsState({
    this.localeCode = 'uz',
    this.themeMode = ThemeMode.system,
    this.productTourCompleted = false,
  });

  Locale get locale => Locale(localeCode == 'ru' ? 'ru' : 'uz');

  AppSettingsState copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    bool? productTourCompleted,
  }) {
    return AppSettingsState(
      localeCode: localeCode ?? this.localeCode,
      themeMode: themeMode ?? this.themeMode,
      productTourCompleted: productTourCompleted ?? this.productTourCompleted,
    );
  }
}

final initialAppSettingsProvider = Provider<AppSettingsState?>((ref) => null);

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final LocalStorageService _storage;
  bool _localeMutated = false;
  bool _themeModeMutated = false;
  bool _tourMutated = false;
  int _localeWriteSeq = 0;
  int _themeModeWriteSeq = 0;
  int _tourWriteSeq = 0;
  String _latestLocaleCode = 'uz';
  ThemeMode _latestThemeMode = ThemeMode.system;
  bool _latestTourCompleted = false;

  AppSettingsNotifier(this._storage, {AppSettingsState? initial})
    : super(initial ?? const AppSettingsState()) {
    if (initial == null) {
      _hydrate();
    } else {
      _latestLocaleCode = initial.localeCode == 'ru' ? 'ru' : 'uz';
      _latestThemeMode = initial.themeMode;
      _latestTourCompleted = initial.productTourCompleted;
      productTourCompleted.value = initial.productTourCompleted;
    }
  }

  Future<void> _hydrate() async {
    final localeCode = await _storage.getLocaleCode();
    final themeMode = await _storage.getThemeMode();
    final tourDone = await _storage.getProductTourCompleted();
    if (!mounted) return;
    if (!_localeMutated) _latestLocaleCode = localeCode;
    if (!_themeModeMutated) _latestThemeMode = themeMode;
    if (!_tourMutated) {
      _latestTourCompleted = tourDone;
      productTourCompleted.value = tourDone;
    }
    state = state.copyWith(
      localeCode: _localeMutated ? null : localeCode,
      themeMode: _themeModeMutated ? null : themeMode,
      productTourCompleted: _tourMutated ? null : tourDone,
    );
  }

  Future<void> setLocale(String code) async {
    _localeMutated = true;
    final normalized = code == 'ru' ? 'ru' : 'uz';
    _latestLocaleCode = normalized;
    var targetSeq = ++_localeWriteSeq;
    var targetValue = normalized;
    state = state.copyWith(localeCode: normalized);
    while (true) {
      await _storage.setLocaleCode(targetValue);
      if (targetSeq == _localeWriteSeq) break;
      targetSeq = _localeWriteSeq;
      targetValue = _latestLocaleCode;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeModeMutated = true;
    _latestThemeMode = mode;
    var targetSeq = ++_themeModeWriteSeq;
    var targetValue = mode;
    state = state.copyWith(themeMode: mode);
    while (true) {
      await _storage.setThemeMode(targetValue);
      if (targetSeq == _themeModeWriteSeq) break;
      targetSeq = _themeModeWriteSeq;
      targetValue = _latestThemeMode;
    }
  }

  Future<void> _setProductTourCompleted(bool completed) async {
    _tourMutated = true;
    _latestTourCompleted = completed;
    var targetSeq = ++_tourWriteSeq;
    var targetValue = completed;
    state = state.copyWith(productTourCompleted: completed);
    productTourCompleted.value = completed;
    while (true) {
      await _storage.setProductTourCompleted(targetValue);
      if (targetSeq == _tourWriteSeq) break;
      targetSeq = _tourWriteSeq;
      targetValue = _latestTourCompleted;
    }
  }

  Future<void> completeProductTour() => _setProductTourCompleted(true);

  Future<void> resetProductTour() => _setProductTourCompleted(false);
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
      final storage = ref.watch(localStorageServiceProvider);
      final initial = ref.watch(initialAppSettingsProvider);
      return AppSettingsNotifier(storage, initial: initial);
    });

// --- Singleton Service & Repository Providers ---
final aiTutorServiceProvider = Provider<IAITutorService>(
  (ref) => SupabaseConfig.hasRemoteConfiguration
      ? SupabaseAITutorService()
      : DemoAITutorService(),
);
final courseRepositoryProvider = Provider<ICourseRepository>(
  (ref) => SupabaseCourseRepository(),
);
final lessonRepositoryProvider = Provider<ILessonRepository>(
  (ref) => SupabaseLessonRepository(),
);
final learnerRepositoryProvider = Provider<ILearnerRepository>(
  (ref) => SupabaseLearnerRepository(
    storage: ref.watch(localStorageServiceProvider),
  ),
);

bool _isFlutterTestBinding() => WidgetsBinding.instance.runtimeType
    .toString()
    .contains('TestWidgetsFlutterBinding');

bool _isRuPlatformLocale() {
  try {
    return WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
        'ru';
  } catch (_) {
    return false;
  }
}

bool _isIntegratedEnglishLesson(Lesson lesson) {
  if (lesson.courseId != 'course_eng_01') return false;
  if (lesson.skillDomain == 'integrated' ||
      lesson.communicativeFocus == 'exit_assessment' ||
      lesson.communicativeFocus == 'checkpoint' ||
      lesson.id.contains('_checkpoint') ||
      lesson.id.contains('_exit')) {
    return true;
  }
  final lessonSkills = <String>{
    lesson.skillId,
    for (final step in lesson.steps)
      if (step.interactiveQuestion != null) step.interactiveQuestion!.skillId,
    lesson.reinforcementExercise.skillId,
    if (lesson.alternateExercise != null) lesson.alternateExercise!.skillId,
  };
  return lessonSkills.length > 1 &&
      lessonSkills.every((skill) => skill.startsWith('skill_eng_'));
}

final lessonAudioControllerFactoryProvider =
    Provider<LessonAudioController Function()>((ref) {
      if (_isFlutterTestBinding()) {
        return () => FakeLessonAudioController();
      }
      return () => JustAudioLessonController();
    });

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
  (ref) => SubmitLessonAnswerUseCase(ref.watch(learnerRepositoryProvider)),
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
      _syncHasStartedCourse(profile);
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
    required String courseId,
    required OnboardingGoal goal,
    required int dailyMinutes,
    required InitialLevel initialLevel,
  }) async {
    final repo = ref.read(learnerRepositoryProvider);
    final saved = await repo.saveCourseLearningPlan(
      courseId: courseId,
      goal: goal,
      dailyMinutes: dailyMinutes,
      initialLevel: initialLevel,
    );
    if (mounted &&
        ref.read(courseStateNotifierProvider).activeCourse?.id == courseId) {
      state = AsyncValue.data(saved);
    }
    if (mounted) {
      _syncHasStartedCourse(saved);
    }
  }

  Future<void> updateDisplayName(String rawName) async {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Name must not be empty');
    }
    final repo = ref.read(learnerRepositoryProvider);
    final current = state.valueOrNull ?? await repo.getProfile();
    final saved = await repo.updateProfile(
      current.copyWith(name: trimmed),
      fields: const {LearnerProfileField.name},
    );
    if (mounted) {
      state = AsyncValue.data(saved);
      _syncHasStartedCourse(saved);
    }
  }

  void _syncHasStartedCourse(LearnerProfile profile) {
    final courses = ref.read(courseStateNotifierProvider).courses;
    if (courses.isNotEmpty) {
      activeSessionHasStartedCourse.value = courses.any(
        (c) => hasStartedCourse(c, profile),
      );
    } else {
      activeSessionHasStartedCourse.value =
          profile.courseLevels.isNotEmpty ||
          profile.scoresByCourse.values.any((m) => m.isNotEmpty) ||
          profile.placementScoreByCourse.isNotEmpty ||
          profile.placementCefrByCourse.isNotEmpty ||
          profile.completedLessonIds.isNotEmpty;
    }
  }

  Future<void> resetAll() async {
    final generation = ++_loadGeneration;
    state = const AsyncValue.loading();
    try {
      final resetUseCase = ref.read(resetDemoUseCaseProvider);
      final resetProfile = await resetUseCase.execute();
      if (!mounted || generation != _loadGeneration) return;
      activeSessionHasStartedCourse.value = false;
      state = AsyncValue.data(resetProfile);
      ref.invalidate(courseStateNotifierProvider);
      ref.invalidate(roadmapStateNotifierProvider);
      ref.invalidate(placementStateNotifierProvider);
      ref.invalidate(lessonSessionNotifierProvider);
    } catch (e, st) {
      if (mounted && generation == _loadGeneration) {
        state = AsyncValue.error(e, st);
      }
      rethrow;
    }
  }

  /// Seeds a ready-made adaptive state so judges can reach the personalised
  /// journey without answering the full placement test. The third skill is set
  /// below the reinforcement threshold so the roadmap demonstrates remediation.
  Future<void> seedQuickDemo() async {
    final repo = ref.read(learnerRepositoryProvider);
    if (repo.supportsServerPlacementPersistence) return;
    final courseState = ref.read(courseStateNotifierProvider);
    final course = courseState.activeCourse;
    final skills = courseState.activeSkills;
    if (course == null || skills.isEmpty) return;

    const preset = [82, 84, 41, 68];
    final scores = <String, SkillScore>{};
    for (var i = 0; i < skills.length; i++) {
      final score = preset[i % preset.length];
      scores[skills[i].id] = SkillScore(
        skillId: skills[i].id,
        courseId: course.id,
        score: score,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        masteryLevel: SkillScoringEngine.getMasteryLevel(score),
      );
    }

    await repo.saveSkillScores(course.id, scores);
    final current = await repo.getProfile();
    await repo.updateProfile(
      current.copyWith(
        selectedCourseId: course.id,
        xp: current.xp < 120 ? 120 : current.xp,
        streakDays: current.streakDays < 3 ? 3 : current.streakDays,
      ),
    );
    await loadProfile();
    await ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(course.id);
  }

  Future<void> recordFlashcardReview({
    required String courseId,
    required String cardId,
    required bool remembered,
  }) async {
    final repo = ref.read(learnerRepositoryProvider);
    final updated = await repo.recordFlashcardReview(
      courseId: courseId,
      cardId: cardId,
      remembered: remembered,
    );
    if (!mounted) return;
    state = AsyncValue.data(updated);
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
  final String? error;

  const CourseState({
    required this.courses,
    this.activeCourse,
    required this.activeSkills,
    this.isLoading = false,
    this.error,
  });

  CourseState copyWith({
    List<Course>? courses,
    Course? activeCourse,
    List<Skill>? activeSkills,
    bool? isLoading,
    String? error,
  }) {
    return CourseState(
      courses: courses ?? this.courses,
      activeCourse: activeCourse ?? this.activeCourse,
      activeSkills: activeSkills ?? this.activeSkills,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CourseStateNotifier extends StateNotifier<CourseState> {
  final Ref ref;
  int _initGeneration = 0;
  Future<void>? _initFuture;
  bool _isSelecting = false;

  CourseStateNotifier(this.ref)
    : super(const CourseState(courses: [], activeSkills: [], isLoading: true)) {
    init();
  }

  Future<void> init() {
    final generation = ++_initGeneration;
    late final Future<void> future;
    future = _runInit(generation).whenComplete(() {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    });
    _initFuture = future;
    return future;
  }

  Future<void> _runInit(int generation) async {
    state = state.copyWith(isLoading: true);
    try {
      final courseRepo = ref.read(courseRepositoryProvider);
      final allCourses = await courseRepo.getAllCourses();
      if (!mounted || generation != _initGeneration) return;

      // Restore the persisted course selection (server/local profile truth)
      // instead of always resetting to courses[0].
      final learnerRepo = ref.read(learnerRepositoryProvider);
      final profile = await learnerRepo.getProfile();
      if (!mounted || generation != _initGeneration) return;
      final selectedId = profile.selectedCourseId;
      final active = selectedId.isEmpty
          ? null
          : allCourses.where((c) => c.id == selectedId).firstOrNull;

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
      activeSessionHasStartedCourse.value = allCourses.any(
        (c) => hasStartedCourse(c, profile),
      );

      if (active != null) {
        ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(active.id);
      }
    } catch (_) {
      if (!mounted || generation != _initGeneration) return;
      state = state.copyWith(
        isLoading: false,
        error: (ref.read(appSettingsProvider).localeCode == 'ru' ||
                _isRuPlatformLocale())
            ? 'Не удалось загрузить предметы. Попробуйте снова.'
            : 'Kurslarni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
      );
    }
  }

  Future<void> selectCourse(String courseId) async {
    if (!mounted || _isSelecting) return;
    _isSelecting = true;
    try {
      final pendingInit = _initFuture;
      if (pendingInit != null) {
        await pendingInit;
        if (!mounted) return;
      }
      state = state.copyWith(isLoading: true);
      final courseRepo = ref.read(courseRepositoryProvider);
      final skills = await courseRepo.getSkillsByCourseId(courseId);
      if (!mounted) return;
      final selectUseCase = ref.read(selectCourseUseCaseProvider);
      final course = await selectUseCase.execute(courseId);
      if (!mounted) return;
      await ref.read(learnerStateNotifierProvider.notifier).loadProfile();
      if (!mounted) return;

      state = state.copyWith(
        activeCourse: course,
        activeSkills: skills,
        isLoading: false,
      );

      ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(course.id);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: (ref.read(appSettingsProvider).localeCode == 'ru' ||
                _isRuPlatformLocale())
            ? 'Не удалось выбрать предмет. Попробуйте снова.'
            : 'Kursni tanlab bo‘lmadi. Qayta urinib ko‘ring.',
      );
    } finally {
      _isSelecting = false;
    }
  }
}

final courseStateNotifierProvider =
    StateNotifierProvider<CourseStateNotifier, CourseState>((ref) {
      return CourseStateNotifier(ref);
    });

// 3. Placement Test State Notifier
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
  final String? sessionId;
  final bool canRetake;
  final String? notice;

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
    this.sessionId,
    this.canRetake = false,
    this.notice,
  });

  // Backward-compatible getters
  List<Question> get questions => allQuestions;
  int get currentIndex => questionNumber - 1;

  PlacementState copyWith({
    String? courseId,
    List<Question>? allQuestions,
    Question? currentQuestion,
    bool clearCurrentQuestion = false,
    int? questionNumber,
    int? totalQuestionsToAsk,
    List<AnswerHistoryItem>? history,
    List<QuestionAnswerSubmission>? submissions,
    bool? isSubmitting,
    AssessmentResult? result,
    bool? hasLoaded,
    DateTime? questionStartedAt,
    DateTime? lastSubmittedAt,
    bool? canRetake,
    String? notice,
    bool clearNotice = false,
  }) {
    return PlacementState(
      courseId: courseId ?? this.courseId,
      allQuestions: allQuestions ?? this.allQuestions,
      currentQuestion: clearCurrentQuestion
          ? null
          : (currentQuestion ?? this.currentQuestion),
      questionNumber: questionNumber ?? this.questionNumber,
      totalQuestionsToAsk: totalQuestionsToAsk ?? this.totalQuestionsToAsk,
      history: history ?? this.history,
      submissions: submissions ?? this.submissions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      questionStartedAt: questionStartedAt ?? this.questionStartedAt,
      lastSubmittedAt: lastSubmittedAt ?? this.lastSubmittedAt,
      sessionId: sessionId,
      canRetake: canRetake ?? this.canRetake,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class PlacementStateNotifier extends StateNotifier<PlacementState> {
  final Ref ref;
  Object _request = Object();

  PlacementStateNotifier(this.ref)
    : super(
        const PlacementState(
          courseId: '',
          allQuestions: [],
          history: [],
          submissions: [],
        ),
      );

  Future<void> loadQuestions(String courseId, {bool restart = false}) async {
    final request = _request = Object();
    bool isCurrent() => mounted && identical(_request, request);
    state = PlacementState(
      courseId: courseId,
      allQuestions: const [],
      history: const [],
      submissions: const [],
    );
    final learner = ref.read(learnerRepositoryProvider);
    if (learner.supportsPlacementSessions) {
      try {
        final session = await learner.advancePlacement(
          courseId,
          restart: restart,
        );
        if (isCurrent()) await _applySession(courseId, session, isCurrent);
      } catch (_) {
        if (isCurrent()) state = state.copyWith(hasLoaded: true);
      }
      return;
    }

    late final List<Question> allQuestions;
    try {
      allQuestions = await ref
          .read(courseRepositoryProvider)
          .getPlacementQuestions(courseId);
    } catch (_) {
      if (isCurrent()) state = state.copyWith(hasLoaded: true);
      return;
    }
    if (!isCurrent()) return;
    final targetSkills = allQuestions.map((q) => q.skillId).toSet().toList();
    final total = targetSkills.fold<int>(
      0,
      (sum, skill) =>
          sum + allQuestions.where((q) => q.skillId == skill).take(2).length,
    );

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
      totalQuestionsToAsk: total,
      history: [],
      submissions: [],
      isSubmitting: false,
      hasLoaded: true,
      questionStartedAt: firstQ != null ? DateTime.now() : null,
      lastSubmittedAt: null,
    );
  }

  Future<void> _applySession(
    String courseId,
    PlacementSession session,
    bool Function() isCurrent,
  ) async {
    final completed = session.result;
    AssessmentResult? result;
    if (completed != null) {
      await ref
          .read(learnerStateNotifierProvider.notifier)
          .loadProfile(isCurrent: isCurrent);
      if (!isCurrent()) return;
      final profile = ref.read(learnerStateNotifierProvider).valueOrNull;
      final reviewSubmissions = completed.review
          .map((answer) => answer.submission)
          .toList(growable: false);
      var placementQuestions = const <Question>[];
      var computedScores = profile?.scoresByCourse[courseId] ?? {};
      var overallScore = 0;
      String? cefrLevel;
      if (courseId == 'course_eng_01') {
        try {
          placementQuestions = await ref
              .read(courseRepositoryProvider)
              .getPlacementQuestions(courseId);
        } catch (_) {
          placementQuestions = englishPlacementQuestionsRaw;
        }
        if (!isCurrent()) return;
        if (placementQuestions.isEmpty) {
          placementQuestions = englishPlacementQuestionsRaw;
        }
        if (reviewSubmissions.isNotEmpty) {
          computedScores = SkillScoringEngine.computePlacementScores(
            courseId,
            placementQuestions,
            reviewSubmissions,
          );
          overallScore = SkillScoringEngine.computeOverallScore(computedScores);
          cefrLevel = SkillScoringEngine.computeEnglishPlacementCefr(
            placementQuestions,
            reviewSubmissions,
            completedNodeIds: profile?.completedNodeIds ?? const [],
          );
        } else {
          overallScore = profile?.placementScoreByCourse[courseId] ?? 0;
          final rawCefr =
              profile?.placementCefrByCourse[courseId] ??
              SkillScoringEngine.computeEnglishPlacementCefr(
                placementQuestions,
                reviewSubmissions,
                completedNodeIds: profile?.completedNodeIds ?? const [],
              );
          cefrLevel = SkillScoringEngine.englishEntryTargetForCefr(
            rawCefr,
          ).cefrLevel;
        }
      } else {
        final correctCount = reviewSubmissions
            .where((s) => s.isCorrect)
            .length;
        overallScore = reviewSubmissions.isEmpty
            ? 0
            : SkillScoringEngine.computeSkillScore(
                correctCount,
                reviewSubmissions.length,
              );
      }
      result = AssessmentResult(
        assessmentId: completed.attemptId,
        courseId: courseId,
        submissions: reviewSubmissions,
        computedScores: computedScores,
        weakestSkillId: completed.weakestSkillId,
        overallScore: overallScore,
        cefrLevel: cefrLevel,
        timestamp: completed.completedAt.millisecondsSinceEpoch,
        review: completed.review,
      );
      final activeCourse = ref.read(courseStateNotifierProvider).activeCourse;
      if (activeCourse == null || activeCourse.id == courseId) {
        await ref
            .read(roadmapStateNotifierProvider.notifier)
            .loadRoadmap(courseId);
        if (!isCurrent()) return;
      }
    }
    state = PlacementState(
      courseId: courseId,
      allQuestions: const [],
      history: const [],
      submissions: result?.submissions ?? const [],
      sessionId: session.id,
      currentQuestion: session.question,
      questionNumber: session.questionNumber,
      totalQuestionsToAsk: session.totalQuestions,
      result: result,
      hasLoaded: true,
      canRetake: session.canRetake,
      notice: session.wasReset
          ? ((ref.read(appSettingsProvider).localeCode == 'ru' ||
                    _isRuPlatformLocale())
                ? 'Вопросы обновлены или срок сессии истёк. Диагностика началась заново.'
                : 'Savollar yangilandi yoki sessiya muddati tugadi. Diagnostika boshidan boshlandi.')
          : null,
    );
  }

  void clearNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }

  Future<bool> submitAnswer(
    int selectedIndex, {
    bool bypassRateLimit = false,
  }) async {
    final currentQ = state.currentQuestion;
    if (currentQ == null || state.isSubmitting) return false;

    // Rate limiting: prevent rapid-fire submission abuse on intermediate steps,
    // while never silently dropping a confirmed final submission.
    final now = DateTime.now();
    final isFinalStep = state.questionNumber >= state.totalQuestionsToAsk;
    if (!bypassRateLimit &&
        !isFinalStep &&
        state.sessionId == null &&
        state.lastSubmittedAt != null &&
        now.difference(state.lastSubmittedAt!).inMilliseconds < 800) {
      final localeCode = ref.read(appSettingsProvider).localeCode;
      state = state.copyWith(
        notice: AppStrings.forCode(localeCode).placementFastTapNotice,
      );
      return false;
    }

    // Input validation: selectedIndex must be within options range
    if (selectedIndex < 0 ||
        (currentQ.options.isNotEmpty &&
            selectedIndex >= currentQ.options.length)) {
      return false;
    }

    final request = _request;
    final courseId = state.courseId;
    bool isCurrent() => mounted && identical(_request, request);
    final sessionId = state.sessionId;
    state = state.copyWith(isSubmitting: true, clearNotice: true);
    final learnerRepository = ref.read(learnerRepositoryProvider);
    if (sessionId != null) {
      try {
        final session = await learnerRepository.advancePlacement(
          courseId,
          sessionId: sessionId,
          questionId: currentQ.id,
          selectedIndex: selectedIndex,
        );
        if (!isCurrent()) return false;
        await _applySession(courseId, session, isCurrent);
        return isCurrent() && session.result != null;
      } catch (_) {
        if (isCurrent()) state = state.copyWith(isSubmitting: false);
        rethrow;
      }
    }
    late final PlacementAnswerEvaluation evaluation;
    try {
      evaluation = await learnerRepository.evaluatePlacementAnswer(
        courseId: state.courseId,
        questionId: currentQ.id,
        selectedIndex: selectedIndex,
      );
    } catch (_) {
      if (isCurrent()) state = state.copyWith(isSubmitting: false);
      rethrow;
    }
    if (!isCurrent()) return false;
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

    final targetSkills = state.allQuestions
        .map((q) => q.skillId)
        .toSet()
        .toList();

    final nextQ = AdaptiveQuestionSelector.getNextQuestion(
      state.allQuestions,
      targetSkills,
      updatedHistory,
      2,
    );

    final isDone =
        nextQ == null || state.questionNumber >= state.totalQuestionsToAsk;

    if (isDone) {
      final submitUseCase = ref.read(submitPlacementTestUseCaseProvider);
      late final AssessmentResult result;
      try {
        result = await submitUseCase.execute(
          courseId,
          updatedSubmissions,
        );
      } catch (_) {
        if (isCurrent()) {
          state = state.copyWith(isSubmitting: false);
        }
        rethrow;
      }
      if (!isCurrent()) return false;

      await ref
          .read(learnerStateNotifierProvider.notifier)
          .loadProfile(isCurrent: isCurrent);
      if (!isCurrent()) return false;
      final activeCourse = ref.read(courseStateNotifierProvider).activeCourse;
      if (activeCourse == null || activeCourse.id == courseId) {
        await ref
            .read(roadmapStateNotifierProvider.notifier)
            .loadRoadmap(courseId);
        if (!isCurrent()) return false;
      }

      state = state.copyWith(
        history: updatedHistory,
        submissions: updatedSubmissions,
        clearCurrentQuestion: true,
        isSubmitting: false,
        result: result,
        canRetake: true,
        lastSubmittedAt: DateTime.now(),
        clearNotice: true,
      );

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
        clearNotice: true,
      );
      return false;
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
  final String textAnswer;
  final Map<String, String> selectedMatchPairs;
  final String? activeMatchLeftId;
  final List<String> selectedOrderTokens;
  final Set<String> checkedRubricIds;
  final LessonAnswerResult? answerResult;
  final Map<String, int> consecutiveMistakesBySkill;
  final Map<String, int> consecutiveMistakesByQuestion;
  final bool isSubmittingAnswer;
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
    this.textAnswer = '',
    this.selectedMatchPairs = const {},
    this.activeMatchLeftId,
    this.selectedOrderTokens = const [],
    this.checkedRubricIds = const {},
    this.answerResult,
    this.consecutiveMistakesBySkill = const {},
    this.consecutiveMistakesByQuestion = const {},
    this.isSubmittingAnswer = false,
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
    String? textAnswer,
    Map<String, String>? selectedMatchPairs,
    String? activeMatchLeftId,
    List<String>? selectedOrderTokens,
    Set<String>? checkedRubricIds,
    LessonAnswerResult? answerResult,
    Map<String, int>? consecutiveMistakesBySkill,
    Map<String, int>? consecutiveMistakesByQuestion,
    bool? isSubmittingAnswer,
    bool? showReinforcementSheet,
    ReinforcementResult? reinforcementResult,
    String? answerError,
    String? lessonError,
    bool clearAnswerResult = false,
    bool clearAnswerError = false,
    bool clearSelectedOption = false,
    bool clearTextAnswer = false,
    bool clearRichExerciseState = false,
    bool clearActiveMatchLeftId = false,
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
      textAnswer: clearTextAnswer ? '' : (textAnswer ?? this.textAnswer),
      selectedMatchPairs: clearRichExerciseState
          ? const {}
          : (selectedMatchPairs ?? this.selectedMatchPairs),
      activeMatchLeftId: (clearRichExerciseState || clearActiveMatchLeftId)
          ? null
          : (activeMatchLeftId ?? this.activeMatchLeftId),
      selectedOrderTokens: clearRichExerciseState
          ? const []
          : (selectedOrderTokens ?? this.selectedOrderTokens),
      checkedRubricIds: clearRichExerciseState
          ? const {}
          : (checkedRubricIds ?? this.checkedRubricIds),
      answerResult: clearAnswerResult
          ? null
          : (answerResult ?? this.answerResult),
      consecutiveMistakesBySkill:
          consecutiveMistakesBySkill ?? this.consecutiveMistakesBySkill,
      consecutiveMistakesByQuestion:
          consecutiveMistakesByQuestion ?? this.consecutiveMistakesByQuestion,
      isSubmittingAnswer: isSubmittingAnswer ?? this.isSubmittingAnswer,
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
  final Map<String, LessonAnswerResult> _pendingSubmittedResults = {};
  ReinforcementResult? _completedReinforcement;
  String? _lastLessonId;

  int get sessionGeneration => _lessonGeneration;
  int get stepGeneration => _stepGeneration;

  LessonSessionNotifier(this.ref) : super(const LessonSessionState());

  String? get _accountId =>
      ref.read(learnerStateNotifierProvider).valueOrNull?.id;

  String _resolveLocale(String? uiLocale) =>
      uiLocale ??
      ((ref.read(appSettingsProvider).localeCode == 'ru' ||
              _isRuPlatformLocale())
          ? 'ru'
          : 'uz');

  Future<void> startLesson(String lessonId, {String? uiLocale}) async {
    final generation = ++_lessonGeneration;
    _stepGeneration++;
    _answerGeneration++;
    _passedQuestionIds.clear();
    _pendingSubmittedResults.clear();
    _completedReinforcement = null;
    _lastLessonId = lessonId;
    final resolvedLocale = _resolveLocale(uiLocale);
    state = const LessonSessionState(isLoading: true);
    final startUseCase = ref.read(startLessonUseCaseProvider);
    try {
      final lesson = await startUseCase.execute(lessonId);
      if (!mounted || generation != _lessonGeneration) return;
      final profile = ref.read(learnerStateNotifierProvider).valueOrNull;
      final alreadyCompleted =
          profile?.completedLessonIds.contains(lesson.id) ?? false;
      final rawRestoredStep = (!lesson.requiresMastery && !alreadyCompleted)
          ? await LessonReadingPositionStore.readStepIndex(
              lesson,
              accountId: profile?.id,
            )
          : 0;
      final restoredStep = lesson.steps.isEmpty
          ? 0
          : rawRestoredStep.clamp(0, lesson.steps.length - 1);
      if (!mounted || generation != _lessonGeneration) return;
      state = LessonSessionState(
        lesson: lesson,
        currentStepIndex: restoredStep,
        selectedOptionIndex: null,
        answerResult: null,
        isSubmittingAnswer: false,
        lessonError: null,
      );
    } on FormatException catch (error) {
      if (!mounted || generation != _lessonGeneration) return;
      state = LessonSessionState(lessonError: error.message);
    } catch (_) {
      if (!mounted || generation != _lessonGeneration) return;
      // Missing/invalid lesson: expose an empty session so the screen can show
      // a recoverable localized empty-state instead of crashing or showing
      // another course's content.
      state = LessonSessionState(
        lesson: null,
        lessonError: resolvedLocale == 'ru'
            ? 'Не удалось загрузить данные урока. Попробуйте снова.'
            : 'Dars ma’lumotlari yuklanmadi. Qayta urinib ko‘ring.',
      );
    }
  }

  Future<void> retryStartLesson({String? uiLocale}) async {
    final lessonId = _lastLessonId;
    if (lessonId != null) await startLesson(lessonId, uiLocale: uiLocale);
  }

  Future<void> nextStep({String? uiLocale}) async {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    final resolvedLocale = _resolveLocale(uiLocale);
    if (state.currentStepIndex < lesson.steps.length - 1) {
      final nextIndex = state.currentStepIndex + 1;
      _stepGeneration++;
      _answerGeneration++;
      state = state.copyWith(
        currentStepIndex: nextIndex,
        clearSelectedOption: true,
        clearTextAnswer: true,
        clearRichExerciseState: true,
        clearAnswerResult: true,
        clearAnswerError: true,
        clearReinforcementResult: true,
        showReinforcementSheet: false,
      );
      if (!lesson.requiresMastery) {
        unawaited(
          LessonReadingPositionStore.saveStepIndex(
            lesson,
            nextIndex,
            accountId: _accountId,
          ),
        );
      }
      return;
    }

    final session = _lessonGeneration;
    final step = _stepGeneration;
    final answer = ++_answerGeneration;
    state = state.copyWith(isSubmittingAnswer: true, clearAnswerError: true);
    try {
      await _completeLesson(
        lesson,
        session,
        step,
        answer,
        uiLocale: resolvedLocale,
      );
      if (!_isCurrent(session, step, answer)) return;
      state = state.copyWith(isSubmittingAnswer: false);
    } catch (_) {
      if (!_isCurrent(session, step, answer)) return;
      state = state.copyWith(
        isSubmittingAnswer: false,
        answerError: resolvedLocale == 'ru'
            ? 'Не удалось завершить урок. Попробуйте снова.'
            : 'Darsni yakunlab bo‘lmadi. Qayta urinib ko‘ring.',
      );
    }
  }

  void previousStep() {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    if (state.currentStepIndex > 0) {
      final prevIndex = state.currentStepIndex - 1;
      _stepGeneration++;
      _answerGeneration++;
      state = state.copyWith(
        currentStepIndex: prevIndex,
        clearSelectedOption: true,
        clearTextAnswer: true,
        clearRichExerciseState: true,
        clearAnswerResult: true,
        clearAnswerError: true,
        clearReinforcementResult: true,
        showReinforcementSheet: false,
      );
      if (!lesson.requiresMastery) {
        unawaited(
          LessonReadingPositionStore.saveStepIndex(
            lesson,
            prevIndex,
            accountId: _accountId,
          ),
        );
      }
    }
  }

  void reviewWorkedExample() {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    final index = lesson.steps.indexWhere((step) => step.type == LessonStepType.visualExample);
    final targetIndex = index < 0 ? 0 : index;
    _stepGeneration++;
    _answerGeneration++;
    state = state.copyWith(
      currentStepIndex: targetIndex,
      clearSelectedOption: true,
      clearTextAnswer: true,
      clearRichExerciseState: true,
      clearAnswerResult: true,
      clearAnswerError: true,
      clearReinforcementResult: true,
      showReinforcementSheet: false,
    );
    if (!lesson.requiresMastery) {
      unawaited(
        LessonReadingPositionStore.saveStepIndex(
          lesson,
          targetIndex,
          accountId: _accountId,
        ),
      );
    }
  }

  LessonStep? _activeStep(Lesson lesson) {
    if (lesson.steps.isEmpty ||
        state.currentStepIndex < 0 ||
        state.currentStepIndex >= lesson.steps.length) {
      return null;
    }
    return lesson.steps[state.currentStepIndex];
  }

  void selectOption(int index) {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    final question = _activeStep(lesson)?.interactiveQuestion;
    if (question == null || index < 0 || index >= question.options.length) {
      return;
    }
    if (!lesson.requiresMastery &&
        state.answerResult != null &&
        !state.answerResult!.isCorrect &&
        state.selectedOptionIndex == index) {
      return;
    }
    state = state.copyWith(
      selectedOptionIndex: index,
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  void setTextAnswer(String value) {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    state = state.copyWith(
      textAnswer: value,
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  void selectMatchLeft(String leftId) {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    state = state.copyWith(
      activeMatchLeftId: leftId,
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  void selectMatchRight(String rightText) {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    final question = _activeStep(lesson)?.interactiveQuestion;
    if (question == null || question.mode != QuestionMode.wordMatch) return;

    var targetLeftId = state.activeMatchLeftId;
    if (targetLeftId == null) {
      for (final pair in question.matchPairs) {
        if (!state.selectedMatchPairs.containsKey(pair.id)) {
          targetLeftId = pair.id;
          break;
        }
      }
      targetLeftId ??=
          question.matchPairs.isNotEmpty ? question.matchPairs.first.id : null;
    }
    if (targetLeftId == null) return;

    final updated = Map<String, String>.from(state.selectedMatchPairs)
      ..[targetLeftId] = rightText;
    state = state.copyWith(
      selectedMatchPairs: updated,
      clearActiveMatchLeftId: true,
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  void clearMatchPairs() {
    if (state.isSubmittingAnswer || state.isCompleted) return;
    state = state.copyWith(
      selectedMatchPairs: const {},
      clearActiveMatchLeftId: true,
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  void addOrderToken(String token) {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    final updated = List<String>.from(state.selectedOrderTokens)..add(token);
    state = state.copyWith(
      selectedOrderTokens: updated,
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  void removeOrderTokenAt(int index) {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer || state.isCompleted) return;
    if (index < 0 || index >= state.selectedOrderTokens.length) return;
    final updated = List<String>.from(state.selectedOrderTokens)..removeAt(index);
    state = state.copyWith(
      selectedOrderTokens: updated,
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  void resetOrderTokens() {
    if (state.isSubmittingAnswer || state.isCompleted) return;
    state = state.copyWith(
      selectedOrderTokens: const [],
      clearAnswerResult: true,
      clearAnswerError: true,
    );
  }

  void toggleRubricCriterion(String criterionId) {
    final lesson = state.lesson;
    if (lesson == null || state.isSubmittingAnswer) return;
    final updated = Set<String>.from(state.checkedRubricIds);
    if (updated.contains(criterionId)) {
      updated.remove(criterionId);
    } else {
      updated.add(criterionId);
    }
    state = state.copyWith(checkedRubricIds: updated);
  }

  Future<void> submitInteractiveQuiz({String? uiLocale}) async {
    final lesson = state.lesson;
    if (lesson == null ||
        state.isSubmittingAnswer ||
        state.isCompleted) {
      return;
    }
    final resolvedLocale = _resolveLocale(uiLocale);

    final currentStepIndex = state.currentStepIndex;
    final currentStep = _activeStep(lesson);
    final question = currentStep?.interactiveQuestion;
    if (question == null) return;

    final isTextOrSelf =
        question.usesTextEvaluation || question.isSelfAssessed;
    final isWordMatch = question.mode == QuestionMode.wordMatch;
    final isSentenceOrder = question.mode == QuestionMode.sentenceOrder;
    final hasInput = isTextOrSelf
        ? state.textAnswer.trim().isNotEmpty
        : isWordMatch
        ? state.selectedMatchPairs.values.any((v) => v.trim().isNotEmpty)
        : isSentenceOrder
        ? state.selectedOrderTokens.any((t) => t.trim().isNotEmpty)
        : state.selectedOptionIndex != null;
    if (!hasInput) return;

    final selectedIndex = question.usesOptionSelection
        ? state.selectedOptionIndex!
        : 0;
    final selectedText = isTextOrSelf ? state.textAnswer.trim() : null;
    final inputKey = isTextOrSelf
        ? selectedText!
        : isWordMatch
        ? (state.selectedMatchPairs.entries
                .map((e) => '${e.key}=${e.value}')
                .toList()
              ..sort())
            .join('&')
        : isSentenceOrder
        ? state.selectedOrderTokens.join('\u0001')
        : '$selectedIndex';
    final session = _lessonGeneration;
    final step = _stepGeneration;
    final cacheKey = '$currentStepIndex:${question.id}:$inputKey';

    final generation = ++_answerGeneration;
    state = state.copyWith(
      isSubmittingAnswer: true,
      clearAnswerResult: true,
      clearAnswerError: true,
    );

    var justSubmitted = false;
    try {
      if (!_isCurrent(session, step, generation)) return;
      var result = _pendingSubmittedResults[cacheKey];
      if (result == null) {
        final submitUseCase = ref.read(submitLessonAnswerUseCaseProvider);
        result = await submitUseCase.execute(
          question: question,
          lessonId: lesson.id,
          selectedIndex: selectedIndex,
          selectedText: selectedText,
          matchedPairs: isWordMatch ? state.selectedMatchPairs : null,
          orderedTokens: isSentenceOrder ? state.selectedOrderTokens : null,
          uiLocale: resolvedLocale,
        );
        if (!_isCurrent(session, step, generation)) return;
        justSubmitted = true;
        if (result.isCorrect) {
          _pendingSubmittedResults[cacheKey] = result;
        }
      }
      final updatedSkillStreaks = Map<String, int>.from(
        state.consecutiveMistakesBySkill,
      );
      final updatedQuestionStreaks = Map<String, int>.from(
        state.consecutiveMistakesByQuestion,
      );
      var roadmapRefreshed = false;
      final completedOnFinalStep =
          result.isCorrect &&
          currentStepIndex == lesson.steps.length - 1 &&
          !question.isSelfAssessed;
      if (result.isCorrect) {
        updatedSkillStreaks[question.skillId] = 0;
        updatedQuestionStreaks[question.id] = 0;
        _passedQuestionIds.add(question.id);
        if (completedOnFinalStep) {
          final completed = await _completeLesson(
            lesson,
            session,
            step,
            generation,
            uiLocale: resolvedLocale,
          );
          if (!_isCurrent(session, step, generation)) return;
          if (!completed) {
            if (justSubmitted) {
              await ref
                  .read(learnerStateNotifierProvider.notifier)
                  .loadProfile(
                    isCurrent: () => _isCurrent(session, step, generation),
                  );
              if (!_isCurrent(session, step, generation)) return;
              final activeCourseId =
                  ref.read(courseStateNotifierProvider).activeCourse?.id;
              if (activeCourseId == null ||
                  activeCourseId == lesson.courseId) {
                await ref
                    .read(roadmapStateNotifierProvider.notifier)
                    .loadRoadmap(lesson.courseId);
                if (!_isCurrent(session, step, generation)) return;
              }
            }
            state = state.copyWith(
              isSubmittingAnswer: false,
              consecutiveMistakesBySkill: updatedSkillStreaks,
              consecutiveMistakesByQuestion: updatedQuestionStreaks,
            );
            return;
          }
          roadmapRefreshed = true;
        }
      } else {
        updatedSkillStreaks[question.skillId] =
            (updatedSkillStreaks[question.skillId] ?? 0) + 1;
        updatedQuestionStreaks[question.id] =
            (updatedQuestionStreaks[question.id] ?? 0) + 1;
      }
      if (!completedOnFinalStep) {
        await ref
            .read(learnerStateNotifierProvider.notifier)
            .loadProfile(
              isCurrent: () => _isCurrent(session, step, generation),
            );
        if (!_isCurrent(session, step, generation)) return;
      }
      if (!roadmapRefreshed) {
        final activeCourseId =
            ref.read(courseStateNotifierProvider).activeCourse?.id;
        if (activeCourseId == null || activeCourseId == lesson.courseId) {
          await ref
              .read(roadmapStateNotifierProvider.notifier)
              .loadRoadmap(lesson.courseId);
          if (!_isCurrent(session, step, generation)) return;
        }
      }
      if (!_isCurrent(session, step, generation)) return;
      _pendingSubmittedResults.remove(cacheKey);
      state = state.copyWith(
        isSubmittingAnswer: false,
        answerResult: result,
        consecutiveMistakesBySkill: updatedSkillStreaks,
        consecutiveMistakesByQuestion: updatedQuestionStreaks,
        clearAnswerError: true,
      );
    } catch (_) {
      if (!_isCurrent(session, step, generation)) return;
      if (justSubmitted) {
        await ref
            .read(learnerStateNotifierProvider.notifier)
            .loadProfile(
              isCurrent: () => _isCurrent(session, step, generation),
            );
        if (!_isCurrent(session, step, generation)) return;
      }
      state = state.copyWith(
        isSubmittingAnswer: false,
        answerError: resolvedLocale == 'ru'
            ? 'Не удалось проверить ответ. Проверьте интернет и попробуйте снова.'
            : 'Javobni tekshirib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',
      );
    }
  }

  void openReinforcement() {
    if (state.lesson == null || state.isSubmittingAnswer || state.isCompleted) {
      return;
    }
    state = state.copyWith(showReinforcementSheet: true);
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
    int answer, {
    String uiLocale = 'uz',
  }) async {
    if (!_isCurrent(session, step, answer)) return false;
    final allowMultiSkill = _isIntegratedEnglishLesson(lesson);
    final requiredIds = lesson.steps
        .map((step) => step.interactiveQuestion?.id)
        .whereType<String>()
        .toSet();
    final hasInvalidAssessment = lesson.steps.any((step) {
      final question = step.interactiveQuestion;
      if (question == null) {
        return step.type == LessonStepType.interactiveQuestion;
      }
      final skillMatches =
          question.skillId == lesson.skillId ||
          (allowMultiSkill &&
              lesson.courseId == 'course_eng_01' &&
              question.skillId.startsWith('skill_eng_'));
      final invalidMcq = question.usesOptionSelection &&
          (question.options.length < 2 ||
              question.options.any((option) => option.trim().isEmpty));
      final invalidText = question.usesTextEvaluation &&
          !SupabaseConfig.hasRemoteConfiguration &&
          !question.acceptedAnswers.any((answer) => answer.trim().isNotEmpty);
      final invalidWordMatch = question.mode == QuestionMode.wordMatch &&
          question.matchPairs.isEmpty;
      final invalidOrder = question.mode == QuestionMode.sentenceOrder &&
          question.orderedTokens.isEmpty;
      return question.id.trim().isEmpty ||
          question.courseId != lesson.courseId ||
          question.skillId.trim().isEmpty ||
          !skillMatches ||
          question.text.trim().isEmpty ||
          invalidMcq ||
          invalidText ||
          invalidWordMatch ||
          invalidOrder;
    });
    if (requiredIds.isEmpty || hasInvalidAssessment ||
        (!lesson.requiresMastery && !_passedQuestionIds.containsAll(requiredIds))) {
      state = state.copyWith(
        answerError: uiLocale == 'ru'
            ? 'Сначала правильно ответьте на все интерактивные вопросы урока.'
            : 'Avval darsdagi barcha interaktiv savollarga to‘g‘ri javob bering.',
      );
      return false;
    }
    await ref
        .read(learnerRepositoryProvider)
        .markLessonCompleted(lesson.id, courseId: lesson.courseId);
    if (!_isCurrent(session, step, answer)) return false;
    await LessonReadingPositionStore.clearStepIndex(
      lesson,
      accountId: _accountId,
    );
    if (!_isCurrent(session, step, answer)) return false;
    await ref
        .read(learnerStateNotifierProvider.notifier)
        .loadProfile(isCurrent: () => _isCurrent(session, step, answer));
    if (!_isCurrent(session, step, answer)) return false;
    final activeCourseId =
        ref.read(courseStateNotifierProvider).activeCourse?.id;
    if (activeCourseId == null || activeCourseId == lesson.courseId) {
      await ref
          .read(roadmapStateNotifierProvider.notifier)
          .loadRoadmap(lesson.courseId);
      if (!_isCurrent(session, step, answer)) return false;
    }
    state = state.copyWith(isCompleted: true);
    return true;
  }

  Future<ReinforcementResult?> submitReinforcement(
    int selectedIndex, {
    String? selectedText,
    Map<String, String>? matchedPairs,
    List<String>? orderedTokens,
    bool useAlternate = false,
  }) async {
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
    final targetQuestion = (useAlternate && lesson.alternateExercise != null)
        ? lesson.alternateExercise!
        : lesson.reinforcementExercise;
    final allowMultiSkill =
        _isIntegratedEnglishLesson(lesson) &&
        targetQuestion.courseId == courseId &&
        targetQuestion.skillId.startsWith('skill_eng_');
    final skillId = allowMultiSkill ? targetQuestion.skillId : lesson.skillId;

    try {
      if (!_isCurrent(session, step, generation)) return null;
      final reinforcementNodeId = deriveCanonicalReinforcementNodeId(
        roadmap: ref.read(roadmapStateNotifierProvider).valueOrNull,
        courseId: courseId,
        skillId: skillId,
        lessonId: lesson.id,
      );
      final submitReinfUseCase = ref.read(submitReinforcementUseCaseProvider);
      final result = await submitReinfUseCase.execute(
        courseId: courseId,
        skillId: skillId,
        reinforcementNodeId: reinforcementNodeId,
        reinforcementQuestion: targetQuestion,
        selectedIndex: selectedIndex,
        selectedText: selectedText,
        matchedPairs: matchedPairs,
        orderedTokens: orderedTokens,
      );

      if (!_isCurrent(session, step, generation)) return null;

      if (result.isCorrect) _completedReinforcement = result;
      state = state.copyWith(reinforcementResult: result);
      if (!_isCurrent(session, step, generation)) return null;

      final activeCourseId =
          ref.read(courseStateNotifierProvider).activeCourse?.id;
      if (result.isCorrect &&
          (activeCourseId == null || activeCourseId == courseId)) {
        ref
            .read(roadmapStateNotifierProvider.notifier)
            .updateRoadmapDirect(result.updatedRoadmap);
        if (!_isCurrent(session, step, generation)) return null;
      }
      await ref
          .read(learnerStateNotifierProvider.notifier)
          .loadProfile(
            isCurrent: () => _isCurrent(session, step, generation),
          );
      if (!_isCurrent(session, step, generation)) return null;

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

String deriveCanonicalReinforcementNodeId({
  required LearningPath? roadmap,
  required String courseId,
  required String skillId,
  String? lessonId,
}) {
  final cleanLessonId = lessonId?.trim();
  if (roadmap != null && roadmap.courseId == courseId) {
    if (cleanLessonId != null && cleanLessonId.isNotEmpty) {
      final baseByLesson = roadmap.nodes
          .where((n) => !n.isReinforcement && n.targetLessonId == cleanLessonId)
          .firstOrNull;
      final explicitByLesson = roadmap.nodes
          .where(
            (n) =>
                n.isReinforcement &&
                (n.targetLessonId == cleanLessonId ||
                    (baseByLesson != null && n.id == 'reinf_${baseByLesson.id}')),
          )
          .firstOrNull;
      if (explicitByLesson != null) return explicitByLesson.id;
      if (baseByLesson != null) {
        return baseByLesson.id.startsWith('reinf_')
            ? baseByLesson.id
            : 'reinf_${baseByLesson.id}';
      }
      return cleanLessonId.startsWith('reinf_')
          ? cleanLessonId
          : 'reinf_lesson_$cleanLessonId';
    }

    final explicitBySkill = roadmap.nodes
        .where((n) => n.isReinforcement && n.skillId == skillId)
        .firstOrNull;
    if (explicitBySkill != null) return explicitBySkill.id;

    final baseBySkill = roadmap.nodes
        .where((n) => !n.isReinforcement && n.skillId == skillId)
        .firstOrNull;
    if (baseBySkill != null) {
      return baseBySkill.id.startsWith('reinf_')
          ? baseBySkill.id
          : 'reinf_${baseBySkill.id}';
    }
  }
  if (cleanLessonId != null && cleanLessonId.isNotEmpty) {
    return cleanLessonId.startsWith('reinf_')
        ? cleanLessonId
        : 'reinf_lesson_$cleanLessonId';
  }
  return 'reinf_${courseId}_$skillId';
}

final lessonSessionNotifierProvider =
    StateNotifierProvider<LessonSessionNotifier, LessonSessionState>((ref) {
      return LessonSessionNotifier(ref);
    });
