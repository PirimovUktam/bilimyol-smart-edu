import { create } from 'zustand';
import { Lesson } from '@/domain/entities/Lesson';
import { supabaseLessonRepository } from '@/data/repositories/SupabaseLessonRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { GeminiAITutorService } from '@/data/services/GeminiAITutorService';
import { SubmitLessonAnswerUseCase, LessonAnswerResult } from '@/domain/usecases/SubmitLessonAnswerUseCase';

import { useLearnerStore } from '@/app/store/useLearnerStore';

const aiService = new GeminiAITutorService();

interface LessonState {
  currentLesson: Lesson | null;
  currentStepIndex: number;
  isLoading: boolean;
  error: string | null;
  isEvaluatingAnswer: boolean;
  selectedAnswerIndex: number | null;
  lastAnswerResult: LessonAnswerResult | null;
  showAIPanel: boolean;
  showReinforcementModal: boolean;
  isCompleted: boolean;

  loadLesson: (lessonId: string) => Promise<void>;
  generateAILesson: (
    courseId: string,
    skillId: string,
    topic: string,
    difficulty?: 'easy' | 'medium' | 'hard' | number
  ) => Promise<Lesson | null>;
  clearError: () => void;
  nextStep: () => void;
  prevStep: () => void;
  goToStep: (index: number) => void;
  submitAnswer: (selectedIndex: number) => Promise<LessonAnswerResult | null>;
  openReinforcement: () => void;
  closeReinforcement: () => void;
  closeAIPanel: () => void;
  resetLessonState: () => void;
}

export const useLessonStore = create<LessonState>((set, get) => ({
  currentLesson: null,
  currentStepIndex: 0,
  isLoading: false,
  error: null,
  isEvaluatingAnswer: false,
  selectedAnswerIndex: null,
  lastAnswerResult: null,
  showAIPanel: false,
  showReinforcementModal: false,
  isCompleted: false,

  clearError: () => set({ error: null }),

  loadLesson: async (lessonId: string) => {
    // If the requested lesson is already loaded and active, don't overwrite it
    if (get().currentLesson && get().currentLesson?.id === lessonId) {
      set({ isLoading: false, error: null });
      return;
    }

    set({
      isLoading: true,
      error: null,
      currentLesson: null,
      currentStepIndex: 0,
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      showReinforcementModal: false,
      isCompleted: false,
    });

    try {
      const lesson = await supabaseLessonRepository.getLessonById(lessonId);
      if (!lesson) {
        set({
          currentLesson: null,
          isLoading: false,
          error: `Dars topilmadi ("${lessonId}"). Iltimos, boshqa darsni tanlang yoki yangi dars yarating.`,
        });
        return;
      }
      set({ currentLesson: lesson, isLoading: false, error: null });
    } catch (err: any) {
      set({
        currentLesson: null,
        isLoading: false,
        error: `Darsni yuklashda xatolik yuz berdi: ${err?.message || 'Server javob bermadi'}. Qayta urinib ko‘ring.`,
      });
    }
  },

  generateAILesson: async (
    courseId: string,
    skillId: string,
    topic: string,
    difficulty?: 'easy' | 'medium' | 'hard' | number
  ): Promise<Lesson | null> => {
    set({
      isLoading: true,
      error: null,
      currentStepIndex: 0,
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      showReinforcementModal: false,
      isCompleted: false,
    });

    try {
      const response = await aiService.generateLesson({
        courseId,
        skillId,
        topic,
        difficulty,
      });

      if (!response || !response.title || !Array.isArray(response.steps) || response.steps.length === 0) {
        throw new Error('AI xizmatidan yaroqli dars ma’lumotlari kelmadi.');
      }

      const firstQ = response.questions && response.questions.length > 0 ? response.questions[0] : null;
      const mappedInteractiveQuestion = firstQ
        ? {
            id: firstQ.id,
            courseId: response.courseId,
            skillId: response.skillId,
            text: firstQ.text,
            formulaLatex: firstQ.formulaLatex || undefined,
            options: firstQ.options,
            difficulty: (typeof firstQ.difficulty === 'string' ? firstQ.difficulty : 'medium') as 'easy' | 'medium' | 'hard',
            explanation: '',
            isPlacement: false,
          }
        : {
            id: `q_${response.skillId}_ai`,
            courseId: response.courseId,
            skillId: response.skillId,
            text: 'Mavzuni to‘liq o‘zlashtirdingizmi?',
            options: ['Ha, tushundim', 'Qisman', 'Mashq qilish kerak', 'Qaytadan'],
            difficulty: 'medium' as const,
            explanation: 'Dars muvaffaqiyatli yakunlandi.',
            isPlacement: false,
          };

      const lessonSteps = response.steps.map((s, idx) => {
        if (s.type === 'interactive_question' || idx === response.steps.length - 1) {
          return {
            ...s,
            interactiveQuestion: s.interactiveQuestion || mappedInteractiveQuestion,
          };
        }
        return s;
      });

      const lessonEntity: Lesson = {
        id: response.lessonId,
        courseId: response.courseId,
        skillId: response.skillId,
        title: response.title,
        estimatedMinutes: response.estimatedMinutes || 15,
        summary: response.summary,
        steps: lessonSteps,
        reinforcementExercise: mappedInteractiveQuestion,
        isAiGenerated: response.isAiGenerated === true,
        isDeterministicFallback: response.isDeterministicFallback === true,
      };

      // Persist to repository cache so getLessonById can retrieve it
      await supabaseLessonRepository.saveLesson(lessonEntity);

      set({ currentLesson: lessonEntity, isLoading: false, error: null });
      return lessonEntity;
    } catch (err: any) {
      console.warn('[useLessonStore] generateAILesson error:', err);
      const errorMessage = err?.message || 'Server javob bermadi yoki cheklovdan oshildi';
      set({
        isLoading: false,
        error: `AI dars yaratishda xatolik yuz berdi: ${errorMessage}. Iltimos, qayta urinib ko‘ring.`,
      });
      return null;
    }
  },

  nextStep: () => {
    const { currentLesson, currentStepIndex } = get();
    if (!currentLesson) return;
    if (currentStepIndex < currentLesson.steps.length - 1) {
      set({ currentStepIndex: currentStepIndex + 1 });
    }
  },

  prevStep: () => {
    const { currentStepIndex } = get();
    if (currentStepIndex > 0) {
      set({ currentStepIndex: currentStepIndex - 1 });
    }
  },

  goToStep: (index: number) => {
    const { currentLesson } = get();
    if (!currentLesson) return;
    if (index >= 0 && index < currentLesson.steps.length) {
      set({ currentStepIndex: index });
    }
  },

  submitAnswer: async (selectedIndex: number) => {
    const { currentLesson, currentStepIndex, isEvaluatingAnswer } = get();
    if (!currentLesson || isEvaluatingAnswer) return null;

    const currentStep = currentLesson.steps[currentStepIndex];
    if (!currentStep.interactiveQuestion) return null;

    set({ isEvaluatingAnswer: true, selectedAnswerIndex: selectedIndex });

    const useCase = new SubmitLessonAnswerUseCase(aiService, supabaseLearnerRepository);
    const learnerName = useLearnerStore.getState().profile?.name || 'O‘quvchi';
    const result = await useCase.execute(
      currentStep.interactiveQuestion,
      selectedIndex,
      learnerName,
      currentLesson.id
    );

    if (result.isCorrect) {
      await supabaseLearnerRepository.markLessonCompleted(currentLesson.id, currentLesson.courseId);
      await useLearnerStore.getState().loadProfile();
      set({
        lastAnswerResult: result,
        isEvaluatingAnswer: false,
        isCompleted: true,
        showAIPanel: false,
      });
    } else {
      await useLearnerStore.getState().loadProfile();
      // Wrong answer -> Show Yo'lchi AI Feedback panel
      set({
        lastAnswerResult: result,
        isEvaluatingAnswer: false,
        showAIPanel: true,
      });
    }

    return result;
  },

  openReinforcement: () => {
    set({ showAIPanel: false, showReinforcementModal: true });
  },

  closeReinforcement: () => {
    set({ showReinforcementModal: false });
  },

  closeAIPanel: () => {
    set({ showAIPanel: false });
  },

  resetLessonState: () => {
    set({
      currentStepIndex: 0,
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      showReinforcementModal: false,
      isCompleted: false,
    });
  },
}));
