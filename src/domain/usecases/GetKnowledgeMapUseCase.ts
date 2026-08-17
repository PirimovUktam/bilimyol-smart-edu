import { ICourseRepository } from '../repositories/ICourseRepository';
import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { Skill } from '../entities/Skill';
import { SkillScore } from '../entities/SkillScore';
import { SkillScoringEngine } from '../personalization/SkillScoringEngine';

export interface KnowledgeMapData {
  courseId: string;
  skills: Skill[];
  scores: Record<string, SkillScore>;
  weakestSkill: SkillScore | null;
  strongestSkill: SkillScore | null;
  overallScore: number;
}

export class GetKnowledgeMapUseCase {
  constructor(
    private courseRepo: ICourseRepository,
    private learnerRepo: ILearnerRepository
  ) {}

  async execute(courseId: string): Promise<KnowledgeMapData> {
    const skills = await this.courseRepo.getSkillsByCourseId(courseId);
    const profile = await this.learnerRepo.getProfile();
    const scores = profile.scoresByCourse[courseId] || {};

    let weakestSkill: SkillScore | null = null;
    let strongestSkill: SkillScore | null = null;

    Object.values(scores).forEach((s) => {
      if (!weakestSkill || s.score < weakestSkill.score) {
        weakestSkill = s;
      }
      if (!strongestSkill || s.score > strongestSkill.score) {
        strongestSkill = s;
      }
    });

    const overallScore = SkillScoringEngine.computeOverallScore(scores);

    return {
      courseId,
      skills,
      scores,
      weakestSkill,
      strongestSkill,
      overallScore,
    };
  }
}
