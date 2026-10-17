import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useLearnerStore } from '../app/store/useLearnerStore';
import { useCourseStore, ACTIVE_COURSE_STORAGE_KEY } from '../app/store/useCourseStore';
import { useRoadmapStore } from '../app/store/useRoadmapStore';

const backend = vi.hoisted(() => ({
  profile: vi.fn(), update: vi.fn(), reset: vi.fn(), courses: vi.fn(), skills: vi.fn(),
  roadmap: vi.fn(), reinforce: vi.fn(),
}));
vi.mock('../data/repositories/SupabaseLearnerRepository', () => ({
  supabaseLearnerRepository: { getProfile: backend.profile, updateProfile: backend.update, resetAll: backend.reset },
}));
vi.mock('../data/repositories/SupabaseCourseRepository', () => ({
  supabaseCourseRepository: { getAllCourses: backend.courses, getSkillsByCourseId: backend.skills },
}));
vi.mock('../domain/usecases/GetRoadmapUseCase', () => ({
  GetRoadmapUseCase: class { execute = backend.roadmap; },
}));
vi.mock('../domain/usecases/SubmitReinforcementUseCase', () => ({
  SubmitReinforcementUseCase: class { execute = backend.reinforce; },
}));
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => { resolve = done; });
  return { promise, resolve };
}
beforeEach(() => {
  vi.resetAllMocks();
  const storage = new Map<string, string>();
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
    removeItem: (key: string) => storage.delete(key),
  });
  useLearnerStore.getState().clearSession();
  useCourseStore.getState().clearSession();
  useRoadmapStore.getState().clearSession();
});
afterEach(() => vi.unstubAllGlobals());

describe('user-scoped stores discard invalidated work', () => {
  it('cannot restore a profile after clearSession/logout', async () => {
    const pending = deferred<{ id: string }>();
    backend.profile.mockReturnValueOnce(pending.promise);
    const load = useLearnerStore.getState().loadProfile();
    useLearnerStore.getState().clearSession();
    pending.resolve({ id: 'previous-account' });
    await load;
    expect(useLearnerStore.getState()).toMatchObject({ profile: null, isLoading: false });
  });

  it('does not let an old learner load replace a newer profile', async () => {
    const pending = deferred<{ id: string }>();
    backend.profile.mockReturnValueOnce(pending.promise).mockResolvedValueOnce({ id: 'new-account' });
    const old = useLearnerStore.getState().loadProfile();
    await useLearnerStore.getState().loadProfile();
    pending.resolve({ id: 'old-account' });
    await old;
    expect(useLearnerStore.getState().profile?.id).toBe('new-account');
  });

  it('does not publish a profile update already pending when the account is cleared', async () => {
    const pending = deferred<{ id: string }>();
    backend.update.mockReturnValueOnce(pending.promise);
    const update = useLearnerStore.getState().setSelectedCourse('course-a');
    useLearnerStore.getState().clearSession();
    pending.resolve({ id: 'previous-account' });
    await update;
    expect(useLearnerStore.getState().profile).toBeNull();
  });

  it('clears the loading flag and propagates a current profile-load failure', async () => {
    backend.profile.mockRejectedValueOnce(new Error('profile offline'));
    await expect(useLearnerStore.getState().loadProfile()).rejects.toThrow('profile offline');
    expect(useLearnerStore.getState().isLoading).toBe(false);
  });

  it('does not restore course/cache or start profile persistence after logout during skills load', async () => {
    const pending = deferred<[]>();
    useCourseStore.setState({ courses: [{
      id: 'course-a', title: 'Math', subject: 'mathematics', description: '', iconName: '',
      primaryColor: '', secondaryColor: '', skills: [], lessons: [],
    }] });
    backend.skills.mockReturnValueOnce(pending.promise);
    const selection = useCourseStore.getState().selectCourseById('course-a');
    useCourseStore.getState().clearSession();
    useLearnerStore.getState().clearSession();
    pending.resolve([]);
    await selection;
    expect(useCourseStore.getState().activeCourse).toBeNull();
    expect(localStorage.getItem(ACTIVE_COURSE_STORAGE_KEY)).toBeNull();
    expect(backend.update).not.toHaveBeenCalled();
  });

  it('ignores a roadmap response after logout', async () => {
    const pending = deferred<{ courseId: string; nodes: [] }>();
    backend.roadmap.mockReturnValueOnce(pending.promise);
    const load = useRoadmapStore.getState().loadRoadmap('course-a');
    useRoadmapStore.getState().clearSession();
    pending.resolve({ courseId: 'course-a', nodes: [] });
    await load;
    expect(useRoadmapStore.getState()).toMatchObject({ roadmap: null, selectedNode: null, isLoading: false });
  });

  it('does not replace the latest course roadmap with an out-of-order response', async () => {
    const pending = deferred<{ courseId: string; nodes: [] }>();
    backend.roadmap.mockReturnValueOnce(pending.promise).mockResolvedValueOnce({ courseId: 'new', nodes: [] });
    const old = useRoadmapStore.getState().loadRoadmap('old');
    await useRoadmapStore.getState().loadRoadmap('new');
    pending.resolve({ courseId: 'old', nodes: [] });
    await old;
    expect(useRoadmapStore.getState().roadmap?.courseId).toBe('new');
  });

  it('cancels stale reinforcement without returning success to its caller', async () => {
    const pending = deferred<{ isCorrect: boolean; updatedRoadmap: { courseId: string; nodes: [] } }>();
    backend.reinforce.mockReturnValueOnce(pending.promise);
    const question = { id: 'q', courseId: 'course-a', skillId: 'skill-a', text: 'Q?', options: ['A', 'B'], difficulty: 'easy' as const, explanation: '' };
    const result = useRoadmapStore.getState().completeReinforcement('course-a', 'skill-a', 'node', question, 0);
    const cancelled = expect(result).rejects.toMatchObject({ name: 'AbortError' });
    await expect(useRoadmapStore.getState().completeReinforcement('course-a', 'skill-a', 'node', question, 0))
      .rejects.toMatchObject({ name: 'AbortError' });
    expect(backend.reinforce).toHaveBeenCalledOnce();
    useRoadmapStore.getState().clearSession();
    pending.resolve({ isCorrect: true, updatedRoadmap: { courseId: 'course-a', nodes: [] } });
    await cancelled;
    expect(useRoadmapStore.getState()).toMatchObject({ roadmap: null, isUpdating: false, error: null });
  });
});
