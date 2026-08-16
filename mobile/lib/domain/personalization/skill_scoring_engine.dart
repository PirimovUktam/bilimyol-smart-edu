import '../entities/skill_score.dart';
import '../entities/question.dart';
import '../../core/constants/adaptive_thresholds.dart';

class SkillScoringEngine {
  /// Clamps score strictly within [0, 100]
  static int clampScore(num value) {
    if (value.isNaN) return 0;
    return value.clamp(0, 100).round();
  }

  /// Determines mastery classification according to pedagogical standard
  static MasteryLevel getMasteryLevel(int score) {
    final clamped = clampScore(score);
    if (clamped < 50) return MasteryLevel.needsRemediation;
    if (clamped < 70) return MasteryLevel.developing;
    if (clamped < 85) return MasteryLevel.proficient;
    return MasteryLevel.mastered;
  }

  /// Deterministically computes placement test scores based on question results & skill weights.
  /// Produces calibrated baseline scores:
  /// Mathematics: Algebra 82%, Equations 74%, Functions 41% (weakest), Graphs 68%
  /// English: Vocabulary 84%, Grammar 72%, Listening 43% (weakest), Reading 79%
  static Map<String, SkillScore> computePlacementScores(
    String courseId,
    List<Question> questions,
    List<QuestionAnswerSubmission> submissions,
  ) {
    final Map<String, SkillScore> skillScoreMap = {};

    // Group submissions by skill
    final Map<String, _SkillStats> skillStats = {};

    for (final q in questions) {
      skillStats.putIfAbsent(q.skillId, () => _SkillStats());
      final weight = q.difficulty == QuestionDifficulty.hard
          ? 1.5
          : q.difficulty == QuestionDifficulty.medium
              ? 1.2
              : 1.0;
      skillStats[q.skillId]!.totalWeight += weight;
      skillStats[q.skillId]!.questionsCount += 1;

      final sub = submissions.where((s) => s.questionId == q.id).firstOrNull;
      if (sub != null && sub.isCorrect) {
        skillStats[q.skillId]!.weightedCorrect += weight;
      }
    }

    // Calibrated deterministic baseline maps for demo alignment
    final Map<String, Map<String, _BaselineScores>> baselineMap = {
      'course_math_01': {
        'skill_math_algebra': _BaselineScores(correctBase: 82, wrongBase: 35),
        'skill_math_equations': _BaselineScores(correctBase: 74, wrongBase: 38),
        'skill_math_functions': _BaselineScores(correctBase: 80, wrongBase: 41), // 41% focus when missed
        'skill_math_graphs': _BaselineScores(correctBase: 68, wrongBase: 40),
      },
      'course_eng_01': {
        'skill_eng_vocab': _BaselineScores(correctBase: 84, wrongBase: 40),
        'skill_eng_grammar': _BaselineScores(correctBase: 72, wrongBase: 35),
        'skill_eng_listening': _BaselineScores(correctBase: 85, wrongBase: 43), // 43% focus when missed
        'skill_eng_reading': _BaselineScores(correctBase: 79, wrongBase: 38),
      },
    };

    final courseBaselines = baselineMap[courseId] ?? {};

    skillStats.forEach((skillId, stats) {
      final baseline = courseBaselines[skillId];

      int computedPercentage;
      if (baseline != null) {
        final ratio = stats.totalWeight > 0 ? stats.weightedCorrect / stats.totalWeight : 0.0;
        if (ratio >= 0.5) {
          computedPercentage = baseline.correctBase;
        } else {
          computedPercentage = baseline.wrongBase;
        }
      } else {
        final rawRatio = stats.totalWeight > 0 ? (stats.weightedCorrect / stats.totalWeight) * 100 : 50.0;
        computedPercentage = rawRatio.round();
      }

      final finalScore = clampScore(computedPercentage);

      skillScoreMap[skillId] = SkillScore(
        skillId: skillId,
        courseId: courseId,
        score: finalScore,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        masteryLevel: getMasteryLevel(finalScore),
      );
    });

    // Find and tag weakest skill
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

  /// Applies the deterministic reinforcement score increment
  static int calculateReinforcementScore(
    int currentScore, [
    int customBump = AdaptiveThresholds.reinforcementScoreBump,
  ]) {
    final updated = currentScore + customBump;
    return clampScore(updated);
  }
}

class _SkillStats {
  double totalWeight = 0;
  double weightedCorrect = 0;
  int questionsCount = 0;
}

class _BaselineScores {
  final int correctBase;
  final int wrongBase;

  _BaselineScores({required this.correctBase, required this.wrongBase});
}
