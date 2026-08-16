enum NodeStatus {
  locked,
  available,
  inProgress,
  completed,
  reinforcement,
}

class LearningPathNode {
  final String id;
  final String courseId;
  final String skillId;
  final String title;
  final String description;
  final List<String> prerequisites;
  final int requiredScore;
  final NodeStatus status;
  final int? score;
  final bool isReinforcement;
  final String? targetLessonId;
  final int estimatedMinutes;
  final double order;

  const LearningPathNode({
    required this.id,
    required this.courseId,
    required this.skillId,
    required this.title,
    this.description = '',
    required this.prerequisites,
    required this.requiredScore,
    required this.status,
    this.score,
    required this.isReinforcement,
    this.targetLessonId,
    required this.estimatedMinutes,
    required this.order,
  });

  LearningPathNode copyWith({
    String? id,
    String? courseId,
    String? skillId,
    String? title,
    String? description,
    List<String>? prerequisites,
    int? requiredScore,
    NodeStatus? status,
    int? score,
    bool? isReinforcement,
    String? targetLessonId,
    int? estimatedMinutes,
    double? order,
  }) {
    return LearningPathNode(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      skillId: skillId ?? this.skillId,
      title: title ?? this.title,
      description: description ?? this.description,
      prerequisites: prerequisites ?? this.prerequisites,
      requiredScore: requiredScore ?? this.requiredScore,
      status: status ?? this.status,
      score: score ?? this.score,
      isReinforcement: isReinforcement ?? this.isReinforcement,
      targetLessonId: targetLessonId ?? this.targetLessonId,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      order: order ?? this.order,
    );
  }
}

class LearningPath {
  final String id;
  final String courseId;
  final String title;
  final List<LearningPathNode> nodes;
  final String activeNodeId;
  final int updatedAt;

  const LearningPath({
    required this.id,
    required this.courseId,
    required this.title,
    required this.nodes,
    required this.activeNodeId,
    required this.updatedAt,
  });
}
