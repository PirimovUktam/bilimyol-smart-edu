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
  });
}

abstract class ILearnerRepository {
  Future<LearnerProfile> getProfile();
  Future<LearnerProfile> updateProfile(LearnerProfile updated);
  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores);
  Future<void> markLessonCompleted(String lessonId);
  Future<void> markNodeCompleted(String nodeId);
  Future<void> markReinforcementCompleted(String reinforcementId);
  Future<AnswerAttemptRecord> recordAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
    required bool isCorrect,
  });
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]);
  Future<int> addXp(int amount, [String? actionIdempotencyKey]);
  Future<int> recordDailyActivity([String? dateStr]);
  Future<LearnerProfile> resetAll();
}
