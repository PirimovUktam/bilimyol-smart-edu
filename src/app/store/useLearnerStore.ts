import { create } from 'zustand';
import { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { OnboardingGoal, DailyTimeCommitment, InitialLevel } from '@/core/types/common';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';

interface LearnerState {
  profile: LearnerProfile | null;
  isLoading: boolean;
  loadProfile: () => Promise<void>;
  setSelectedCourse: (courseId: string, isCurrent?: () => boolean) => Promise<void>;
  saveStudyPreferences: (goal: OnboardingGoal, dailyMinutes: DailyTimeCommitment) => Promise<void>;
  saveCourseLearningPlan: (courseId: string, goal: OnboardingGoal, dailyMinutes: DailyTimeCommitment,
    initialLevel: InitialLevel, isCurrent: () => boolean) => Promise<void>;
  recordFlashcardSrs: (
    courseId: string,
    cardId: string,
    rating: 'need_practice' | 'remembered',
    intervalsDays?: readonly number[],
  ) => Promise<void>;
  clearSession: () => void;
  resetAll: () => Promise<void>;
}

export const useLearnerStore = create<LearnerState>((set) => {
  // Replacing the identity invalidates every older read or write continuation.
  let currentOperation: object | null = null;
  let sessionEpoch = 0;
  let srsWriteChain: Promise<void> = Promise.resolve();
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

    saveStudyPreferences: async (goal, dailyMinutes) => {
      await applyProfile(() => supabaseLearnerRepository.updateProfile({
        goal,
        dailyMinutes,
      }));
    },

    saveCourseLearningPlan: async (courseId, goal, dailyMinutes, initialLevel, isCurrent) => {
      await applyProfile(() => supabaseLearnerRepository.saveCourseLearningPlan(courseId, goal, dailyMinutes, initialLevel), false, isCurrent);
    },

    recordFlashcardSrs: async (courseId, cardId, rating, intervalsDays) => {
      if (typeof supabaseLearnerRepository.recordFlashcardSrs !== 'function') return;
      const expectedEpoch = sessionEpoch;
      const runSrs = async () => {
        if (sessionEpoch !== expectedEpoch) return;
        const updatedProfile = await supabaseLearnerRepository.recordFlashcardSrs!(
          courseId,
          cardId,
          rating,
          intervalsDays,
        );
        if (sessionEpoch !== expectedEpoch) return;
        set((state) => {
          if (!state.profile || state.profile.id !== updatedProfile.id) {
            return { profile: updatedProfile };
          }
          const mergedSrsByCourse = {
            ...(state.profile.flashcardSrsByCourse ?? {}),
            ...(updatedProfile.flashcardSrsByCourse ?? {}),
          };
          for (const [cid, deck] of Object.entries(updatedProfile.flashcardSrsByCourse ?? {})) {
            mergedSrsByCourse[cid] = {
              ...(state.profile.flashcardSrsByCourse?.[cid] ?? {}),
              ...deck,
            };
          }
          return {
            profile: {
              ...state.profile,
              flashcardSrsByCourse: mergedSrsByCourse,
            },
          };
        });
      };
      const next = srsWriteChain.then(runSrs, runSrs);
      srsWriteChain = next.catch(() => {});
      await next;
    },

    clearSession: () => {
      currentOperation = null;
      sessionEpoch += 1;
      set({ profile: null, isLoading: false });
    },

    resetAll: async () => {
      await applyProfile(() => supabaseLearnerRepository.resetAll());
    },
  };
});
