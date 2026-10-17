import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';
import { InMemoryLessonRepository } from '../data/repositories/InMemoryLessonRepository';
import { SubmitReinforcementUseCase } from '../domain/usecases/SubmitReinforcementUseCase';
import { Question } from '../domain/entities/Question';
import { SubmitAnswerAttemptRequest, SubmitAnswerAttemptResult } from '../domain/repositories/ILearnerRepository';

const source = (relativePath: string): string =>
  readFileSync(resolve(process.cwd(), relativePath), 'utf8');

class ServerEvaluatedLearnerRepository extends InMemoryLearnerRepository {
  public lastRequest: SubmitAnswerAttemptRequest | null = null;
  public recordAnswerAttemptCalls = 0;

  constructor(private readonly serverIsCorrect: boolean) {
    super();
  }

  override async submitAnswerAttempt(request: SubmitAnswerAttemptRequest): Promise<SubmitAnswerAttemptResult> {
    this.lastRequest = request;
    return {
      isCorrect: this.serverIsCorrect,
      explanation: this.serverIsCorrect ? 'To‘g‘ri.' : 'Noto‘g‘ri.',
      newSkillScore: this.serverIsCorrect ? 100 : 0,
      overallScore: this.serverIsCorrect ? 100 : 0,
      xpAwarded: this.serverIsCorrect ? 2 : 0,
    };
  }

  override async recordAnswerAttempt(
    attempt: Parameters<InMemoryLearnerRepository['recordAnswerAttempt']>[0]
  ) {
    this.recordAnswerAttemptCalls += 1;
    return super.recordAnswerAttempt(attempt);
  }
}

const reinforcementQuestion: Question = {
  id: 'q_server_authoritative_reinforcement',
  courseId: 'course_math_01',
  skillId: 'skill_math_functions',
  text: 'Qaysi javob to‘g‘ri?',
  options: ['A', 'B'],
  // Deliberately contradictory/stale client data.
  correctIndex: 0,
  difficulty: 'easy',
  explanation: '',
};

describe('P1 closure: server evaluation and production persistence boundaries', () => {
  it('uses the server evaluation result even when the local answer key disagrees', async () => {
    const learnerRepo = new ServerEvaluatedLearnerRepository(false);
    const useCase = new SubmitReinforcementUseCase(
      learnerRepo,
      new InMemoryLessonRepository()
    );

    const result = await useCase.execute(
      reinforcementQuestion.courseId,
      reinforcementQuestion.skillId,
      'reinf_node_math_func',
      reinforcementQuestion,
      0
    );

    expect(result.isCorrect).toBe(false);
    expect(learnerRepo.lastRequest?.selectedIndex).toBe(0);
    expect(learnerRepo.lastRequest?.selectedAnswer).toBe('A');
    expect(learnerRepo.recordAnswerAttemptCalls).toBe(0);
  });

  it('can accept a server-approved answer without needing a client answer key', async () => {
    const learnerRepo = new ServerEvaluatedLearnerRepository(true);
    const questionWithoutKey = { ...reinforcementQuestion, correctIndex: undefined };
    const useCase = new SubmitReinforcementUseCase(
      learnerRepo,
      new InMemoryLessonRepository()
    );

    const result = await useCase.execute(
      questionWithoutKey.courseId,
      questionWithoutKey.skillId,
      'reinf_node_math_func',
      questionWithoutKey,
      1
    );

    expect(result.isCorrect).toBe(true);
    expect(result.newScore).toBe(22);
  });

  it('keeps production content and learner failures out of seed fallbacks', () => {
    const learner = source('src/data/repositories/SupabaseLearnerRepository.ts');
    const course = source('src/data/repositories/SupabaseCourseRepository.ts');
    const lesson = source('src/data/repositories/SupabaseLessonRepository.ts');
    const roadmapStore = source('src/app/store/useRoadmapStore.ts');

    expect(course).toContain(".from('learner_questions')");
    expect(course).not.toContain('missingSeeds');
    expect(course).not.toMatch(/catch\s*\{[\s\S]{0,160}return this\.fallback/);
    expect(lesson).not.toMatch(/catch\s*\{[\s\S]{0,160}return this\.fallback/);
    expect(learner).not.toMatch(/catch\s*\([^)]*\)\s*\{[\s\S]{0,160}return this\.fallbackRepo/);
    expect(learner).not.toContain('correctIndex: typeof data.correct_index');
    expect(learner).not.toContain('correctOption: data.correct_option');
    expect(roadmapStore).toContain("from '@/data/repositories/SupabaseLessonRepository'");
    expect(roadmapStore).not.toContain("from '@/data/repositories/InMemoryLessonRepository'");
  });

  it('leaves a visible error when lesson completion or progress loading fails', () => {
    const lessonStore = source('src/app/store/useLessonStore.ts');
    const progressView = source('src/features/progress/ProgressView.tsx');

    expect(lessonStore).toContain('Dars progressi saqlanmadi:');
    expect(progressView).toContain('activityError');
    expect(progressView).toContain('role="alert"');
  });
});
