import { create } from 'zustand';
import { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { OnboardingGoal, DailyTimeCommitment, InitialLevel } from '@/core/types/common';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';

interface LearnerState {
  profile: LearnerProfile | null;
  isLoading: boolean;
  loadProfile: () => Promise<void>;
  setSelectedCourse: (courseId: string, isCurrent?: () => boolean) => Promise<void>;
  setOnboardingData: (goal: OnboardingGoal, dailyMinutes: DailyTimeCommitment, initialLevel: InitialLevel) => Promise<void>;
  clearSession: () => void;
  resetAll: () => Promise<void>;
}

export const useLearnerStore = create<LearnerState>((set) => {
  // Replacing the identity invalidates every older read or write continuation.
  let currentOperation: object | null = null;
  const applyProfile = async (
    request: () => Promise<LearnerProfile>,
    isLoading = false,
    isCurrent = () => true
  ) => {
    if (!isCurrent()) return;
    const operation = {};
    currentOperation = operation;
    set({ isLoading });
    if (currentOperation !== operation || !isCurrent()) return;
    try {
      const profile = await request();
      if (currentOperation !== operation) return;
      if (!isCurrent()) {
        set({ isLoading: false });
        return;
      }
      set({ profile, isLoading: false });
    } catch (err) {
      if (currentOperation !== operation) return;
      set({ isLoading: false });
      if (!isCurrent()) return;
      throw err;
    }
  };

  return {
    profile: null,
    isLoading: false,

    loadProfile: async () => {
      await applyProfile(() => supabaseLearnerRepository.getProfile(), true);
    },

    setSelectedCourse: async (courseId: string, isCurrent) => {
      // Course selection can be replaced while its profile write is in flight.
      await applyProfile(() => supabaseLearnerRepository.updateProfile({ selectedCourseId: courseId }), false, isCurrent);
    },

    setOnboardingData: async (goal, dailyMinutes, initialLevel) => {
      await applyProfile(() => supabaseLearnerRepository.updateProfile({
        goal,
        dailyMinutes,
        initialLevel,
      }));
    },

    clearSession: () => {
      currentOperation = null;
      set({ profile: null, isLoading: false });
    },

    resetAll: async () => {
      await applyProfile(() => supabaseLearnerRepository.resetAll());
    },
  };
});
