/**
 * BilimYo‘l Adaptive Thresholds Configuration
 * 
 * Rules:
 * score < 50     -> reinforcement (requires remediation node)
 * 50 <= score < 70 -> targeted_practice
 * 70 <= score < 85 -> standard
 * score >= 85    -> advanced
 */
export const ADAPTIVE_THRESHOLDS = {
  REINFORCEMENT_MAX: 49,
  TARGETED_PRACTICE_MIN: 50,
  TARGETED_PRACTICE_MAX: 69,
  STANDARD_MIN: 70,
  STANDARD_MAX: 84,
  ADVANCED_MIN: 85,
} as const;

export type RouteStrategy = 'reinforcement' | 'targeted_practice' | 'standard' | 'advanced';

export function getRouteStrategy(score: number): RouteStrategy {
  if (score <= ADAPTIVE_THRESHOLDS.REINFORCEMENT_MAX) {
    return 'reinforcement';
  }
  if (score <= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MAX) {
    return 'targeted_practice';
  }
  if (score <= ADAPTIVE_THRESHOLDS.STANDARD_MAX) {
    return 'standard';
  }
  return 'advanced';
}

/**
 * Improvement delta constants
 */
export const REINFORCEMENT_SCORE_BUMP = 22; // e.g. 41% -> 63% or 43% -> 65%
export const REINFORCEMENT_XP_REWARD = 30; // +30 XP
export const LESSON_XP_REWARD = 20;
