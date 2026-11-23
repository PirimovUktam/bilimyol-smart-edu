import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/course.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/skill.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:bilimyol_mobile/features/knowledge_map/knowledge_map_screen.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const _openLessonId = 'fixture_open_addition_lesson';

const _mathCourse = Course(
  id: 'course_math_01',
  title: 'Matematika',
  subject: SubjectType.mathematics,
  description: 'Tayanç arifmetikadan çiziqli tenglamalargacha.',
  iconName: 'calculator',
  primaryColorHex: '#4F46E5',
  secondaryColorHex: '#0EA5E9',
  skills: ['skill_math_addition', 'skill_math_multiplication'],
  lessons: [_openLessonId, 'lesson_math_foundation_02'],
  totalStudentsEstimate: 1200,
);

const _pilotSkills = [
  Skill(
    id: 'skill_math_addition',
    courseId: 'course_math_01',
    name: 'Qöşiş va ayiriş',
    code: 'MATH_ADD',
    description: 'Miqdorlarni birlaştiriş va farqni topiş.',
    order: -2,
    iconName: 'calculator',
  ),
  Skill(
    id: 'skill_math_multiplication',
    courseId: 'course_math_01',
    name: 'Teng guruhlar',
    code: 'MATH_MUL',
    description: 'Teng miqdorlarni takror qöşiş va köpaytiriş.',
    order: -1,
    iconName: 'calculator',
  ),
];

List<LearningPathNode> _buildNodes({
  NodeStatus firstStatus = NodeStatus.available,
  String? firstLessonId = _openLessonId,
  int firstAnswered = 0,
  int firstCorrect = 0,
}) => [
  LearningPathNode(
    id: 'node_math_addition',
    courseId: 'course_math_01',
    skillId: 'skill_math_addition',
    title: 'Qöşiş va ayiriş',
    description:
        'Birlaştiriş va ayrim qismini olib taşlaşni sonlar bilan ifodalang.',
    prerequisites: const [],
    requiredScore: 80,
    status: firstStatus,
    isReinforcement: false,
    targetLessonId: firstLessonId,
    estimatedMinutes: 8,
    order: 10,
    serverMastery: true,
    mastery: NodeMastery(
      state: firstAnswered > 0 ? 'practicing' : 'not_started',
      answered: firstAnswered,
      correct: firstCorrect,
      requiredItems: 5,
      passedCheckpoints: 0,
      requiredCheckpoints: 2,
      reviewDue: false,
    ),
  ),
  const LearningPathNode(
    id: 'node_math_multiplication',
    courseId: 'course_math_01',
    skillId: 'skill_math_multiplication',
    title: 'Teng guruhlar va köpaytiriş',
    description:
        'Teng guruhlarni takroriy qöşiş va köpaytiriş bilan ifodalang.',
    prerequisites: ['node_math_addition'],
    requiredScore: 80,
    status: NodeStatus.locked,
    isReinforcement: false,
    targetLessonId: 'lesson_math_foundation_02',
    estimatedMinutes: 8,
    order: 20,
    serverMastery: true,
    mastery: NodeMastery(
      state: 'not_started',
      answered: 0,
      correct: 0,
      requiredItems: 5,
      passedCheckpoints: 0,
      requiredCheckpoints: 2,
      reviewDue: false,
    ),
  ),
];

class _FakeCourseRepository extends InMemoryCourseRepository {
  bool failCourses = false;

  @override
  Future<List<Course>> getAllCourses() async {
    if (failCourses) {
      throw StateError('Simulated courses load error');
    }
    return const [_mathCourse];
  }

  @override
  Future<Course?> getCourseById(String courseId) async =>
      courseId == _mathCourse.id ? _mathCourse : null;

  @override
  Future<List<Skill>> getSkillsByCourseId(String courseId) async =>
      courseId == _mathCourse.id ? _pilotSkills : const [];
}

class _FakeLessonRepository extends InMemoryLessonRepository {
  _FakeLessonRepository(this.nodes);

  List<LearningPathNode> nodes;
  int loadCalls = 0;
  bool failLoad = false;

  @override
  Future<List<LearningPathNode>> getBaseRoadmapNodes(String courseId) async {
    loadCalls++;
    if (failLoad) {
      throw StateError('Simulated network error');
    }
    return nodes;
  }

  @override
  Future<Lesson?> getLessonById(String lessonId) async {
    if (lessonId != _openLessonId) return null;
    return const Lesson(
      id: _openLessonId,
      courseId: 'course_math_01',
      skillId: 'skill_math_addition',
      title: 'Qöşiş va ayirişdan boşlaymiz',
      summary: 'Tayanç dars',
      estimatedMinutes: 8,
      requiresMastery: true,
      steps: [
        LessonStep(
          id: 'step_1',
          stepNumber: 1,
          type: LessonStepType.interactiveQuestion,
          title: '1-maşq',
          content: '4 + 3 neçaga teng?',
          interactiveQuestion: Question(
            id: 'q_pilot_lesson_math_starter_1',
            courseId: 'course_math_01',
            skillId: 'skill_math_addition',
            text: '4 + 3 neçaga teng?',
            options: ['7', '6', '8'],
            correctIndex: 0,
            difficulty: QuestionDifficulty.easy,
            explanation: '4 + 3 = 7.',
          ),
        ),
        LessonStep(
          id: 'step_2',
          stepNumber: 2,
          type: LessonStepType.concept,
          title: 'Xulosa',
          content: 'Davom eting.',
        ),
      ],
      reinforcementExercise: Question(
        id: 'q_pilot_lesson_math_starter_1',
        courseId: 'course_math_01',
        skillId: 'skill_math_addition',
        text: '4 + 3 neçaga teng?',
        options: ['7', '6', '8'],
        correctIndex: 0,
        difficulty: QuestionDifficulty.easy,
        explanation: '4 + 3 = 7.',
      ),
    );
  }
}

class _FakeLearnerRepository extends InMemoryLearnerRepository {
  _FakeLearnerRepository(
    this.scores, {
    this.onAnswer,
    this.selectedCourseId = 'course_math_01',
  });

  final Map<String, SkillScore> scores;
  final VoidCallback? onAnswer;
  final String selectedCourseId;

  @override
  Future<LearnerProfile> getProfile() async {
    final base = await super.getProfile();
    return base.copyWith(
      selectedCourseId: selectedCourseId,
      scoresByCourse: scores.isEmpty ? const {} : {'course_math_01': scores},
    );
  }

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
    onAnswer?.call();
    return super.recordAnswerAttempt(
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      isCorrect: isCorrect,
    );
  }
}

Future<
  ({
    GoRouter router,
    ProviderContainer container,
    _FakeLessonRepository lessonRepo,
  })
>
_mountKnowledgeMap(
  WidgetTester tester, {
  required Map<String, SkillScore> scores,
  List<LearningPathNode>? nodes,
  bool invalidateRoadmapBeforeMount = true,
  bool failInitialLoad = false,
  VoidCallback? onAnswer,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final lessonRepo = _FakeLessonRepository(nodes ?? _buildNodes());
  late final _FakeLearnerRepository learnerRepo;
  learnerRepo = _FakeLearnerRepository(
    scores,
    onAnswer: () {
      lessonRepo.nodes = _buildNodes(
        firstStatus: NodeStatus.inProgress,
        firstAnswered: 1,
        firstCorrect: 1,
      );
      onAnswer?.call();
    },
  );
  final courseRepo = _FakeCourseRepository();

  final router = GoRouter(
    initialLocation: '/knowledge-map',
    routes: [
      GoRoute(
        path: '/knowledge-map',
        builder: (_, _) => const KnowledgeMapScreen(),
      ),
      GoRoute(
        path: '/placement',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('OPENED:/placement'))),
      ),
      GoRoute(
        path: '/roadmap',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('OPENED:/roadmap'))),
      ),
      GoRoute(
        path: '/lesson',
        builder: (_, _) => const InteractiveLessonScreen(),
      ),
    ],
  );

  final container = ProviderContainer(
    overrides: [
      courseRepositoryProvider.overrideWithValue(courseRepo),
      lessonRepositoryProvider.overrideWithValue(lessonRepo),
      learnerRepositoryProvider.overrideWithValue(learnerRepo),
    ],
  );
  addTearDown(container.dispose);

  container.read(courseStateNotifierProvider);
  await tester.pump(const Duration(milliseconds: 100));
  await container.read(learnerStateNotifierProvider.notifier).loadProfile();
  await container
      .read(courseStateNotifierProvider.notifier)
      .selectCourse('course_math_01');
  if (invalidateRoadmapBeforeMount) {
    container.invalidate(roadmapStateNotifierProvider);
  }
  lessonRepo.loadCalls = 0;
  lessonRepo.failLoad = failInitialLoad;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return (router: router, container: container, lessonRepo: lessonRepo);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SupabaseConfig.hasRemoteConfiguration = true;
  });

  tearDown(() {
    SupabaseConfig.hasRemoteConfiguration = false;
  });

  test(
    'SupabaseLessonRepository.parseRoadmapNode maps RPC mastery counts and copyWith preserves them',
    () {
      final parsed = SupabaseLessonRepository.parseRoadmapNode({
        'id': 'node_math_addition',
        'course_id': 'course_math_01',
        'skill_id': 'skill_math_addition',
        'title': 'Qöşiş va ayiriş',
        'description': 'Tavsif',
        'prerequisites': const <String>[],
        'required_score': 80,
        'status': 'in_progress',
        'target_lesson_id': _openLessonId,
        'estimated_minutes': 8,
        'order_index': 10,
        'mastery_state': 'practicing',
        'answered': 1,
        'correct': 1,
        'required_items': 5,
        'passed_checkpoints': 1,
        'required_checkpoints': 2,
        'review_due': false,
        'is_optional': false,
      });

      expect(parsed.serverMastery, isTrue);
      expect(parsed.mastery?.answered, 1);
      expect(parsed.mastery?.correct, 1);
      expect(parsed.mastery?.requiredItems, 5);
      expect(parsed.mastery?.passedCheckpoints, 1);
      expect(parsed.mastery?.requiredCheckpoints, 2);

      final copied = parsed.copyWith(title: 'Yangilangan');
      expect(copied.mastery?.answered, 1);
      expect(copied.mastery?.requiredItems, 5);
      expect(copied.serverMastery, isTrue);
    },
  );

  testWidgets(
    'Direct /knowledge-map entry loads once without refetching on rebuilds and supports State A -> /placement',
    (tester) async {
      final ctx = await _mountKnowledgeMap(tester, scores: const {});

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(ctx.lessonRepo.loadCalls, 1);

      // Force additional widget rebuilds without changing active course
      ctx.container
          .read(roadmapStateNotifierProvider.notifier)
          .updateRoadmapDirect(
            LearningPath(
              id: 'roadmap_course_math_01',
              courseId: 'course_math_01',
              title: 'Moslaşuvçan Yöl Xaritasi',
              nodes: _buildNodes(),
              activeNodeId: 'node_math_addition',
              updatedAt: 1,
            ),
          );
      await tester.pump();
      await tester.pump();
      expect(ctx.lessonRepo.loadCalls, 1);

      expect(find.text('Diagnostikani boşlaş'), findsOneWidget);
      expect(find.text('Birinçi maşqni boşlaş'), findsNothing);

      await tester.tap(find.text('Diagnostikani boşlaş'));
      await tester.pumpAndSettle();
      expect(find.text('OPENED:/placement'), findsOneWidget);
    },
  );

  testWidgets(
    'KnowledgeMapScreen shows retryable error state when roadmap load fails',
    (tester) async {
      final ctx = await _mountKnowledgeMap(
        tester,
        scores: const {},
        failInitialLoad: true,
      );

      expect(find.text('Ta’lim yölini yuklab bölmadi.'), findsOneWidget);
      expect(find.text('Qayta uriniş'), findsOneWidget);

      ctx.lessonRepo.failLoad = false;
      await tester.tap(find.text('Qayta uriniş'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Diagnostikani boşlaş'), findsOneWidget);
      expect(ctx.lessonRepo.loadCalls, 2);
    },
  );

  testWidgets(
    'State B (diagnostic score < 100, answered = 0) names checked skill and shows single Birinçi maşqni boşlaş',
    (tester) async {
      await _mountKnowledgeMap(
        tester,
        scores: const {
          'skill_math_addition': SkillScore(
            skillId: 'skill_math_addition',
            courseId: 'course_math_01',
            score: 50,
            lastUpdated: 1700000000000,
            masteryLevel: MasteryLevel.needsRemediation,
            isWeakestFocus: true,
          ),
          'skill_math_multiplication': SkillScore(
            skillId: 'skill_math_multiplication',
            courseId: 'course_math_01',
            score: 100,
            lastUpdated: 1700000000000,
            masteryLevel: MasteryLevel.mastered,
            isWeakestFocus: false,
          ),
        },
      );

      expect(find.text('Diagnostikani boşlaş'), findsNothing);
      expect(find.text('Qöşiş va ayiriş · 50%'), findsOneWidget);
      expect(find.text('Birinçi maşqni boşlaş'), findsOneWidget);
    },
  );

  testWidgets(
    'State B (4/4 diagnostics with isWeakestFocus: true, answered = 0) -> State C (answered = 1, 1/5) end-to-end across /lesson',
    (tester) async {
      final ctx = await _mountKnowledgeMap(
        tester,
        scores: const {
          'skill_math_addition': SkillScore(
            skillId: 'skill_math_addition',
            courseId: 'course_math_01',
            score: 100,
            lastUpdated: 1700000000000,
            masteryLevel: MasteryLevel.mastered,
            isWeakestFocus: true,
          ),
          'skill_math_multiplication': SkillScore(
            skillId: 'skill_math_multiplication',
            courseId: 'course_math_01',
            score: 100,
            lastUpdated: 1700000000000,
            masteryLevel: MasteryLevel.mastered,
            isWeakestFocus: false,
          ),
        },
      );

      expect(find.text('Diagnostikani boşlaş'), findsNothing);
      expect(find.text('0%'), findsOneWidget);
      expect(find.textContaining('xato qildingiz'), findsNothing);
      expect(find.textContaining('tasdiqlaş'), findsOneWidget);
      expect(find.text('Birinçi maşqni boşlaş'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('0/5'), 200);
      expect(find.text('0/5'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Tayanç mavzu talab qilinadi'),
        200,
      );
      expect(find.text('Tayanç mavzu talab qilinadi'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Birinçi maşqni boşlaş'),
        -200,
      );
      await tester.tap(find.text('Birinçi maşqni boşlaş'));
      await tester.pumpAndSettle();

      expect(
        ctx.container.read(lessonSessionNotifierProvider).lesson?.id,
        _openLessonId,
      );
      expect(find.text('Qöşiş va ayirişdan boşlaymiz'), findsOneWidget);

      // Answer question 1 in InteractiveLessonScreen
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      // Return from /lesson back to /knowledge-map
      ctx.router.pop();
      await tester.pumpAndSettle();

      // State C: updated progress 1/5 and Maşq qilinyapti visible immediately
      expect(find.text('Birinçi maşqni boşlaş'), findsNothing);
      expect(find.text('Diagnostikani boşlaş'), findsNothing);
      expect(find.text('1/5'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Maşq qilinyapti'), findsOneWidget);
    },
  );

  testWidgets(
    'State B fallback navigates to /roadmap when no open lesson is resolved',
    (tester) async {
      await _mountKnowledgeMap(
        tester,
        scores: const {
          'skill_math_addition': SkillScore(
            skillId: 'skill_math_addition',
            courseId: 'course_math_01',
            score: 100,
            lastUpdated: 1700000000000,
            masteryLevel: MasteryLevel.mastered,
            isWeakestFocus: true,
          ),
        },
        nodes: _buildNodes(
          firstStatus: NodeStatus.locked,
          firstLessonId: null,
        ),
      );

      expect(find.text('Birinçi maşqni boşlaş'), findsOneWidget);
      await tester.tap(find.text('Birinçi maşqni boşlaş'));
      await tester.pumpAndSettle();
      expect(find.text('OPENED:/roadmap'), findsOneWidget);
    },
  );

  testWidgets(
    'Direct /knowledge-map cold entry recovers from course load error via retry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final courseRepo = _FakeCourseRepository()..failCourses = true;
      final lessonRepo = _FakeLessonRepository(_buildNodes());
      final learnerRepo = _FakeLearnerRepository(const {});
      final router = GoRouter(
        initialLocation: '/knowledge-map',
        routes: [
          GoRoute(
            path: '/knowledge-map',
            builder: (_, _) => const KnowledgeMapScreen(),
          ),
          GoRoute(
            path: '/placement',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('OPENED:/placement'))),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          courseRepositoryProvider.overrideWithValue(courseRepo),
          lessonRepositoryProvider.overrideWithValue(lessonRepo),
          learnerRepositoryProvider.overrideWithValue(learnerRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Kurslarni yuklab bölmadi. Qayta urinib köring.'),
        findsOneWidget,
      );
      expect(find.text('Qayta uriniş'), findsOneWidget);

      courseRepo.failCourses = false;
      await tester.tap(find.text('Qayta uriniş'));
      await tester.pumpAndSettle();

      expect(find.text('Diagnostikani boşlaş'), findsOneWidget);
      expect(find.text('Mavzular va özlaştiriş'), findsOneWidget);
    },
  );

  testWidgets(
    'Direct /knowledge-map cold entry shows course chooser when no active course is selected',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final courseRepo = _FakeCourseRepository();
      final lessonRepo = _FakeLessonRepository(_buildNodes());
      final learnerRepo = _FakeLearnerRepository(
        const {},
        selectedCourseId: '',
      );
      final router = GoRouter(
        initialLocation: '/knowledge-map',
        routes: [
          GoRoute(
            path: '/knowledge-map',
            builder: (_, _) => const KnowledgeMapScreen(),
          ),
          GoRoute(
            path: '/courses',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('OPENED:/courses'))),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          courseRepositoryProvider.overrideWithValue(courseRepo),
          lessonRepositoryProvider.overrideWithValue(lessonRepo),
          learnerRepositoryProvider.overrideWithValue(learnerRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bilim Xaritasi'), findsOneWidget);
      expect(find.text('Fan tanlaş'), findsOneWidget);
      await tester.tap(find.text('Fan tanlaş'));
      await tester.pumpAndSettle();
      expect(find.text('OPENED:/courses'), findsOneWidget);
    },
  );
}
