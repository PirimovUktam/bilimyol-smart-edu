import { create } from 'zustand';
import { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { OnboardingGoal, DailyTimeCommitment, InitialLevel } from '@/core/types/common';
import { inMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';

interface LearnerState {
  profile: LearnerProfile | null;
  isLoading: boolean;
  loadProfile: () => Promise<void>;
  setSelectedCourse: (courseId: string) => Promise<void>;
  setOnboardingData: (goal: OnboardingGoal, dailyMinutes: DailyTimeCommitment, initialLevel: InitialLevel) => Promise<void>;
  resetAll: () => Promise<void>;
}

export const useLearnerStore = create<LearnerState>((set) => ({
  profile: null,
  isLoading: false,

  loadProfile: async () => {
    set({ isLoading: true });
    const profile = await inMemoryLearnerRepository.getProfile();
    set({ profile, isLoading: false });
  },

  setSelectedCourse: async (courseId: string) => {
    const updated = await inMemoryLearnerRepository.updateProfile({ selectedCourseId: courseId });
    set({ profile: updated });
  },

  setOnboardingData: async (goal, dailyMinutes, initialLevel) => {
    const updated = await inMemoryLearnerRepository.updateProfile({
      goal,
      dailyMinutes,
      initialLevel,
    });
    set({ profile: updated });
  },

  resetAll: async () => {
    const resetted = await inMemoryLearnerRepository.resetAll();
    set({ profile: resetted });
  },
}));
