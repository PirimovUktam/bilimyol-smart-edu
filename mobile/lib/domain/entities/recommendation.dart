enum RecommendationPriority {
  high,
  medium,
  normal,
}

class Recommendation {
  final String id;
  final String courseId;
  final String title;
  final String subtitle;
  final String targetSkillId;
  final String targetSkillName;
  final String targetNodeId;
  final String reason;
  final int suggestedMinutes;
  final RecommendationPriority priority;

  const Recommendation({
    required this.id,
    required this.courseId,
    required this.title,
    required this.subtitle,
    required this.targetSkillId,
    required this.targetSkillName,
    required this.targetNodeId,
    required this.reason,
    required this.suggestedMinutes,
    required this.priority,
  });
}
