import { create } from 'zustand';
import { Lesson } from '@/domain/entities/Lesson';
import { Question, normalizeFreeTextAnswer } from '@/domain/entities/Question';
import { supabaseLessonRepository } from '@/data/repositories/SupabaseLessonRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { GeminiAITutorService } from '@/data/services/GeminiAITutorService';
import { SubmitLessonAnswerUseCase, LessonAnswerResult } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { usePreferences } from '@/core/preferences/preferences';

import { useLearnerStore } from '@/app/store/useLearnerStore';

const aiService = new GeminiAITutorService();

// Identity tokens stay bounded and invalidate work even when the same lesson or
// step is reopened before an earlier request settles.
let sessionToken = {};
let evaluationToken = {};
let nextLessonSessionId = 0;
let pendingMasteryAnswer: { session: object; questionId: string; answerKey: string; key: string } | null = null;
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

export const isValidAssessment = (
  question: unknown,
  courseId: string,
  skillId: string,
  allowIntegratedEnglishSkills = false,
): question is Question => {
  if (!question || typeof question !== 'object') return false;
  const candidate = question as Question;
  const skillMatches = candidate.skillId === skillId || (
    allowIntegratedEnglishSkills &&
    courseId === 'course_eng_01' &&
    typeof candidate.skillId === 'string' &&
    candidate.skillId.startsWith('skill_eng_')
  );
  if (!hasText(candidate.id) || candidate.courseId !== courseId || !skillMatches ||
    !hasText(candidate.text)) {
    return false;
  }
  const qType = candidate.questionType ?? 'multiple_choice';
  if (qType === 'text_input' || qType === 'fill_blank') {
    return true;
  }
  if (qType === 'word_match') {
    return Array.isArray(candidate.matchPairs) && candidate.matchPairs.length >= 2 &&
      candidate.matchPairs.every((p) => hasText(p?.id) && hasText(p?.left) && hasText(p?.right));
  }
  if (qType === 'sentence_order') {
    return Array.isArray(candidate.orderedTokens) && candidate.orderedTokens.length >= 2 &&
      candidate.orderedTokens.every(hasText);
  }
  if (qType === 'speaking_prompt' || qType === 'writing_prompt') {
    return candidate.evaluationMode === 'self_assessed' &&
      hasText(candidate.sampleResponse) &&
      Array.isArray(candidate.rubricCriteria) &&
      candidate.rubricCriteria.length >= 1;
  }
  return Array.isArray(candidate.options) && candidate.options.length >= 2 &&
    candidate.options.every(hasText);
};

export const isIntegratedEnglishLesson = (lesson: Lesson): boolean =>
  lesson.courseId === 'course_eng_01' &&
  (lesson.skillDomain === 'integrated' ||
    lesson.id.includes('_checkpoint') ||
    lesson.id.includes('_exit') ||
    ['A2', 'B1', 'B2', 'C1', 'C2'].includes(lesson.cefrLevel ?? ''));

const hasPassedRequiredQuestions = (lesson: Lesson, answeredQuestionIds: string[]): boolean => {
  const allowMultiSkill = isIntegratedEnglishLesson(lesson);
  if (!Array.isArray(lesson.steps) || lesson.steps.length === 0 || lesson.steps.some((step) =>
    !step || ((step.type === 'interactive_question' || step.interactiveQuestion != null) &&
      !isValidAssessment(step.interactiveQuestion, lesson.courseId, lesson.skillId, allowMultiSkill)))) return false;
  const requiredIds = new Set(lesson.steps.flatMap((step) => step.interactiveQuestion ? [step.interactiveQuestion.id] : []));
  // complete_lesson currently rejects an empty required-assessment set too.
  return requiredIds.size > 0 && [...requiredIds].every((id) => hasText(id) && answeredQuestionIds.includes(id));
};

export const shouldCompleteLesson = (currentStepIndex: number, totalSteps: number): boolean =>
  totalSteps > 0 && currentStepIndex >= totalSteps - 1;

interface LessonState {
  currentLesson: Lesson | null;
  lessonSessionId: number;
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
  consecutiveMistakes: number;
  consecutiveMistakeSkillId: string | null;

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
  submitTextAnswer: (answerText: string) => Promise<LessonAnswerResult | null>;
  submitStructuredAnswer: (payload: {
    matchPairs?: Record<string, string>;
    orderedTokens?: string[];
  }) => Promise<LessonAnswerResult | null>;
  submitSelfAssessment: (
    responseText: string,
    checkedCriteriaIds: string[],
  ) => Promise<LessonAnswerResult | null>;
  switchToAlternateExercise: () => boolean;
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
  lessonSessionId: 0,
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
  consecutiveMistakes: 0,
  consecutiveMistakeSkillId: null,

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
    const syncDemoLesson = hasText(lessonId)
      ? supabaseLessonRepository.getCachedDemoLessonSync?.(lessonId) ?? null
      : null;
    if (syncDemoLesson && syncDemoLesson.id === lessonId) {
      set({
        isLoading: false,
        error: null,
        currentLesson: syncDemoLesson,
        lessonSessionId: ++nextLessonSessionId,
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
        consecutiveMistakes: 0,
        consecutiveMistakeSkillId: null,
      });
      return;
    }
    set({
      isLoading: true,
      error: null,
      currentLesson: null,
      lessonSessionId: 0,
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
      consecutiveMistakes: 0,
      consecutiveMistakeSkillId: null,
    });

    try {
      if (!hasText(lessonId)) throw new Error('Dars identifikatori notöğri.');
      if (!isCurrent()) return;
      const lesson = await supabaseLessonRepository.getLessonById(lessonId);
      if (!isCurrent()) return;
      if (!lesson) {
        set({
          currentLesson: null,
          lessonSessionId: 0,
          isLoading: false,
          error: `Dars topilmadi ("${lessonId}"). Iltimos, boşqa darsni tanlang yoki yangi dars yarating.`,
        });
        return;
      }
      if (lesson.id !== lessonId) throw new Error('Söralgan dars örniga boşqa dars qaytdi.');
      set({ currentLesson: lesson, lessonSessionId: ++nextLessonSessionId, isLoading: false, error: null });
    } catch (err: any) {
      if (!isCurrent()) return;
      set({
        currentLesson: null,
        isLoading: false,
        error: `Darsni yuklaşda xatolik yuz berdi: ${err?.message || 'Server javob bermadi'}. Qayta urinib köring.`,
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
      consecutiveMistakes: 0,
      consecutiveMistakeSkillId: null,
    });

    try {
      if (!hasText(courseId) || !hasText(skillId)) {
        throw new Error('Dars uçun fan va könikma tanlanişi kerak.');
      }
      if (!isCurrent()) return null;
      const response = await aiService.generateLesson({ courseId, skillId, topic, difficulty });
      if (!isCurrent()) return null;

      if (!response || !hasText(response.lessonId) || !hasText(response.title) ||
          !Array.isArray(response.steps) || response.steps.length === 0) {
        throw new Error('AI xizmatidan yaroqli dars ma’lumotlari kelmadi.');
      }
      if (response.courseId !== courseId || response.skillId !== skillId) {
        throw new Error('Yaratilgan dars tanlangan fan yoki könikmaga mos kelmadi.');
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
            throw new Error('Dars savoli tanlangan fan yoki server baholaşiga mos kelmadi.');
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

      set({ currentLesson: lessonEntity, lessonSessionId: ++nextLessonSessionId, isLoading: false, error: null });
      return isCurrent() ? lessonEntity : null;
    } catch (err: any) {
      if (!isCurrent()) return null;
      console.warn('[useLessonStore] generateAILesson error:', err);
      const errorMessage = err?.message || 'Server javob bermadi yoki cheklovdan oşildi';
      set({
        isLoading: false,
        error: `AI dars yaratişda xatolik yuz berdi: ${errorMessage}. Iltimos, qayta urinib köring.`,
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
    if (!currentLesson.requiresMastery && !hasPassedRequiredQuestions(currentLesson, get().answeredQuestionIds)) {
      set({ error: 'Darsni yakunlaş uçun barça yaroqli sinov savollariga töğri javob bering. Savol yetişmasa, darsni qayta oçing.' });
      return;
    }
    const activeQuestion = currentLesson.steps[currentStepIndex].interactiveQuestion;
    const isAnsweredSelfAssessed = Boolean(
      activeQuestion &&
      (activeQuestion.questionType === 'speaking_prompt' || activeQuestion.questionType === 'writing_prompt') &&
      get().answeredQuestionIds.includes(activeQuestion.id)
    );
    // Final quizzes keep their existing submitAnswer completion flow; answered
    // self-assessed prompts allow reviewing the model/rubric before completing.
    if (activeQuestion && !isAnsweredSelfAssessed) return;

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
        throw new Error('Dars yakuni profilda tasdiqlanmadi. Qayta urinib köring.');
      }
      useLearnerStore.setState({ profile, isLoading: false });
      if (!isCurrent()) return;
      set({ isCompleted: true, isCompletingLesson: false, error: null });
    } catch (err: any) {
      if (!isCurrent()) return;
      set({
        isCompletingLesson: false,
        isCompleted: false,
        error: `Dars yakunini tasdiqlab bölmadi: ${err?.message || 'Server javob bermadi'}. Qayta urinib köring.`,
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
    const qType = question?.questionType ?? 'multiple_choice';
    const isChoiceMode =
      qType === 'multiple_choice' || qType === 'error_correction' || qType === 'conversation_completion';
    if (!isValidAssessment(question, currentLesson.courseId, currentLesson.skillId, isIntegratedEnglishLesson(currentLesson)) ||
        !isChoiceMode ||
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
        throw new Error('Dars yakuni profilda tasdiqlanmadi. Qayta urinib köring.');
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
      const useCase = new SubmitLessonAnswerUseCase(supabaseLearnerRepository);
      if (!isCurrent()) return null;
      let attemptKey: string | undefined;
      if (currentLesson.requiresMastery) {
        const answerKey = `idx:${selectedIndex}`;
        if (pendingMasteryAnswer?.session !== requestSession || pendingMasteryAnswer.questionId !== question.id ||
            pendingMasteryAnswer.answerKey !== answerKey) {
          pendingMasteryAnswer = { session: requestSession, questionId: question.id, answerKey, key: crypto.randomUUID() };
        }
        attemptKey = pendingMasteryAnswer.key;
      }
      const language = usePreferences.getState().language;
      const result = await useCase.execute(question, selectedIndex, currentLesson.id, attemptKey, language);
      if (pendingMasteryAnswer?.key === attemptKey) pendingMasteryAnswer = null;
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
          consecutiveMistakes: 0,
          consecutiveMistakeSkillId: null,
          error: null,
        });
      } else {
        await refreshProfile();
        if (!isCurrent()) return null;
        const nextMistakeCount =
          get().consecutiveMistakeSkillId === question.skillId ? get().consecutiveMistakes + 1 : 1;
        // Wrong answer -> the inline feedback card already reveals the correct
        // answer + explanation. The detailed AI panel is opt-in so a blocking
        // modal never hides the answer from the learner.
        set({
          lastAnswerResult: result,
          isEvaluatingAnswer: false,
          showAIPanel: false,
          consecutiveMistakes: nextMistakeCount,
          consecutiveMistakeSkillId: question.skillId,
          error: null,
        });
      }

      return isCurrent() ? result : null;
    } catch (err: any) {
      if (!isCurrent()) return null;
      const message = err?.message || 'Javob yoki dars progressini serverda saqlab bölmadi.';
      set({
        isEvaluatingAnswer: false,
        isCompleted: false,
        error: `Dars progressi saqlanmadi: ${message}. Qayta urinib köring.`,
      });
      return null;
    }
  },

  submitTextAnswer: async (answerText: string) => {
    const { currentLesson, currentStepIndex, isEvaluatingAnswer, isCompletingLesson, isLoading, isCompleted } = get();
    if (!currentLesson || isLoading || isEvaluatingAnswer || isCompletingLesson || isCompleted) return null;

    const question = currentLesson.steps[currentStepIndex]?.interactiveQuestion;
    const trimmed = typeof answerText === 'string' ? answerText.trim() : '';
    const answerLanguage = currentLesson.courseId === 'course_eng_01' ? undefined : 'uz';
    const normalized = normalizeFreeTextAnswer(trimmed, answerLanguage);
    const isTextMode = question?.questionType === 'text_input' || question?.questionType === 'fill_blank';
    if (!isValidAssessment(question, currentLesson.courseId, currentLesson.skillId, isIntegratedEnglishLesson(currentLesson)) ||
        !isTextMode || !normalized) {
      return null;
    }

    const requestSession = sessionToken;
    const requestEvaluation = evaluationToken = {};
    const learnerId = useLearnerStore.getState().profile?.id;
    const isCurrent = () => sessionToken === requestSession && evaluationToken === requestEvaluation &&
      get().currentLesson === currentLesson && get().currentStepIndex === currentStepIndex;
    const refreshProfile = async (expectCompletion = false) => {
      if (!isCurrent()) return;
      const profile = await supabaseLearnerRepository.getProfile();
      if (!isCurrent()) return;
      if ((learnerId && profile.id !== learnerId) ||
          (expectCompletion && !profile.completedLessonIds.includes(currentLesson.id))) {
        throw new Error('Dars yakuni profilda tasdiqlanmadi. Qayta urinib köring.');
      }
      useLearnerStore.setState({ profile, isLoading: false });
    };
    set({
      isEvaluatingAnswer: true,
      selectedAnswerIndex: 0,
      lastAnswerResult: null,
      showAIPanel: false,
      error: null,
    });

    try {
      const useCase = new SubmitLessonAnswerUseCase(supabaseLearnerRepository);
      if (!isCurrent()) return null;
      let attemptKey: string | undefined;
      if (currentLesson.requiresMastery) {
        const answerKey = `text:${normalized}`;
        if (pendingMasteryAnswer?.session !== requestSession || pendingMasteryAnswer.questionId !== question.id ||
            pendingMasteryAnswer.answerKey !== answerKey) {
          pendingMasteryAnswer = { session: requestSession, questionId: question.id, answerKey, key: crypto.randomUUID() };
        }
        attemptKey = pendingMasteryAnswer.key;
      }
      const language = usePreferences.getState().language;
      const result = await useCase.executeText(question, trimmed, currentLesson.id, attemptKey, language);
      if (pendingMasteryAnswer?.key === attemptKey) pendingMasteryAnswer = null;
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
          consecutiveMistakes: 0,
          consecutiveMistakeSkillId: null,
          error: null,
        });
      } else {
        await refreshProfile();
        if (!isCurrent()) return null;
        const nextMistakeCount =
          get().consecutiveMistakeSkillId === question.skillId ? get().consecutiveMistakes + 1 : 1;
        set({
          lastAnswerResult: result,
          isEvaluatingAnswer: false,
          showAIPanel: false,
          consecutiveMistakes: nextMistakeCount,
          consecutiveMistakeSkillId: question.skillId,
          error: null,
        });
      }

      return isCurrent() ? result : null;
    } catch (err: any) {
      if (!isCurrent()) return null;
      const message = err?.message || 'Javob yoki dars progressini serverda saqlab bölmadi.';
      set({
        isEvaluatingAnswer: false,
        isCompleted: false,
        error: `Dars progressi saqlanmadi: ${message}. Qayta urinib köring.`,
      });
      return null;
    }
  },

  submitStructuredAnswer: async (payload: {
    matchPairs?: Record<string, string>;
    orderedTokens?: string[];
  }) => {
    const { currentLesson, currentStepIndex, isEvaluatingAnswer, isCompletingLesson, isLoading, isCompleted } = get();
    if (!currentLesson || isLoading || isEvaluatingAnswer || isCompletingLesson || isCompleted) return null;

    const question = currentLesson.steps[currentStepIndex]?.interactiveQuestion;
    const qType = question?.questionType;
    if (!isValidAssessment(question, currentLesson.courseId, currentLesson.skillId, isIntegratedEnglishLesson(currentLesson)) ||
        (qType !== 'word_match' && qType !== 'sentence_order')) {
      return null;
    }
    if (qType === 'word_match' && Object.keys(payload.matchPairs ?? {}).length === 0) {
      return null;
    }
    if (
      qType === 'sentence_order' &&
      (payload.orderedTokens ?? []).filter((token) => typeof token === 'string' && token.trim().length > 0).length === 0
    ) {
      return null;
    }

    const serializedAnswer = qType === 'word_match'
      ? JSON.stringify(
          Object.fromEntries(
            Object.entries(payload.matchPairs ?? {}).sort(([a], [b]) => a.localeCompare(b)),
          ),
        )
      : JSON.stringify(payload.orderedTokens ?? []);
    const displayAnswer = qType === 'word_match'
      ? Object.entries(payload.matchPairs ?? {})
          .map(([leftId, rightVal]) => {
            const pair = question.matchPairs?.find((p) => p.id === leftId);
            const rightPair = question.matchPairs?.find((p) => p.id === rightVal);
            return `${pair?.left ?? leftId} -> ${rightPair?.right ?? rightVal}`;
          })
          .join(', ')
      : (payload.orderedTokens ?? []).join(' ');

    const requestSession = sessionToken;
    const requestEvaluation = evaluationToken = {};
    const learnerId = useLearnerStore.getState().profile?.id;
    const isCurrent = () => sessionToken === requestSession && evaluationToken === requestEvaluation &&
      get().currentLesson === currentLesson && get().currentStepIndex === currentStepIndex;
    const refreshProfile = async (expectCompletion = false) => {
      if (!isCurrent()) return;
      const profile = await supabaseLearnerRepository.getProfile();
      if (!isCurrent()) return;
      if ((learnerId && profile.id !== learnerId) ||
          (expectCompletion && !profile.completedLessonIds.includes(currentLesson.id))) {
        throw new Error('Dars yakuni profilda tasdiqlanmadi. Qayta urinib köring.');
      }
      useLearnerStore.setState({ profile, isLoading: false });
    };

    set({
      isEvaluatingAnswer: true,
      selectedAnswerIndex: 0,
      lastAnswerResult: null,
      showAIPanel: false,
      error: null,
    });

    try {
      const useCase = new SubmitLessonAnswerUseCase(supabaseLearnerRepository);
      if (!isCurrent()) return null;
      const language = usePreferences.getState().language;
      const result = await useCase.executeStructured(
        question,
        {
          serializedAnswer,
          displayAnswer,
          matchPairs: payload.matchPairs,
          orderedTokens: payload.orderedTokens,
        },
        currentLesson.id,
        undefined,
        language,
      );
      if (!isCurrent()) return null;

      if (result.isCorrect) {
        const answeredQuestionIds = get().answeredQuestionIds.includes(question.id)
          ? get().answeredQuestionIds
          : [...get().answeredQuestionIds, question.id];
        const completed = shouldCompleteLesson(currentStepIndex, currentLesson.steps.length) &&
          hasPassedRequiredQuestions(currentLesson, answeredQuestionIds);
        if (completed && !get().isCompleted) {
          if (!isCurrent()) return null;
          await persistCompletion(currentLesson, requestSession);
          if (!isCurrent()) return null;
        }
        await refreshProfile(completed);
        if (!isCurrent()) return null;
        set({
          lastAnswerResult: result,
          isEvaluatingAnswer: false,
          isCompleted: completed,
          showAIPanel: false,
          answeredQuestionIds,
          correctAnswerCount: answeredQuestionIds.length,
          consecutiveMistakes: 0,
          consecutiveMistakeSkillId: null,
          error: null,
        });
      } else {
        await refreshProfile();
        if (!isCurrent()) return null;
        const nextMistakeCount =
          get().consecutiveMistakeSkillId === question.skillId ? get().consecutiveMistakes + 1 : 1;
        set({
          lastAnswerResult: result,
          isEvaluatingAnswer: false,
          showAIPanel: false,
          consecutiveMistakes: nextMistakeCount,
          consecutiveMistakeSkillId: question.skillId,
          error: null,
        });
      }

      return isCurrent() ? result : null;
    } catch (err: any) {
      if (!isCurrent()) return null;
      const message = err?.message || 'Javob yoki dars progressini serverda saqlab bölmadi.';
      set({
        isEvaluatingAnswer: false,
        isCompleted: false,
        error: `Dars progressi saqlanmadi: ${message}. Qayta urinib köring.`,
      });
      return null;
    }
  },

  submitSelfAssessment: async (responseText: string, checkedCriteriaIds: string[]) => {
    const { currentLesson, currentStepIndex, isEvaluatingAnswer, isCompletingLesson, isLoading, isCompleted } = get();
    if (!currentLesson || isLoading || isEvaluatingAnswer || isCompletingLesson || isCompleted) return null;

    const question = currentLesson.steps[currentStepIndex]?.interactiveQuestion;
    const trimmed = typeof responseText === 'string' ? responseText.trim() : '';
    if (!isValidAssessment(question, currentLesson.courseId, currentLesson.skillId, isIntegratedEnglishLesson(currentLesson)) ||
        (question.questionType !== 'speaking_prompt' && question.questionType !== 'writing_prompt') ||
        !trimmed) {
      return null;
    }

    const requestSession = sessionToken;
    const requestEvaluation = evaluationToken = {};
    const learnerId = useLearnerStore.getState().profile?.id;
    const isCurrent = () => sessionToken === requestSession && evaluationToken === requestEvaluation &&
      get().currentLesson === currentLesson && get().currentStepIndex === currentStepIndex;
    const refreshProfile = async (expectCompletion = false) => {
      if (!isCurrent()) return;
      const profile = await supabaseLearnerRepository.getProfile();
      if (!isCurrent()) return;
      if ((learnerId && profile.id !== learnerId) ||
          (expectCompletion && !profile.completedLessonIds.includes(currentLesson.id))) {
        throw new Error('Dars yakuni profilda tasdiqlanmadi. Qayta urinib köring.');
      }
      useLearnerStore.setState({ profile, isLoading: false });
    };

    set({
      isEvaluatingAnswer: true,
      selectedAnswerIndex: 0,
      lastAnswerResult: null,
      showAIPanel: false,
      error: null,
    });

    try {
      const useCase = new SubmitLessonAnswerUseCase(supabaseLearnerRepository);
      if (!isCurrent()) return null;
      const language = usePreferences.getState().language;
      const result = await useCase.executeSelfAssessed(
        question,
        trimmed,
        checkedCriteriaIds,
        currentLesson.id,
        undefined,
        language,
      );
      if (!isCurrent()) return null;

      if (result.isCorrect) {
        const answeredQuestionIds = get().answeredQuestionIds.includes(question.id)
          ? get().answeredQuestionIds
          : [...get().answeredQuestionIds, question.id];
        // Do NOT complete immediately: allow reviewing model answer & rubric checkboxes,
        // then complete via nextStep() when the learner clicks "Darsni yakunlaş".
        await refreshProfile(false);
        if (!isCurrent()) return null;
        set({
          lastAnswerResult: result,
          isEvaluatingAnswer: false,
          showAIPanel: false,
          answeredQuestionIds,
          correctAnswerCount: answeredQuestionIds.length,
          error: null,
        });
      } else {
        await refreshProfile();
        if (!isCurrent()) return null;
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
      const message = err?.message || 'Javob yoki dars progressini serverda saqlab bölmadi.';
      set({
        isEvaluatingAnswer: false,
        isCompleted: false,
        error: `Dars progressi saqlanmadi: ${message}. Qayta urinib köring.`,
      });
      return null;
    }
  },

  switchToAlternateExercise: () => {
    const { currentLesson, currentStepIndex } = get();
    if (!currentLesson?.alternateExercise) return false;
    const alt = currentLesson.alternateExercise;
    if (!isValidAssessment(alt, currentLesson.courseId, currentLesson.skillId, isIntegratedEnglishLesson(currentLesson))) return false;
    const step = currentLesson.steps[currentStepIndex];
    if (!step) return false;
    if (currentLesson.steps.some((item) => item.interactiveQuestion?.id === alt.id)) {
      return false;
    }
    const updatedSteps = currentLesson.steps.map((item, idx) =>
      idx === currentStepIndex ? { ...item, interactiveQuestion: alt } : item
    );
    evaluationToken = {};
    set({
      currentLesson: { ...currentLesson, steps: updatedSteps },
      selectedAnswerIndex: null,
      lastAnswerResult: null,
      showAIPanel: false,
      consecutiveMistakes: 0,
      consecutiveMistakeSkillId: null,
      error: null,
    });
    return true;
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
      lessonSessionId: 0,
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
      consecutiveMistakes: 0,
      consecutiveMistakeSkillId: null,
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
      consecutiveMistakes: 0,
      consecutiveMistakeSkillId: null,
    });
  },
}));
