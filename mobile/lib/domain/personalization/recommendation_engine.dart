import '../entities/recommendation.dart';
import '../entities/skill_score.dart';
import '../entities/learning_path_node.dart';
import '../entities/skill.dart';
import '../../core/constants/adaptive_thresholds.dart';

class RecommendationEngine {
  /// Generates tailored next-step recommendation for the learner
  static Recommendation generateRecommendation({
    required String courseId,
    required List<Skill> skills,
    required Map<String, SkillScore> skillScores,
    required LearningPath roadmap,
  }) {
    // 1. Find weakest skill
    SkillScore? weakestSkill;
    for (final sc in skillScores.values) {
      if (weakestSkill == null || sc.score < weakestSkill.score) {
        weakestSkill = sc;
      }
    }

    final targetSkill = skills.where((s) => s.id == weakestSkill?.skillId).firstOrNull;
    final targetSkillName = targetSkill?.name ?? 'Asosiy mavzu';

    // 2. Find next active node in roadmap
    final activeNode = roadmap.nodes.firstWhere(
      (n) => n.status == NodeStatus.reinforcement || n.status == NodeStatus.available || n.status == NodeStatus.inProgress,
      orElse: () => roadmap.nodes.first,
    );

    final isReinforcement = activeNode.isReinforcement || activeNode.status == NodeStatus.reinforcement;
    final weakestScore = weakestSkill?.score;
    final isTargetedPractice =
        weakestScore != null &&
        weakestScore >= AdaptiveThresholds.targetedPracticeMin &&
        weakestScore <= AdaptiveThresholds.targetedPracticeMax;

    return Recommendation(
      id: 'rec_${courseId}_${DateTime.now().millisecondsSinceEpoch}',
      courseId: courseId,
      title: isReinforcement
          ? 'Mustahkamlaş: $targetSkillName'
          : isTargetedPractice
          ? 'Maqsadli maşq: $targetSkillName'
          : 'Bugungi Reja: ${activeNode.title}',
      subtitle: isReinforcement
          ? 'Aniqlangan böşliqni töldiriş uçun maxsus 5 daqiqalik maşq'
          : isTargetedPractice
          ? '50–69% oraliqdagi könikmani 70%+ darajaga kötariş uçun maşq'
          : 'Keyingi bosqiçga ötiş va özlaştiriş darajasini oşiriş',
      targetSkillId: targetSkill?.id ?? '',
      targetSkillName: targetSkillName,
      targetNodeId: activeNode.id,
      reason: weakestScore != null && weakestScore < AdaptiveThresholds.targetedPracticeMin
          ? 'Uşbu könikma hozirda $weakestScore% darajasida. Tavsiya etilgan maşq orqali uni 60%+ darajaga kötaring.'
          : isTargetedPractice
          ? 'Uşbu könikma hozirda $weakestScore% darajasida. Maqsadli maşq bilan 70%+ barqaror natijaga erişing.'
          : 'Özlaştiriş sur’atini saqlab qoliş uçun rejadagi darsni davom ettiring.',
      suggestedMinutes: isReinforcement ? 5 : activeNode.estimatedMinutes,
      priority: weakestScore != null && weakestScore < AdaptiveThresholds.targetedPracticeMin
          ? RecommendationPriority.high
          : RecommendationPriority.medium,
    );
  }
}
