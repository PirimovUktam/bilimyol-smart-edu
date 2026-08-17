import { create } from 'zustand';
import { Lesson } from '@/domain/entities/Lesson';
import { inMemoryLessonRepository } from '@/data/repositories/InMemoryLessonRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { GeminiAITutorService } from '@/data/services/GeminiAITutorService';
import { SubmitLessonAnswerUseCase, LessonAnswerResult } from '@/domain/usecases/SubmitLessonAnswerUseCase';

import { useLearnerStore } from '@/app/store/useLearnerStore';

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
  generateAILesson: (
    courseId: string,
    skillId: string,
    topic: string,
    difficulty?: 'easy' | 'medium' | 'hard' | number
  ) => Promise<void>;
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

  generateAILesson: async (
    courseId: string,
    skillId: string,
    topic: string,
    difficulty?: 'easy' | 'medium' | 'hard' | number
  ) => {
    set({
      isLoading: true,
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

      const firstQ = response.questions && response.questions.length > 0 ? response.questions[0] : null;
      const mappedInteractiveQuestion = firstQ
        ? {
            id: firstQ.id,
            courseId: response.courseId,
            skillId: response.skillId,
            text: firstQ.text,
            formulaLatex: firstQ.formulaLatex || undefined,
            options: firstQ.options,
            correctIndex: 0, // Server validates answer attempts for anti-cheat
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
            correctIndex: 0,
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
      };

      set({ currentLesson: lessonEntity, isLoading: false });
    } catch (err) {
      console.warn('[useLessonStore] generateAILesson error, falling back:', err);
      const fallbackLesson = await inMemoryLessonRepository.getLessonById('lesson_math_functions_01');
      set({ currentLesson: fallbackLesson, isLoading: false });
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
