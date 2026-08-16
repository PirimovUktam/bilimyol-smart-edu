import '../entities/learner_profile.dart';
import '../entities/skill_score.dart';

abstract class ILearnerRepository {
  Future<LearnerProfile> getProfile();
  Future<LearnerProfile> updateProfile(LearnerProfile updated);
  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores);
  Future<void> markLessonCompleted(String lessonId);
  Future<void> markNodeCompleted(String nodeId);
  Future<void> markReinforcementCompleted(String reinforcementId);
  Future<LearnerProfile> resetAll();
}
