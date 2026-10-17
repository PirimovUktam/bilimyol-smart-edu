import '../entities/learner_profile.dart';
import '../entities/skill_score.dart';

class AnswerAttemptRecord {
  final String id;
  final String courseId;
  final String skillId;
  final String lessonId;
  final String questionId;
  final int selectedIndex;
  final String selectedAnswer;
  final bool isCorrect;
  final int timestamp;
  final String? correctOption;
  final String? explanation;
  final int? newSkillScore;
  final int xpAwarded;
  final bool alreadyProcessed;

  const AnswerAttemptRecord({
    required this.id,
    required this.courseId,
    required this.skillId,
    required this.lessonId,
    required this.questionId,
    required this.selectedIndex,
    required this.selectedAnswer,
    required this.isCorrect,
    required this.timestamp,
    this.correctOption,
    this.explanation,
    this.newSkillScore,
    this.xpAwarded = 0,
    this.alreadyProcessed = false,
  });
}

class PlacementAttemptSubmission {
  final String questionId;
  final int selectedIndex;
  final bool isCorrect;

  const PlacementAttemptSubmission({
    required this.questionId,
    required this.selectedIndex,
    required this.isCorrect,
  });
}

class PlacementAttemptData {
  final String courseId;
  final int score;
  final String? weakestSkillId;
  final List<PlacementAttemptSubmission> submissions;

  const PlacementAttemptData({
    required this.courseId,
    required this.score,
    this.weakestSkillId,
    required this.submissions,
  });
}

class PlacementAnswerEvaluation {
  final bool isCorrect;

  const PlacementAnswerEvaluation({required this.isCorrect});
}

class ReinforcementCompletionResult {
  final int oldScore;
  final int newScore;
  final int xpAwarded;
  final bool alreadyProcessed;

  const ReinforcementCompletionResult({
    required this.oldScore,
    required this.newScore,
    required this.xpAwarded,
    required this.alreadyProcessed,
  });
}

class DailyActivitySummary {
  final String date;
  final int activeMinutes;
  final int xpEarned;
  final int lessonsCompleted;

  const DailyActivitySummary({
    required this.date,
    required this.activeMinutes,
    required this.xpEarned,
    required this.lessonsCompleted,
  });
}

abstract class ILearnerRepository {
  /// Production persistence currently completes lessons/reinforcements through
  /// server RPCs. Demo repositories may still maintain roadmap state locally.
  bool get supportsNodeCompletion => true;
  bool get supportsServerPlacementPersistence => false;
  bool get supportsServerReinforcementPersistence => false;

  Future<LearnerProfile> getProfile();
  Future<LearnerProfile> getCurrentProfile();
  Future<LearnerProfile> updateProfile(LearnerProfile updated);
  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores);
  Future<String> savePlacementAttempt(PlacementAttemptData data);
  Future<PlacementAnswerEvaluation> evaluatePlacementAnswer({
    required String courseId,
    required String questionId,
    required int selectedIndex,
  });
  Future<void> markLessonCompleted(String lessonId, {String? courseId});
  Future<void> markNodeCompleted(String nodeId, {String? courseId});
  /// Returns authoritative persisted values online, or null for demo scoring.
  Future<ReinforcementCompletionResult?> markReinforcementCompleted({
    required String reinforcementId,
    required String courseId,
    required String skillId,
    required String questionId,
    required int beforeScore,
    required int afterScore,
    required int xpAwarded,
  });
  Future<AnswerAttemptRecord> recordAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
    required bool isCorrect,
  });

  /// Submits an answer without accepting a client-computed correctness value.
  /// Online repositories must evaluate it against trusted server content;
  /// offline repositories may evaluate it against their bundled demo content.
  Future<AnswerAttemptRecord> submitAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
  });
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]);
  Future<List<DailyActivitySummary>> getDailyActivity([int days = 7]);
  Future<int> addXp(int amount, [String? actionIdempotencyKey]);
  Future<int> recordDailyActivity([String? dateStr]);
  Future<void> clearLocalState();
  Future<LearnerProfile> resetAll();
}
