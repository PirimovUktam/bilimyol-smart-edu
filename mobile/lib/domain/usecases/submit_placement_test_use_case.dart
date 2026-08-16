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

  Future<AssessmentResult> execute(String courseId, List<QuestionAnswerSubmission> submissions) async {
    final questions = await courseRepository.getPlacementQuestions(courseId);

    // Deterministic placement scoring
    final computedScores = SkillScoringEngine.computePlacementScores(courseId, questions, submissions);

    // Save to learner profile
    await learnerRepository.saveSkillScores(courseId, computedScores);

    // Identify weakest skill
    String weakestSkillId = '';
    int minScore = 101;
    for (final s in computedScores.values) {
      if (s.score < minScore) {
        minScore = s.score;
        weakestSkillId = s.skillId;
      }
    }

    return AssessmentResult(
      assessmentId: 'placement_$courseId',
      courseId: courseId,
      submissions: submissions,
      computedScores: computedScores,
      weakestSkillId: weakestSkillId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
