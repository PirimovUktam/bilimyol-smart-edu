import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { LearnerProfile } from '../domain/entities/LearnerProfile';
import type { Lesson } from '../domain/entities/Lesson';
import type { Question } from '../domain/entities/Question';
import { useLessonStore } from '../app/store/useLessonStore';
import { useLearnerStore } from '../app/store/useLearnerStore';

const backend = vi.hoisted(() => ({
  load: vi.fn(), save: vi.fn(), score: vi.fn(), complete: vi.fn(), profile: vi.fn(),
  generate: vi.fn(), explain: vi.fn(),
}));
vi.mock('../data/repositories/SupabaseLessonRepository', () => ({
  supabaseLessonRepository: { getLessonById: backend.load, saveLesson: backend.save },
}));
vi.mock('../data/repositories/SupabaseLearnerRepository', () => ({
  supabaseLearnerRepository: {
    submitAnswerAttempt: backend.score, markLessonCompleted: backend.complete, getProfile: backend.profile,
  },
}));
vi.mock('../data/services/GeminiAITutorService', () => ({
  GeminiAITutorService: class { generateLesson = backend.generate; explainMistake = backend.explain; },
}));

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
const question = (id: string): Question => ({
  id, courseId: 'course_math_01', skillId: 'skill_math_functions', text: 'Q?',
  options: ['A', 'B'], difficulty: 'easy', explanation: '',
});

describe('completion retry and invalid assessment boundaries', () => {
  async function readyToFinish() {
    await useLessonStore.getState().loadLesson('finish');
    await useLessonStore.getState().submitAnswer(0);
    await useLessonStore.getState().nextStep();
  }

  it('shares pending persistence and retries a failed read-back without a second write', async () => {
    await readyToFinish();
    const persisted = deferred<void>();
    backend.complete.mockImplementationOnce(async (id: string) => { await persisted.promise; completed.add(id); });
    backend.profile.mockRejectedValueOnce(new Error('profile offline'));
    const first = useLessonStore.getState().nextStep();
    await useLessonStore.getState().nextStep();
    expect(backend.complete).toHaveBeenCalledOnce();
    expect(useLessonStore.getState().isCompleted).toBe(false);
    persisted.resolve();
    await first;
    expect(useLessonStore.getState()).toMatchObject({ isCompleted: false, isCompletingLesson: false });
    expect(useLessonStore.getState().error).toContain('profile offline');
    await useLessonStore.getState().nextStep();
    expect(backend.complete).toHaveBeenCalledOnce();
    expect(useLessonStore.getState().isCompleted).toBe(true);
  });

  it('allows a failed completion write to be retried, without false success', async () => {
    await readyToFinish();
    backend.complete.mockRejectedValueOnce(new Error('write offline'));
    await useLessonStore.getState().nextStep();
    expect(useLessonStore.getState()).toMatchObject({ isCompleted: false, isCompletingLesson: false });
    expect(useLessonStore.getState().error).toContain('write offline');
    await useLessonStore.getState().nextStep();
    expect(backend.complete).toHaveBeenCalledTimes(2);
    expect(useLessonStore.getState().isCompleted).toBe(true);
  });

  it('discards completion and profile work after the lesson session is cleared', async () => {
    await readyToFinish();
    const persisted = deferred<void>();
    backend.complete.mockReturnValueOnce(persisted.promise);
    backend.profile.mockClear();
    const finish = useLessonStore.getState().nextStep();
    useLessonStore.getState().clearSession();
    useLearnerStore.getState().clearSession();
    persisted.resolve();
    await finish;
    expect(backend.profile).not.toHaveBeenCalled();
    expect(useLessonStore.getState()).toMatchObject({ currentLesson: null, isCompleted: false, isCompletingLesson: false });
    expect(useLearnerStore.getState().profile).toBeNull();
  });

  it('requires completion read-back even when the final step is a quiz', async () => {
    backend.load.mockResolvedValueOnce(lesson('quiz_finish', ['quiz'], false));
    backend.complete.mockResolvedValueOnce(undefined); // Acknowledged write, but no read-back evidence yet.
    await useLessonStore.getState().loadLesson('quiz_finish');
    await useLessonStore.getState().submitAnswer(0);
    expect(useLessonStore.getState().isCompleted).toBe(false);
    expect(useLessonStore.getState().error).toBeTruthy();
  });

  it('blocks incomplete or malformed assessment content before completion', async () => {
    const malformed = lesson('malformed', ['broken']);
    malformed.steps[0].interactiveQuestion = undefined;
    backend.load.mockResolvedValueOnce(malformed);
    await useLessonStore.getState().loadLesson('malformed');
    useLessonStore.getState().goToStep(1);
    await useLessonStore.getState().nextStep();
    expect(backend.complete).not.toHaveBeenCalled();
    expect(useLessonStore.getState()).toMatchObject({ isCompleted: false });
    expect(useLessonStore.getState().error).toBeTruthy();
  });

  it('rejects invalid selected indices without dispatching scoring', async () => {
    await useLessonStore.getState().loadLesson('invalid');
    for (const value of [-1, 2, 0.5, Number.NaN]) {
      expect(await useLessonStore.getState().submitAnswer(value)).toBeNull();
    }
    expect(backend.score).not.toHaveBeenCalled();
  });
});
function lesson(id = 'lesson_session', ids = ['q_session'], trailingContent = true): Lesson {
  return {
    id, courseId: 'course_math_01', skillId: 'skill_math_functions', title: id,
    summary: '', estimatedMinutes: 5, reinforcementExercise: question('q_reinforcement'),
    steps: [
      ...ids.map((q, index) => ({
        id: `step_${q}`, stepNumber: index + 1, type: 'interactive_question' as const,
        title: q, content: '', interactiveQuestion: question(q),
      })),
      ...(trailingContent ? [{ id: 'summary', stepNumber: ids.length + 1, type: 'concept' as const, title: 'Summary', content: 'Done' }] : []),
    ],
  };
}
let completed: Set<string>;
const profile = (): LearnerProfile => ({
  id: 'learner-session', name: 'Ali', selectedCourseId: 'course_math_01', goal: 'mastery',
  dailyMinutes: 15, initialLevel: 'intermediate', xp: 0, streakDays: 0, lastActiveDate: '',
  scoresByCourse: {}, completedLessonIds: [...completed], completedNodeIds: [],
  completedReinforcementIds: [], createdAt: 0,
});
beforeEach(() => {
  vi.resetAllMocks();
  completed = new Set();
  useLessonStore.getState().clearSession();
  useLearnerStore.getState().clearSession();
  backend.load.mockImplementation(async (id: string) => lesson(id));
  backend.score.mockResolvedValue({ isCorrect: true, explanation: '', xpAwarded: 2 });
  backend.complete.mockImplementation(async (id: string) => { completed.add(id); });
  backend.profile.mockImplementation(async () => profile());
  useLearnerStore.setState({ profile: profile() });
});

describe('lesson session and authoritative completion', () => {
  it('ignores out-of-order lesson success and failure after replacement', async () => {
    const old = deferred<Lesson>();
    backend.load.mockReturnValueOnce(old.promise);
    const stale = useLessonStore.getState().loadLesson('old');
    await useLessonStore.getState().loadLesson('current');
    old.reject(new Error('old unavailable'));
    await stale;
    expect(useLessonStore.getState()).toMatchObject({ currentLesson: { id: 'current' }, error: null, isLoading: false });
  });

  it('ignores scoring after navigation and does not complete or refresh another step', async () => {
    const pending = deferred<{ isCorrect: boolean }>();
    backend.score.mockReturnValueOnce(pending.promise);
    await useLessonStore.getState().loadLesson('current');
    const submission = useLessonStore.getState().submitAnswer(0);
    await useLessonStore.getState().nextStep();
    pending.resolve({ isCorrect: true });
    expect(await submission).toBeNull();
    expect(useLessonStore.getState()).toMatchObject({ currentStepIndex: 1, isCompleted: false, lastAnswerResult: null });
    expect(backend.complete).not.toHaveBeenCalled();
    expect(backend.profile).not.toHaveBeenCalled();
  });

  it('does not repopulate learner state after logout during profile read-back', async () => {
    const pending = deferred<LearnerProfile>();
    backend.profile.mockReturnValueOnce(pending.promise);
    await useLessonStore.getState().loadLesson('current');
    const submission = useLessonStore.getState().submitAnswer(0);
    await vi.waitFor(() => expect(backend.profile).toHaveBeenCalledOnce());
    useLessonStore.getState().clearSession();
    useLearnerStore.getState().clearSession();
    pending.resolve(profile());
    expect(await submission).toBeNull();
    expect(useLearnerStore.getState().profile).toBeNull();
    expect(useLessonStore.getState().currentLesson).toBeNull();
  });

  it('requires every distinct question before finishing a trailing content step', async () => {
    backend.load.mockResolvedValueOnce(lesson('all', ['first', 'second']));
    await useLessonStore.getState().loadLesson('all');
    await useLessonStore.getState().submitAnswer(0);
    expect(backend.complete).not.toHaveBeenCalled();
    useLessonStore.getState().goToStep(2);
    await useLessonStore.getState().nextStep();
    expect(useLessonStore.getState().isCompleted).toBe(false);
    expect(backend.complete).not.toHaveBeenCalled();
    useLessonStore.getState().goToStep(1);
    await useLessonStore.getState().submitAnswer(0);
    await useLessonStore.getState().nextStep();
    await useLessonStore.getState().nextStep();
    expect(backend.complete).toHaveBeenCalledExactlyOnceWith('all', 'course_math_01');
    expect(useLessonStore.getState()).toMatchObject({ isCompleted: true, correctAnswerCount: 2, error: null });
    expect(useLearnerStore.getState().profile?.completedLessonIds).toContain('all');
  });
});
