import { ICourseRepository } from '../repositories/ICourseRepository';
import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { Skill } from '../entities/Skill';
import { SkillScore } from '../entities/SkillScore';

export interface KnowledgeMapData {
  courseId: string;
  skills: Skill[];
  scores: Record<string, SkillScore>;
  weakestSkill: SkillScore | null;
  averageScore: number;
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
    let totalScore = 0;
    let count = 0;

    Object.values(scores).forEach((s) => {
      totalScore += s.score;
      count += 1;
      if (!weakestSkill || s.score < weakestSkill.score) {
        weakestSkill = s;
      }
    });

    return {
      courseId,
      skills,
      scores,
      weakestSkill,
      averageScore: count > 0 ? Math.round(totalScore / count) : 0,
    };
  }
}
