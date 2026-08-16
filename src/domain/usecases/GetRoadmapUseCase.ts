import { ILessonRepository } from '../repositories/ILessonRepository';
import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { LearningPath } from '../entities/LearningPathNode';
import { RouteEngine } from '../personalization/RouteEngine';

export class GetRoadmapUseCase {
  constructor(
    private lessonRepo: ILessonRepository,
    private learnerRepo: ILearnerRepository
  ) {}

  async execute(courseId: string): Promise<LearningPath> {
    const baseNodes = await this.lessonRepo.getBaseRoadmapNodes(courseId);
    const profile = await this.learnerRepo.getProfile();
    const scores = profile.scoresByCourse[courseId] || {};

    return RouteEngine.adaptRoadmap(
      courseId,
      baseNodes,
      scores,
      profile.completedNodeIds || [],
      profile.completedReinforcementIds || []
    );
  }
}
