import { create } from 'zustand';
import { Question, QuestionAnswerSubmission } from '@/domain/entities/Question';
import { AssessmentResult } from '@/domain/entities/Assessment';
import { inMemoryCourseRepository } from '@/data/repositories/InMemoryCourseRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
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

const COURSE_TARGET_SKILLS: Record<string, string[]> = {
  course_math_01: [
    'skill_math_algebra',
    'skill_math_equations',
    'skill_math_functions',
    'skill_math_graphs',
  ],
  course_eng_01: [
    'skill_eng_vocab',
    'skill_eng_grammar',
    'skill_eng_listening',
    'skill_eng_reading',
  ],
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
  hasFinished: false,

  initPlacement: async (courseId: string) => {
    const allQuestions = await inMemoryCourseRepository.getPlacementQuestions(courseId);
    const targetSkills = COURSE_TARGET_SKILLS[courseId] || Array.from(new Set(allQuestions.map((q) => q.skillId)));
    const firstQ = AdaptiveQuestionSelector.getNextQuestion(
      allQuestions,
      targetSkills,
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
    const targetSkills = COURSE_TARGET_SKILLS[currentQuestion.courseId] || Array.from(new Set(allQuestions.map((q) => q.skillId)));
    const nextQ = AdaptiveQuestionSelector.getNextQuestion(
      allQuestions,
      targetSkills,
      updatedHistory,
      2
    );

    const isDone = !nextQ || questionNumber >= totalQuestionsToAsk;

    if (isDone) {
      // Evaluate full placement test using UseCase
      const useCase = new SubmitPlacementTestUseCase(
        inMemoryCourseRepository,
        supabaseLearnerRepository
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
