import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { ILessonRepository } from '../repositories/ILessonRepository';
import { Question } from '../entities/Question';
import { SkillScoringEngine } from '../personalization/SkillScoringEngine';
import { ProgressEngine } from '../personalization/ProgressEngine';
import { RouteEngine } from '../personalization/RouteEngine';
import { LearningPath } from '../entities/LearningPathNode';

export interface ReinforcementResult {
  isCorrect: boolean;
  oldScore: number;
  newScore: number;
  xpAwarded: number;
  updatedRoadmap: LearningPath;
}

export class SubmitReinforcementUseCase {
  constructor(
    private learnerRepo: ILearnerRepository,
    private lessonRepo: ILessonRepository
  ) {}

  async execute(
    courseId: string,
    skillId: string,
    reinforcementNodeId: string,
    reinforcementQuestion: Question,
    selectedIndex: number
  ): Promise<ReinforcementResult> {
    const isCorrect = selectedIndex === reinforcementQuestion.correctIndex;
    const profile = await this.learnerRepo.getProfile();
    const courseScores = profile.scoresByCourse[courseId] || {};
    const currentSkillScore = courseScores[skillId]?.score ?? 0;

    // Record answer attempt in audit log
    await this.learnerRepo.recordAnswerAttempt({
      courseId,
      skillId,
      lessonId: reinforcementNodeId,
      questionId: reinforcementQuestion.id,
      selectedIndex,
      selectedAnswer: reinforcementQuestion.options[selectedIndex] || '',
      isCorrect,
    });

    if (!isCorrect) {
      const baseNodes = await this.lessonRepo.getBaseRoadmapNodes(courseId);
      const currentRoadmap = RouteEngine.adaptRoadmap(
        courseId,
        baseNodes,
        courseScores,
        profile.completedNodeIds,
        profile.completedReinforcementIds
      );
      return {
        isCorrect: false,
        oldScore: currentSkillScore,
        newScore: currentSkillScore,
        xpAwarded: 0,
        updatedRoadmap: currentRoadmap,
      };
    }

    // 1. Calculate new score deterministically
    const newScore = SkillScoringEngine.calculateReinforcementScore(currentSkillScore);

    // 2. Mark reinforcement node as completed
    await this.learnerRepo.markReinforcementCompleted(reinforcementNodeId);

    // Also mark the target node as completed so downstream unlocks
    const targetNodeId = reinforcementNodeId.replace('reinf_', '');
    await this.learnerRepo.markNodeCompleted(targetNodeId);

    // 3. Save new score
    const updatedSkillScore = {
      skillId,
      courseId,
      score: newScore,
      lastUpdated: Date.now(),
      masteryLevel: SkillScoringEngine.getMasteryLevel(newScore),
      isWeakestFocus: false,
    };

    await this.learnerRepo.saveSkillScores(courseId, {
      [skillId]: updatedSkillScore,
    });

    // 4. Calculate XP idempotently
    const { newXP, wasAwarded } = ProgressEngine.calculateNewXP(
      profile.xp,
      'reinforcement_completion',
      reinforcementNodeId,
      profile.completedReinforcementIds
    );

    if (wasAwarded) {
      await this.learnerRepo.updateProfile({ xp: newXP });
    }

    // 5. Adapt updated roadmap
    const updatedProfile = await this.learnerRepo.getProfile();
    const baseNodes = await this.lessonRepo.getBaseRoadmapNodes(courseId);
    const updatedScores = updatedProfile.scoresByCourse[courseId] || {};

    const updatedRoadmap = RouteEngine.adaptRoadmap(
      courseId,
      baseNodes,
      updatedScores,
      updatedProfile.completedNodeIds,
      updatedProfile.completedReinforcementIds
    );

    return {
      isCorrect: true,
      oldScore: currentSkillScore,
      newScore,
      xpAwarded: wasAwarded ? 30 : 0,
      updatedRoadmap,
    };
  }
}
