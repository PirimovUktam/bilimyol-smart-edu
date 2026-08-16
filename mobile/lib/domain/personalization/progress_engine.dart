import '../entities/skill_score.dart';
import '../entities/learning_path_node.dart';
import '../../core/constants/adaptive_thresholds.dart';

class ProgressEngine {
  /// Calculates overall course mastery % based on average skill scores
  static int calculateCourseMastery(Map<String, SkillScore> skillScores) {
    final scores = skillScores.values.toList();
    if (scores.isEmpty) return 0;
    final total = scores.fold<int>(0, (sum, item) => sum + item.score);
    return (total / scores.length).round();
  }

  /// Calculates roadmap completion percentage
  static int calculateRoadmapProgress(List<LearningPathNode> nodes) {
    if (nodes.isEmpty) return 0;
    final completedCount = nodes.where((n) => n.status == NodeStatus.completed).length;
    return ((completedCount / nodes.length) * 100).round();
  }

  /// Safe idempotent XP adder preventing double-awarding
  static ({int newXP, bool wasAwarded}) calculateNewXP({
    required int currentXP,
    required String actionType, // 'lesson_completion' | 'reinforcement_completion'
    required String actionId,
    required List<String> completedActionIds,
  }) {
    if (completedActionIds.contains(actionId)) {
      return (newXP: currentXP, wasAwarded: false);
    }

    final reward = actionType == 'reinforcement_completion'
        ? AdaptiveThresholds.reinforcementXpReward
        : AdaptiveThresholds.lessonXpReward;

    return (
      newXP: currentXP + reward,
      wasAwarded: true,
    );
  }
}
