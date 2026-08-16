enum MasteryLevel {
  needsRemediation,
  developing,
  proficient,
  mastered,
}

class SkillScore {
  final String skillId;
  final String courseId;
  final int score; // 0 to 100
  final int lastUpdated;
  final MasteryLevel masteryLevel;
  final bool isWeakestFocus;

  const SkillScore({
    required this.skillId,
    required this.courseId,
    required this.score,
    required this.lastUpdated,
    required this.masteryLevel,
    this.isWeakestFocus = false,
  });

  SkillScore copyWith({
    String? skillId,
    String? courseId,
    int? score,
    int? lastUpdated,
    MasteryLevel? masteryLevel,
    bool? isWeakestFocus,
  }) {
    return SkillScore(
      skillId: skillId ?? this.skillId,
      courseId: courseId ?? this.courseId,
      score: score ?? this.score,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      isWeakestFocus: isWeakestFocus ?? this.isWeakestFocus,
    );
  }
}
