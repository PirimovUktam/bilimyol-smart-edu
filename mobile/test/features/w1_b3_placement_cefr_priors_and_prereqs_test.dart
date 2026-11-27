import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/data/datasources/english/placement_questions_data.dart';
import 'package:bilimyol_mobile/data/datasources/questions_data.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/placement_session.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/personalization/adaptive_question_selector.dart';
import 'package:bilimyol_mobile/domain/personalization/route_engine.dart';
import 'package:bilimyol_mobile/domain/personalization/skill_scoring_engine.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_placement_test_use_case.dart';
import 'package:bilimyol_mobile/features/knowledge_map/knowledge_map_screen.dart';
import 'package:bilimyol_mobile/features/placement/placement_test_screen.dart';

class _CompletedSessionLearnerRepository extends InMemoryLearnerRepository {
  final PlacementSession completedSession;

  _CompletedSessionLearnerRepository(this.completedSession);

  @override
  bool get supportsPlacementSessions => true;

  @override
  bool get supportsServerPlacementPersistence => false;

  @override
  Future<PlacementSession> advancePlacement(
    String courseId, {
    String? sessionId,
    String? questionId,
    int? selectedIndex,
    bool restart = false,
  }) async {
    return completedSession;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('W1-B3: Placement CEFR Calibration, Priors, Prerequisites & Retake Integrity', () {
    test('FIX-P0-11 & FIX-P1-14: starts English placement at medium (A2), enforces 1-step Markov transitions, and requires B1 evidence for B1', () {
      final engBank = placementQuestionsData['course_eng_01']!;
      const skills = [
        'skill_eng_vocab',
        'skill_eng_grammar',
        'skill_eng_listening',
        'skill_eng_reading',
      ];

      // 1. Starts at medium (A2)
      final first = AdaptiveQuestionSelector.getNextQuestion(
        engBank,
        skills,
        const [],
        2,
      );
      expect(first?.difficulty, equals(QuestionDifficulty.medium));
      expect(first?.cefrLevel, equals('A2'));

      // 2. 1-step Markov transition parity: [easy:true, medium:false] -> easy
      expect(
        AdaptiveQuestionSelector.determineNextDifficulty('skill_eng_vocab', const [
          AnswerHistoryItem(
            questionId: 'q_eng_place_vocab_a1',
            skillId: 'skill_eng_vocab',
            difficulty: QuestionDifficulty.easy,
            isCorrect: true,
          ),
          AnswerHistoryItem(
            questionId: 'q_eng_place_vocab_a2',
            skillId: 'skill_eng_vocab',
            difficulty: QuestionDifficulty.medium,
            isCorrect: false,
          ),
        ]),
        equals(QuestionDifficulty.easy),
      );

      // [hard:false, medium:true] -> hard
      expect(
        AdaptiveQuestionSelector.determineNextDifficulty('skill_eng_vocab', const [
          AnswerHistoryItem(
            questionId: 'q_eng_place_vocab_b1',
            skillId: 'skill_eng_vocab',
            difficulty: QuestionDifficulty.hard,
            isCorrect: false,
          ),
          AnswerHistoryItem(
            questionId: 'q_eng_place_vocab_a2',
            skillId: 'skill_eng_vocab',
            difficulty: QuestionDifficulty.medium,
            isCorrect: true,
          ),
        ]),
        equals(QuestionDifficulty.hard),
      );

      // 3. 8/8 on A1+A2 (b1Total == 0) caps at A2; 8/8 on A2+B1 awards B1
      final a1AndA2 = englishPlacementQuestionsRaw
          .where((q) => q.difficulty != QuestionDifficulty.hard)
          .toList();
      expect(
        SkillScoringEngine.computeEnglishPlacementCefr(
          englishPlacementQuestionsRaw,
          [
            for (final q in a1AndA2)
              QuestionAnswerSubmission(
                questionId: q.id,
                selectedIndex: q.correctIndex,
                isCorrect: true,
              ),
          ],
        ),
        equals('A2'),
      );

      final a2AndB1 = englishPlacementQuestionsRaw
          .where((q) => q.difficulty != QuestionDifficulty.easy)
          .toList();
      expect(
        SkillScoringEngine.computeEnglishPlacementCefr(
          englishPlacementQuestionsRaw,
          [
            for (final q in a2AndB1)
              QuestionAnswerSubmission(
                questionId: q.id,
                selectedIndex: q.correctIndex,
                isCorrect: true,
              ),
          ],
        ),
        equals('B1'),
      );

      // 4/4 A2 + 0/4 B1 places at A2 (never demoted to A1)
      expect(
        SkillScoringEngine.computeEnglishPlacementCefr(
          englishPlacementQuestionsRaw,
          [
            for (final q in a2AndB1)
              QuestionAnswerSubmission(
                questionId: q.id,
                selectedIndex: 0,
                isCorrect: q.cefrLevel == 'A2',
              ),
          ],
        ),
        equals('A2'),
      );
    });

    test('FIX-P1-16: weights placement item credit by difficulty, gates weakest focus on < 80, and deduplicates last-wins', () async {
      SharedPreferences.setMockInitialValues({});
      final engBank = placementQuestionsData['course_eng_01']!;

      // score(m:1, h:0) > score(m:0, e:1)
      final mhScores = SkillScoringEngine.computePlacementScores(
        'course_eng_01',
        engBank,
        const [
          QuestionAnswerSubmission(
            questionId: 'q_eng_place_vocab_a2',
            selectedIndex: 0,
            isCorrect: true,
          ),
          QuestionAnswerSubmission(
            questionId: 'q_eng_place_vocab_b1',
            selectedIndex: 0,
            isCorrect: false,
          ),
        ],
      );
      final meScores = SkillScoringEngine.computePlacementScores(
        'course_eng_01',
        engBank,
        const [
          QuestionAnswerSubmission(
            questionId: 'q_eng_place_vocab_a2',
            selectedIndex: 0,
            isCorrect: false,
          ),
          QuestionAnswerSubmission(
            questionId: 'q_eng_place_vocab_a1',
            selectedIndex: 0,
            isCorrect: true,
          ),
        ],
      );
      expect(
        mhScores['skill_eng_vocab']!.score,
        greaterThan(meScores['skill_eng_vocab']!.score),
      );

      // Duplicate [false, true] deduplicates last-wins -> 100%, with 0 isWeakestFocus flags
      final dupScores = SkillScoringEngine.computePlacementScores(
        'course_eng_01',
        engBank,
        const [
          QuestionAnswerSubmission(
            questionId: 'q_eng_place_vocab_a2',
            selectedIndex: 0,
            isCorrect: false,
          ),
          QuestionAnswerSubmission(
            questionId: 'q_eng_place_vocab_a2',
            selectedIndex: 0,
            isCorrect: true,
          ),
        ],
      );
      expect(dupScores['skill_eng_vocab']!.score, equals(100));
      expect(dupScores['skill_eng_vocab']!.isWeakestFocus, isFalse);

      final courseRepo = InMemoryCourseRepository();
      final learnerRepo = InMemoryLearnerRepository();
      final useCase = SubmitPlacementTestUseCase(courseRepo, learnerRepo);
      final a2AndB1 = engBank
          .where((q) => q.difficulty != QuestionDifficulty.easy)
          .toList();
      final res = await useCase.execute(
        'course_eng_01',
        [
          for (final q in a2AndB1)
            QuestionAnswerSubmission(
              questionId: q.id,
              selectedIndex: q.correctIndex,
              isCorrect: true,
            ),
        ],
      );
      expect(res.overallScore, equals(100));
      expect(res.weakestSkillId, isEmpty);
      expect(
        res.computedScores.values.any((s) => s.isWeakestFocus),
        isFalse,
      );
    });

    test('FIX-P0-02, FIX-P1-09 & FIX-P1-46: calibrates 0% placement + 1 starter <= 25%, caps 1/1 below mastered, and supersedes Day-1 misses on retake', () async {
      SharedPreferences.setMockInitialValues({});
      final courseRepo = InMemoryCourseRepository();
      final learnerRepo = InMemoryLearnerRepository();
      final useCase = SubmitPlacementTestUseCase(courseRepo, learnerRepo);

      final engBank = await courseRepo.getPlacementQuestions('course_eng_01');
      final a1AndA2 = engBank
          .where((q) => q.difficulty != QuestionDifficulty.hard)
          .toList();

      // 1. 0/8 English placement -> isolated from scoresByCourse, saved in placementSkillScoresByCourse
      await useCase.execute(
        'course_eng_01',
        [
          for (final q in a1AndA2)
            QuestionAnswerSubmission(
              questionId: q.id,
              selectedIndex: (q.correctIndex + 1) % q.options.length,
              isCorrect: false,
            ),
        ],
      );
      var profile = await learnerRepo.getProfile();
      expect(profile.scoresByCourse['course_eng_01'], isNull);
      expect(profile.placementScoreByCourse['course_eng_01'], equals(0));
      expect(profile.placementCefrByCourse['course_eng_01'], equals('Pre-A1'));
      expect(
        profile
            .placementSkillScoresByCourse['course_eng_01']?['skill_eng_vocab']
            ?.score,
        equals(0),
      );

      // 2. Answering 1 starter question right after 0% placement stays <= 25% (needsRemediation)
      await learnerRepo.recordAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        selectedIndex: 0,
        selectedAnswer: "I'm Sam",
        isCorrect: true,
      );
      profile = await learnerRepo.getProfile();
      final starterAfterZero =
          profile.scoresByCourse['course_eng_01']?['skill_eng_vocab'];
      expect(starterAfterZero, isNotNull);
      expect(starterAfterZero!.score, lessThanOrEqualTo(25));
      expect(starterAfterZero.masteryLevel, equals(MasteryLevel.needsRemediation));

      // 3. Day-1 0% placement on course_it -> Day-2 100% retake yields 100%
      final itBank = await courseRepo.getPlacementQuestions('course_it');
      final itAsked = [
        ...itBank.where((q) => q.skillId == 'skill_it_python').take(2),
        ...itBank.where((q) => q.skillId == 'skill_it_web').take(2),
      ];
      await useCase.execute(
        'course_it',
        [
          for (final q in itAsked)
            QuestionAnswerSubmission(
              questionId: q.id,
              selectedIndex: (q.correctIndex + 1) % q.options.length,
              isCorrect: false,
            ),
        ],
      );
      expect(
        (await learnerRepo.getProfile())
            .scoresByCourse['course_it']?['skill_it_python']
            ?.score,
        equals(0),
      );

      await useCase.execute(
        'course_it',
        [
          for (final q in itAsked)
            QuestionAnswerSubmission(
              questionId: q.id,
              selectedIndex: q.correctIndex,
              isCorrect: true,
            ),
        ],
      );
      final afterRetake = await learnerRepo.getProfile();
      expect(
        afterRetake.scoresByCourse['course_it']?['skill_it_python']?.score,
        equals(100),
      );
    });

    test('FIX-P1-07: chains all 15 A1 English nodes sequentially and unlocks orthogonal IT/Logic skills at Day 0', () {
      final engA1Nodes = seedRoadmapNodes['course_eng_01']!
          .where((n) => n.cefrLevel == 'A1')
          .toList();
      expect(engA1Nodes.length, equals(15));

      final openAtDay0 = engA1Nodes
          .where((n) => n.prerequisites.isEmpty)
          .map((n) => n.id)
          .toList();
      expect(openAtDay0, equals(['node_eng_a1_m1_greetings']));

      final byId = {for (final n in engA1Nodes) n.id: n};
      final ancestors = <String>{};
      final stack = [...byId['node_eng_a1_exit']!.prerequisites];
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        if (ancestors.add(cur)) {
          stack.addAll(byId[cur]?.prerequisites ?? const []);
        }
      }
      expect(ancestors.length, equals(14));

      final itPath = RouteEngine.adaptRoadmap(
        courseId: 'course_it',
        baseNodes: seedRoadmapNodes['course_it']!,
        skillScores: const {},
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );
      expect(
        itPath.nodes.firstWhere((n) => n.id == 'node_it_web').status,
        equals(NodeStatus.available),
      );

      final logicPath = RouteEngine.adaptRoadmap(
        courseId: 'course_logic',
        baseNodes: seedRoadmapNodes['course_logic']!,
        skillScores: const {},
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );
      expect(
        logicPath.nodes.firstWhere((n) => n.id == 'node_logic_patterns').status,
        equals(NodeStatus.available),
      );
    });

    testWidgets('FIX-P2-09: renders ConfidenceLevel badges on KnowledgeMapScreen and separates assessedCefr from unlockedCefrFloor on PlacementTestScreen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. KnowledgeMapScreen renders ConfidenceLevel badge when skill has attemptCount/confidence
      final kmRepo = InMemoryLearnerRepository();
      await kmRepo.recordAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        selectedIndex: 0,
        selectedAnswer: "I'm Sam",
        isCorrect: true,
      );

      final kmContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(kmRepo),
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(kmContainer.dispose);

      await kmContainer.read(learnerStateNotifierProvider.notifier).loadProfile();
      await kmContainer.read(courseStateNotifierProvider.notifier).init();
      await kmContainer
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');

      final kmRouter = GoRouter(
        initialLocation: '/knowledge-map',
        routes: [
          GoRoute(
            path: '/knowledge-map',
            builder: (_, _) => const KnowledgeMapScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: kmContainer,
          child: MaterialApp.router(
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            routerConfig: kmRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Aniqlik: Dastlabki'), findsOneWidget);
    });

    testWidgets('FIX-P2-09: separates assessedCefr from unlockedCefrFloor on PlacementTestScreen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // PlacementTestScreen renders assessedCefr ('Pre-A1') alongside preserved unlockedCefrFloor ('A2')
      final sessionRepo = _CompletedSessionLearnerRepository(
        PlacementSession(
          id: 'sess_floor_1',
          questionNumber: 8,
          totalQuestions: 8,
          question: null,
          result: CompletedPlacement(
            attemptId: 'att_floor_1',
            weakestSkillId: 'skill_eng_vocab',
            overallScore: 0,
            placementCefr: 'A2',
            assessedCefr: 'Pre-A1',
            unlockedCefrFloor: 'A2',
            completedAt: DateTime.utc(2026, 11, 27),
            review: const [],
          ),
        ),
      );
      final baseProfile = await sessionRepo.getProfile();
      await sessionRepo.updateProfile(
        baseProfile.copyWith(
          selectedCourseId: 'course_eng_01',
          completedLessonIds: const ['lesson_eng_a1_exit_assessment'],
          completedNodeIds: const ['node_eng_a1_exit'],
          placementScoreByCourse: const {'course_eng_01': 0},
          placementCefrByCourse: const {'course_eng_01': 'A2'},
        ),
      );

      final plcContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(sessionRepo),
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(plcContainer.dispose);

      await plcContainer.read(learnerStateNotifierProvider.notifier).loadProfile();
      await plcContainer.read(courseStateNotifierProvider.notifier).init();
      await plcContainer
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');

      final plcRouter = GoRouter(
        initialLocation: '/placement',
        routes: [
          GoRoute(
            path: '/placement',
            builder: (_, _) => const PlacementTestScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: plcContainer,
          child: MaterialApp.router(
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            routerConfig: plcRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diagnostika: Pre-A1'), findsOneWidget);
      expect(
        find.textContaining('Oldingi o‘zlashtirilgan bosqich saqlandi: A2'),
        findsOneWidget,
      );
    });
  });
}
