import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';

describe('Gamification and Streak System', () => {
  let repo: InMemoryLearnerRepository;

  beforeEach(() => {
    repo = new InMemoryLearnerRepository();
  });

  it('awards XP idempotently and prevents duplicate awarding for the same actionKey', async () => {
    const xp1 = await repo.addXp(20, 'placement_completed_math');
    expect(xp1).toBe(20);

    // Duplicate call with same key should NOT increase XP
    const xp2 = await repo.addXp(20, 'placement_completed_math');
    expect(xp2).toBe(20);

    // Different action should award additional XP
    const xp3 = await repo.addXp(20, 'lesson_completed_lesson_01');
    expect(xp3).toBe(40);
  });

  it('increments streak only once per calendar date regardless of activity count', async () => {
    const today = '2026-08-17';
    const streak1 = await repo.recordDailyActivity(today);
    expect(streak1).toBe(1);

    // Multiple activities on the same day do not inflate streak
    const streak2 = await repo.recordDailyActivity(today);
    const streak3 = await repo.recordDailyActivity(today);
    expect(streak2).toBe(1);
    expect(streak3).toBe(1);

    // Next consecutive day activity increments streak
    const streakNext = await repo.recordDailyActivity('2026-08-18');
    expect(streakNext).toBe(2);
  });

  it('records answer attempts and recalculates real cumulative skill scores', async () => {
    await repo.recordAnswerAttempt({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      questionId: 'q_f1',
      selectedIndex: 0,
      selectedAnswer: '11',
      isCorrect: true,
    });

    await repo.recordAnswerAttempt({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      questionId: 'q_f2',
      selectedIndex: 1,
      selectedAnswer: 'wrong',
      isCorrect: false,
    });

    const profile = await repo.getProfile();
    const funcScore = profile.scoresByCourse['course_math_01']['skill_math_functions'];

    // 1 correct out of 2 attempts = 50%
    expect(funcScore.score).toBe(50);
    expect(funcScore.masteryLevel).toBe('developing');

    const recent = await repo.getAnswerAttempts(5);
    expect(recent.length).toBe(2);
    expect(recent[0].isCorrect).toBe(true);
    expect(recent[1].isCorrect).toBe(false);
  });
});
