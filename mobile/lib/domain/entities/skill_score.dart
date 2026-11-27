enum MasteryLevel {
  needsRemediation,
  developing,
  proficient,
  mastered,
}

enum ConfidenceLevel { low, medium, high }

class SkillScore {
  final String skillId;
  final String courseId;
  final int score; // 0 to 100
  final int lastUpdated;
  final MasteryLevel masteryLevel;
  final bool isWeakestFocus;
  final int? attemptCount;
  final ConfidenceLevel? confidence;

  const SkillScore({
    required this.skillId,
    required this.courseId,
    required this.score,
    required this.lastUpdated,
    required this.masteryLevel,
    this.isWeakestFocus = false,
    this.attemptCount,
    this.confidence,
  });

  SkillScore copyWith({
    String? skillId,
    String? courseId,
    int? score,
    int? lastUpdated,
    MasteryLevel? masteryLevel,
    bool? isWeakestFocus,
    int? attemptCount,
    ConfidenceLevel? confidence,
  }) {
    return SkillScore(
      skillId: skillId ?? this.skillId,
      courseId: courseId ?? this.courseId,
      score: score ?? this.score,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      isWeakestFocus: isWeakestFocus ?? this.isWeakestFocus,
      attemptCount: attemptCount ?? this.attemptCount,
      confidence: confidence ?? this.confidence,
    );
  }
}
