import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/data/datasources/english/b1_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:bilimyol_mobile/domain/personalization/adaptive_cycle_engine.dart';
import 'package:bilimyol_mobile/domain/personalization/route_engine.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_reinforcement_use_case.dart';
import 'package:bilimyol_mobile/features/dashboard/dashboard_screen.dart';
import 'package:bilimyol_mobile/features/dashboard/widgets/adaptive_cycle_card.dart';
import 'package:bilimyol_mobile/features/reinforcement/reinforcement_sheet.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

SkillScore _score(String courseId, String skillId, int score) => SkillScore(
  courseId: courseId,
  skillId: skillId,
  score: score,
  lastUpdated: 1700000000000,
  masteryLevel: score >= 80
      ? MasteryLevel.mastered
      : score >= 70
      ? MasteryLevel.proficient
      : score >= 50
      ? MasteryLevel.developing
      : MasteryLevel.needsRemediation,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('W1-B4: Unified Roadmap Unlock Policy, Targeted Reinforcement & Honest 5-Step XAI', () {
    test('FIX-P1-08: Scenario C & D diagnostic >=80% unlocks downstream prerequisites without marking unstudied nodes completed', () {
      final mathNodes = seedRoadmapNodes['course_math_01']!;

      // Scenario C: alg=100, eq=100, func=0, graphs=0 -> 0 completed, alg & eq available, func reinforcement
      final scenarioC = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: {
          'skill_math_algebra': _score('course_math_01', 'skill_math_algebra', 100),
          'skill_math_equations': _score('course_math_01', 'skill_math_equations', 100),
          'skill_math_functions': _score('course_math_01', 'skill_math_functions', 0),
          'skill_math_graphs': _score('course_math_01', 'skill_math_graphs', 0),
        },
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );
      final baseC = scenarioC.nodes.where((n) => !n.isReinforcement).toList();
      expect(baseC.where((n) => n.status == NodeStatus.completed), isEmpty);
      expect(baseC.firstWhere((n) => n.id == 'node_math_alg').status, NodeStatus.available);
      expect(baseC.firstWhere((n) => n.id == 'node_math_eq').status, NodeStatus.available);
      expect(baseC.firstWhere((n) => n.id == 'node_math_func').status, NodeStatus.reinforcement);
      expect(baseC.firstWhere((n) => n.id == 'node_math_graphs').status, NodeStatus.locked);
      expect(scenarioC.activeNodeId, 'node_math_func');

      // Scenario D: 100% across all skills -> 0 completed, all 4 available (never 0 available!)
      final scenarioDScores = {
        'skill_math_algebra': _score('course_math_01', 'skill_math_algebra', 100),
        'skill_math_equations': _score('course_math_01', 'skill_math_equations', 100),
        'skill_math_functions': _score('course_math_01', 'skill_math_functions', 100),
        'skill_math_graphs': _score('course_math_01', 'skill_math_graphs', 100),
      };
      final scenarioD = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: scenarioDScores,
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );
      final baseD = scenarioD.nodes.where((n) => !n.isReinforcement).toList();
      expect(baseD.where((n) => n.status == NodeStatus.completed), isEmpty);
      expect(baseD.where((n) => n.status == NodeStatus.available).length, 4);
      expect(scenarioD.activeNodeId, 'node_math_alg');

      final scenarioDExam = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: scenarioDScores,
        completedNodeIds: const [],
        completedReinforcementIds: const [],
        goal: OnboardingGoal.examPrep,
        dailyMinutes: 30,
      );
      expect(scenarioDExam.activeNodeId, 'node_math_graphs');
    });

    test('FIX-P1-19: Scenario F returning learner injects reinf_node_math_alg, retains completed reinf_* when score >=50, and aligns English A2 activeNodeId', () {
      final mathNodes = seedRoadmapNodes['course_math_01']!;
      final zeroMathScores = {
        'skill_math_algebra': _score('course_math_01', 'skill_math_algebra', 0),
        'skill_math_equations': _score('course_math_01', 'skill_math_equations', 0),
        'skill_math_functions': _score('course_math_01', 'skill_math_functions', 0),
        'skill_math_graphs': _score('course_math_01', 'skill_math_graphs', 0),
      };

      final returningMath = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: zeroMathScores,
        completedNodeIds: const ['node_math_alg'],
        completedReinforcementIds: const [],
      );
      final reinfAlg = returningMath.nodes.firstWhere((n) => n.id == 'reinf_node_math_alg');
      expect(reinfAlg.status, NodeStatus.available);
      expect(reinfAlg.targetLessonId, 'lesson_math_algebra_01');
      expect(RouteEngine.canStartNode(reinfAlg, const []), isTrue);
      expect(returningMath.activeNodeId, 'reinf_node_math_alg');

      // Completed reinforcement node retained when score rises to 65%
      final retainedRoadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: {
          'skill_math_algebra': _score('course_math_01', 'skill_math_algebra', 65),
        },
        completedNodeIds: const [],
        completedReinforcementIds: const ['reinf_node_math_alg'],
      );
      final retainedReinf = retainedRoadmap.nodes.firstWhere((n) => n.id == 'reinf_node_math_alg');
      expect(retainedReinf.status, NodeStatus.completed);

      // Returning A2-placed English learner with <50% scores keeps activeNodeId on A2 entry
      final engRoadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_eng_01',
        baseNodes: seedRoadmapNodes['course_eng_01']!,
        skillScores: {
          'skill_eng_vocab': _score('course_eng_01', 'skill_eng_vocab', 30),
          'skill_eng_grammar': _score('course_eng_01', 'skill_eng_grammar', 30),
          'skill_eng_listening': _score('course_eng_01', 'skill_eng_listening', 30),
          'skill_eng_reading': _score('course_eng_01', 'skill_eng_reading', 30),
        },
        completedNodeIds: const ['node_eng_a1_exit'],
        completedReinforcementIds: const [],
        placementCefrTier: 'A2',
      );
      expect(engRoadmap.activeNodeId, 'node_eng_a2_m1_directions');
    });

    test('FIX-P1-18: SubmitReinforcementUseCase preserves B1 placementCefrTier across wrong and correct submissions', () async {
      SharedPreferences.setMockInitialValues({});
      final learnerRepo = InMemoryLearnerRepository();
      final lessonRepo = InMemoryLessonRepository();
      final current = await learnerRepo.getProfile();
      await learnerRepo.updateProfile(
        current.copyWith(
          selectedCourseId: 'course_eng_01',
          placementCefrByCourse: const {'course_eng_01': 'B1'},
          scoresByCourse: {
            'course_eng_01': {
              'skill_eng_grammar': _score('course_eng_01', 'skill_eng_grammar', 32),
            },
          },
        ),
      );

      final b1Lesson = b1LessonsData['lesson_eng_b1_m1_travel']!;
      final q = b1Lesson.reinforcementExercise;
      final useCase = SubmitReinforcementUseCase(learnerRepo, lessonRepo);

      // 1. Wrong answer path must STILL preserve B1 unlock
      if (q.usesOptionSelection && q.options.length > 1) {
        final wrongIdx = (q.correctIndex + 1) % q.options.length;
        final wrongRes = await useCase.execute(
          courseId: 'course_eng_01',
          skillId: q.skillId,
          reinforcementNodeId: 'reinf_node_eng_b1_m1_travel',
          reinforcementQuestion: q,
          selectedIndex: wrongIdx,
        );
        expect(wrongRes.isCorrect, isFalse);
        final b1NodeAfterWrong = wrongRes.updatedRoadmap.nodes.firstWhere(
          (n) => n.id == 'node_eng_b1_m1_travel',
        );
        expect(b1NodeAfterWrong.status, isNot(NodeStatus.locked));
      }

      // 2. Correct answer path must preserve B1 unlock and complete reinf_node_eng_b1_m1_travel
      final correctRes = await useCase.execute(
        courseId: 'course_eng_01',
        skillId: q.skillId,
        reinforcementNodeId: 'reinf_node_eng_b1_m1_travel',
        reinforcementQuestion: q,
        selectedIndex: q.usesOptionSelection ? q.correctIndex : 0,
        selectedText: q.usesTextEvaluation ? q.acceptedAnswers.first : null,
      );
      expect(correctRes.isCorrect, isTrue);
      final b1NodeAfterCorrect = correctRes.updatedRoadmap.nodes.firstWhere(
        (n) => n.id == 'node_eng_b1_m1_travel',
      );
      expect(b1NodeAfterCorrect.status, isNot(NodeStatus.locked));
      final completedReinf = correctRes.updatedRoadmap.nodes.firstWhere(
        (n) => n.id == 'reinf_node_eng_b1_m1_travel',
      );
      expect(completedReinf.status, NodeStatus.completed);
    });

    test('FIX-P0-03 & FIX-P1-01: AdaptiveCycleEngine prevents Step 4/5 inversion, reports 0% zero-lesson growth, and supports Math Pilot', () async {
      final courseRepo = InMemoryCourseRepository();
      final courses = await courseRepo.getAllCourses();
      final mathCourse = courses.firstWhere((c) => c.id == 'course_math_01');
      final mathSkills = await courseRepo.getSkillsByCourseId('course_math_01');
      final mathNodes = seedRoadmapNodes['course_math_01']!;

      final dScores = {
        'skill_math_algebra': _score('course_math_01', 'skill_math_algebra', 100),
        'skill_math_equations': _score('course_math_01', 'skill_math_equations', 100),
        'skill_math_functions': _score('course_math_01', 'skill_math_functions', 100),
        'skill_math_graphs': _score('course_math_01', 'skill_math_graphs', 100),
      };
      final dRoadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: dScores,
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );
      final dProfile = LearnerProfile(
        id: 'p_d',
        name: 'Test',
        selectedCourseId: 'course_math_01',
        goal: OnboardingGoal.mastery,
        dailyMinutes: 15,
        initialLevel: InitialLevel.intermediate,
        courseLevels: const {'course_math_01': InitialLevel.intermediate},
        xp: 0,
        streakDays: 0,
        lastActiveDate: '',
        scoresByCourse: {'course_math_01': dScores},
        placementScoreByCourse: const {'course_math_01': 100},
        placementSkillScoresByCourse: {'course_math_01': dScores},
        completedLessonIds: const [],
        completedNodeIds: const [],
        completedReinforcementIds: const [],
        createdAt: 1700000000000,
      );

      final cycle = AdaptiveCycleEngine.evaluateCycle(
        AdaptiveContextInput(
          course: mathCourse,
          profile: dProfile,
          skills: mathSkills,
          skillScores: dScores,
          roadmap: dRoadmap,
        ),
      );
      expect(cycle.steps[3].status, AdaptiveStepStatus.upcoming);
      expect(cycle.steps[4].status, AdaptiveStepStatus.upcoming);

      final metrics = AdaptiveCycleEngine.measureEffectiveness(
        AdaptiveContextInput(
          course: mathCourse,
          profile: dProfile,
          skills: mathSkills,
          skillScores: dScores,
          roadmap: dRoadmap,
        ),
      );
      expect(metrics.growthDelta, 0);
      expect(metrics.baselineScore, 100);

      // Scenario C micro-task targets reinf_node_math_func
      final cScores = {
        'skill_math_algebra': _score('course_math_01', 'skill_math_algebra', 100),
        'skill_math_equations': _score('course_math_01', 'skill_math_equations', 100),
        'skill_math_functions': _score('course_math_01', 'skill_math_functions', 0),
        'skill_math_graphs': _score('course_math_01', 'skill_math_graphs', 50),
      };
      final cRoadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: cScores,
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );
      final cTasks = AdaptiveCycleEngine.buildDailyMicroTasks(
        AdaptiveContextInput(
          course: mathCourse,
          profile: dProfile,
          skills: mathSkills,
          skillScores: cScores,
          roadmap: cRoadmap,
        ),
      );
      expect(cTasks.first.id, 'micro_reinf');
      expect(cTasks.first.targetNodeId, 'reinf_node_math_func');
    });

    testWidgets('FIX-P0-03 & FIX-P1-18: DashboardScreen renders AdaptiveCycleCard and RoadmapScreen opens standalone ReinforcementSheet', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final learnerRepo = InMemoryLearnerRepository();
      final courseRepo = InMemoryCourseRepository();
      final lessonRepo = InMemoryLessonRepository();
      final base = await learnerRepo.getProfile();
      await learnerRepo.updateProfile(
        base.copyWith(
          selectedCourseId: 'course_it',
          courseLevels: const {'course_it': InitialLevel.beginner},
          scoresByCourse: {
            'course_it': {
              'skill_it_python': _score('course_it', 'skill_it_python', 35),
            },
          },
          placementScoreByCourse: const {'course_it': 35},
          placementSkillScoresByCourse: {
            'course_it': {
              'skill_it_python': _score('course_it', 'skill_it_python', 35),
            },
          },
        ),
      );

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/roadmap', builder: (_, _) => const RoadmapScreen()),
          GoRoute(path: '/lesson', builder: (_, _) => const Scaffold(body: Text('FULL_LESSON_SCREEN'))),
          GoRoute(path: '/courses', builder: (_, _) => const Scaffold(body: Text('COURSES'))),
          GoRoute(path: '/knowledge-map', builder: (_, _) => const Scaffold(body: Text('KNOWLEDGE_MAP'))),
          GoRoute(path: '/placement', builder: (_, _) => const Scaffold(body: Text('PLACEMENT'))),
          GoRoute(path: '/progress', builder: (_, _) => const Scaffold(body: Text('PROGRESS'))),
          GoRoute(path: '/ai-tutor', builder: (_, _) => const Scaffold(body: Text('AI_TUTOR'))),
          GoRoute(path: '/profile', builder: (_, _) => const Scaffold(body: Text('PROFILE'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(learnerRepo),
            courseRepositoryProvider.overrideWithValue(courseRepo),
            lessonRepositoryProvider.overrideWithValue(lessonRepo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppStrings.localizationsDelegates,
            supportedLocales: AppStrings.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Dashboard renders AdaptiveCycleCard once scrolled into the ListView viewport
      await tester.scrollUntilVisible(
        find.byType(AdaptiveCycleCard),
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveCycleCard), findsOneWidget);

      // 2. Navigate to RoadmapScreen and tap reinforcement button -> opens ReinforcementSheet modal, NOT /lesson
      router.go('/roadmap');
      await tester.pumpAndSettle();

      final practiceBtn = find.text('Mashq qilish');
      expect(practiceBtn, findsAtLeastNWidgets(2));
      await tester.ensureVisible(practiceBtn.last);
      await tester.pumpAndSettle();
      await tester.tap(practiceBtn.last);
      await tester.pumpAndSettle();

      expect(find.byType(ReinforcementSheet), findsOneWidget);
      expect(find.text('FULL_LESSON_SCREEN'), findsNothing);
    });

    test('FIX-P1-18 & FIX-P1-19: Multi-skill B1 SubmitReinforcementUseCase remediates listening parent without corrupting unassessed grammar to 22%', () async {
      SharedPreferences.setMockInitialValues({});
      final learnerRepo = InMemoryLearnerRepository();
      final lessonRepo = InMemoryLessonRepository();
      final current = await learnerRepo.getProfile();
      await learnerRepo.updateProfile(
        current.copyWith(
          selectedCourseId: 'course_eng_01',
          placementCefrByCourse: const {'course_eng_01': 'B1'},
          scoresByCourse: {
            'course_eng_01': {
              'skill_eng_listening': _score(
                'course_eng_01',
                'skill_eng_listening',
                32,
              ),
            },
          },
        ),
      );

      final b1Lesson = b1LessonsData['lesson_eng_b1_m1_travel']!;
      final q = b1Lesson.reinforcementExercise;
      expect(q.skillId, 'skill_eng_grammar');
      final useCase = SubmitReinforcementUseCase(learnerRepo, lessonRepo);

      final res = await useCase.execute(
        courseId: 'course_eng_01',
        skillId: q.skillId,
        reinforcementNodeId: 'reinf_node_eng_b1_m1_travel',
        reinforcementQuestion: q,
        selectedIndex: q.usesOptionSelection ? q.correctIndex : 0,
        selectedText: q.usesTextEvaluation ? q.acceptedAnswers.first : null,
      );

      expect(res.isCorrect, isTrue);
      expect(res.oldScore, 32);
      expect(res.newScore, 54);

      final updated = await learnerRepo.getProfile();
      expect(
        updated.scoresByCourse['course_eng_01']!['skill_eng_listening']!.score,
        54,
      );
      expect(
        updated.scoresByCourse['course_eng_01']!['skill_eng_grammar']!.score,
        greaterThanOrEqualTo(50),
      );

      final b1Entry = res.updatedRoadmap.nodes.firstWhere(
        (n) => n.id == 'node_eng_b1_m1_travel',
      );
      final b1Reinf = res.updatedRoadmap.nodes.firstWhere(
        (n) => n.id == 'reinf_node_eng_b1_m1_travel',
      );
      final b1GrammarNode = res.updatedRoadmap.nodes.firstWhere(
        (n) => n.id == 'node_eng_b1_m2_work_study',
      );
      expect(b1Entry.status, NodeStatus.available);
      expect(b1Reinf.status, NodeStatus.completed);
      expect(b1GrammarNode.status, isNot(NodeStatus.reinforcement));
      expect(
        RouteEngine.canStartNode(
          b1Reinf,
          const [],
          placementCefrTier: 'B1',
        ),
        isTrue,
      );
    });

    test('FIX-P0-03 & FIX-P1-01: Mobile AdaptiveCycleEngine counts omitted <50% completed reinforcements and keeps Day-0 steps monotonic', () async {
      final courseRepo = InMemoryCourseRepository();
      final mathCourse = (await courseRepo.getAllCourses()).firstWhere(
        (c) => c.id == 'course_math_01',
      );
      final mathSkills = await courseRepo.getSkillsByCourseId('course_math_01');
      final mathNodes = seedRoadmapNodes['course_math_01']!;

      // 1. Day-0 onboarded learner -> Step 01 active, Steps 02..05 strictly upcoming
      final day0Roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: const {},
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );
      const day0Profile = LearnerProfile(
        id: 'learner_day0',
        name: 'Aziza',
        selectedCourseId: 'course_math_01',
        goal: OnboardingGoal.mastery,
        dailyMinutes: 15,
        initialLevel: InitialLevel.beginner,
        courseLevels: {'course_math_01': InitialLevel.beginner},
        xp: 0,
        streakDays: 0,
        lastActiveDate: '',
        scoresByCourse: {},
        completedLessonIds: [],
        completedNodeIds: [],
        completedReinforcementIds: [],
        createdAt: 1700000000000,
      );
      final day0Cycle = AdaptiveCycleEngine.evaluateCycle(
        AdaptiveContextInput(
          course: mathCourse,
          profile: day0Profile,
          skills: mathSkills,
          skillScores: const {},
          roadmap: day0Roadmap,
        ),
      );
      expect(day0Cycle.activeStep, 1);
      expect(day0Cycle.steps[0].status, AdaptiveStepStatus.active);
      expect(
        day0Cycle.steps.skip(1).every((s) => s.status == AdaptiveStepStatus.upcoming),
        isTrue,
      );

      // 2. Completing reinf_node_math_alg (0% -> 22%) omits reinf_node_math_alg from Mobile roadmap.nodes
      // yet AdaptiveCycleEngine still detects practice activity, Step 05, and +22% growthDelta
      final postReinfScores = {
        'skill_math_algebra': _score('course_math_01', 'skill_math_algebra', 22),
      };
      final postReinfRoadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: mathNodes,
        skillScores: postReinfScores,
        completedNodeIds: const [],
        completedReinforcementIds: const ['reinf_node_math_alg'],
      );
      expect(
        postReinfRoadmap.nodes.any((n) => n.id == 'reinf_node_math_alg'),
        isFalse,
      );
      final postReinfProfile = LearnerProfile(
        id: 'learner_reinf22',
        name: 'Aziza',
        selectedCourseId: 'course_math_01',
        goal: OnboardingGoal.mastery,
        dailyMinutes: 15,
        initialLevel: InitialLevel.beginner,
        xp: 30,
        streakDays: 1,
        lastActiveDate: '2026-11-28',
        scoresByCourse: {'course_math_01': postReinfScores},
        placementScoreByCourse: const {'course_math_01': 0},
        placementSkillScoresByCourse: {
          'course_math_01': {
            'skill_math_algebra': _score('course_math_01', 'skill_math_algebra', 0),
          },
        },
        completedLessonIds: const [],
        completedNodeIds: const [],
        completedReinforcementIds: const ['reinf_node_math_alg'],
        createdAt: 1700000000000,
      );
      final postReinfCycle = AdaptiveCycleEngine.evaluateCycle(
        AdaptiveContextInput(
          course: mathCourse,
          profile: postReinfProfile,
          skills: mathSkills,
          skillScores: postReinfScores,
          roadmap: postReinfRoadmap,
        ),
      );
      final postReinfEff = AdaptiveCycleEngine.measureEffectiveness(
        AdaptiveContextInput(
          course: mathCourse,
          profile: postReinfProfile,
          skills: mathSkills,
          skillScores: postReinfScores,
          roadmap: postReinfRoadmap,
        ),
      );
      expect(postReinfCycle.activeStep, 5);
      expect(postReinfCycle.steps[3].status, AdaptiveStepStatus.completed);
      expect(postReinfEff.growthDelta, 22);
    });

    test('FIX-P1-18: RoadmapStateNotifier.submitStandaloneReinforcement reuses UUID and graded attempt across transient completion failure', () async {
      SharedPreferences.setMockInitialValues({});
      final baseRepo = InMemoryLearnerRepository();
      final lessonRepo = InMemoryLessonRepository();
      final courseRepo = InMemoryCourseRepository();
      final current = await baseRepo.getProfile();
      await baseRepo.updateProfile(
        current.copyWith(
          selectedCourseId: 'course_eng_01',
          placementCefrByCourse: const {'course_eng_01': 'B1'},
          scoresByCourse: {
            'course_eng_01': {
              'skill_eng_listening': _score(
                'course_eng_01',
                'skill_eng_listening',
                32,
              ),
            },
          },
        ),
      );

      final proxyRepo = _TransientFailReinforcementRepo(baseRepo);
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(proxyRepo),
          lessonRepositoryProvider.overrideWithValue(lessonRepo),
          courseRepositoryProvider.overrideWithValue(courseRepo),
        ],
      );
      addTearDown(container.dispose);

      final q = b1LessonsData['lesson_eng_b1_m1_travel']!.reinforcementExercise;
      final notifier = container.read(roadmapStateNotifierProvider.notifier);

      // 1st attempt: submitAnswerAttemptIdempotent succeeds, markReinforcementCompleted throws transiently
      await expectLater(
        () => notifier.submitStandaloneReinforcement(
          courseId: 'course_eng_01',
          skillId: q.skillId,
          reinforcementNodeId: 'reinf_node_eng_b1_m1_travel',
          question: q,
          selectedIndex: q.usesOptionSelection ? q.correctIndex : 0,
          selectedText: q.usesTextEvaluation ? q.acceptedAnswers.first : null,
        ),
        throwsStateError,
      );
      expect(proxyRepo.submittedKeys.length, 1);

      // 2nd attempt (retry): reuses cached graded attempt without re-calling submitAnswerAttemptIdempotent
      final retryRes = await notifier.submitStandaloneReinforcement(
        courseId: 'course_eng_01',
        skillId: q.skillId,
        reinforcementNodeId: 'reinf_node_eng_b1_m1_travel',
        question: q,
        selectedIndex: q.usesOptionSelection ? q.correctIndex : 0,
        selectedText: q.usesTextEvaluation ? q.acceptedAnswers.first : null,
      );
      expect(retryRes, isNotNull);
      expect(retryRes!.isCorrect, isTrue);
      expect(proxyRepo.submittedKeys.length, 1);
    });
  });
}

class _TransientFailReinforcementRepo implements ILearnerRepository {
  final InMemoryLearnerRepository _inner;
  bool failNextCompletion = true;
  final List<String> submittedKeys = [];

  _TransientFailReinforcementRepo(this._inner);

  @override
  bool get supportsNodeCompletion => _inner.supportsNodeCompletion;
  @override
  bool get supportsServerPlacementPersistence =>
      _inner.supportsServerPlacementPersistence;
  @override
  bool get supportsServerReinforcementPersistence =>
      _inner.supportsServerReinforcementPersistence;

  @override
  Future<AnswerAttemptRecord> submitAnswerAttemptIdempotent({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
    String? idempotencyKey,
  }) {
    submittedKeys.add(idempotencyKey ?? '');
    return _inner.submitAnswerAttemptIdempotent(
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      idempotencyKey: idempotencyKey,
    );
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
    if (failNextCompletion) {
      failNextCompletion = false;
      throw StateError('Transient network failure');
    }
    return _inner.markReinforcementCompleted(
      reinforcementId: reinforcementId,
      courseId: courseId,
      skillId: skillId,
      questionId: questionId,
      beforeScore: beforeScore,
      afterScore: afterScore,
      xpAwarded: xpAwarded,
    );
  }

  @override
  Future<LearnerProfile> getProfile() => _inner.getProfile();

  @override
  Future<LearnerProfile> getCurrentProfile() => _inner.getCurrentProfile();

  @override
  Future<LearnerProfile> updateProfile(
    LearnerProfile updated, {
    Set<LearnerProfileField>? fields,
  }) => _inner.updateProfile(updated, fields: fields);

  @override
  Future<void> saveSkillScores(
    String courseId,
    Map<String, SkillScore> scores,
  ) => _inner.saveSkillScores(courseId, scores);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
