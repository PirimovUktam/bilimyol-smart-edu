import { create } from 'zustand';
import { Question, QuestionAnswerSubmission } from '@/domain/entities/Question';
import { AssessmentResult } from '@/domain/entities/Assessment';
import { inMemoryCourseRepository } from '@/data/repositories/InMemoryCourseRepository';
import { inMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { SubmitPlacementTestUseCase } from '@/domain/usecases/SubmitPlacementTestUseCase';

interface PlacementState {
  questions: Question[];
  currentQuestionIndex: number;
  submissions: QuestionAnswerSubmission[];
  assessmentResult: AssessmentResult | null;
  isSubmitting: boolean;
  hasFinished: boolean;

  initPlacement: (courseId: string) => Promise<void>;
  submitAnswer: (selectedIndex: number) => Promise<boolean>; // returns true if test finished
  resetPlacement: () => void;
}

export const usePlacementStore = create<PlacementState>((set, get) => ({
  questions: [],
  currentQuestionIndex: 0,
  submissions: [],
  assessmentResult: null,
  isSubmitting: false,
  hasFinished: false,

  initPlacement: async (courseId: string) => {
    const questions = await inMemoryCourseRepository.getPlacementQuestions(courseId);
    set({
      questions,
      currentQuestionIndex: 0,
      submissions: [],
      assessmentResult: null,
      isSubmitting: false,
      hasFinished: false,
    });
  },

  submitAnswer: async (selectedIndex: number) => {
    const { questions, currentQuestionIndex, submissions, isSubmitting } = get();
    if (isSubmitting || currentQuestionIndex >= questions.length) return false;

    set({ isSubmitting: true });
    const currentQ = questions[currentQuestionIndex];
    const isCorrect = selectedIndex === currentQ.correctIndex;

    const newSubmissions: QuestionAnswerSubmission[] = [
      ...submissions,
      {
        questionId: currentQ.id,
        selectedIndex,
        isCorrect,
        timeSpentSeconds: 5,
      },
    ];

    const nextIndex = currentQuestionIndex + 1;

    if (nextIndex >= questions.length) {
      // Test is finished! Compute results using UseCase
      const useCase = new SubmitPlacementTestUseCase(
        inMemoryCourseRepository,
        inMemoryLearnerRepository
      );

      const result = await useCase.execute(currentQ.courseId, newSubmissions);

      set({
        submissions: newSubmissions,
        currentQuestionIndex: nextIndex,
        assessmentResult: result,
        hasFinished: true,
        isSubmitting: false,
      });
      return true;
    } else {
      set({
        submissions: newSubmissions,
        currentQuestionIndex: nextIndex,
        isSubmitting: false,
      });
      return false;
    }
  },

  resetPlacement: () => {
    set({
      questions: [],
      currentQuestionIndex: 0,
      submissions: [],
      assessmentResult: null,
      isSubmitting: false,
      hasFinished: false,
    });
  },
}));
