import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';

describe('UserIdentityResolution & Profile Persistence Suite', () => {
  let learnerRepo: InMemoryLearnerRepository;

  beforeEach(async () => {
    learnerRepo = new InMemoryLearnerRepository();
    await learnerRepo.resetAll();
  });

  it('A. registration creates and initializes profile with neutral default name Foydalanuvchi', async () => {
    const profile = await learnerRepo.getProfile();
    expect(profile.name).toBe('Foydalanuvchi');
    expect(profile.name).not.toBe('Azizbek');
  });

  it('B. user registration with name "Aaaaa" accurately updates and persists profile', async () => {
    const updated = await learnerRepo.updateProfile({
      name: 'Aaaaa',
      firstName: 'Aaaaa',
    });

    expect(updated.name).toBe('Aaaaa');
    expect(updated.firstName).toBe('Aaaaa');

    const fresh = await learnerRepo.getCurrentProfile();
    expect(fresh.name).toBe('Aaaaa');
    expect(fresh.firstName).toBe('Aaaaa');
  });

  it('C. profile data persists across consecutive reloads and reads', async () => {
    await learnerRepo.updateProfile({
      name: 'Test',
      firstName: 'Test',
      lastName: 'User',
    });

    const read1 = await learnerRepo.getProfile();
    const read2 = await learnerRepo.getCurrentProfile();

    expect(read1.firstName).toBe('Test');
    expect(read1.lastName).toBe('User');
    expect(read2.firstName).toBe('Test');
    expect(read2.lastName).toBe('User');
  });

  it('D. profile update persists non-destructive updates for course, goal, and names', async () => {
    await learnerRepo.updateProfile({
      name: 'Sherzod',
      firstName: 'Sherzod',
      goal: 'exam_prep',
      dailyMinutes: 30,
    });

    const current = await learnerRepo.getCurrentProfile();
    expect(current.firstName).toBe('Sherzod');
    expect(current.goal).toBe('exam_prep');
    expect(current.dailyMinutes).toBe(30);
  });

  it('E & F. logout / login isolates user state preventing cross-user data leakage', async () => {
    // User A session
    await learnerRepo.updateProfile({
      name: 'UserA',
      firstName: 'UserA',
      xp: 250,
      scoresByCourse: {
        course_math_01: {
          skill_math_algebra: {
            skillId: 'skill_math_algebra',
            courseId: 'course_math_01',
            score: 85,
            lastUpdated: Date.now(),
            masteryLevel: 'mastered',
          },
        },
      },
    });

    const userA = await learnerRepo.getProfile();
    expect(userA.name).toBe('UserA');
    expect(userA.xp).toBe(250);

    // Logout & isolate
    await learnerRepo.resetAll();

    // User B session
    const freshForUserB = await learnerRepo.getProfile();
    expect(freshForUserB.name).toBe('Foydalanuvchi');
    expect(freshForUserB.xp).toBe(0);
    expect(Object.keys(freshForUserB.scoresByCourse).length).toBe(0);

    await learnerRepo.updateProfile({
      name: 'UserB',
      firstName: 'UserB',
      xp: 50,
    });

    const userB = await learnerRepo.getProfile();
    expect(userB.name).toBe('UserB');
    expect(userB.xp).toBe(50);
  });

  it('G. existing auth user without custom name defaults safely to Foydalanuvchi', async () => {
    const uncustomized = await learnerRepo.getProfile();
    expect(uncustomized.name).toBe('Foydalanuvchi');
  });

  it('H. verified zero presence of legacy hardcoded name Azizbek in repository defaults', async () => {
    const profile = await learnerRepo.getProfile();
    expect(profile.name).not.toMatch(/Azizbek/i);
    expect(profile.firstName).not.toMatch(/Azizbek/i);
  });
});
