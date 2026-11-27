import '../entities/skill_score.dart';
import '../entities/question.dart';

export '../entities/skill_score.dart' show ConfidenceLevel;

class EnglishPlacementCefrBreakdown {
  final String assessedCefr;
  final String? unlockedCefrFloor;
  final String effectiveCefr;

  const EnglishPlacementCefrBreakdown({
    required this.assessedCefr,
    required this.unlockedCefrFloor,
    required this.effectiveCefr,
  });
}

class SkillScoringEngine {
  static const Map<String, int> _cefrRank = {
    'Pre-A1': 0,
    'A1': 1,
    'A2': 2,
    'B1': 3,
  };

  /// Clamps score strictly within [0, 100]
  static int clampScore(num value) {
    if (value.isNaN) return 0;
    return value.clamp(0, 100).round();
  }

  /// Central level classification:
  /// 0–39: needsRemediation (Boshlang‘ich)
  /// 40–59: developing (Rivojlanmoqda)
  /// 60–79: proficient (O‘rta)
  /// 80–100: mastered (Yuqori — requires attemptCount >= 4 when attemptCount is provided)
  static MasteryLevel getMasteryLevel(int score, {int? attemptCount}) {
    final clamped = clampScore(score);
    if (clamped < 40) return MasteryLevel.needsRemediation;
    if (clamped < 60) return MasteryLevel.developing;
    if (clamped < 80) return MasteryLevel.proficient;
    if (attemptCount != null && attemptCount < 4) return MasteryLevel.proficient;
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

  static double getDifficultyWeight(QuestionDifficulty difficulty) {
    return switch (difficulty) {
      QuestionDifficulty.easy => 0.75,
      QuestionDifficulty.medium => 1.0,
      QuestionDifficulty.hard => 1.25,
    };
  }

  static const int starterOnlyMaxScore = 55;

  /// Real statistical score calculation: (correct / total) * 100
  static int computeSkillScore(int correctCount, int totalCount) {
    if (totalCount <= 0) return 0;
    final ratio = (correctCount / totalCount) * 100;
    return clampScore(ratio);
  }

  /// Calibrates skill mastery from lesson attempts while respecting starter
  /// difficulty bounds and preserving prior diagnostic/demo evidence.
  static int computeCalibratedSkillScore({
    required double weightedCorrect,
    required double weightedTotal,
    int? priorScore,
    int priorWeight = 4,
    bool starterOnly = false,
    bool hasNonStarterAttempt = false,
  }) {
    if (priorScore != null) {
      if (!hasNonStarterAttempt &&
          priorScore >= starterOnlyMaxScore &&
          weightedTotal > 0 &&
          weightedCorrect == weightedTotal) {
        return priorScore;
      }
      final priorCorrect = (priorScore / 100.0) * priorWeight;
      final blended =
          ((priorCorrect + weightedCorrect) / (priorWeight + weightedTotal)) *
          100;
      final clamped = clampScore(blended);
      if (!hasNonStarterAttempt) {
        final starterCeiling = priorScore > starterOnlyMaxScore
            ? priorScore
            : starterOnlyMaxScore;
        return clamped > starterCeiling ? starterCeiling : clamped;
      }
      return clamped;
    }
    if (weightedTotal <= 0 || weightedCorrect <= 0) return 0;
    if (starterOnly) {
      final raw = ((weightedCorrect + 0.25) / (weightedTotal + 0.75)) * 85;
      return clampScore(raw).clamp(0, starterOnlyMaxScore);
    }
    final smoothed = ((weightedCorrect + 0.5) / (weightedTotal + 1)) * 100;
    return clampScore(smoothed);
  }

  /// Computes overall knowledge score as exact arithmetic mean of skill scores
  static int computeOverallScore(Map<String, SkillScore> skillScores) {
    final scores = skillScores.values.toList();
    if (scores.isEmpty) return 0;
    final sum = scores.fold<int>(0, (acc, s) => acc + s.score);
    return clampScore(sum / scores.length);
  }

  /// Difficulty-weighted statistical placement test scoring from actual student submissions.
  /// Deduplicates by `questionId` using `last wins`, weights credit by item difficulty,
  /// and tags `isWeakestFocus = true` strictly when `lowestScore < 80` (`FIX-P1-16`).
  static Map<String, SkillScore> computePlacementScores(
    String courseId,
    List<Question> questions,
    List<QuestionAnswerSubmission> submissions,
  ) {
    final Map<String, SkillScore> skillScoreMap = {};
    final Map<String, _SkillStats> skillStats = {};
    final Map<String, Question> questionsById = {
      for (final q in questions) q.id: q,
    };
    final Map<String, QuestionAnswerSubmission> deduped = {};

    for (final sub in submissions) {
      if (questionsById.containsKey(sub.questionId)) {
        deduped[sub.questionId] = sub;
      }
    }

    for (final sub in deduped.values) {
      final q = questionsById[sub.questionId];
      if (q == null) continue;
      final stats = skillStats.putIfAbsent(q.skillId, () => _SkillStats());
      final weight = getDifficultyWeight(q.difficulty);
      stats.count += 1;
      if (sub.isCorrect) {
        stats.earned += weight;
        stats.possible += weight;
      } else {
        stats.possible += weight < 1.0 ? weight : 1.0;
      }
    }

    skillStats.forEach((skillId, stats) {
      final finalScore = stats.possible > 0
          ? clampScore((stats.earned / stats.possible) * 100)
          : 0;

      skillScoreMap[skillId] = SkillScore(
        skillId: skillId,
        courseId: courseId,
        score: finalScore,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        masteryLevel: getMasteryLevel(finalScore),
        attemptCount: stats.count,
        confidence: computeConfidence(stats.count),
      );
    });

    // Find and tag weakest skill dynamically only when lowestScore < 80
    int lowestScore = 101;
    String weakestId = '';
    for (final s in skillScoreMap.values) {
      if (s.score < lowestScore) {
        lowestScore = s.score;
        weakestId = s.skillId;
      }
    }

    if (weakestId.isNotEmpty &&
        lowestScore < 80 &&
        skillScoreMap.containsKey(weakestId)) {
      skillScoreMap[weakestId] = skillScoreMap[weakestId]!.copyWith(
        isWeakestFocus: true,
      );
    }

    return skillScoreMap;
  }

  /// Evaluates both `assessedCefr` and `unlockedCefrFloor` separately (`FIX-P0-11`, `FIX-P2-09`).
  static EnglishPlacementCefrBreakdown evaluateEnglishPlacementCefr(
    List<Question> questions,
    List<QuestionAnswerSubmission> submissions, {
    List<String> completedNodeIds = const [],
  }) {
    final questionsById = {for (final q in questions) q.id: q};
    final deduped = <String, QuestionAnswerSubmission>{};
    for (final sub in submissions) {
      if (questionsById.containsKey(sub.questionId)) {
        deduped[sub.questionId] = sub;
      }
    }

    var total = 0;
    var correct = 0;
    var a1Total = 0;
    var a1Correct = 0;
    var a2Total = 0;
    var a2Correct = 0;
    var b1Total = 0;
    var b1Correct = 0;

    for (final sub in deduped.values) {
      final q = questionsById[sub.questionId]!;
      total += 1;
      if (sub.isCorrect) correct += 1;

      final normalizedCefr = (q.cefrLevel ?? '').trim().toUpperCase();
      final tier =
          (normalizedCefr == 'B1' ||
              normalizedCefr == 'B2' ||
              normalizedCefr == 'C1' ||
              normalizedCefr == 'C2')
          ? 'B1'
          : normalizedCefr == 'A2'
          ? 'A2'
          : (normalizedCefr == 'A1' || normalizedCefr == 'PRE-A1')
          ? 'A1'
          : switch (q.difficulty) {
              QuestionDifficulty.easy => 'A1',
              QuestionDifficulty.medium => 'A2',
              QuestionDifficulty.hard => 'B1',
            };
      if (tier == 'B1') {
        b1Total += 1;
        if (sub.isCorrect) b1Correct += 1;
      } else if (tier == 'A2') {
        a2Total += 1;
        if (sub.isCorrect) a2Correct += 1;
      } else {
        a1Total += 1;
        if (sub.isCorrect) a1Correct += 1;
      }
    }

    final overall = total > 0 ? correct / total : 0.0;
    final higherTotal = a2Total + b1Total;
    final higherCorrect = a2Correct + b1Correct;
    final higherAcc = higherTotal > 0 ? higherCorrect / higherTotal : overall;
    final a2Acc = a2Total > 0 ? a2Correct / a2Total : higherAcc;
    final a1Acc = a1Total > 0
        ? a1Correct / a1Total
        : (a2Total > 0 ? a2Acc : overall);
    final b1Acc = b1Total > 0 ? b1Correct / b1Total : 0.0;

    var assessedCefr = 'Pre-A1';
    if (total > 0) {
      if (overall >= 0.875 &&
          a1Acc >= 0.75 &&
          higherAcc >= 0.75 &&
          b1Total >= 2 &&
          b1Acc >= 0.5) {
        assessedCefr = 'B1';
      } else if ((overall >= 0.625 && a1Acc >= 0.5 && a2Acc >= 0.5) ||
          (a2Total >= 3 && a2Acc >= 0.75 && a1Acc >= 0.5)) {
        assessedCefr = 'A2';
      } else if (overall >= 0.375) {
        assessedCefr = 'A1';
      } else {
        assessedCefr = 'Pre-A1';
      }
    }

    String? unlockedFloor;
    if (completedNodeIds.contains('node_eng_b1_exit') ||
        completedNodeIds.contains('node_eng_a2_exit') ||
        completedNodeIds.contains('lesson_eng_b1_exit_assessment') ||
        completedNodeIds.contains('lesson_eng_a2_exit_assessment')) {
      unlockedFloor = 'B1';
    } else if (completedNodeIds.contains('node_eng_a1_exit') ||
        completedNodeIds.contains('lesson_eng_a1_exit_assessment')) {
      unlockedFloor = 'A2';
    }

    final effectiveCefr =
        unlockedFloor != null &&
            (_cefrRank[unlockedFloor] ?? 0) > (_cefrRank[assessedCefr] ?? 0)
        ? unlockedFloor
        : assessedCefr;

    return EnglishPlacementCefrBreakdown(
      assessedCefr: assessedCefr,
      unlockedCefrFloor: unlockedFloor,
      effectiveCefr: effectiveCefr,
    );
  }

  /// Computes calibrated CEFR placement tier (`Pre-A1`, `A1`, `A2`, `B1`),
  /// strictly capped at `B1` (`B2–C2` are DEFERRED).
  /// Matches Web `EnglishCefrPlacement.computeEnglishPlacementCefr` parity.
  static String computeEnglishPlacementCefr(
    List<Question> questions,
    List<QuestionAnswerSubmission> submissions, {
    List<String> completedNodeIds = const [],
  }) {
    return evaluateEnglishPlacementCefr(
      questions,
      submissions,
      completedNodeIds: completedNodeIds,
    ).effectiveCefr;
  }

  static ({String lessonId, String? nodeId, String cefrLevel})
  englishEntryTargetForCefr(String cefrLevel) {
    final normalized = cefrLevel.trim();
    if (normalized == 'B1' ||
        normalized == 'B2' ||
        normalized == 'C1' ||
        normalized == 'C2') {
      return (
        lessonId: 'lesson_eng_b1_m1_travel',
        nodeId: 'node_eng_b1_m1_travel',
        cefrLevel: 'B1',
      );
    }
    if (normalized == 'A2') {
      return (
        lessonId: 'lesson_eng_a2_m1_directions',
        nodeId: 'node_eng_a2_m1_directions',
        cefrLevel: 'A2',
      );
    }
    return (
      lessonId: 'lesson_eng_starter',
      nodeId: null,
      cefrLevel: normalized == 'A1' ? 'A1' : 'Pre-A1',
    );
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
  double earned = 0;
  double possible = 0;
  int count = 0;
}
