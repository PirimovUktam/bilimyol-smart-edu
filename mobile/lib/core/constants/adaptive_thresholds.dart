/// BilimYo‘l Adaptive Thresholds Configuration
///
/// Rules:
/// score < 50        -> reinforcement (requires remediation node)
/// 50 <= score < 70  -> targeted_practice
/// 70 <= score < 85  -> standard
/// score >= 85       -> advanced
class AdaptiveThresholds {
  static const int reinforcementMax = 49;
  static const int targetedPracticeMin = 50;
  static const int targetedPracticeMax = 69;
  static const int standardMin = 70;
  static const int standardMax = 84;
  static const int advancedMin = 85;

  static const int reinforcementScoreBump = 22; // e.g. 41% -> 63% or 43% -> 65%
  static const int reinforcementXpReward = 30; // +30 XP
  static const int lessonXpReward = 20; // +20 XP
}

enum RouteStrategy {
  reinforcement,
  targetedPractice,
  standard,
  advanced,
}

RouteStrategy getRouteStrategy(int score) {
  if (score <= AdaptiveThresholds.reinforcementMax) {
    return RouteStrategy.reinforcement;
  }
  if (score <= AdaptiveThresholds.targetedPracticeMax) {
    return RouteStrategy.targetedPractice;
  }
  if (score <= AdaptiveThresholds.standardMax) {
    return RouteStrategy.standard;
  }
  return RouteStrategy.advanced;
}
