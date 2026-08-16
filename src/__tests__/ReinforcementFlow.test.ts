import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';
import { InMemoryLessonRepository } from '../data/repositories/InMemoryLessonRepository';
import { SubmitReinforcementUseCase } from '../domain/usecases/SubmitReinforcementUseCase';
import { ProgressEngine } from '../domain/personalization/ProgressEngine';

describe('ReinforcementFlow', () => {
  let learnerRepo: InMemoryLearnerRepository;
  let lessonRepo: InMemoryLessonRepository;
  let useCase: SubmitReinforcementUseCase;

  beforeEach(async () => {
    learnerRepo = new InMemoryLearnerRepository();
    lessonRepo = new InMemoryLessonRepository();
    await learnerRepo.resetAll();
    await learnerRepo.saveSkillScores('course_math_01', {
      skill_math_functions: {
        skillId: 'skill_math_functions',
        courseId: 'course_math_01',
        score: 41,
        lastUpdated: Date.now(),
        masteryLevel: 'needs_remediation',
      },
    });
    useCase = new SubmitReinforcementUseCase(learnerRepo, lessonRepo);
  });

  it('should upgrade score from 41% to 63% on correct reinforcement submission', async () => {
    const lesson = await lessonRepo.getLessonById('lesson_math_functions_01');
    expect(lesson).toBeDefined();

    const result = await useCase.execute(
      'course_math_01',
      'skill_math_functions',
      'reinf_node_math_func',
      lesson!.reinforcementExercise,
      1 // Correct answer ('8')
    );

    expect(result.isCorrect).toBe(true);
    expect(result.oldScore).toBe(41);
    expect(result.newScore).toBe(63);
    expect(result.xpAwarded).toBe(30);

    const profile = await learnerRepo.getProfile();
    expect(profile.completedReinforcementIds).toContain('reinf_node_math_func');
    expect(profile.completedNodeIds).toContain('node_math_func');
    expect(profile.scoresByCourse['course_math_01']['skill_math_functions'].score).toBe(63);
  });

  it('should prevent double XP awarding when reinforcement is re-submitted (idempotency)', async () => {
    const { newXP: firstXP, wasAwarded: firstAward } = ProgressEngine.calculateNewXP(
      100,
      'reinforcement_completion',
      'reinf_01',
      []
    );
    expect(firstXP).toBe(130);
    expect(firstAward).toBe(true);

    const { newXP: secondXP, wasAwarded: secondAward } = ProgressEngine.calculateNewXP(
      130,
      'reinforcement_completion',
      'reinf_01',
      ['reinf_01']
    );
    expect(secondXP).toBe(130);
    expect(secondAward).toBe(false);
  });
});
