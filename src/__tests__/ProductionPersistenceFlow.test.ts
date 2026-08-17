import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryCourseRepository } from '../data/repositories/InMemoryCourseRepository';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';
import { SubmitPlacementTestUseCase } from '../domain/usecases/SubmitPlacementTestUseCase';
import { GetKnowledgeMapUseCase } from '../domain/usecases/GetKnowledgeMapUseCase';
import { QuestionAnswerSubmission } from '../domain/entities/Question';

describe('ProductionPersistenceFlow', () => {
  let courseRepo: InMemoryCourseRepository;
  let learnerRepo: InMemoryLearnerRepository;
  let placementUseCase: SubmitPlacementTestUseCase;
  let knowledgeMapUseCase: GetKnowledgeMapUseCase;

  beforeEach(async () => {
    courseRepo = new InMemoryCourseRepository();
    learnerRepo = new InMemoryLearnerRepository();
    await learnerRepo.resetAll();
    placementUseCase = new SubmitPlacementTestUseCase(courseRepo, learnerRepo);
    knowledgeMapUseCase = new GetKnowledgeMapUseCase(courseRepo, learnerRepo);
  });

  it('should persist placement test attempts and compute scores strictly from actual responses', async () => {
    const questions = await courseRepo.getPlacementQuestions('course_math_01');
    expect(questions.length).toBeGreaterThan(0);

    // Build real user submissions: answer half correctly, half incorrectly
    const submissions: QuestionAnswerSubmission[] = questions.slice(0, 4).map((q, idx) => ({
      questionId: q.id,
      selectedIndex: idx % 2 === 0 ? q.correctIndex : (q.correctIndex + 1) % 4,
      isCorrect: idx % 2 === 0,
      timeSpentSeconds: 12,
    }));

    const result = await placementUseCase.execute('course_math_01', submissions);

    expect(result).toBeDefined();
    expect(result.assessmentId).toMatch(/^plc_att_/);
    expect(result.submissions.length).toBe(4);
    expect(result.computedScores).toBeDefined();

    // Verify persistence in repository: 2 correct answers (+4 XP) + placement (+20 XP) = 24 XP
    const profile = await learnerRepo.getProfile();
    expect(profile.xp).toBe(24);
    expect(profile.scoresByCourse['course_math_01']).toBeDefined();

    // Verify answer attempts were recorded
    const attempts = await learnerRepo.getAnswerAttempts(10);
    expect(attempts.length).toBe(4);
    expect(attempts[0].lessonId).toBe('placement_test');
  });

  it('should sync knowledge map directly with persisted learner skill scores', async () => {
    // Record real skill scores
    await learnerRepo.saveSkillScores('course_math_01', {
      skill_math_algebra: {
        skillId: 'skill_math_algebra',
        courseId: 'course_math_01',
        score: 75,
        lastUpdated: Date.now(),
        masteryLevel: 'proficient',
        isWeakestFocus: false,
      },
      skill_math_functions: {
        skillId: 'skill_math_functions',
        courseId: 'course_math_01',
        score: 35,
        lastUpdated: Date.now(),
        masteryLevel: 'needs_remediation',
        isWeakestFocus: true,
      },
    });

    const mapData = await knowledgeMapUseCase.execute('course_math_01');

    expect(mapData).toBeDefined();
    expect(mapData.overallScore).toBe(55); // (75 + 35) / 2 = 55
    expect(mapData.weakestSkill?.skillId).toBe('skill_math_functions');
    expect(mapData.weakestSkill?.score).toBe(35);
  });
});
