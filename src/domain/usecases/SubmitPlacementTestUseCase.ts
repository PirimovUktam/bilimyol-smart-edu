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

    // Compute deterministic scores
    const computedScores = SkillScoringEngine.computePlacementScores(courseId, questions, submissions);

    // Save scores into learner repository
    await this.learnerRepo.saveSkillScores(courseId, computedScores);

    // Find weakest skill
    let weakestSkillId = '';
    let minScore = 101;
    Object.values(computedScores).forEach((s) => {
      if (s.score < minScore) {
        minScore = s.score;
        weakestSkillId = s.skillId;
      }
    });

    return {
      assessmentId: `placement_${courseId}`,
      courseId,
      submissions,
      computedScores,
      weakestSkillId,
      timestamp: Date.now(),
    };
  }
}
