import '../repositories/i_course_repository.dart';
import '../repositories/i_learner_repository.dart';
import '../entities/skill.dart';
import '../entities/skill_score.dart';

class KnowledgeMapData {
  final String courseId;
  final List<Skill> skills;
  final Map<String, SkillScore> scores;
  final SkillScore? weakestSkill;
  final int averageScore;

  const KnowledgeMapData({
    required this.courseId,
    required this.skills,
    required this.scores,
    this.weakestSkill,
    required this.averageScore,
  });
}

class GetKnowledgeMapUseCase {
  final ICourseRepository courseRepository;
  final ILearnerRepository learnerRepository;

  const GetKnowledgeMapUseCase(this.courseRepository, this.learnerRepository);

  Future<KnowledgeMapData> execute(String courseId) async {
    final skills = await courseRepository.getSkillsByCourseId(courseId);
    final profile = await learnerRepository.getProfile();
    final scores = profile.scoresByCourse[courseId] ?? {};

    SkillScore? weakestSkill;
    int totalScore = 0;
    int count = 0;

    for (final s in scores.values) {
      totalScore += s.score;
      count += 1;
      if (weakestSkill == null || s.score < weakestSkill.score) {
        weakestSkill = s;
      }
    }

    return KnowledgeMapData(
      courseId: courseId,
      skills: skills,
      scores: scores,
      weakestSkill: weakestSkill,
      averageScore: count > 0 ? (totalScore / count).round() : 0,
    );
  }
}
