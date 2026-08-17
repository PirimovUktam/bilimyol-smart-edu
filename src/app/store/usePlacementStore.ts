import { create } from 'zustand';
import { Question, QuestionAnswerSubmission } from '@/domain/entities/Question';
import { AssessmentResult } from '@/domain/entities/Assessment';
import { inMemoryCourseRepository } from '@/data/repositories/InMemoryCourseRepository';
import { inMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { SubmitPlacementTestUseCase } from '@/domain/usecases/SubmitPlacementTestUseCase';
import { AdaptiveQuestionSelector, AnswerHistoryItem } from '@/domain/personalization/AdaptiveQuestionSelector';

interface PlacementState {
  allQuestions: Question[];
  currentQuestion: Question | null;
  questionNumber: number;
  totalQuestionsToAsk: number;
  history: AnswerHistoryItem[];
  submissions: QuestionAnswerSubmission[];
  assessmentResult: AssessmentResult | null;
  isSubmitting: boolean;
  hasFinished: boolean;

  initPlacement: (courseId: string) => Promise<void>;
  submitAnswer: (selectedIndex: number) => Promise<boolean>;
  resetPlacement: () => void;
}

const TARGET_SKILLS_MATH = [
  'skill_math_algebra',
  'skill_math_equations',
  'skill_math_functions',
  'skill_math_graphs',
];

export const usePlacementStore = create<PlacementState>((set, get) => ({
  allQuestions: [],
  currentQuestion: null,
  questionNumber: 1,
  totalQuestionsToAsk: 8, // 2 questions per skill (8 total adaptive questions)
  history: [],
  submissions: [],
  assessmentResult: null,
  isSubmitting: false,
  hasFinished: false,

  initPlacement: async (courseId: string) => {
    const allQuestions = await inMemoryCourseRepository.getPlacementQuestions(courseId);
    const firstQ = AdaptiveQuestionSelector.getNextQuestion(
      allQuestions,
      TARGET_SKILLS_MATH,
      [],
      2
    ) || allQuestions[0];

    set({
      allQuestions,
      currentQuestion: firstQ,
      questionNumber: 1,
      totalQuestionsToAsk: 8,
      history: [],
      submissions: [],
      assessmentResult: null,
      isSubmitting: false,
      hasFinished: false,
    });
  },

  submitAnswer: async (selectedIndex: number) => {
    const {
      allQuestions,
      currentQuestion,
      questionNumber,
      totalQuestionsToAsk,
      history,
      submissions,
      isSubmitting,
    } = get();

    if (isSubmitting || !currentQuestion) return false;

    set({ isSubmitting: true });
    const isCorrect = selectedIndex === currentQuestion.correctIndex;

    const newHistoryItem: AnswerHistoryItem = {
      questionId: currentQuestion.id,
      skillId: currentQuestion.skillId,
      difficulty: currentQuestion.difficulty,
      isCorrect,
    };

    const updatedHistory = [...history, newHistoryItem];

    const newSubmission: QuestionAnswerSubmission = {
      questionId: currentQuestion.id,
      selectedIndex,
      isCorrect,
      timeSpentSeconds: 5,
    };

    const updatedSubmissions = [...submissions, newSubmission];

    // Find next adaptive question
    const nextQ = AdaptiveQuestionSelector.getNextQuestion(
      allQuestions,
      TARGET_SKILLS_MATH,
      updatedHistory,
      2
    );

    const isDone = !nextQ || questionNumber >= totalQuestionsToAsk;

    if (isDone) {
      // Evaluate full placement test using UseCase
      const useCase = new SubmitPlacementTestUseCase(
        inMemoryCourseRepository,
        inMemoryLearnerRepository
      );

      const result = await useCase.execute(currentQuestion.courseId, updatedSubmissions);

      set({
        history: updatedHistory,
        submissions: updatedSubmissions,
        currentQuestion: null,
        assessmentResult: result,
        hasFinished: true,
        isSubmitting: false,
      });
      return true;
    } else {
      set({
        history: updatedHistory,
        submissions: updatedSubmissions,
        currentQuestion: nextQ,
        questionNumber: questionNumber + 1,
        isSubmitting: false,
      });
      return false;
    }
  },

  resetPlacement: () => {
    set({
      allQuestions: [],
      currentQuestion: null,
      questionNumber: 1,
      history: [],
      submissions: [],
      assessmentResult: null,
      isSubmitting: false,
      hasFinished: false,
    });
  },
}));
