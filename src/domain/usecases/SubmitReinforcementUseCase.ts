import { ILearnerRepository, SubmitAnswerAttemptResult } from '../repositories/ILearnerRepository';
import { ILessonRepository } from '../repositories/ILessonRepository';
import { Question } from '../entities/Question';
import { SkillScoringEngine } from '../personalization/SkillScoringEngine';
import { ProgressEngine } from '../personalization/ProgressEngine';
import { RouteEngine } from '../personalization/RouteEngine';
import { LearningPath } from '../entities/LearningPathNode';
import { generateAttemptUuid } from '@/core/utils/attemptUuid';

export interface ReinforcementResult {
  isCorrect: boolean;
  oldScore: number;
  newScore: number;
  xpAwarded: number;
  updatedRoadmap: LearningPath;
  /** Present when the attempt was wrong — surfaced to the learner as feedback. */
  correctOption?: string;
  explanation?: string;
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
    selectedIndex: number,
    selectedAnswerOverride?: string,
    language: 'uz' | 'ru' = 'uz',
    attemptOptions?: {
      idempotencyKey?: string;
      cachedAttemptResult?: SubmitAnswerAttemptResult;
      onAttemptGraded?: (result: SubmitAnswerAttemptResult) => void;
    },
  ): Promise<ReinforcementResult> {
    if (reinforcementQuestion.courseId !== courseId || reinforcementQuestion.skillId !== skillId) {
      throw new Error('Mustahkamlash savoli kurs va ko‘nikma bilan mos emas.');
    }
    const qType = reinforcementQuestion.questionType ?? 'multiple_choice';
    const isChoiceType =
      qType === 'multiple_choice' || qType === 'error_correction' || qType === 'conversation_completion';
    if (isChoiceType && (!Number.isInteger(selectedIndex) || selectedIndex < 0 || selectedIndex >= reinforcementQuestion.options.length)) {
      throw new Error('Tanlangan javob indeksi noto‘g‘ri.');
    }
    if (!isChoiceType && typeof selectedAnswerOverride !== 'string') {
      throw new Error('Mustahkamlash javobi kiritilmadi.');
    }

    // The learner payload is intentionally answer-key-free. Evaluation must
    // go through the repository's server-authoritative contract; never trust a
    // client-side correctIndex (or default to one when it is absent).
    const profile = await this.learnerRepo.getProfile();
    const courseScores = profile.scoresByCourse[courseId] || {};
    const hadPriorSkillScore = Object.prototype.hasOwnProperty.call(courseScores, skillId);
    const currentSkillScore = courseScores[skillId]?.score ?? 0;
    const resolveEffectiveScores = (p: typeof profile) =>
      courseId !== 'course_eng_01'
        ? { ...(p.placementSkillScoresByCourse?.[courseId] ?? {}), ...(p.scoresByCourse[courseId] ?? {}) }
        : (p.scoresByCourse[courseId] ?? {});
    const selectedAnswer = isChoiceType
      ? reinforcementQuestion.options[selectedIndex] || ''
      : (selectedAnswerOverride ?? '');
    const answerResult =
      attemptOptions?.cachedAttemptResult ??
      (await this.learnerRepo.submitAnswerAttempt({
        courseId,
        skillId,
        lessonId: reinforcementNodeId,
        questionId: reinforcementQuestion.id,
        selectedIndex: isChoiceType ? selectedIndex : 0,
        selectedAnswer,
        questionType: reinforcementQuestion.questionType,
        evaluationMode: reinforcementQuestion.evaluationMode,
        language,
        idempotencyKey: attemptOptions?.idempotencyKey ?? generateAttemptUuid(),
      }));
    if (!attemptOptions?.cachedAttemptResult) {
      attemptOptions?.onAttemptGraded?.(answerResult);
    }
    const isCorrect = answerResult.isCorrect;

    if (!isCorrect) {
      const currentProfile = this.learnerRepo.supportsServerReinforcementPersistence
        ? await this.learnerRepo.getProfile()
        : profile;
      const currentScores = resolveEffectiveScores(currentProfile);
      const baseNodes = await this.lessonRepo.getBaseRoadmapNodes(courseId);
      const currentRoadmap = RouteEngine.adaptRoadmap(
        courseId,
        baseNodes,
        currentScores,
        currentProfile.completedNodeIds,
        currentProfile.completedReinforcementIds,
        {
          placementCefr: currentProfile.placementCefrByCourse?.[courseId],
          goal: currentProfile.goal,
          dailyMinutes: currentProfile.dailyMinutes,
        }
      );
      return {
        isCorrect: false,
        oldScore: currentSkillScore,
        newScore: currentScores[skillId]?.score ?? 0,
        xpAwarded: 0,
        updatedRoadmap: currentRoadmap,
        correctOption: answerResult.correctOption,
        explanation: answerResult.explanation,
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
          resolveEffectiveScores(updatedProfile),
          updatedProfile.completedNodeIds,
          updatedProfile.completedReinforcementIds,
          {
            placementCefr: updatedProfile.placementCefrByCourse?.[courseId],
            goal: updatedProfile.goal,
            dailyMinutes: updatedProfile.dailyMinutes,
          }
        ),
      };
    }

    // 1. Calculate new score deterministically (preserving multi-skill parent remediation parity)
    const postAttemptProfile = await this.learnerRepo.getProfile();
    const baseNodes = await this.lessonRepo.getBaseRoadmapNodes(courseId);
    const parentBase = baseNodes.find(
      (n) => !n.isReinforcement && (reinforcementNodeId === `reinf_${n.id}` || n.id === reinforcementNodeId)
    );
    const isMultiSkillParent = Boolean(parentBase && parentBase.skillId !== skillId);
    const postAttemptSkillScore =
      postAttemptProfile.scoresByCourse[courseId]?.[skillId]?.score ??
      answerResult.newSkillScore ??
      0;
    const bumpedSkillScore = SkillScoringEngine.calculateReinforcementScore(currentSkillScore);
    const exerciseNewScore = isMultiSkillParent
      ? hadPriorSkillScore
        ? Math.max(postAttemptSkillScore, bumpedSkillScore)
        : Math.max(50, postAttemptSkillScore, bumpedSkillScore)
      : bumpedSkillScore;

    const parentExisting =
      isMultiSkillParent && parentBase ? courseScores[parentBase.skillId] : undefined;
    const remediateParent = Boolean(
      parentBase && parentExisting && parentExisting.score < parentBase.requiredScore
    );
    const parentOldScore = parentExisting?.score ?? 0;
    const parentNewScore = remediateParent
      ? SkillScoringEngine.calculateReinforcementScore(parentOldScore)
      : parentOldScore;
    const reportedOldScore =
      remediateParent && (!hadPriorSkillScore || currentSkillScore >= (parentBase?.requiredScore ?? 50))
        ? parentOldScore
        : currentSkillScore;
    const reportedNewScore =
      remediateParent && (!hadPriorSkillScore || currentSkillScore >= (parentBase?.requiredScore ?? 50))
        ? parentNewScore
        : exerciseNewScore;

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
      beforeScore: reportedOldScore,
      afterScore: reportedNewScore,
      xpAwarded,
    });

    // 4. Save new score (and remediate parent node's weak skill when exercise skill differs)
    const now = Date.now();
    const scoresToSave: Record<string, typeof courseScores[string]> = {
      [skillId]: {
        skillId,
        courseId,
        score: exerciseNewScore,
        lastUpdated: now,
        masteryLevel: SkillScoringEngine.getMasteryLevel(exerciseNewScore),
        isWeakestFocus: false,
      },
    };
    if (remediateParent && parentBase) {
      scoresToSave[parentBase.skillId] = {
        skillId: parentBase.skillId,
        courseId,
        score: parentNewScore,
        lastUpdated: now,
        masteryLevel: SkillScoringEngine.getMasteryLevel(parentNewScore),
        isWeakestFocus: false,
      };
    }

    await this.learnerRepo.saveSkillScores(courseId, scoresToSave);

    if (wasAwarded) {
      await this.learnerRepo.updateProfile({ xp: newXP });
    }

    // 5. Adapt updated roadmap
    const updatedProfile = await this.learnerRepo.getProfile();
    const updatedScores = resolveEffectiveScores(updatedProfile);

    const updatedRoadmap = RouteEngine.adaptRoadmap(
      courseId,
      baseNodes,
      updatedScores,
      updatedProfile.completedNodeIds,
      updatedProfile.completedReinforcementIds,
      {
        placementCefr: updatedProfile.placementCefrByCourse?.[courseId],
        goal: updatedProfile.goal,
        dailyMinutes: updatedProfile.dailyMinutes,
      }
    );

    return {
      isCorrect: true,
      oldScore: reportedOldScore,
      newScore: reportedNewScore,
      xpAwarded,
      updatedRoadmap,
    };
  }
}
