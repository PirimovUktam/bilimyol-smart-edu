import { IAITutorService, AIExplanationResponse } from '@/data/services/IAITutorService';
import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { Question } from '../entities/Question';

export interface LessonAnswerResult {
  isCorrect: boolean;
  selectedOption: string;
  correctOption: string;
  aiExplanation?: AIExplanationResponse;
}

export class SubmitLessonAnswerUseCase {
  constructor(
    private aiTutorService: IAITutorService,
    private learnerRepo?: ILearnerRepository
  ) {}

  async execute(
    question: Question,
    selectedIndex: number,
    learnerName?: string,
    lessonId?: string
  ): Promise<LessonAnswerResult> {
    const isCorrect = selectedIndex === question.correctIndex;
    const selectedOption = question.options[selectedIndex] || '';
    const correctOption = question.options[question.correctIndex] || '';

    // Log answer attempt if repository provided
    if (this.learnerRepo) {
      await this.learnerRepo.recordAnswerAttempt({
        courseId: question.courseId,
        skillId: question.skillId,
        lessonId: lessonId || 'lesson_general',
        questionId: question.id,
        selectedIndex,
        selectedAnswer: selectedOption,
        isCorrect,
      });
    }

    if (isCorrect) {
      return {
        isCorrect: true,
        selectedOption,
        correctOption,
      };
    }

    // Call AI Tutor service for diagnostic feedback on error
    const aiExplanation = await this.aiTutorService.explainMistake({
      courseId: question.courseId,
      skillId: question.skillId,
      questionId: question.id,
      questionText: question.text,
      selectedOption,
      correctOption,
      learnerName,
    });

    return {
      isCorrect: false,
      selectedOption,
      correctOption,
      aiExplanation,
    };
  }
}
