import {
  ILearnerRepository,
  AnswerAttemptRecord,
  PlacementAttemptData,
  ReinforcementCompletionContext,
  SubmitAnswerAttemptRequest,
  SubmitAnswerAttemptResult,
} from '@/domain/repositories/ILearnerRepository';
import { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { SkillScore } from '@/domain/entities/SkillScore';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { PLACEMENT_QUESTIONS } from '@/data/datasources/questions';
import { SEED_LESSONS } from '@/data/datasources/lessons';

const DEFAULT_PROFILE: LearnerProfile = {
  id: 'learner_default_01',
  name: 'Foydalanuvchi',
  firstName: 'Foydalanuvchi',
  lastName: '',
  email: '',
  selectedCourseId: 'course_math_01',
  goal: 'mastery',
  dailyMinutes: 15,
  initialLevel: 'intermediate',
  xp: 0,
  streakDays: 1,
  lastActiveDate: new Date().toISOString().split('T')[0],
  scoresByCourse: {},
  completedLessonIds: [],
  completedNodeIds: [],
  completedReinforcementIds: [],
  createdAt: Date.now(),
};

// Deep clone: DEFAULT_PROFILE's nested objects/arrays must NEVER be shared
// between repository instances (shallow spreads leaked completed-node and
// score state across instances — a cross-profile data leak).
const createDefaultProfile = (): LearnerProfile =>
  JSON.parse(JSON.stringify(DEFAULT_PROFILE)) as LearnerProfile;

export class InMemoryLearnerRepository implements ILearnerRepository {
  private profile: LearnerProfile = createDefaultProfile();
  private answerAttempts: AnswerAttemptRecord[] = [];
  private processedActionKeys: Set<string> = new Set();
  private recordedActivityDates: Set<string> = new Set();

  async getCurrentProfile(): Promise<LearnerProfile> {
    return this.getProfile();
  }

  async getProfile(): Promise<LearnerProfile> {
    return JSON.parse(JSON.stringify(this.profile));
  }

  async updateProfile(updates: Partial<LearnerProfile>): Promise<LearnerProfile> {
    this.profile = {
      ...this.profile,
      ...updates,
      scoresByCourse: updates.scoresByCourse || this.profile.scoresByCourse,
    };
    return this.getProfile();
  }

  async saveSkillScores(courseId: string, scores: Record<string, SkillScore>): Promise<void> {
    if (!this.profile.scoresByCourse) {
      this.profile.scoresByCourse = {};
    }
    this.profile.scoresByCourse[courseId] = {
      ...(this.profile.scoresByCourse[courseId] || {}),
      ...scores,
    };
  }

  async savePlacementAttempt(_data: PlacementAttemptData): Promise<string> {
    const attemptId = 'plc_att_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
    return attemptId;
  }

  async markLessonCompleted(lessonId: string, _courseId?: string | null): Promise<void> {
    if (!this.profile.completedLessonIds.includes(lessonId)) {
      this.profile.completedLessonIds.push(lessonId);
      await this.addXp(20, `lesson_completed_${lessonId}`);
      await this.recordDailyActivity();
    }
  }

  async markNodeCompleted(nodeId: string): Promise<void> {
    if (!this.profile.completedNodeIds.includes(nodeId)) {
      this.profile.completedNodeIds.push(nodeId);
    }
  }

  async markReinforcementCompleted(reinforcementId: string, _context?: ReinforcementCompletionContext): Promise<void> {
    if (!this.profile.completedReinforcementIds.includes(reinforcementId)) {
      this.profile.completedReinforcementIds.push(reinforcementId);
      await this.addXp(15, `reinforcement_completed_${reinforcementId}`);
      await this.recordDailyActivity();
    }
  }

  async submitAnswerAttempt(request: SubmitAnswerAttemptRequest): Promise<SubmitAnswerAttemptResult> {
    const idempotencyKey = request.idempotencyKey || `${request.lessonId}:${request.questionId}:${request.selectedIndex}`;
    if (this.processedActionKeys.has(idempotencyKey)) {
      const existing = this.answerAttempts.find(
        (a) => a.questionId === request.questionId && a.selectedIndex === request.selectedIndex
      );
      const skillScore = this.profile.scoresByCourse[request.courseId]?.[request.skillId]?.score ?? 50;
      const overall = SkillScoringEngine.computeOverallScore(this.profile.scoresByCourse[request.courseId] || {});
      return {
        isCorrect: existing ? existing.isCorrect : false,
        explanation: 'Javob avval qayd etilgan.',
        newSkillScore: skillScore,
        overallScore: overall,
        xpAwarded: 0,
        totalXp: this.profile.xp,
        alreadyProcessed: true,
      };
    }

    // Server-side lookup of the question's true correct index
    let correctIndex: number | undefined;
    let correctOption: string | undefined;
    let explanation = 'To‘g‘ri yechim va pedagogik tushuntirish.';

    // 1. Check placement questions
    for (const qList of Object.values(PLACEMENT_QUESTIONS)) {
      const found = qList.find((q) => q.id === request.questionId);
      if (found) {
        correctIndex = found.correctIndex;
        explanation = found.explanation;
        if (correctIndex !== undefined && found.options[correctIndex]) {
          correctOption = found.options[correctIndex];
        }
        break;
      }
    }

    // 2. Check seed lessons questions
    if (correctIndex === undefined) {
      for (const lesson of Object.values(SEED_LESSONS)) {
        if (lesson.reinforcementExercise && lesson.reinforcementExercise.id === request.questionId) {
          correctIndex = lesson.reinforcementExercise.correctIndex;
          explanation = lesson.reinforcementExercise.explanation;
          if (correctIndex !== undefined && lesson.reinforcementExercise.options[correctIndex]) {
            correctOption = lesson.reinforcementExercise.options[correctIndex];
          }
          break;
        }
        for (const step of lesson.steps) {
          if (step.interactiveQuestion && step.interactiveQuestion.id === request.questionId) {
            correctIndex = step.interactiveQuestion.correctIndex;
            explanation = step.interactiveQuestion.explanation;
            if (correctIndex !== undefined && step.interactiveQuestion.options[correctIndex]) {
              correctOption = step.interactiveQuestion.options[correctIndex];
            }
            break;
          }
        }
        if (correctIndex !== undefined) break;
      }
    }

    // Anti-cheat verification: If question is unknown, do NOT assume 0
    const isCorrect = correctIndex !== undefined ? request.selectedIndex === correctIndex : false;

    this.processedActionKeys.add(idempotencyKey);

    const record: AnswerAttemptRecord = {
      id: 'att_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5),
      userId: this.profile.id,
      courseId: request.courseId,
      skillId: request.skillId,
      lessonId: request.lessonId,
      questionId: request.questionId,
      selectedIndex: request.selectedIndex,
      selectedAnswer: request.selectedAnswer,
      isCorrect,
      timestamp: Date.now(),
    };
    this.answerAttempts.push(record);

    let xpAwarded = 0;
    if (isCorrect) {
      xpAwarded = 2;
      this.profile.xp = (this.profile.xp || 0) + 2;
    }
    await this.recordDailyActivity();

    // Recalculate skill score
    const skillAttempts = this.answerAttempts.filter(
      (a) => a.courseId === request.courseId && a.skillId === request.skillId
    );
    const correctCount = skillAttempts.filter((a) => a.isCorrect).length;
    const newScoreVal = SkillScoringEngine.computeSkillScore(correctCount, skillAttempts.length);

    if (!this.profile.scoresByCourse[request.courseId]) {
      this.profile.scoresByCourse[request.courseId] = {};
    }

    this.profile.scoresByCourse[request.courseId][request.skillId] = {
      skillId: request.skillId,
      courseId: request.courseId,
      score: newScoreVal,
      lastUpdated: Date.now(),
      masteryLevel: SkillScoringEngine.getMasteryLevel(newScoreVal),
    };

    const overallScore = SkillScoringEngine.computeOverallScore(this.profile.scoresByCourse[request.courseId] || {});

    return {
      isCorrect,
      correctIndex,
      correctOption,
      explanation,
      newSkillScore: newScoreVal,
      overallScore,
      xpAwarded,
      totalXp: this.profile.xp,
      totalAttempts: skillAttempts.length,
      correctAttempts: correctCount,
      alreadyProcessed: false,
    };
  }

  async recordAnswerAttempt(attempt: Omit<AnswerAttemptRecord, 'id' | 'timestamp'>): Promise<AnswerAttemptRecord> {
    const record: AnswerAttemptRecord = {
      ...attempt,
      id: 'att_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5),
      timestamp: Date.now(),
    };
    this.answerAttempts.push(record);

    // If answer is correct, award +2 XP idempotently
    if (attempt.isCorrect) {
      await this.addXp(2, `answer_${attempt.questionId}_${record.id}`);
    }
    await this.recordDailyActivity();

    // Recalculate cumulative skill score for this skill
    const skillAttempts = this.answerAttempts.filter(
      (a) => a.courseId === attempt.courseId && a.skillId === attempt.skillId
    );
    const correctCount = skillAttempts.filter((a) => a.isCorrect).length;
    const newScoreVal = SkillScoringEngine.computeSkillScore(correctCount, skillAttempts.length);

    if (!this.profile.scoresByCourse[attempt.courseId]) {
      this.profile.scoresByCourse[attempt.courseId] = {};
    }

    this.profile.scoresByCourse[attempt.courseId][attempt.skillId] = {
      skillId: attempt.skillId,
      courseId: attempt.courseId,
      score: newScoreVal,
      lastUpdated: Date.now(),
      masteryLevel: SkillScoringEngine.getMasteryLevel(newScoreVal),
    };

    return record;
  }

  async getAnswerAttempts(limit: number = 10): Promise<AnswerAttemptRecord[]> {
    return [...this.answerAttempts].slice(-limit);
  }

  async addXp(amount: number, actionIdempotencyKey?: string): Promise<number> {
    if (actionIdempotencyKey) {
      if (this.processedActionKeys.has(actionIdempotencyKey)) {
        return this.profile.xp;
      }
      this.processedActionKeys.add(actionIdempotencyKey);
    }
    this.profile.xp = (this.profile.xp || 0) + amount;
    return this.profile.xp;
  }

  async recordDailyActivity(dateStr?: string): Promise<number> {
    const today = dateStr || new Date().toISOString().split('T')[0];

    if (this.recordedActivityDates.has(today)) {
      return this.profile.streakDays;
    }

    this.recordedActivityDates.add(today);

    const lastDate = this.profile.lastActiveDate;
    if (!lastDate) {
      this.profile.streakDays = 1;
    } else if (lastDate === today) {
      // Same day, streak unchanged
    } else {
      const prevMs = new Date(lastDate).getTime();
      const currMs = new Date(today).getTime();
      const diffDays = Math.round((currMs - prevMs) / (1000 * 60 * 60 * 24));

      if (diffDays === 1) {
        this.profile.streakDays = (this.profile.streakDays || 0) + 1;
      } else {
        this.profile.streakDays = 1;
      }
    }

    this.profile.lastActiveDate = today;
    return this.profile.streakDays;
  }

  async resetAll(): Promise<LearnerProfile> {
    this.profile = createDefaultProfile();
    this.answerAttempts = [];
    this.processedActionKeys.clear();
    this.recordedActivityDates.clear();
    return this.getProfile();
  }
}

export const inMemoryLearnerRepository = new InMemoryLearnerRepository();
