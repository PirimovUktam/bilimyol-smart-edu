import { create } from 'zustand';
import { Question, QuestionAnswerSubmission } from '@/domain/entities/Question';
import type { AssessmentResult, PlacementSession } from '@/domain/entities/Assessment';
import { supabaseCourseRepository } from '@/data/repositories/SupabaseCourseRepository';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { SubmitPlacementTestUseCase } from '@/domain/usecases/SubmitPlacementTestUseCase';
import { AdaptiveQuestionSelector, AnswerHistoryItem } from '@/domain/personalization/AdaptiveQuestionSelector';

/** Minimum interval between answer submissions (ms) to prevent rapid-fire abuse. */
const MIN_SUBMIT_INTERVAL_MS = 800;

interface PlacementState {
  allQuestions: Question[];
  currentQuestion: Question | null;
  questionNumber: number;
  totalQuestionsToAsk: number;
  history: AnswerHistoryItem[];
  submissions: QuestionAnswerSubmission[];
  assessmentResult: AssessmentResult | null;
  isSubmitting: boolean;
  isLoading: boolean;
  error: string | null;
  hasFinished: boolean;
  sessionId: string | null;
  canRetake: boolean;
  /** Timestamp when the current question was first displayed (ms). */
  _questionStartedAt: number;
  /** Timestamp of the last successful submission (ms) — for rate limiting. */
  _lastSubmittedAt: number;

  initPlacement: (courseId: string, restart?: boolean) => Promise<void>;
  submitAnswer: (selectedIndex: number) => Promise<boolean>;
  resetPlacement: () => void;
}

/**
 * Placement targets every skill that actually has bank questions for the
 * course — derived from the loaded question set, not a hardcoded course map.
 * That keeps IT / logic / newly-added courses on the same targeted coverage
 * instead of silently falling back to "all questions".
 */
export const getTargetSkillsForCourse = (allQuestions: Question[]): string[] =>
  Array.from(new Set(allQuestions.map((q) => q.skillId).filter(Boolean)));

const QUESTIONS_PER_SKILL = 2;
let placementRequestToken: object = {};

async function sessionState(session: PlacementSession, isCurrent: () => boolean): Promise<Partial<PlacementState>> {
  const result = session.result;
  if (result && isCurrent()) await useLearnerStore.getState().loadProfile().catch(() => undefined);
  const learner = useLearnerStore.getState().profile;
  return {
    allQuestions: [], currentQuestion: session.question, questionNumber: session.number,
    totalQuestionsToAsk: session.total, sessionId: session.id, canRetake: session.canRetake,
    submissions: result?.submissions ?? [], history: [], hasFinished: result !== null,
    assessmentResult: result ? { ...result, computedScores: learner?.scoresByCourse[result.courseId] ?? {} } : null,
    isLoading: false, isSubmitting: false,
    error: session.wasReset ? 'Savollar yangilandi yoki sessiya muddati tugadi. Diagnostika boshidan boshlandi.' : null,
  };
}

/** The displayed total is derived from the configured target coverage and bank. */
export const getPlacementQuestionCount = (
  allQuestions: Question[],
  targetSkills: string[],
  questionsPerSkill = QUESTIONS_PER_SKILL
): number => {
  const configuredCount = targetSkills.reduce(
    (count, skillId) => count + Math.min(
      questionsPerSkill,
      allQuestions.filter((question) => question.skillId === skillId).length
    ),
    0
  );

  return Math.min(configuredCount, allQuestions.length);
};

export const usePlacementStore = create<PlacementState>((set, get) => ({
  allQuestions: [],
  currentQuestion: null,
  questionNumber: 1,
  totalQuestionsToAsk: 8, // 2 questions per skill (8 total adaptive questions)
  history: [],
  submissions: [],
  assessmentResult: null,
  isSubmitting: false,
  isLoading: false,
  error: null,
  hasFinished: false,
  sessionId: null,
  canRetake: false,
  _questionStartedAt: 0,
  _lastSubmittedAt: 0,

  initPlacement: async (courseId: string, restart = false) => {
    const requestToken = placementRequestToken = {};
    const isCurrent = () => placementRequestToken === requestToken;
    set({ isLoading: true, error: null, currentQuestion: null, assessmentResult: null,
      sessionId: null, canRetake: false, hasFinished: false, isSubmitting: false });

    try {
      if (supabaseLearnerRepository.supportsServerPlacementPersistence) {
        const session = await supabaseLearnerRepository.advancePlacement(courseId, undefined, restart);
        if (!isCurrent()) return;
        const next = await sessionState(session, isCurrent);
        if (isCurrent()) set(next);
        return;
      }
      const allQuestions = await supabaseCourseRepository.getPlacementQuestions(courseId);
      if (!isCurrent()) return;
      const targetSkills = getTargetSkillsForCourse(allQuestions);
      const totalQuestionsToAsk = getPlacementQuestionCount(allQuestions, targetSkills);
      const firstQ = AdaptiveQuestionSelector.getNextQuestion(
        allQuestions,
        targetSkills,
        [],
        QUESTIONS_PER_SKILL
      );
      if (!isCurrent()) return;

      set({
        allQuestions,
        currentQuestion: firstQ,
        questionNumber: firstQ ? 1 : 0,
        totalQuestionsToAsk,
        history: [],
        submissions: [],
        assessmentResult: null,
        isSubmitting: false,
        isLoading: false,
        error: firstQ ? null : 'Ushbu fan uchun diagnostika savollari topilmadi.',
        hasFinished: false,
        _questionStartedAt: firstQ ? Date.now() : 0,
        _lastSubmittedAt: 0,
      });
    } catch (err) {
      if (!isCurrent()) return;
      set({
        allQuestions: [],
        currentQuestion: null,
        questionNumber: 0,
        totalQuestionsToAsk: 0,
        isLoading: false,
        isSubmitting: false,
        hasFinished: false,
        error: err instanceof Error ? err.message : 'Diagnostika savollarini yuklashda xatolik yuz berdi.',
      });
    }
  },

  submitAnswer: async (selectedIndex: number) => {
    const token = placementRequestToken;
    const isCurrent = () => token === placementRequestToken;
    const {
      allQuestions,
      currentQuestion,
      questionNumber,
      totalQuestionsToAsk,
      history,
      submissions,
      isSubmitting,
      sessionId,
      _questionStartedAt,
      _lastSubmittedAt,
    } = get();

    if (isSubmitting || !currentQuestion || totalQuestionsToAsk === 0) return false;

    // Rate limiting: prevent rapid-fire submission abuse
    const now = Date.now();
    if (!sessionId && _lastSubmittedAt && now - _lastSubmittedAt < MIN_SUBMIT_INTERVAL_MS) {
      return false;
    }

    // Input validation: selectedIndex must be an integer within valid option bounds
    if (
      typeof selectedIndex !== 'number' ||
      !Number.isInteger(selectedIndex) ||
      selectedIndex < 0 ||
      (currentQuestion.options && selectedIndex >= currentQuestion.options.length)
    ) {
      return false;
    }

    set({ isSubmitting: true, error: null });
    if (sessionId) {
      try {
        const session = await supabaseLearnerRepository.advancePlacement(currentQuestion.courseId, {
          sessionId, questionId: currentQuestion.id, selectedIndex,
        });
        if (!isCurrent()) return false;
        const next = await sessionState(session, isCurrent);
        if (!isCurrent()) return false;
        set(next);
        return session.result !== null;
      } catch (error) {
        if (isCurrent()) set({ isSubmitting: false,
          error: error instanceof Error ? error.message : 'Javobni yuborib bo‘lmadi. Qayta urinib ko‘ring.' });
        return false;
      }
    }

    let isCorrect: boolean;
    try {
      const evaluation = await supabaseLearnerRepository.evaluatePlacementAnswer(
        currentQuestion.courseId,
        currentQuestion.id,
        selectedIndex
      );
      if (!isCurrent()) return false;
      isCorrect = Boolean(evaluation?.isCorrect);
    } catch (err) {
      if (!isCurrent()) return false;
      set({
        isSubmitting: false,
        error: err instanceof Error
          ? err.message
          : 'Javobni serverda tekshirib bo‘lmadi. Internetni tekshirib qayta urinib ko‘ring.',
      });
      return false;
    }

    const newHistoryItem: AnswerHistoryItem = {
      questionId: currentQuestion.id,
      skillId: currentQuestion.skillId,
      difficulty: currentQuestion.difficulty,
      isCorrect,
    };

    const updatedHistory = [...history, newHistoryItem];

    // Compute real elapsed time; clamp to a sane range [1, 600] seconds.
    const elapsedMs = _questionStartedAt > 0 ? now - _questionStartedAt : 0;
    const timeSpentSeconds = Math.max(1, Math.min(600, Math.round(elapsedMs / 1000)));

    const newSubmission: QuestionAnswerSubmission = {
      questionId: currentQuestion.id,
      selectedIndex,
      isCorrect,
      timeSpentSeconds,
    };

    const updatedSubmissions = [...submissions, newSubmission];

    // Find next adaptive question
    const targetSkills = getTargetSkillsForCourse(allQuestions);
    const nextQ = AdaptiveQuestionSelector.getNextQuestion(
      allQuestions,
      targetSkills,
      updatedHistory,
      2
    );

    const isDone = !nextQ || questionNumber >= totalQuestionsToAsk;

    if (isDone) {
      // Evaluate full placement test using UseCase
      const useCase = new SubmitPlacementTestUseCase(supabaseCourseRepository, supabaseLearnerRepository);

      try {
        const result = await useCase.execute(currentQuestion.courseId, updatedSubmissions, isCurrent);
        if (!isCurrent()) return false;
        await useLearnerStore.getState().loadProfile().catch(() => undefined);
        if (!isCurrent()) return false;

        set({
          history: updatedHistory,
          submissions: updatedSubmissions,
          currentQuestion: null,
          assessmentResult: result,
          hasFinished: true,
          canRetake: true,
          isSubmitting: false,
          error: null,
          _questionStartedAt: 0,
          _lastSubmittedAt: now,
        });
        return true;
      } catch (err) {
        if (!isCurrent()) return false;
        set({
          isSubmitting: false,
          error: err instanceof Error
            ? err.message
            : 'Diagnostika natijasini serverga saqlab bo‘lmadi. Qayta urinib ko‘ring.',
        });
        return false;
      }
    } else {
      set({
        history: updatedHistory,
        submissions: updatedSubmissions,
        currentQuestion: nextQ,
        questionNumber: questionNumber + 1,
        isSubmitting: false,
        _questionStartedAt: Date.now(),
        _lastSubmittedAt: Date.now(),
      });
      return false;
    }
  },

  resetPlacement: () => {
    placementRequestToken = {};
    set({
      allQuestions: [],
      currentQuestion: null,
      questionNumber: 1,
      totalQuestionsToAsk: 0,
      history: [],
      submissions: [],
      assessmentResult: null,
      isSubmitting: false,
      isLoading: false,
      error: null,
      hasFinished: false,
      sessionId: null,
      canRetake: false,
      _questionStartedAt: 0,
      _lastSubmittedAt: 0,
    });
  },
}));
