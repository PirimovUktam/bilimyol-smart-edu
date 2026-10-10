import { IAITutorService, AIExplanationResponse } from '@/data/services/IAITutorService';
import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { Question } from '../entities/Question';

export interface LessonAnswerResult {
  isCorrect: boolean;
  selectedOption: string;
  correctOption: string;
  explanation?: string;
  newSkillScore?: number;
  overallScore?: number;
  xpAwarded?: number;
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
    const selectedOption = question.options[selectedIndex] || '';

    let isCorrect = false;
    let correctOption = '';
    let explanation = '';
    let newSkillScore: number | undefined;
    let overallScore: number | undefined;
    let xpAwarded: number | undefined;

    if (this.learnerRepo) {
      if (typeof this.learnerRepo.submitAnswerAttempt === 'function') {
        const serverResult = await this.learnerRepo.submitAnswerAttempt({
          courseId: question.courseId,
          skillId: question.skillId,
          lessonId: lessonId || 'lesson_general',
          questionId: question.id,
          selectedIndex,
          selectedAnswer: selectedOption,
          idempotencyKey: `attempt_${lessonId || 'general'}_${question.id}_${selectedIndex}`,
        });

        isCorrect = serverResult.isCorrect;
        correctOption =
          serverResult.correctOption ||
          (serverResult.correctIndex !== undefined ? question.options[serverResult.correctIndex] || '' : '');
        explanation = serverResult.explanation;
        newSkillScore = serverResult.newSkillScore;
        overallScore = serverResult.overallScore;
        xpAwarded = serverResult.xpAwarded;
      } else {
        const knownIndex = question.correctIndex ?? 0;
        isCorrect = selectedIndex === knownIndex;
        correctOption = question.options[knownIndex] || '';
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
    } else {
      // Local fallback only if no repository injected
      const knownIndex = question.correctIndex ?? 0;
      isCorrect = selectedIndex === knownIndex;
      correctOption = question.options[knownIndex] || '';
    }

    if (isCorrect) {
      return {
        isCorrect: true,
        selectedOption,
        correctOption,
        explanation,
        newSkillScore,
        overallScore,
        xpAwarded,
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
      explanation,
      newSkillScore,
      overallScore,
      xpAwarded,
      aiExplanation,
    };
  }
}
