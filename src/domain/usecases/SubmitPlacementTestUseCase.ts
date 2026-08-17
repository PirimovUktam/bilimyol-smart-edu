import { ICourseRepository } from '../repositories/ICourseRepository';
import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { QuestionAnswerSubmission } from '../entities/Question';
import { AssessmentResult } from '../entities/Assessment';
import { SkillScoringEngine } from '../personalization/SkillScoringEngine';

export class SubmitPlacementTestUseCase {
  constructor(
    private courseRepo: ICourseRepository,
    private learnerRepo: ILearnerRepository
  ) {}

  async execute(courseId: string, submissions: QuestionAnswerSubmission[]): Promise<AssessmentResult> {
    const questions = await this.courseRepo.getPlacementQuestions(courseId);

    // Record answer attempts for audit and logging
    for (const sub of submissions) {
      const q = questions.find((item) => item.id === sub.questionId);
      if (q) {
        await this.learnerRepo.recordAnswerAttempt({
          courseId,
          skillId: q.skillId,
          lessonId: 'placement_test',
          questionId: q.id,
          selectedIndex: sub.selectedIndex,
          selectedAnswer: q.options[sub.selectedIndex] || '',
          isCorrect: sub.isCorrect,
        });
      }
    }

    // Compute real scores strictly from actual submissions
    const computedScores = SkillScoringEngine.computePlacementScores(courseId, questions, submissions);
    const overallScore = SkillScoringEngine.computeOverallScore(computedScores);

    // Find weakest skill dynamically
    let weakestSkillId = '';
    let minScore = 101;
    Object.values(computedScores).forEach((s) => {
      if (s.score < minScore) {
        minScore = s.score;
        weakestSkillId = s.skillId;
      }
    });

    // Save placement attempt & individual answers to Supabase / repository
    const attemptId = await this.learnerRepo.savePlacementAttempt({
      courseId,
      score: overallScore,
      weakestSkillId,
      submissions: submissions.map((s) => ({
        questionId: s.questionId,
        selectedIndex: s.selectedIndex,
        isCorrect: s.isCorrect,
      })),
    });

    // Save scores into learner repository
    await this.learnerRepo.saveSkillScores(courseId, computedScores);

    // Award +20 XP for completing placement test (idempotent)
    await this.learnerRepo.addXp(20, `placement_completed_${courseId}`);
    await this.learnerRepo.recordDailyActivity();

    return {
      assessmentId: attemptId || `placement_${courseId}`,
      courseId,
      submissions,
      computedScores,
      weakestSkillId,
      timestamp: Date.now(),
    };
  }
}
