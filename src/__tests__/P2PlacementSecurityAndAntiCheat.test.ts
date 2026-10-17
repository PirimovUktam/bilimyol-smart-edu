import { beforeEach, describe, expect, it, vi } from 'vitest';
import { usePlacementStore } from '../app/store/usePlacementStore';
import { supabaseLearnerRepository } from '../data/repositories/SupabaseLearnerRepository';

describe('P2 Placement Test Security & Anti-Cheat Hardening', () => {
  beforeEach(async () => {
    vi.restoreAllMocks();
    usePlacementStore.getState().resetPlacement();
  });

  it('initializes placement with real start timestamp and safe zero submission count', async () => {
    await usePlacementStore.getState().initPlacement('course_math_01');
    const state = usePlacementStore.getState();

    expect(state.isLoading).toBe(false);
    expect(state.currentQuestion).not.toBeNull();
    expect(state.questionNumber).toBe(1);
    expect(state.history).toHaveLength(0);
    expect(state.submissions).toHaveLength(0);
    expect(state._questionStartedAt).toBeGreaterThan(0);
    expect(state._lastSubmittedAt).toBe(0);
  });

  it('rejects invalid selectedIndex input values without calling server', async () => {
    await usePlacementStore.getState().initPlacement('course_math_01');
    const evaluateSpy = vi.spyOn(supabaseLearnerRepository, 'evaluatePlacementAnswer');

    // Negative index
    let result = await usePlacementStore.getState().submitAnswer(-1);
    expect(result).toBe(false);

    // Non-integer (float)
    result = await usePlacementStore.getState().submitAnswer(1.5);
    expect(result).toBe(false);

    // Out-of-bounds index (higher than options length)
    result = await usePlacementStore.getState().submitAnswer(999);
    expect(result).toBe(false);

    // Server should not have been called for invalid inputs
    expect(evaluateSpy).not.toHaveBeenCalled();
  });

  it('enforces rate limiting on rapid submissions within 800ms', async () => {
    await usePlacementStore.getState().initPlacement('course_math_01');
    vi.spyOn(supabaseLearnerRepository, 'evaluatePlacementAnswer').mockResolvedValue({
      isCorrect: true,
    });

    // First submission should succeed
    const firstSubmit = await usePlacementStore.getState().submitAnswer(0);
    expect(firstSubmit).toBe(false); // false means next question is ready

    // Immediate second submission (< 800ms) must be throttled
    const throttledSubmit = await usePlacementStore.getState().submitAnswer(0);
    expect(throttledSubmit).toBe(false);

    // State submissions count should be exactly 1, not 2
    expect(usePlacementStore.getState().submissions).toHaveLength(1);
  });

  it('measures real elapsed time spent per question and clamps within [1, 600]', async () => {
    await usePlacementStore.getState().initPlacement('course_math_01');
    vi.spyOn(supabaseLearnerRepository, 'evaluatePlacementAnswer').mockResolvedValue({
      isCorrect: true,
    });

    // Artificially simulate 12 seconds having elapsed
    const simulatedStart = Date.now() - 12000;
    usePlacementStore.setState({ _questionStartedAt: simulatedStart, _lastSubmittedAt: 0 });

    await usePlacementStore.getState().submitAnswer(0);
    const submissions = usePlacementStore.getState().submissions;

    expect(submissions).toHaveLength(1);
    expect(submissions[0].timeSpentSeconds).toBeGreaterThanOrEqual(11);
    expect(submissions[0].timeSpentSeconds).toBeLessThanOrEqual(13);
  });

  it('safely handles server evaluation errors and maintains recoverable state', async () => {
    await usePlacementStore.getState().initPlacement('course_math_01');
    vi.spyOn(supabaseLearnerRepository, 'evaluatePlacementAnswer').mockRejectedValue(
      new Error('Network error during evaluation')
    );

    const result = await usePlacementStore.getState().submitAnswer(0);
    expect(result).toBe(false);

    const state = usePlacementStore.getState();
    expect(state.isSubmitting).toBe(false);
    expect(state.error).toContain('Network error during evaluation');
    expect(state.submissions).toHaveLength(0); // Failed submission was not appended
  });

  it('resets placement store and clears all security timing markers', async () => {
    await usePlacementStore.getState().initPlacement('course_math_01');
    usePlacementStore.getState().resetPlacement();

    const state = usePlacementStore.getState();
    expect(state.currentQuestion).toBeNull();
    expect(state.allQuestions).toHaveLength(0);
    expect(state.submissions).toHaveLength(0);
    expect(state._questionStartedAt).toBe(0);
    expect(state._lastSubmittedAt).toBe(0);
    expect(state.isSubmitting).toBe(false);
  });
});
