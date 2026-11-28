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
    if (baseNodes.some((node) => node.mastery)) {
      try {
        const profile = await this.learnerRepo.getProfile();
        const combinedScores = {
          ...(profile.placementSkillScoresByCourse?.[courseId] ?? {}),
          ...(profile.scoresByCourse[courseId] ?? {}),
        };
        return RouteEngine.adaptRoadmap(courseId, baseNodes, combinedScores, [], [], {
          goal: profile.goal,
          dailyMinutes: profile.dailyMinutes,
        });
      } catch {
        return RouteEngine.adaptRoadmap(courseId, baseNodes, {}, [], []);
      }
    }
    const profile = await this.learnerRepo.getProfile();
    const scores =
      courseId !== 'course_eng_01'
        ? {
            ...(profile.placementSkillScoresByCourse?.[courseId] ?? {}),
            ...(profile.scoresByCourse[courseId] ?? {}),
          }
        : (profile.scoresByCourse[courseId] || {});

    return RouteEngine.adaptRoadmap(
      courseId,
      baseNodes,
      scores,
      profile.completedNodeIds || [],
      profile.completedReinforcementIds || [],
      {
        placementCefr: profile.placementCefrByCourse?.[courseId],
        goal: profile.goal,
        dailyMinutes: profile.dailyMinutes,
      }
    );
  }
}
