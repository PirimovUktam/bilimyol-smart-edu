import { create } from 'zustand';
import { Lesson } from '@/domain/entities/Lesson';
import { Question } from '@/domain/entities/Question';
import { supabaseLessonRepository } from '@/data/repositories/SupabaseLessonRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { GeminiAITutorService } from '@/data/services/GeminiAITutorService';
import { SubmitLessonAnswerUseCase, LessonAnswerResult } from '@/domain/usecases/SubmitLessonAnswerUseCase';

import { useLearnerStore } from '@/app/store/useLearnerStore';

const aiService = new GeminiAITutorService();

// Identity tokens stay bounded and invalidate work even when the same lesson or
// step is reopened before an earlier request settles.
let sessionToken = {};
let evaluationToken = {};
// Keep one persistence receipt for the active lesson session. Navigation can
// discard UI work, but must not start a second RPC or repeat a confirmed write
// when only the profile read-back needs retrying.
let completionRequest: { session: object; lesson: Lesson; promise: Promise<void> } | null = null;

const persistCompletion = (lesson: Lesson, session: object): Promise<void> => {
  if (completionRequest?.session === session && completionRequest.lesson === lesson) {
    return completionRequest.promise;
  }
  const request = {
    session,
    lesson,
    promise: supabaseLearnerRepository.markLessonCompleted(lesson.id, lesson.courseId).catch((error) => {
      if (completionRequest === request) completionRequest = null;
      throw error;
    }),
  };
  completionRequest = request;
  return request.promise;
};

const hasText = (value: unknown): value is string => typeof value === 'string' && value.trim().length > 0;

const isValidAssessment = (question: unknown, courseId: string, skillId: string): question is Question => {
  if (!question || typeof question !== 'object') return false;
  const candidate = question as Question;
  return hasText(candidate.id) && candidate.courseId === courseId && candidate.skillId === skillId &&
    hasText(candidate.text) && Array.isArray(candidate.options) && candidate.options.length >= 2 &&
    candidate.options.every(hasText);
};

const hasPassedRequiredQuestions = (lesson: Lesson, answeredQuestionIds: string[]): boolean => {
  if (!Array.isArray(lesson.steps) || lesson.steps.length === 0 || lesson.steps.some((step) =>
    !step || ((step.type === 'interactive_question' || step.interactiveQuestion != null) &&
      !isValidAssessment(step.interactiveQuestion, lesson.courseId, lesson.skillId)))) return false;
  const requiredIds = new Set(lesson.steps.flatMap((step) => step.interactiveQuestion ? [step.interactiveQuestion.id] : []));
  // complete_lesson currently rejects an empty required-assessment set too.
  return requiredIds.size > 0 && [...requiredIds].every((id) => hasText(id) && answeredQuestionIds.includes(id));
};

export const shouldCompleteLesson = (currentStepIndex: number, totalSteps: number): boolean =>
  totalSteps > 0 && currentStepIndex >= totalSteps - 1;

interface LessonState {
  currentLesson: Lesson | null;
  currentStepIndex: number;
  isLoading: boolean;
  error: string | null;
  isEvaluatingAnswer: boolean;
  isCompletingLesson: boolean;
  selectedAnswerIndex: number | null;
  lastAnswerResult: LessonAnswerResult | null;
  showAIPanel: boolean;
  showReinforcementModal: boolean;
  isCompleted: boolean;
  answeredQuestionIds: string[];
  correctAnswerCount: number;

  loadLesson: (lessonId: string) => Promise<void>;
  generateAILesson: (
    courseId: string,
    skillId: string,
    topic: string,
    difficulty?: 'easy' | 'medium' | 'hard' | number
  ) => Promise<Lesson | null>;
  clearError: () => void;
  nextStep: () => Promise<void>;
  prevStep: () => void;
  goToStep: (index: number) => void;
  submitAnswer: (selectedIndex: number) => Promise<LessonAnswerResult | null>;
  clearAnswerResult: () => void;
  openAIPanel: () => void;
  openReinforcement: () => void;
  closeReinforcement: () => void;
  closeAIPanel: () => void;
  resetLessonState: () => void;
  clearSession: () => void;
}

export const useLessonStore = create<LessonState>((set, get) => ({
  currentLesson: null,
  currentStepIndex: 0,
  isLoading: false,
  error: null,
  isEvaluatingAnswer: false,
  isCompletingLesson: false,
  selectedAnswerIndex: null,
  lastAnswerResult: null,
  showAIPanel: false,
  showReinforcementModal: false,
  isCompleted: false,
  answeredQuestionIds: [],
  correctAnswerCount: 0,

  clearError: () => set({ error: null }),

  loadLesson: async (lessonId: string) => {
    // If the requested lesson is already loaded and active, don't overwrite it
    if (get().currentLesson && get().currentLesson?.id === lessonId) {
      set({ isLoading: false, error: null });
      return;
    }

    const requestToken = sessionToken = {};
    evaluationToken = {};
    completionRequest = null;
    const isCurrent = () => sessionToken === requestToken;
    set({
      isLoading: true,
      error: null,
      currentLesson: null,
      currentStepIndex: 0,
      isEvaluatingAnswer: false,
      isCompletingLesson: false,
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      showReinforcementModal: false,
      isCompleted: false,
      answeredQuestionIds: [],
      correctAnswerCount: 0,
    });

    try {
      if (!hasText(lessonId)) throw new Error('Dars identifikatori noto‘g‘ri.');
      if (!isCurrent()) return;
      const lesson = await supabaseLessonRepository.getLessonById(lessonId);
      if (!isCurrent()) return;
      if (!lesson) {
        set({
          currentLesson: null,
          isLoading: false,
          error: `Dars topilmadi ("${lessonId}"). Iltimos, boshqa darsni tanlang yoki yangi dars yarating.`,
        });
        return;
      }
      if (lesson.id !== lessonId) throw new Error('So‘ralgan dars o‘rniga boshqa dars qaytdi.');
      set({ currentLesson: lesson, isLoading: false, error: null });
    } catch (err: any) {
      if (!isCurrent()) return;
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
    const requestToken = sessionToken = {};
    evaluationToken = {};
    completionRequest = null;
    const isCurrent = () => sessionToken === requestToken;
    set({
      isLoading: true,
      error: null,
      currentLesson: null,
      currentStepIndex: 0,
      isEvaluatingAnswer: false,
      isCompletingLesson: false,
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      showReinforcementModal: false,
      isCompleted: false,
      answeredQuestionIds: [],
      correctAnswerCount: 0,
    });

    try {
      if (!hasText(courseId) || !hasText(skillId)) {
        throw new Error('Dars uchun fan va ko‘nikma tanlanishi kerak.');
      }
      if (!isCurrent()) return null;
      const response = await aiService.generateLesson({ courseId, skillId, topic, difficulty });
      if (!isCurrent()) return null;

      if (!response || !hasText(response.lessonId) || !hasText(response.title) ||
          !Array.isArray(response.steps) || response.steps.length === 0) {
        throw new Error('AI xizmatidan yaroqli dars ma’lumotlari kelmadi.');
      }
      if (response.courseId !== courseId || response.skillId !== skillId) {
        throw new Error('Yaratilgan dars tanlangan fan yoki ko‘nikmaga mos kelmadi.');
      }
      // Only assessment ids returned by the service can be submitted for scoring.
      if (!Array.isArray(response.questions) || response.questions.length === 0 ||
          response.questions.some((question) => !isValidAssessment(question, courseId, skillId)) ||
          new Set(response.questions.map((question) => question.id)).size !== response.questions.length) {
        throw new Error('Darsning serverda baholanadigan savoli topilmadi.');
      }
      const questions = response.questions.map((question): Question => ({
        id: question.id,
        courseId,
        skillId,
        text: question.text,
        formulaLatex: question.formulaLatex || undefined,
        options: question.options,
        difficulty: ['easy', 'medium', 'hard'].includes(question.difficulty) ? question.difficulty : 'medium',
        explanation: '',
      }));
      const mappedInteractiveQuestion = questions[0];

      const lessonSteps = response.steps.map((s, idx) => {
        if (s.interactiveQuestion || s.type === 'interactive_question' || idx === response.steps.length - 1) {
          const inlineQuestion = s.interactiveQuestion;
          const question = inlineQuestion ? questions.find((candidate) => candidate.id === inlineQuestion.id) : mappedInteractiveQuestion;
          if (!question || (inlineQuestion && (
            (inlineQuestion.courseId !== undefined && inlineQuestion.courseId !== courseId) ||
            (inlineQuestion.skillId !== undefined && inlineQuestion.skillId !== skillId)
          ))) {
            throw new Error('Dars savoli tanlangan fan yoki server baholashiga mos kelmadi.');
          }
          return { ...s, interactiveQuestion: question };
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
      if (!isCurrent()) return null;
      await supabaseLessonRepository.saveLesson(lessonEntity);
      if (!isCurrent()) return null;

      set({ currentLesson: lessonEntity, isLoading: false, error: null });
      return isCurrent() ? lessonEntity : null;
    } catch (err: any) {
      if (!isCurrent()) return null;
      console.warn('[useLessonStore] generateAILesson error:', err);
      const errorMessage = err?.message || 'Server javob bermadi yoki cheklovdan oshildi';
      set({
        isLoading: false,
        error: `AI dars yaratishda xatolik yuz berdi: ${errorMessage}. Iltimos, qayta urinib ko‘ring.`,
      });
      return null;
    }
  },

  nextStep: async () => {
    const { currentLesson, currentStepIndex, isLoading, isCompletingLesson, isCompleted } = get();
    if (!currentLesson || isLoading || isCompletingLesson || isCompleted) return;
    if (!Number.isInteger(currentStepIndex) || currentStepIndex < 0 || !currentLesson.steps[currentStepIndex]) return;
    if (currentStepIndex < currentLesson.steps.length - 1) {
      evaluationToken = {};
      set({
        currentStepIndex: currentStepIndex + 1,
        isEvaluatingAnswer: false,
        selectedAnswerIndex: null,
        lastAnswerResult: null,
        showAIPanel: false,
        error: null,
      });
      return;
    }
    if (get().isEvaluatingAnswer) return;
    if (!hasPassedRequiredQuestions(currentLesson, get().answeredQuestionIds)) {
      set({ error: 'Darsni yakunlash uchun barcha yaroqli sinov savollariga to‘g‘ri javob bering. Savol yetishmasa, darsni qayta oching.' });
      return;
    }
    // Final quizzes keep their existing submitAnswer completion flow.
    if (currentLesson.steps[currentStepIndex].interactiveQuestion) return;

    const requestSession = sessionToken;
    const requestEvaluation = evaluationToken = {};
    const learnerId = useLearnerStore.getState().profile?.id;
    const isCurrent = () => sessionToken === requestSession && evaluationToken === requestEvaluation &&
      get().currentLesson === currentLesson && get().currentStepIndex === currentStepIndex;
    set({ isCompletingLesson: true, error: null });
    try {
      if (!isCurrent()) return;
      await persistCompletion(currentLesson, requestSession);
      if (!isCurrent()) return;
      const profile = await supabaseLearnerRepository.getProfile();
      if (!isCurrent()) return;
      if ((learnerId && profile.id !== learnerId) || !profile.completedLessonIds.includes(currentLesson.id)) {
        throw new Error('Dars yakuni profilda tasdiqlanmadi. Qayta urinib ko‘ring.');
      }
      useLearnerStore.setState({ profile, isLoading: false });
      if (!isCurrent()) return;
      set({ isCompleted: true, isCompletingLesson: false, error: null });
    } catch (err: any) {
      if (!isCurrent()) return;
      set({
        isCompletingLesson: false,
        isCompleted: false,
        error: `Dars yakunini tasdiqlab bo‘lmadi: ${err?.message || 'Server javob bermadi'}. Qayta urinib ko‘ring.`,
      });
    }
  },

  prevStep: () => {
    const { currentStepIndex } = get();
    if (currentStepIndex > 0) {
      evaluationToken = {};
      set({
        currentStepIndex: currentStepIndex - 1,
        isEvaluatingAnswer: false,
        isCompletingLesson: false,
        selectedAnswerIndex: null,
        lastAnswerResult: null,
        showAIPanel: false,
        error: null,
      });
    }
  },

  goToStep: (index: number) => {
    const { currentLesson, currentStepIndex } = get();
    if (!currentLesson) return;
    if (Number.isInteger(index) && index >= 0 && index < currentLesson.steps.length && index !== currentStepIndex) {
      evaluationToken = {};
      set({
        currentStepIndex: index,
        isEvaluatingAnswer: false,
        isCompletingLesson: false,
        selectedAnswerIndex: null,
        lastAnswerResult: null,
        showAIPanel: false,
        error: null,
      });
    }
  },

  submitAnswer: async (selectedIndex: number) => {
    const { currentLesson, currentStepIndex, isEvaluatingAnswer, isCompletingLesson, isLoading, isCompleted } = get();
    if (!currentLesson || isLoading || isEvaluatingAnswer || isCompletingLesson || isCompleted) return null;

    const question = currentLesson.steps[currentStepIndex]?.interactiveQuestion;
    if (!isValidAssessment(question, currentLesson.courseId, currentLesson.skillId) ||
        !Number.isInteger(selectedIndex) || selectedIndex < 0 || selectedIndex >= question.options.length) return null;

    const requestSession = sessionToken;
    const requestEvaluation = evaluationToken = {};
    const learnerId = useLearnerStore.getState().profile?.id;
    const isCurrent = () => sessionToken === requestSession && evaluationToken === requestEvaluation &&
      get().currentLesson === currentLesson && get().currentStepIndex === currentStepIndex;
    // loadProfile publishes after its own await without a session guard. Fetch
    // here so even the learner profile cannot be repopulated after navigation.
    const refreshProfile = async (expectCompletion = false) => {
      if (!isCurrent()) return;
      const profile = await supabaseLearnerRepository.getProfile();
      if (!isCurrent()) return;
      if ((learnerId && profile.id !== learnerId) ||
          (expectCompletion && !profile.completedLessonIds.includes(currentLesson.id))) {
        throw new Error('Dars yakuni profilda tasdiqlanmadi. Qayta urinib ko‘ring.');
      }
      useLearnerStore.setState({ profile, isLoading: false });
    };
    set({
      isEvaluatingAnswer: true,
      selectedAnswerIndex: selectedIndex,
      lastAnswerResult: null,
      showAIPanel: false,
      error: null,
    });

    try {
      const useCase = new SubmitLessonAnswerUseCase({
        explainMistake: async (request) => {
          // The use case may request feedback after awaiting answer scoring.
          // Do not start that follow-up work for a discarded question/session.
          if (!isCurrent()) throw new Error('Dars sessiyasi o‘zgardi.');
          const explanation = await aiService.explainMistake(request);
          if (!isCurrent()) throw new Error('Dars sessiyasi o‘zgardi.');
          return explanation;
        },
      }, supabaseLearnerRepository);
      const learnerName = useLearnerStore.getState().profile?.name || 'O‘quvchi';
      if (!isCurrent()) return null;
      const result = await useCase.execute(question, selectedIndex, learnerName, currentLesson.id);
      if (!isCurrent()) return null;

      if (result.isCorrect) {
        const answeredQuestionIds = get().answeredQuestionIds.includes(question.id)
          ? get().answeredQuestionIds
          : [...get().answeredQuestionIds, question.id];
        const isCompleted = shouldCompleteLesson(currentStepIndex, currentLesson.steps.length) &&
          hasPassedRequiredQuestions(currentLesson, answeredQuestionIds);
        if (isCompleted && !get().isCompleted) {
          if (!isCurrent()) return null;
          await persistCompletion(currentLesson, requestSession);
          if (!isCurrent()) return null;
        }
        await refreshProfile(isCompleted);
        if (!isCurrent()) return null;
        set({
          lastAnswerResult: result,
          isEvaluatingAnswer: false,
          isCompleted,
          showAIPanel: false,
          answeredQuestionIds,
          correctAnswerCount: answeredQuestionIds.length,
          error: null,
        });
      } else {
        await refreshProfile();
        if (!isCurrent()) return null;
        // Wrong answer -> the inline feedback card already reveals the correct
        // answer + explanation. The detailed AI panel is opt-in so a blocking
        // modal never hides the answer from the learner.
        set({
          lastAnswerResult: result,
          isEvaluatingAnswer: false,
          showAIPanel: false,
          error: null,
        });
      }

      return isCurrent() ? result : null;
    } catch (err: any) {
      if (!isCurrent()) return null;
      const message = err?.message || 'Javob yoki dars progressini serverda saqlab bo‘lmadi.';
      set({
        isEvaluatingAnswer: false,
        isCompleted: false,
        error: `Dars progressi saqlanmadi: ${message}. Qayta urinib ko‘ring.`,
      });
      return null;
    }
  },

  clearAnswerResult: () => {
    set({ lastAnswerResult: null, showAIPanel: false, error: null });
  },

  openAIPanel: () => {
    set({ showAIPanel: true });
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

  clearSession: () => {
    sessionToken = {};
    evaluationToken = {};
    completionRequest = null;
    set({
      currentLesson: null,
      currentStepIndex: 0,
      isLoading: false,
      error: null,
      isEvaluatingAnswer: false,
      isCompletingLesson: false,
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      showReinforcementModal: false,
      isCompleted: false,
      answeredQuestionIds: [],
      correctAnswerCount: 0,
    });
  },

  resetLessonState: () => {
    sessionToken = {};
    evaluationToken = {};
    completionRequest = null;
    set({
      currentStepIndex: 0,
      isLoading: false,
      error: null,
      isEvaluatingAnswer: false,
      isCompletingLesson: false,
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      showReinforcementModal: false,
      isCompleted: false,
      answeredQuestionIds: [],
      correctAnswerCount: 0,
    });
  },
}));
