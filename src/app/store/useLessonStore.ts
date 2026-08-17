import { create } from 'zustand';
import { Lesson } from '@/domain/entities/Lesson';
import { inMemoryLessonRepository } from '@/data/repositories/InMemoryLessonRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { GeminiAITutorService } from '@/data/services/GeminiAITutorService';
import { SubmitLessonAnswerUseCase, LessonAnswerResult } from '@/domain/usecases/SubmitLessonAnswerUseCase';

const aiService = new GeminiAITutorService();

interface LessonState {
  currentLesson: Lesson | null;
  currentStepIndex: number;
  isLoading: boolean;
  isEvaluatingAnswer: boolean;
  selectedAnswerIndex: number | null;
  lastAnswerResult: LessonAnswerResult | null;
  showAIPanel: boolean;
  showReinforcementModal: boolean;
  isCompleted: boolean;

  loadLesson: (lessonId: string) => Promise<void>;
  nextStep: () => void;
  prevStep: () => void;
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
  isEvaluatingAnswer: false,
  selectedAnswerIndex: null,
  lastAnswerResult: null,
  showAIPanel: false,
  showReinforcementModal: false,
  isCompleted: false,

  loadLesson: async (lessonId: string) => {
    set({
      isLoading: true,
      currentStepIndex: 0,
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      showReinforcementModal: false,
      isCompleted: false,
    });
    const lesson = await inMemoryLessonRepository.getLessonById(lessonId);
    set({ currentLesson: lesson, isLoading: false });
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

  submitAnswer: async (selectedIndex: number) => {
    const { currentLesson, currentStepIndex, isEvaluatingAnswer } = get();
    if (!currentLesson || isEvaluatingAnswer) return null;

    const currentStep = currentLesson.steps[currentStepIndex];
    if (!currentStep.interactiveQuestion) return null;

    set({ isEvaluatingAnswer: true, selectedAnswerIndex: selectedIndex });

    const useCase = new SubmitLessonAnswerUseCase(aiService, supabaseLearnerRepository);
    const result = await useCase.execute(
      currentStep.interactiveQuestion,
      selectedIndex,
      'Azizbek',
      currentLesson.id
    );

    if (result.isCorrect) {
      await supabaseLearnerRepository.markLessonCompleted(currentLesson.id);
      set({
        lastAnswerResult: result,
        isEvaluatingAnswer: false,
        isCompleted: true,
        showAIPanel: false,
      });
    } else {
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
