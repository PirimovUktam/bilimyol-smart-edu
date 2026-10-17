import '../repositories/i_course_repository.dart';
import '../repositories/i_learner_repository.dart';
import '../entities/question.dart';
import '../entities/skill_score.dart';
import '../personalization/skill_scoring_engine.dart';

class AssessmentResult {
  final String assessmentId;
  final String courseId;
  final List<QuestionAnswerSubmission> submissions;
  final Map<String, SkillScore> computedScores;
  final String weakestSkillId;
  final int timestamp;

  const AssessmentResult({
    required this.assessmentId,
    required this.courseId,
    required this.submissions,
    required this.computedScores,
    required this.weakestSkillId,
    required this.timestamp,
  });
}

class SubmitPlacementTestUseCase {
  final ICourseRepository courseRepository;
  final ILearnerRepository learnerRepository;

  const SubmitPlacementTestUseCase(this.courseRepository, this.learnerRepository);

  Future<AssessmentResult> execute(
    String courseId,
    List<QuestionAnswerSubmission> submissions,
  ) async {
    final questions = await courseRepository.getPlacementQuestions(courseId);

    if (submissions.isEmpty) {
      throw ArgumentError('Placement javoblari bo‘sh bo‘lishi mumkin emas.');
    }
    final questionsById = {
      for (final question in questions) question.id: question,
    };
    final seenQuestionIds = <String>{};
    // Validate the entire adaptive submission before recording any answers.
    for (final submission in submissions) {
      final question = questionsById[submission.questionId];
      if (question == null || question.courseId != courseId) {
        throw ArgumentError.value(submission.questionId, 'questionId');
      }
      if (!seenQuestionIds.add(submission.questionId)) {
        throw ArgumentError(
          'Duplicate placement question: ${submission.questionId}',
        );
      }
      if (submission.selectedIndex < 0 ||
          submission.selectedIndex >= question.options.length) {
        throw ArgumentError.value(submission.selectedIndex, 'selectedIndex');
      }
    }

    // The repository returns the server-authoritative result in online mode;
    // online placement never trusts the UI-provided isCorrect value for scoring.
    // It uses read-only evaluation plus one atomic save RPC.
    final verifiedSubmissions = <QuestionAnswerSubmission>[];
    for (final sub in submissions) {
      final q = questionsById[sub.questionId]!;
      final optionText = q.options[sub.selectedIndex];
      final bool verifiedIsCorrect;
      if (learnerRepository.supportsServerPlacementPersistence) {
        final evaluation = await learnerRepository.evaluatePlacementAnswer(
          courseId: courseId,
          questionId: q.id,
          selectedIndex: sub.selectedIndex,
        );
        verifiedIsCorrect = evaluation.isCorrect;
      } else {
        final attempt = await learnerRepository.recordAnswerAttempt(
          courseId: courseId,
          skillId: q.skillId,
          lessonId: 'placement_test',
          questionId: q.id,
          selectedIndex: sub.selectedIndex,
          selectedAnswer: optionText,
          isCorrect: sub.isCorrect,
        );
        verifiedIsCorrect = attempt.isCorrect;
      }
      verifiedSubmissions.add(
        QuestionAnswerSubmission(
          questionId: sub.questionId,
          selectedIndex: sub.selectedIndex,
          isCorrect: verifiedIsCorrect,
          timeSpentSeconds: sub.timeSpentSeconds,
        ),
      );
    }

    // Real statistical placement scoring
    var computedScores = SkillScoringEngine.computePlacementScores(
      courseId,
      questions,
      verifiedSubmissions,
    );

    // Save to learner profile
    // Identify weakest skill dynamically
    String weakestSkillId = '';
    int minScore = 101;
    for (final s in computedScores.values) {
      if (s.score < minScore) {
        minScore = s.score;
        weakestSkillId = s.skillId;
      }
    }

    final overallScore = SkillScoringEngine.computeOverallScore(computedScores);

    // Save placement attempt record to Supabase
    final attemptId = await learnerRepository.savePlacementAttempt(
      PlacementAttemptData(
        courseId: courseId,
        score: overallScore,
        weakestSkillId: weakestSkillId,
        submissions: verifiedSubmissions
            .map((s) => PlacementAttemptSubmission(
                  questionId: s.questionId,
                  selectedIndex: s.selectedIndex,
                  isCorrect: s.isCorrect,
                ))
            .toList(),
      ),
    );

    // The production placement RPC already awards XP and activity atomically.
    if (learnerRepository.supportsServerPlacementPersistence) {
      final persistedProfile = await learnerRepository.getProfile();
      computedScores = persistedProfile.scoresByCourse[courseId] ?? {};
      weakestSkillId = '';
      minScore = 101;
      for (final score in computedScores.values) {
        if (score.isWeakestFocus) {
          weakestSkillId = score.skillId;
          break;
        }
        if (score.score < minScore) {
          minScore = score.score;
          weakestSkillId = score.skillId;
        }
      }
    } else {
      await learnerRepository.saveSkillScores(courseId, computedScores);
      await learnerRepository.addXp(20, 'placement_completed_$courseId');
      await learnerRepository.recordDailyActivity();
    }

    return AssessmentResult(
      assessmentId: attemptId.isNotEmpty ? attemptId : 'placement_$courseId',
      courseId: courseId,
      submissions: verifiedSubmissions,
      computedScores: computedScores,
      weakestSkillId: weakestSkillId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
