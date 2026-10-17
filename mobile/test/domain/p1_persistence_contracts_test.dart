import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_placement_test_use_case.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_reinforcement_use_case.dart';

class _ServerRepository extends InMemoryLearnerRepository {
  @override
  bool get supportsServerPlacementPersistence => true;
  @override
  bool get supportsServerReinforcementPersistence => true;
  @override
  bool get supportsNodeCompletion => false;

  int scoreWrites = 0;
  int profileWrites = 0;
  int auditWrites = 0;
  int evaluations = 0;
  int placementSaves = 0;
  PlacementAttemptData? savedPlacement;
  ReinforcementCompletionResult? completion = const ReinforcementCompletionResult(
    oldScore: 75, newScore: 97, xpAwarded: 30, alreadyProcessed: false,
  );

  @override
  Future<AnswerAttemptRecord> submitAnswerAttempt({
    required String courseId, required String skillId, required String lessonId,
    required String questionId, required int selectedIndex, required String selectedAnswer,
  }) async => AnswerAttemptRecord(
    id: 'verified', courseId: courseId, skillId: skillId, lessonId: lessonId,
    questionId: questionId, selectedIndex: selectedIndex, selectedAnswer: selectedAnswer,
    isCorrect: true, timestamp: 0,
  );

  @override
  Future<ReinforcementCompletionResult?> markReinforcementCompleted({
    required String reinforcementId, required String courseId, required String skillId,
    required String questionId, required int beforeScore, required int afterScore,
    required int xpAwarded,
  }) async => completion;

  @override
  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores) async {
    scoreWrites++;
    await super.saveSkillScores(courseId, scores);
  }

  @override
  Future<LearnerProfile> updateProfile(LearnerProfile updated) async {
    profileWrites++;
    return super.updateProfile(updated);
  }

  @override
  Future<AnswerAttemptRecord> recordAnswerAttempt({
    required String courseId, required String skillId, required String lessonId,
    required String questionId, required int selectedIndex, required String selectedAnswer,
    required bool isCorrect,
  }) async {
    auditWrites++;
    return super.recordAnswerAttempt(courseId: courseId, skillId: skillId,
      lessonId: lessonId, questionId: questionId, selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer, isCorrect: isCorrect);
  }

  @override
  Future<PlacementAnswerEvaluation> evaluatePlacementAnswer({
    required String courseId, required String questionId, required int selectedIndex,
  }) async {
    evaluations++;
    return const PlacementAnswerEvaluation(isCorrect: false);
  }

  @override
  Future<String> savePlacementAttempt(PlacementAttemptData data) async {
    placementSaves++;
    savedPlacement = data;
    await super.saveSkillScores(data.courseId, {
      'skill_math_algebra': SkillScore(skillId: 'skill_math_algebra', courseId: data.courseId,
        score: 73, lastUpdated: 0, masteryLevel: MasteryLevel.proficient),
    });
    return 'persisted-placement';
  }
}

void main() {
  late bool previousRemote;
  setUp(() {
    previousRemote = SupabaseConfig.hasRemoteConfiguration;
    SupabaseConfig.hasRemoteConfiguration = false;
  });
  tearDown(() => SupabaseConfig.hasRemoteConfiguration = previousRemote);

  final lesson = seedLessons['lesson_math_functions_01']!;
  Future<ReinforcementResult> reinforce(_ServerRepository repository) =>
    SubmitReinforcementUseCase(repository, InMemoryLessonRepository()).execute(
      courseId: lesson.courseId, skillId: lesson.skillId,
      reinforcementNodeId: 'reinf_node_math_func', reinforcementQuestion: lesson.reinforcementExercise,
      selectedIndex: 0,
    );

  test('online reinforcement uses persisted scores and skips secondary writes', () async {
    final repository = _ServerRepository();
    final result = await reinforce(repository);
    expect(result.oldScore, 75);
    expect(result.newScore, 97);
    expect(result.xpAwarded, 30);
    expect(repository.scoreWrites, 0);
    expect(repository.profileWrites, 0);
    expect((await repository.getProfile()).completedNodeIds, isEmpty);
  });

  test('reinforcement retry reports zero additional XP', () async {
    final repository = _ServerRepository()..completion = const ReinforcementCompletionResult(
      oldScore: 75, newScore: 97, xpAwarded: 30, alreadyProcessed: true,
    );
    expect((await reinforce(repository)).xpAwarded, 0);
  });

  test('missing server completion result cannot become local success', () async {
    final repository = _ServerRepository()..completion = null;
    await expectLater(reinforce(repository), throwsStateError);
    expect(repository.scoreWrites, 0);
  });

  test('online placement stores one verified payload and reads back server score', () async {
    final repository = _ServerRepository();
    final courses = InMemoryCourseRepository();
    final question = (await courses.getPlacementQuestions('course_math_01')).first;
    final result = await SubmitPlacementTestUseCase(courses, repository).execute('course_math_01', [
      QuestionAnswerSubmission(questionId: question.id, selectedIndex: 0, isCorrect: true),
    ]);
    expect(result.assessmentId, 'persisted-placement');
    expect(result.computedScores['skill_math_algebra']?.score, 73);
    expect(repository.savedPlacement?.submissions.single.isCorrect, isFalse);
    expect(repository.placementSaves, 1);
    expect(repository.auditWrites, 0);
    expect(repository.scoreWrites, 0);
    expect((await repository.getProfile()).xp, 0);
  });

  test('invalid placement input is rejected before evaluation or writes', () async {
    final repository = _ServerRepository();
    final courses = InMemoryCourseRepository();
    final question = (await courses.getPlacementQuestions('course_math_01')).first;
    final submission = QuestionAnswerSubmission(questionId: question.id, selectedIndex: 0, isCorrect: true);
    final usecase = SubmitPlacementTestUseCase(courses, repository);
    for (final invalid in <List<QuestionAnswerSubmission>>[
      [], [submission, submission],
      [submission, const QuestionAnswerSubmission(questionId: 'unknown', selectedIndex: 0, isCorrect: true)],
      [QuestionAnswerSubmission(questionId: question.id, selectedIndex: -1, isCorrect: true)],
    ]) {
      await expectLater(usecase.execute('course_math_01', invalid), throwsArgumentError);
    }
    expect(repository.evaluations, 0);
    expect(repository.placementSaves, 0);
    expect(repository.auditWrites, 0);
  });

  test('Supabase repository capabilities reflect intentional demo versus configured mode', () {
    final repository = SupabaseLearnerRepository();
    expect(repository.supportsServerPlacementPersistence, isFalse);
    expect(repository.supportsServerReinforcementPersistence, isFalse);
    expect(repository.supportsNodeCompletion, isTrue);
    SupabaseConfig.hasRemoteConfiguration = true;
    expect(repository.supportsServerPlacementPersistence, isTrue);
    expect(repository.supportsServerReinforcementPersistence, isTrue);
    expect(repository.supportsNodeCompletion, isFalse);
  });

  test('configured but unavailable content never falls back to seed questions', () async {
    SupabaseConfig.hasRemoteConfiguration = true;
    await expectLater(SupabaseCourseRepository().getPlacementQuestions('course_math_01'), throwsStateError);
    await expectLater(SupabaseLessonRepository().getLessonById(lesson.id), throwsStateError);
  });

  Map<String, dynamic> generatedRow() => {
    'id': 'server-lesson', 'course_id': 'course_math_01', 'skill_id': 'skill_math_functions', 'title': 'Lesson',
    'steps': [{'id': 'check', 'type': 'interactive_question', 'title': 'Check'}],
    'questions': [{'id': 'server-question', 'text': 'Q?', 'options': ['a', 'b'], 'correct_index': 1}],
  };

  test('generated lesson view restores an interactive question with server identity and no key', () {
    final parsed = SupabaseLessonRepository.parseLearnerLesson(generatedRow());
    final question = parsed.steps.single.interactiveQuestion!;
    expect(question.id, 'server-question');
    expect(question.skillId, 'skill_math_functions');
    expect(question.correctIndex, -1);
    expect(parsed.reinforcementExercise.id, question.id);
  });

  test('missing lesson assessment is rejected instead of inventing a synthetic question', () {
    final row = generatedRow()..['questions'] = [];
    expect(() => SupabaseLessonRepository.parseLearnerLesson(row), throwsFormatException);
  });
}
