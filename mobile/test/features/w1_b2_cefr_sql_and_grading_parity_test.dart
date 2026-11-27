import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/personalization/route_engine.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_lesson_answer_use_case.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_reinforcement_use_case.dart';
import 'package:bilimyol_mobile/features/reinforcement/reinforcement_sheet.dart';

class _RecordingServerLearnerRepository extends InMemoryLearnerRepository {
  AnswerAttemptRecord? lastRecorded;
  String? lastSubmittedAnswer;
  int? lastSubmittedIndex;
  final bool serverCorrect;
  final String? serverCorrectOption;
  final String? serverExplanation;

  _RecordingServerLearnerRepository({
    required this.serverCorrect,
    this.serverCorrectOption,
    this.serverExplanation,
  });

  @override
  bool get supportsServerReinforcementPersistence => true;

  @override
  Future<AnswerAttemptRecord> recordAnswerAttemptIdempotent({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
    required bool isCorrect,
    String? idempotencyKey,
  }) async {
    lastSubmittedAnswer = selectedAnswer;
    lastSubmittedIndex = selectedIndex;
    final rec = AnswerAttemptRecord(
      id: 'rec_1',
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      isCorrect: serverCorrect,
      timestamp: 1,
      correctOption: serverCorrectOption,
      explanation: serverExplanation,
      idempotencyKey: idempotencyKey,
    );
    lastRecorded = rec;
    return rec;
  }

  @override
  Future<AnswerAttemptRecord> submitAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
  }) async {
    lastSubmittedAnswer = selectedAnswer;
    lastSubmittedIndex = selectedIndex;
    return AnswerAttemptRecord(
      id: 'sub_1',
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      isCorrect: serverCorrect,
      timestamp: 1,
      correctOption: serverCorrectOption,
      explanation: serverExplanation,
    );
  }
}

void main() {
  group('W1-B2: Mobile CEFR node columns, wire parity, and reinforcement feedback', () {
    test('FIX-P0-01 & FIX-P1-40: SupabaseLessonRepository preserves all 14 CEFR/RU node columns and per-question skillId', () {
      expect(
        SupabaseLessonRepository.roadmapNodesSelectColumns,
        equals('*'),
      );

      final parsedLesson = SupabaseLessonRepository.parseLearnerLesson({
        'id': 'lesson_eng_a1_exit',
        'course_id': 'course_eng_01',
        'skill_id': 'skill_eng_reading',
        'cefr_level': 'A1',
        'title': 'A1 Exit',
        'title_ru': 'Итог A1',
        'summary': 'Summary',
        'estimated_minutes': 15,
        'pedagogy17': {
          'grammarFocus': 'Present Simple',
        },
        'steps': [
          {
            'id': 's1',
            'stepNumber': 1,
            'type': 'interactive_question',
            'title': 'Listening',
            'content': 'Listen',
            'interactiveQuestion': {
              'id': 'q_eng_a1_exit_listen',
              'courseId': 'course_eng_01',
              'skillId': 'skill_eng_listening',
              'questionType': 'multiple_choice',
              'text': 'What time?',
              'options': ['08:30', '20:30'],
              'difficulty': 'easy',
            },
          },
        ],
        'reinforcement_exercise': {
          'id': 'q_reinf',
          'courseId': 'course_eng_01',
          'skillId': 'skill_eng_reading',
          'questionType': 'text_input',
          'text': 'Write',
          'options': <String>[],
          'difficulty': 'easy',
        },
      });

      expect(
        parsedLesson.steps.first.interactiveQuestion?.skillId,
        equals('skill_eng_listening'),
      );
      expect(parsedLesson.pedagogy17, isNotNull);
    });

    test('FIX-P1-40: SubmitLessonAnswerUseCase & SubmitReinforcementUseCase emit canonical JSON wire payloads for sentenceOrder, wordMatch, and selfAssessed', () async {
      final repo = _RecordingServerLearnerRepository(
        serverCorrect: false,
        serverCorrectOption: 'I wake up at seven.',
        serverExplanation: 'Vaqt predlogi at ishlatiladi.',
      );
      final lessonUseCase = SubmitLessonAnswerUseCase(repo);
      final reinfUseCase = SubmitReinforcementUseCase(
        repo,
        InMemoryLessonRepository(),
      );

      // 1. sentenceOrder with multi-word chips -> JSON array
      const orderQ = Question(
        id: 'q_order',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_grammar',
        text: 'Order tokens',
        mode: QuestionMode.sentenceOrder,
        options: [],
        correctIndex: -1,
        orderedTokens: ['at seven.', 'I wake up'],
        difficulty: QuestionDifficulty.easy,
        explanation: '',
      );
      final orderRes = await lessonUseCase.execute(
        question: orderQ,
        lessonId: 'lesson_eng_a1_m2_sentence_builder',
        orderedTokens: const ['I wake up', 'at seven.'],
      );
      expect(repo.lastSubmittedAnswer, equals('["I wake up","at seven."]'));
      expect(orderRes.correctOption, isEmpty);
      expect(orderRes.explanation, equals('Vaqt predlogi at ishlatiladi.'));

      // 1b. MCQ Lesson forwards serverCorrectOption when local correctIndex == -1
      const mcqQ = Question(
        id: 'q_mcq_live',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        text: 'Select morning greeting',
        mode: QuestionMode.multipleChoice,
        options: ['Good night!', 'I wake up at seven.'],
        correctIndex: -1,
        difficulty: QuestionDifficulty.easy,
        explanation: '',
      );
      final mcqRes = await lessonUseCase.execute(
        question: mcqQ,
        lessonId: 'lesson_eng_a1_m1_greetings',
        selectedIndex: 0,
      );
      expect(mcqRes.correctOption, equals('I wake up at seven.'));

      // 2. wordMatch with unsorted map -> key-sorted JSON {"pair_a":"...","pair_b":"..."}
      const matchQ = Question(
        id: 'q_match',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        text: 'Match pairs',
        mode: QuestionMode.wordMatch,
        options: [],
        correctIndex: -1,
        matchPairs: [
          WordMatchPair(id: 'pair_b', left: 'Evening', right: 'Kech'),
          WordMatchPair(id: 'pair_a', left: 'Morning', right: 'Tong'),
        ],
        difficulty: QuestionDifficulty.easy,
        explanation: '',
      );
      await lessonUseCase.execute(
        question: matchQ,
        lessonId: 'lesson_eng_a1_m1_greetings',
        matchedPairs: const {'pair_b': 'Kech', 'pair_a': 'Tong'},
      );
      expect(
        repo.lastSubmittedAnswer,
        equals('{"pair_a":"Tong","pair_b":"Kech"}'),
      );

      // 3. selfAssessed -> JSON {"response":"...","criteria":["crit_1","crit_2"]} with selectedIndex 0
      const selfQ = Question(
        id: 'q_self',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        text: 'Introduce yourself',
        mode: QuestionMode.speakingPrompt,
        evaluationMode: 'self_assessed',
        options: [],
        correctIndex: -1,
        sampleResponse: 'Hello, I am Sardor.',
        difficulty: QuestionDifficulty.easy,
        explanation: '',
      );
      await lessonUseCase.execute(
        question: selfQ,
        lessonId: 'lesson_eng_a1_m1_speaking',
        selectedText: 'Hello, I am Sardor.',
        checkedCriteriaIds: const ['crit_2', 'crit_1'],
      );
      expect(repo.lastSubmittedIndex, equals(0));
      expect(
        repo.lastSubmittedAnswer,
        equals('{"response":"Hello, I am Sardor.","criteria":["crit_1","crit_2"]}'),
      );

      // 4. SubmitReinforcementUseCase forwards correctOption & explanation and uses identical JSON wire format
      final reinfRes = await reinfUseCase.execute(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_grammar',
        reinforcementNodeId: 'reinf_node_eng_a1_m2_sentence_builder',
        reinforcementQuestion: orderQ,
        selectedIndex: 0,
        orderedTokens: const ['at seven.', 'I wake up'],
      );
      expect(repo.lastSubmittedAnswer, equals('["at seven.","I wake up"]'));
      expect(reinfRes.isCorrect, isFalse);
      expect(reinfRes.correctOption, equals('I wake up at seven.'));
      expect(reinfRes.explanation, equals('Vaqt predlogi at ishlatiladi.'));
    });

    testWidgets('FIX-P1-40: ReinforcementSheet renders server correctOption and explanation when live sanitized question has correctIndex == -1', (tester) async {
      const sanitizedMcq = Question(
        id: 'q_sanitized_reinf',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        text: 'Select the formal morning greeting:',
        mode: QuestionMode.multipleChoice,
        options: ['Good night!', 'Good morning!'],
        correctIndex: -1,
        difficulty: QuestionDifficulty.easy,
        explanation: '',
      );

      final dummyRoadmap = LearningPath(
        id: 'roadmap_course_eng_01',
        courseId: 'course_eng_01',
        title: 'Roadmap',
        nodes: const [],
        activeNodeId: '',
        updatedAt: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReinforcementSheet(
              question: sanitizedMcq,
              onSubmit: (_) async => ReinforcementResult(
                isCorrect: false,
                oldScore: 20,
                newScore: 20,
                xpAwarded: 0,
                updatedRoadmap: dummyRoadmap,
                correctOption: 'Good morning!',
                explanation: 'Ertalab rasmiy salomlashishda Good morning ishlatiladi.',
              ),
              onGoToDashboard: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Good night!'));
      await tester.pump();
      await tester.tap(find.text(AppStrings.forCode('uz').checkAnswerBtn));
      await tester.pumpAndSettle();

      expect(find.textContaining('Good morning!'), findsWidgets);
      expect(
        find.text('Ertalab rasmiy salomlashishda Good morning ishlatiladi.'),
        findsOneWidget,
      );

      // Verify InMemoryLearnerRepository returns wrongFeedback (NOT praise explanation) and null correctOption on wrong text_input
      final demoRepo = InMemoryLearnerRepository();
      final wrongStarter = await demoRepo.submitAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        selectedIndex: 0,
        selectedAnswer: 'Goodbye',
      );
      expect(wrongStarter.isCorrect, isFalse);
      expect(wrongStarter.correctOption, isNull);
      expect(wrongStarter.explanation, isNot(startsWith('Ajoyib!')));
      expect(wrongStarter.explanation, contains("I'm"));
    });

    test('FIX-P1-40: RouteEngine clears NodeStatus.reinforcement once reinf_<node_id> is completed even when score < 50', () {
      const baseNodes = <LearningPathNode>[
        LearningPathNode(
          id: 'node_eng_a1_m1_greetings',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          title: 'Greetings',
          description: 'Desc',
          prerequisites: [],
          requiredScore: 70,
          status: NodeStatus.available,
          isReinforcement: false,
          targetLessonId: 'lesson_eng_a1_m1_greetings',
          estimatedMinutes: 10,
          order: 1,
        ),
      ];

      final cleared = RouteEngine.adaptRoadmap(
        courseId: 'course_eng_01',
        baseNodes: baseNodes,
        skillScores: {
          'skill_eng_vocab': const SkillScore(
            skillId: 'skill_eng_vocab',
            courseId: 'course_eng_01',
            score: 22,
            lastUpdated: 1,
            masteryLevel: MasteryLevel.needsRemediation,
          ),
        },
        completedNodeIds: const [],
        completedReinforcementIds: const ['reinf_node_eng_a1_m1_greetings'],
      );

      final parent = cleared.nodes.firstWhere(
        (n) => n.id == 'node_eng_a1_m1_greetings',
      );
      expect(parent.status, equals(NodeStatus.available));
      expect(
        cleared.nodes.any((n) => n.id == 'reinf_node_eng_a1_m1_greetings'),
        isFalse,
      );
    });
  });
}
