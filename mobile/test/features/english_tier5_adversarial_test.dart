import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/widgets/app_button.dart';
import 'package:bilimyol_mobile/data/datasources/courses_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/placement_questions_data.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/placement_session.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/personalization/learning_start.dart';
import 'package:bilimyol_mobile/domain/personalization/route_engine.dart';
import 'package:bilimyol_mobile/domain/personalization/skill_scoring_engine.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_lesson_answer_use_case.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/placement/placement_test_screen.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

class _OnlineRetakePlacementRepository extends InMemoryLearnerRepository {
  final PlacementSession session;

  _OnlineRetakePlacementRepository(this.session);

  @override
  bool get supportsPlacementSessions => true;

  @override
  Future<PlacementSession> advancePlacement(
    String courseId, {
    String? sessionId,
    String? questionId,
    int? selectedIndex,
    bool restart = false,
  }) async {
    return session;
  }
}

class _TwoQuestionCourseRepository extends InMemoryCourseRepository {
  @override
  Future<List<Question>> getPlacementQuestions(String courseId) async {
    return const [
      Question(
        id: 'q_fast_1',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        cefrLevel: 'A1',
        isPlacement: true,
        text: 'Fast Q1',
        options: ['Alpha', 'Beta', 'Gamma'],
        correctIndex: 0,
        difficulty: QuestionDifficulty.easy,
        explanation: 'Alpha is right.',
      ),
      Question(
        id: 'q_fast_2',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_grammar',
        cefrLevel: 'A2',
        isPlacement: true,
        text: 'Fast Q2',
        options: ['One', 'Two', 'Three'],
        correctIndex: 1,
        difficulty: QuestionDifficulty.medium,
        explanation: 'Two is right.',
      ),
    ];
  }
}

class _FastPlacementLearnerRepository extends InMemoryLearnerRepository {
  @override
  Future<PlacementAnswerEvaluation> evaluatePlacementAnswer({
    required String courseId,
    required String questionId,
    required int selectedIndex,
  }) async {
    return PlacementAnswerEvaluation(
      isCorrect: (questionId == 'q_fast_1' && selectedIndex == 0) ||
          (questionId == 'q_fast_2' && selectedIndex == 1),
    );
  }
}

class _CountingLearnerRepository extends InMemoryLearnerRepository {
  int recordAttemptCalls = 0;

  @override
  Future<AnswerAttemptRecord> recordAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
    required bool isCorrect,
  }) {
    recordAttemptCalls++;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tier 5 Adversarial Hardening Tests', () {
    test(
      'F1: pendingFoundationLesson returns null for placed A1/A2/B1 and returns starter for Pre-A1/unplaced',
      () {
        final engCourse = seedCourses.firstWhere(
          (c) => c.id == 'course_eng_01',
        );
        const baseProfile = LearnerProfile(
          id: 'u1',
          name: 'Aziz',
          selectedCourseId: 'course_eng_01',
          goal: OnboardingGoal.mastery,
          dailyMinutes: 15,
          initialLevel: InitialLevel.beginner,
          courseLevels: {'course_eng_01': InitialLevel.beginner},
          xp: 0,
          streakDays: 1,
          lastActiveDate: '2026-11-20',
          scoresByCourse: {},
          completedLessonIds: [],
          completedNodeIds: [],
          completedReinforcementIds: [],
          createdAt: 1,
        );

        expect(
          pendingFoundationLesson(engCourse, baseProfile),
          equals('lesson_eng_starter'),
        );
        expect(
          pendingFoundationLesson(
            engCourse,
            baseProfile.copyWith(
              placementCefrByCourse: {'course_eng_01': 'Pre-A1'},
            ),
          ),
          equals('lesson_eng_starter'),
        );
        for (final placedTier in const ['A1', 'A2', 'B1']) {
          expect(
            pendingFoundationLesson(
              engCourse,
              baseProfile.copyWith(
                placementCefrByCourse: {'course_eng_01': placedTier},
              ),
            ),
            isNull,
            reason:
                'Placed $placedTier learner must skip starter foundation lesson.',
          );
        }
      },
    );

    test(
      'F2: PlacementState.copyWith clears currentQuestion, online retake ignores stale cached CEFR, and RouteEngine caps B2-C2 -> B1',
      () async {
        const q = Question(
          id: 'q1',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          text: 'Test?',
          options: ['A', 'B'],
          correctIndex: 0,
          difficulty: QuestionDifficulty.easy,
          explanation: 'E',
        );
        const withQ = PlacementState(
          courseId: 'course_eng_01',
          allQuestions: [q],
          currentQuestion: q,
          history: [],
          submissions: [],
        );
        expect(withQ.copyWith(isSubmitting: true).currentQuestion, equals(q));
        expect(withQ.copyWith(clearCurrentQuestion: true).currentQuestion, isNull);

        // Online retake: stale profile had B1, new reviewSubmissions score A1 (3/8).
        final a1Qs = englishPlacementQuestionsRaw
            .where((x) => x.cefrLevel == 'A1')
            .toList();
        final a2Qs = englishPlacementQuestionsRaw
            .where((x) => x.cefrLevel == 'A2')
            .toList();
        final retakeReviews = <PlacementReview>[
          for (var i = 0; i < a1Qs.length; i++)
            PlacementReview(
              submission: QuestionAnswerSubmission(
                questionId: a1Qs[i].id,
                selectedIndex: i < 3 ? a1Qs[i].correctIndex : 0,
                isCorrect: i < 3,
              ),
              question: a1Qs[i].text,
              selected: a1Qs[i].options[0],
              correct: a1Qs[i].options[a1Qs[i].correctIndex],
              explanation: a1Qs[i].explanation,
            ),
          for (final item in a2Qs)
            PlacementReview(
              submission: QuestionAnswerSubmission(
                questionId: item.id,
                selectedIndex: (item.correctIndex + 1) % item.options.length,
                isCorrect: false,
              ),
              question: item.text,
              selected: item.options[0],
              correct: item.options[item.correctIndex],
              explanation: item.explanation,
            ),
        ];

        final onlineRepo = _OnlineRetakePlacementRepository(
          PlacementSession(
            id: 'sess_retake',
            questionNumber: 8,
            totalQuestions: 8,
            canRetake: true,
            result: CompletedPlacement(
              attemptId: 'att_retake',
              weakestSkillId: 'skill_eng_grammar',
              completedAt: DateTime(2026, 11, 20),
              review: retakeReviews,
            ),
          ),
        );
        await onlineRepo.savePlacementSummary(
          courseId: 'course_eng_01',
          score: 100,
          cefrTier: 'B1',
        );

        final container = ProviderContainer(
          overrides: [learnerRepositoryProvider.overrideWithValue(onlineRepo)],
        );
        addTearDown(container.dispose);

        await container
            .read(placementStateNotifierProvider.notifier)
            .loadQuestions('course_eng_01', restart: true);
        final placementState = container.read(placementStateNotifierProvider);
        expect(placementState.result, isNotNull);
        expect(placementState.result!.cefrLevel, equals('A1'));
        expect(placementState.result!.overallScore, lessThan(50));

        // Web EnglishCefrPlacement parity checks (thresholds + exit node floor)
        expect(
          SkillScoringEngine.computeEnglishPlacementCefr(
            englishPlacementQuestionsRaw,
            retakeReviews.map((r) => r.submission).toList(),
            completedNodeIds: const ['node_eng_a1_exit'],
          ),
          equals('A2'),
        );
        expect(
          SkillScoringEngine.computeEnglishPlacementCefr(
            englishPlacementQuestionsRaw,
            retakeReviews.map((r) => r.submission).toList(),
            completedNodeIds: const ['node_eng_a2_exit'],
          ),
          equals('B1'),
        );

        // RouteEngine normalizes B2/C1/C2 -> B1 (node_eng_b1_m1_travel)
        final engNodes = seedRoadmapNodes['course_eng_01']!;
        for (final legacyTier in const ['B2', 'C1', 'C2', 'b2', 'c1', 'c2']) {
          final roadmap = RouteEngine.adaptRoadmap(
            courseId: 'course_eng_01',
            baseNodes: engNodes,
            skillScores: const {},
            completedNodeIds: const [],
            completedReinforcementIds: const [],
            placementCefrTier: legacyTier,
          );
          expect(roadmap.activeNodeId, equals('node_eng_b1_m1_travel'));
          final b1Entry = roadmap.nodes.firstWhere(
            (n) => n.id == 'node_eng_b1_m1_travel',
          );
          expect(b1Entry.status, equals(NodeStatus.available));
          expect(
            RouteEngine.canStartNode(
              b1Entry,
              const [],
              placementCefrTier: legacyTier,
            ),
            isTrue,
          );
        }
      },
    );

    testWidgets(
      'F3: rapid double-tap prevents duplicate final AlertDialog and final confirmation within 800ms succeeds without getting stuck',
      (tester) async {
        final learnerRepo = _FastPlacementLearnerRepository();
        final courseRepo = _TwoQuestionCourseRepository();
        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(learnerRepo),
            courseRepositoryProvider.overrideWithValue(courseRepo),
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(learnerStateNotifierProvider.notifier)
            .loadProfile();
        await container.read(courseStateNotifierProvider.notifier).init();
        await container
            .read(courseStateNotifierProvider.notifier)
            .selectCourse('course_eng_01');

        final router = GoRouter(
          initialLocation: '/placement',
          routes: [
            GoRoute(
              path: '/placement',
              builder: (_, _) => const PlacementTestScreen(),
            ),
            GoRoute(
              path: '/roadmap',
              builder: (_, _) => const RoadmapScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 -> immediate submit
        await tester.tap(find.text('Alpha'));
        await tester.pump();
        await tester.tap(find.text('Keyingi Savol'));
        await tester.pumpAndSettle();
        expect(find.text('Fast Q2'), findsOneWidget);

        // Step 2 (< 800ms after Step 1!) -> tap Natijalarni Köriş and verify button disables immediately so duplicate AlertDialogs cannot stack
        await tester.ensureVisible(find.text('Two'));
        await tester.tap(find.text('Two'));
        await tester.pump();
        final finishBtn = find.text('Natijalarni Köriş');
        await tester.ensureVisible(finishBtn);
        await tester.tap(finishBtn);
        await tester.pumpAndSettle();

        // Must have exactly ONE AlertDialog and disabled AppButton underneath
        expect(find.byType(AlertDialog), findsOneWidget);
        final finishAppButton = tester.widget<AppButton>(
          find.ancestor(of: finishBtn, matching: find.byType(AppButton)),
        );
        expect(finishAppButton.onPressed, isNull);

        // Confirm within 800ms of step 1 -> must complete cleanly without silent drop
        await tester.tap(find.text('Topşiriş'));
        await tester.pumpAndSettle();

        expect(find.text('Diagnostika yakunlandi'), findsOneWidget);
        expect(find.text('2 / 2 javob töğri.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'F4: InteractiveLessonScreen handles empty steps and out-of-bounds currentStepIndex without RangeError; empty wordMatch/sentenceOrder blocked while partial >=1 grades',
      (tester) async {
        // 1) Empty steps lesson renders FriendlyErrorState safely
        final emptyContainer = ProviderContainer(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
        );
        addTearDown(emptyContainer.dispose);
        await emptyContainer
            .read(learnerStateNotifierProvider.notifier)
            .loadProfile();
        await emptyContainer.read(courseStateNotifierProvider.notifier).init();
        await emptyContainer
            .read(courseStateNotifierProvider.notifier)
            .selectCourse('course_eng_01');
        // Force empty-step lesson directly into state
        emptyContainer
            .read(lessonSessionNotifierProvider.notifier)
            .state = LessonSessionState(
          lesson: Lesson(
            id: 'lesson_empty_steps',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            title: 'Empty Lesson',
            estimatedMinutes: 1,
            summary: 'Empty',
            steps: const [],
            reinforcementExercise: seedLessons['lesson_eng_starter']!
                .reinforcementExercise,
          ),
          currentStepIndex: 5,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: emptyContainer,
            child: const MaterialApp(home: InteractiveLessonScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Dars bosqiçlari topilmadi.'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2) SubmitLessonAnswerUseCase rejects empty wordMatch/sentenceOrder/textInput
        final countingRepo = _CountingLearnerRepository();
        final useCase = SubmitLessonAnswerUseCase(countingRepo);
        final matchQ = seedLessons['lesson_eng_a1_m1_greetings']!
            .steps
            .firstWhere((s) => s.interactiveQuestion?.mode == QuestionMode.wordMatch)
            .interactiveQuestion!;
        final orderQ = seedLessons['lesson_eng_a1_m2_sentence_builder']!
            .steps
            .firstWhere(
              (s) => s.interactiveQuestion?.mode == QuestionMode.sentenceOrder,
            )
            .interactiveQuestion!;

        await expectLater(
          () => useCase.execute(
            question: matchQ,
            lessonId: 'lesson_eng_a1_m1_greetings',
            matchedPairs: const {},
          ),
          throwsArgumentError,
        );
        await expectLater(
          () => useCase.execute(
            question: orderQ,
            lessonId: 'lesson_eng_a1_m2_sentence_builder',
            orderedTokens: const [],
          ),
          throwsArgumentError,
        );
        expect(countingRepo.recordAttemptCalls, equals(0));

        // Partial >= 1 still grades and returns targeted hint
        final partialOrder = await useCase.execute(
          question: orderQ,
          lessonId: 'lesson_eng_a1_m2_sentence_builder',
          orderedTokens: const ['They'],
          uiLocale: 'uz',
        );
        expect(partialOrder.isCorrect, isFalse);
        expect(partialOrder.correctOption, isEmpty);
        expect(
          partialOrder.optionFeedback,
          contains('Gapdagi barça sözlarni tartiblang (1/6)'),
        );
      },
    );

    testWidgets(
      'F5: Non-MCQ wrong answers hide Töğri javob & answer key in UI and DemoAITutorService blocks all UZ/RU/EN paraphrases without word-fragment [...] leaks',
      (tester) async {
        // 1) UI check on InteractiveLessonScreen for starter free-text
        final container = ProviderContainer(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(learnerStateNotifierProvider.notifier)
            .loadProfile();
        await container.read(courseStateNotifierProvider.notifier).init();
        await container
            .read(courseStateNotifierProvider.notifier)
            .selectCourse('course_eng_01');
        await container
            .read(lessonSessionNotifierProvider.notifier)
            .startLesson('lesson_eng_starter');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: InteractiveLessonScreen()),
          ),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Keyingi qadam'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.byKey(const Key('free_text_answer_input')),
          '123',
        );
        await tester.pump();
        await tester.tap(find.text('TEKŞIRIŞ'));
        await tester.pumpAndSettle();

        expect(find.text('Sizning javobingiz: 123'), findsOneWidget);
        expect(find.textContaining('töliq gap yozing'), findsOneWidget);
        expect(find.textContaining('Töğri javob:'), findsNothing);
        expect(find.textContaining("I'm Sam"), findsNothing);
        expect(find.textContaining('My name is Sam'), findsNothing);

        // 2) Anti-spoiler paraphrase attack sweep (UZ/RU/EN)
        final tutor = DemoAITutorService();
        final starterQ = seedLessons['lesson_eng_starter']!
            .steps[3]
            .interactiveQuestion!;
        final paraphrases = <({String msg, String lang})>[
          (msg: "qaysi biri töğri", lang: 'uz'),
          (msg: "töğrisi nima", lang: 'uz'),
          (msg: 'qaysi variantni tanlay', lang: 'uz'),
          (msg: 'qaysi javobni bosay', lang: 'uz'),
          (msg: 'какой вариант верный', lang: 'ru'),
          (msg: 'что мне выбрать', lang: 'ru'),
          (msg: 'подскажи правильный вариант пожалуйста', lang: 'ru'),
          (msg: 'which one should I pick', lang: 'uz'),
          (msg: 'which one should i choose', lang: 'uz'),
          (msg: 'just give me the solution', lang: 'uz'),
        ];

        for (final attack in paraphrases) {
          final res = await tutor.askTutor(
            AskTutorRequest(
              message: attack.msg,
              courseId: 'course_eng_01',
              skillId: starterQ.skillId,
              lessonId: 'lesson_eng_starter',
              questionId: starterQ.id,
              questionSkillId: starterQ.skillId,
              language: attack.lang,
            ),
          );
          expect(
            res.answer,
            isNot(contains("I'm Sam")),
            reason: 'Paraphrase "${attack.msg}" leaked answer key.',
          );
          expect(res.answer, isNot(contains('My name is Sam')));
          expect(
            res.answer.toLowerCase(),
            anyOf(
              contains('qadam-baqadam'),
              contains('шаг за шагом'),
            ),
            reason: 'Paraphrase "${attack.msg}" did not trigger spoiler guard.',
          );
        }

        // 3) Exhaustive non-MCQ secret & word-fragment [...] leak audit across all English lessons
        final wordFragmentMask = RegExp(
          r'[\p{L}\p{N}_]\[\.\.\.\]|\[...\][\p{L}\p{N}_]',
          unicode: true,
        );
        for (final lesson in seedLessons.values) {
          if (lesson.courseId != 'course_eng_01') continue;
          final questions = <Question>[
            for (final step in lesson.steps)
              if (step.interactiveQuestion != null) step.interactiveQuestion!,
            lesson.reinforcementExercise,
            if (lesson.alternateExercise != null) lesson.alternateExercise!,
          ];
          for (final q in questions) {
            if (q.usesOptionSelection) continue;
            final secrets = <String>[
              for (final a in q.acceptedAnswers)
                if (a.trim().length >= 3)
                  a.trim().replaceAll(RegExp(r'[.!?]+$'), ''),
              if (q.mode == QuestionMode.sentenceOrder &&
                  q.orderedTokens.isNotEmpty)
                q.orderedTokens.join(' ').replaceAll(RegExp(r'[.!?]+$'), ''),
              for (final pair in q.matchPairs) ...[
                if (pair.right.trim().length >= 3) pair.right.trim(),
              ],
            ];
            for (final lang in const ['uz', 'ru']) {
              final exp = await tutor.explainMistake(
                AIExplanationRequest(
                  courseId: 'course_eng_01',
                  skillId: q.skillId,
                  lessonId: lesson.id,
                  questionId: q.id,
                  questionText: q.localizedText(lang),
                  selectedOption: 'wrong_test_input',
                  correctOption: '',
                  language: lang,
                ),
              );
              final ask = await tutor.askTutor(
                AskTutorRequest(
                  message: lang == 'ru'
                      ? 'Какой правильный ответ?'
                      : 'Töğri javobni ayt',
                  courseId: 'course_eng_01',
                  skillId: q.skillId,
                  lessonId: lesson.id,
                  questionId: q.id,
                  questionSkillId: q.skillId,
                  language: lang,
                ),
              );
              final combined =
                  '${exp.explanation} ${exp.remediationStep} ${ask.answer}';
              expect(
                wordFragmentMask.hasMatch(combined),
                isFalse,
                reason:
                    'Word-fragment [...] leak for ${q.id} ($lang): $combined',
              );
              for (final secret in secrets) {
                final boundary = RegExp(
                  "(?<![\\p{L}\\p{N}_'’‘`´\\u02BB\\u02BC])${RegExp.escape(secret)}(?![\\p{L}\\p{N}_'’‘`´\\u02BB\\u02BC])",
                  unicode: true,
                  caseSensitive: false,
                );
                expect(
                  boundary.hasMatch(exp.explanation),
                  isFalse,
                  reason:
                      'explainMistake leaked secret "$secret" for ${q.id} ($lang): ${exp.explanation}',
                );
                expect(
                  boundary.hasMatch(ask.answer),
                  isFalse,
                  reason:
                      'askTutor leaked secret "$secret" for ${q.id} ($lang): ${ask.answer}',
                );
              }
            }
          }
        }
      },
    );
  });
}
