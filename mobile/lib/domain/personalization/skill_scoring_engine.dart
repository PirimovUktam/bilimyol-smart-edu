import '../entities/skill_score.dart';
import '../entities/question.dart';

enum ConfidenceLevel { low, medium, high }

class SkillScoringEngine {
  /// Clamps score strictly within [0, 100]
  static int clampScore(num value) {
    if (value.isNaN) return 0;
    return value.clamp(0, 100).round();
  }

  /// Central level classification:
  /// 0–39: needsRemediation (Boshlang‘ich)
  /// 40–59: developing (Rivojlanmoqda)
  /// 60–79: proficient (O‘rta)
  /// 80–100: mastered (Yuqori)
  static MasteryLevel getMasteryLevel(int score) {
    final clamped = clampScore(score);
    if (clamped < 40) return MasteryLevel.needsRemediation;
    if (clamped < 60) return MasteryLevel.developing;
    if (clamped < 80) return MasteryLevel.proficient;
    return MasteryLevel.mastered;
  }

  /// Uzbek level label
  static String getMasteryLabelUz(int score) {
    final level = getMasteryLevel(score);
    switch (level) {
      case MasteryLevel.needsRemediation:
        return 'Boshlang‘ich';
      case MasteryLevel.developing:
        return 'Rivojlanmoqda';
      case MasteryLevel.proficient:
        return 'O‘rta';
      case MasteryLevel.mastered:
        return 'Yuqori';
    }
  }

  /// Determines confidence level based on number of attempts
  static ConfidenceLevel computeConfidence(int attemptCount) {
    if (attemptCount < 3) return ConfidenceLevel.low;
    if (attemptCount <= 5) return ConfidenceLevel.medium;
    return ConfidenceLevel.high;
  }

  /// Real statistical score calculation: (correct / total) * 100
  static int computeSkillScore(int correctCount, int totalCount) {
    if (totalCount <= 0) return 0;
    final ratio = (correctCount / totalCount) * 100;
    return clampScore(ratio);
  }

  /// Computes overall knowledge score as exact arithmetic mean of skill scores
  static int computeOverallScore(Map<String, SkillScore> skillScores) {
    final scores = skillScores.values.toList();
    if (scores.isEmpty) return 0;
    final sum = scores.fold<int>(0, (acc, s) => acc + s.score);
    return clampScore(sum / scores.length);
  }

  /// Real statistical placement test scoring from actual student submissions
  static Map<String, SkillScore> computePlacementScores(
    String courseId,
    List<Question> questions,
    List<QuestionAnswerSubmission> submissions,
  ) {
    final Map<String, SkillScore> skillScoreMap = {};
    final Map<String, _SkillStats> skillStats = {};

    for (final q in questions) {
      skillStats.putIfAbsent(q.skillId, () => _SkillStats());
      skillStats[q.skillId]!.total += 1;

      final sub = submissions.where((s) => s.questionId == q.id).firstOrNull;
      if (sub != null && sub.isCorrect) {
        skillStats[q.skillId]!.correct += 1;
      }
    }

    skillStats.forEach((skillId, stats) {
      final finalScore = computeSkillScore(stats.correct, stats.total);

      skillScoreMap[skillId] = SkillScore(
        skillId: skillId,
        courseId: courseId,
        score: finalScore,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        masteryLevel: getMasteryLevel(finalScore),
      );
    });

    // Find and tag weakest skill dynamically
    int lowestScore = 101;
    String weakestId = '';
    for (final s in skillScoreMap.values) {
      if (s.score < lowestScore) {
        lowestScore = s.score;
        weakestId = s.skillId;
      }
    }

    if (weakestId.isNotEmpty && skillScoreMap.containsKey(weakestId)) {
      skillScoreMap[weakestId] = skillScoreMap[weakestId]!.copyWith(isWeakestFocus: true);
    }

    return skillScoreMap;
  }

  /// Real cumulative reinforcement score calculation
  static int calculateCumulativeReinforcementScore(
    int previousCorrect,
    int previousTotal,
    int reinforcementCorrect,
    int reinforcementTotal,
  ) {
    final totalAttempts = previousTotal + reinforcementTotal;
    if (totalAttempts <= 0) return 0;
    final totalCorrect = previousCorrect + reinforcementCorrect;
    return computeSkillScore(totalCorrect, totalAttempts);
  }

  /// Standard helper for reinforcement score bump
  static int calculateReinforcementScore(int currentScore, [int customBump = 22]) {
    return clampScore(currentScore + customBump);
  }
}

class _SkillStats {
  int correct = 0;
  int total = 0;
}
