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
    if (reinforcementQuestion.courseId !== courseId || reinforcementQuestion.skillId !== skillId) {
      throw new Error('Mustahkamlash savoli kurs va ko‘nikma bilan mos emas.');
    }
    if (!Number.isInteger(selectedIndex) || selectedIndex < 0 || selectedIndex >= reinforcementQuestion.options.length) {
      throw new Error('Tanlangan javob indeksi noto‘g‘ri.');
    }

    // The learner payload is intentionally answer-key-free. Evaluation must
    // go through the repository's server-authoritative contract; never trust a
    // client-side correctIndex (or default to one when it is absent).
    const profile = await this.learnerRepo.getProfile();
    const courseScores = profile.scoresByCourse[courseId] || {};
    const currentSkillScore = courseScores[skillId]?.score ?? 0;
    const answerResult = await this.learnerRepo.submitAnswerAttempt({
      courseId,
      skillId,
      lessonId: reinforcementNodeId,
      questionId: reinforcementQuestion.id,
      selectedIndex,
      selectedAnswer: reinforcementQuestion.options[selectedIndex] || '',
      idempotencyKey: `reinforcement_${reinforcementNodeId}_${reinforcementQuestion.id}_${selectedIndex}`,
    });
    const isCorrect = answerResult.isCorrect;

    if (!isCorrect) {
      const currentProfile = this.learnerRepo.supportsServerReinforcementPersistence
        ? await this.learnerRepo.getProfile()
        : profile;
      const currentScores = currentProfile.scoresByCourse[courseId] || {};
      const baseNodes = await this.lessonRepo.getBaseRoadmapNodes(courseId);
      const currentRoadmap = RouteEngine.adaptRoadmap(
        courseId,
        baseNodes,
        currentScores,
        currentProfile.completedNodeIds,
        currentProfile.completedReinforcementIds
      );
      return {
        isCorrect: false,
        oldScore: currentSkillScore,
        newScore: currentScores[skillId]?.score ?? 0,
        xpAwarded: 0,
        updatedRoadmap: currentRoadmap,
      };
    }

    if (this.learnerRepo.supportsServerReinforcementPersistence) {
      // The server ignores legacy score/XP hints and persists the complete
      // transaction. Only its result may describe the awarded score and XP.
      const completion = await this.learnerRepo.markReinforcementCompleted(reinforcementNodeId, {
        courseId,
        skillId,
        questionId: reinforcementQuestion.id,
        beforeScore: currentSkillScore,
        afterScore: currentSkillScore,
        xpAwarded: 0,
      });
      if (!completion) {
        throw new Error('Mustahkamlash server natijasi yetishmaydi.');
      }
      const updatedProfile = await this.learnerRepo.getProfile();
      const baseNodes = await this.lessonRepo.getBaseRoadmapNodes(courseId);
      return {
        isCorrect: true,
        oldScore: completion.oldScore,
        newScore: completion.newScore,
        xpAwarded: completion.alreadyProcessed ? 0 : completion.xpAwarded,
        updatedRoadmap: RouteEngine.adaptRoadmap(
          courseId,
          baseNodes,
          updatedProfile.scoresByCourse[courseId] || {},
          updatedProfile.completedNodeIds,
          updatedProfile.completedReinforcementIds
        ),
      };
    }

    // 1. Calculate new score deterministically
    const newScore = SkillScoringEngine.calculateReinforcementScore(currentSkillScore);

    // 2. Calculate XP idempotently BEFORE writes so the audit row stores real values
    const { newXP, wasAwarded } = ProgressEngine.calculateNewXP(
      profile.xp,
      'reinforcement_completion',
      reinforcementNodeId,
      profile.completedReinforcementIds
    );
    const xpAwarded = wasAwarded ? Math.max(0, newXP - profile.xp) : 0;

    // 3. Mark reinforcement node as completed with full course context
    await this.learnerRepo.markReinforcementCompleted(reinforcementNodeId, {
      courseId,
      skillId,
      questionId: reinforcementQuestion.id,
      beforeScore: currentSkillScore,
      afterScore: newScore,
      xpAwarded,
    });

    // Also mark the target node as completed so downstream unlocks
    const targetNodeId = reinforcementNodeId.replace('reinf_', '');
    // The server completion RPC is authoritative in production. Do not mark a
    // roadmap node as completed in an in-memory cache after a remote success;
    // that would make the UI report a state the server cannot reproduce.
    if (this.learnerRepo.supportsNodeCompletion !== false) {
      await this.learnerRepo.markNodeCompleted(targetNodeId);
    }

    // 4. Save new score
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
      xpAwarded,
      updatedRoadmap,
    };
  }
}
