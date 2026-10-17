import { beforeEach, describe, expect, it, vi } from 'vitest';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';
import { InMemoryCourseRepository } from '../data/repositories/InMemoryCourseRepository';
import { InMemoryLessonRepository } from '../data/repositories/InMemoryLessonRepository';
import { SupabaseLearnerRepository } from '../data/repositories/SupabaseLearnerRepository';
import { ILearnerRepository } from '../domain/repositories/ILearnerRepository';
import { SubmitReinforcementUseCase } from '../domain/usecases/SubmitReinforcementUseCase';
import { SubmitPlacementTestUseCase } from '../domain/usecases/SubmitPlacementTestUseCase';
import { SEED_LESSONS } from '../data/datasources/lessons';

const backend = vi.hoisted(() => ({ configured: true, rpc: vi.fn(), from: vi.fn(), getUser: vi.fn() }));
vi.mock('../core/config/supabase', () => ({
  get isSupabaseConfigured() { return backend.configured; },
  supabase: { rpc: backend.rpc, from: backend.from, auth: { getUser: backend.getUser } },
}));

beforeEach(() => {
  vi.clearAllMocks();
  backend.configured = true;
  backend.getUser.mockResolvedValue({ data: { user: { id: 'test-learner' } }, error: null });
});

describe('production learner repository contracts', () => {
  const context = { courseId: 'course_math_01', skillId: 'skill_math_functions', questionId: 'q_server', beforeScore: 1, afterScore: 2, xpAwarded: 999 };

  it('derives persistence capabilities from mode instead of breaking demo mode', () => {
    const repo = new SupabaseLearnerRepository();
    expect(repo.supportsServerPlacementPersistence).toBe(true);
    expect(repo.supportsServerReinforcementPersistence).toBe(true);
    expect(repo.supportsNodeCompletion).toBe(false);
    backend.configured = false;
    expect(repo.supportsServerPlacementPersistence).toBe(false);
    expect(repo.supportsServerReinforcementPersistence).toBe(false);
    expect(repo.supportsNodeCompletion).toBe(true);
  });

  it('returns validated persisted reinforcement values, not client hints', async () => {
    backend.rpc.mockResolvedValue({ data: { old_score: 50, new_score: 72, xp_awarded: 30, already_processed: false }, error: null });
    const result = await new SupabaseLearnerRepository().markReinforcementCompleted('reinf_node_math_func', context);
    expect(result).toEqual({ oldScore: 50, newScore: 72, xpAwarded: 30, alreadyProcessed: false });
    expect(backend.rpc).toHaveBeenCalledWith('complete_reinforcement', expect.objectContaining({ p_question_id: context.questionId }));
  });

  it('rejects a malformed completion result instead of reporting local success', async () => {
    backend.rpc.mockResolvedValue({ data: { new_score: 72 }, error: null });
    await expect(new SupabaseLearnerRepository().markReinforcementCompleted('reinf_node_math_func', context)).rejects.toThrow();
  });

  it('completes lessons through one atomic RPC without direct progress writes', async () => {
    backend.rpc.mockResolvedValue({ data: { completed: true, xp_awarded: 20 }, error: null });
    await new SupabaseLearnerRepository().markLessonCompleted('lesson_server', 'course_math_01');
    expect(backend.rpc).toHaveBeenCalledExactlyOnceWith('complete_lesson', { p_lesson_id: 'lesson_server', p_course_id: 'course_math_01' });
    expect(backend.from).not.toHaveBeenCalled();
  });

  it('propagates configured placement write failures without a demo attempt id', async () => {
    backend.rpc.mockResolvedValue({ data: null, error: { message: 'remote unavailable' } });
    await expect(new SupabaseLearnerRepository().savePlacementAttempt({ courseId: 'course_math_01', score: 100, submissions: [] })).rejects.toThrow('remote unavailable');
  });
});

describe('server-authoritative usecase persistence', () => {
  const lesson = SEED_LESSONS.lesson_math_functions_01;
  const question = lesson.reinforcementExercise;

  function serverRepository(): ILearnerRepository {
    const repo: ILearnerRepository = new InMemoryLearnerRepository();
    Object.defineProperties(repo, {
      supportsServerPlacementPersistence: { value: true },
      supportsServerReinforcementPersistence: { value: true },
      supportsNodeCompletion: { value: false },
    });
    return repo;
  }

  it.each([false, true])('uses persisted reinforcement scores and no extra writes (retry=%s)', async (retry) => {
    const repo = serverRepository();
    vi.spyOn(repo, 'submitAnswerAttempt').mockResolvedValue({ isCorrect: true, explanation: '', newSkillScore: 75, overallScore: 75, xpAwarded: 0 });
    vi.spyOn(repo, 'markReinforcementCompleted').mockResolvedValue({ oldScore: 75, newScore: 97, xpAwarded: 30, alreadyProcessed: retry });
    const save = vi.spyOn(repo, 'saveSkillScores');
    const update = vi.spyOn(repo, 'updateProfile');
    const node = vi.spyOn(repo, 'markNodeCompleted');
    const result = await new SubmitReinforcementUseCase(repo, new InMemoryLessonRepository()).execute(
      lesson.courseId, lesson.skillId, 'reinf_node_math_func', question, 0,
    );
    expect(result).toMatchObject({ isCorrect: true, oldScore: 75, newScore: 97, xpAwarded: retry ? 0 : 30 });
    expect(save).not.toHaveBeenCalled();
    expect(update).not.toHaveBeenCalled();
    expect(node).not.toHaveBeenCalled();
  });

  it('rejects reinforcement context mismatch before any answer submission', async () => {
    const repo = serverRepository();
    const submit = vi.spyOn(repo, 'submitAnswerAttempt');
    await expect(new SubmitReinforcementUseCase(repo, new InMemoryLessonRepository()).execute(
      'course_eng_01', lesson.skillId, 'reinf_wrong', question, 0,
    )).rejects.toThrow();
    expect(submit).not.toHaveBeenCalled();
  });

  it('placement saves one verified payload and reads server scores without duplicate rewards', async () => {
    const courseRepo = new InMemoryCourseRepository();
    const [question] = await courseRepo.getPlacementQuestions('course_math_01');
    const repo = serverRepository();
    const profile = await repo.getProfile();
    profile.scoresByCourse.course_math_01 = { [question.skillId]: { courseId: 'course_math_01', skillId: question.skillId, score: 73, masteryLevel: 'proficient', lastUpdated: 0 } };
    vi.spyOn(repo, 'getProfile').mockResolvedValue(profile);
    vi.spyOn(repo, 'evaluatePlacementAnswer').mockResolvedValue({ isCorrect: false });
    const persist = vi.spyOn(repo, 'savePlacementAttempt').mockResolvedValue('persisted-id');
    const record = vi.spyOn(repo, 'recordAnswerAttempt');
    const scores = vi.spyOn(repo, 'saveSkillScores');
    const xp = vi.spyOn(repo, 'addXp');
    const activity = vi.spyOn(repo, 'recordDailyActivity');
    const result = await new SubmitPlacementTestUseCase(courseRepo, repo).execute('course_math_01', [
      { questionId: question.id, selectedIndex: 0, isCorrect: true, timeSpentSeconds: 2 },
    ]);
    expect(result.computedScores[question.skillId].score).toBe(73);
    expect(persist).toHaveBeenCalledOnce();
    expect(persist.mock.calls[0][0].submissions[0].isCorrect).toBe(false);
    expect(record).not.toHaveBeenCalled();
    expect(scores).not.toHaveBeenCalled();
    expect(xp).not.toHaveBeenCalled();
    expect(activity).not.toHaveBeenCalled();
  });

  it('validates all placement submissions before any write', async () => {
    const courseRepo = new InMemoryCourseRepository();
    const [question] = await courseRepo.getPlacementQuestions('course_math_01');
    const repo = serverRepository();
    const evaluate = vi.spyOn(repo, 'evaluatePlacementAnswer');
    const persist = vi.spyOn(repo, 'savePlacementAttempt');
    const submission = { questionId: question.id, selectedIndex: 0, isCorrect: true, timeSpentSeconds: 2 };
    const usecase = new SubmitPlacementTestUseCase(courseRepo, repo);
    for (const invalid of [[], [submission, submission], [submission, { ...submission, questionId: 'unknown' }], [{ ...submission, selectedIndex: -1 }]]) {
      await expect(usecase.execute('course_math_01', invalid)).rejects.toThrow();
    }
    expect(evaluate).not.toHaveBeenCalled();
    expect(persist).not.toHaveBeenCalled();
  });
});
