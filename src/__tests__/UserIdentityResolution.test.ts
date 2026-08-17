import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';

describe('UserIdentityResolution Tests', () => {
  let learnerRepo: InMemoryLearnerRepository;

  beforeEach(async () => {
    learnerRepo = new InMemoryLearnerRepository();
    await learnerRepo.resetAll();
  });

  it('should initialize with neutral default name O‘quvchi and not any hardcoded personal name', async () => {
    const profile = await learnerRepo.getProfile();
    expect(profile.name).toBe('O‘quvchi');
    expect(profile.name).not.toBe('Azizbek');
  });

  it('should update learner profile name dynamically when user registers with name "Aaaaa"', async () => {
    const updated = await learnerRepo.updateProfile({
      name: 'Aaaaa',
    });

    expect(updated.name).toBe('Aaaaa');

    const fresh = await learnerRepo.getProfile();
    expect(fresh.name).toBe('Aaaaa');
  });

  it('should preserve distinct identity for another user "Test User" upon profile update', async () => {
    const userProfile = await learnerRepo.updateProfile({
      name: 'Test User',
    });

    expect(userProfile.name).toBe('Test User');
  });

  it('should isolate user session data on resetAll', async () => {
    await learnerRepo.updateProfile({
      name: 'UserA',
      xp: 150,
      scoresByCourse: {
        course_math_01: {
          skill_math_algebra: {
            skillId: 'skill_math_algebra',
            courseId: 'course_math_01',
            score: 80,
            lastUpdated: Date.now(),
            masteryLevel: 'mastered',
          },
        },
      },
    });

    let current = await learnerRepo.getProfile();
    expect(current.name).toBe('UserA');
    expect(current.xp).toBe(150);

    // Simulate logout / reset for new user
    await learnerRepo.resetAll();
    const cleanProfile = await learnerRepo.getProfile();
    expect(cleanProfile.name).toBe('O‘quvchi');
    expect(cleanProfile.xp).toBe(0);
    expect(Object.keys(cleanProfile.scoresByCourse).length).toBe(0);
  });
});
