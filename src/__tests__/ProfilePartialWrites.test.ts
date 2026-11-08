import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SupabaseLearnerRepository } from '../data/repositories/SupabaseLearnerRepository';
import { LearnerProfile } from '../domain/entities/LearnerProfile';
const backend = vi.hoisted(() => ({ from: vi.fn(), upsert: vi.fn(), getUser: vi.fn() }));
vi.mock('../core/config/supabase', () => ({ isSupabaseConfigured: true,
  supabase: { from: backend.from, auth: { getUser: backend.getUser } } }));
vi.mock('../core/runtime/demoRuntime', () => ({ isDemoRuntimeActive: () => false }));
const profile = { id: 'learner', name: 'Ali', selectedCourseId: 'math', goal: 'mastery',
  dailyMinutes: 15, initialLevel: 'intermediate', xp: 0, streakDays: 0,
  lastActiveDate: '', scoresByCourse: {}, completedLessonIds: [], completedNodeIds: [],
  completedReinforcementIds: [], createdAt: 0 } as LearnerProfile;
beforeEach(() => {
  vi.resetAllMocks();
  backend.getUser.mockResolvedValue({ data: { user: { id: 'learner' } }, error: null });
  backend.upsert.mockResolvedValue({ error: null });
  backend.from.mockReturnValue({ upsert: backend.upsert });
  vi.spyOn(console, 'warn').mockImplementation(() => {});
});
afterEach(() => vi.restoreAllMocks());
describe('configured profile partial writes', () => {
  it('does not overwrite a concurrently selected course when changing daily goal', async () => {
    const repo = new SupabaseLearnerRepository();
    vi.spyOn(repo, 'getProfile').mockResolvedValueOnce(profile)
      .mockResolvedValue({ ...profile, selectedCourseId: 'english', dailyMinutes: 30 });
    const saved = await repo.updateProfile({ dailyMinutes: 30 });
    expect(backend.upsert).toHaveBeenCalledWith({ user_id: 'learner', daily_minutes: 30,
      updated_at: expect.any(String) });
    expect(saved.selectedCourseId).toBe('english');
  });
  it('does not send old onboarding settings when selecting a course', async () => {
    const repo = new SupabaseLearnerRepository();
    vi.spyOn(repo, 'getProfile').mockResolvedValue(profile);
    await repo.updateProfile({ selectedCourseId: 'english' });
    expect(backend.upsert).toHaveBeenCalledWith({ user_id: 'learner', selected_course_id: 'english',
      updated_at: expect.any(String) });
  });
  it('does not write learner preferences for a name-only change', async () => {
    const repo = new SupabaseLearnerRepository();
    vi.spyOn(repo, 'getProfile').mockResolvedValue(profile);
    const eq = vi.fn().mockResolvedValue({ error: null });
    backend.from.mockReturnValue({ update: vi.fn().mockReturnValue({ eq }), upsert: backend.upsert });
    await repo.updateProfile({ firstName: 'Vali' });
    expect(backend.from).toHaveBeenCalledExactlyOnceWith('profiles');
    expect(backend.upsert).not.toHaveBeenCalled();
  });
  it('reports read-back failure instead of returning an unverified merged profile', async () => {
    const repo = new SupabaseLearnerRepository();
    vi.spyOn(repo, 'getProfile').mockResolvedValueOnce(profile)
      .mockRejectedValueOnce(new Error('read-back failed'));
    await expect(repo.updateProfile({ dailyMinutes: 30 })).rejects.toThrow('read-back failed');
  });
  it('propagates write errors instead of reporting local success', async () => {
    const repo = new SupabaseLearnerRepository();
    vi.spyOn(repo, 'getProfile').mockResolvedValue(profile);
    backend.upsert.mockResolvedValue({ error: new Error('write failed') });
    await expect(repo.updateProfile({ selectedCourseId: 'english' })).rejects.toThrow('write failed');
  });
});
