import { LearnerProfile } from '../entities/LearnerProfile';
import { SkillScore } from '../entities/SkillScore';

export interface AnswerAttemptRecord {
  id: string;
  userId?: string;
  courseId: string;
  skillId: string;
  lessonId?: string;
  questionId: string;
  selectedIndex: number;
  selectedAnswer: string;
  isCorrect: boolean;
  timestamp: number;
}

export interface PlacementAttemptSubmission {
  questionId: string;
  selectedIndex: number;
  isCorrect: boolean;
}

export interface PlacementAttemptData {
  courseId: string;
  score: number;
  weakestSkillId?: string;
  submissions: PlacementAttemptSubmission[];
}

export interface PlacementAnswerEvaluation {
  isCorrect: boolean;
}

export interface SubmitAnswerAttemptRequest {
  courseId: string;
  skillId: string;
  lessonId: string;
  questionId: string;
  selectedIndex: number;
  selectedAnswer: string;
  idempotencyKey?: string;
}

export interface SubmitAnswerAttemptResult {
  isCorrect: boolean;
  correctIndex?: number;
  correctOption?: string;
  explanation: string;
  newSkillScore: number;
  overallScore: number;
  xpAwarded: number;
  totalXp?: number;
  totalAttempts?: number;
  correctAttempts?: number;
  alreadyProcessed?: boolean;
}

export interface ReinforcementCompletionContext {
  courseId: string;
  skillId: string;
  questionId: string;
  beforeScore: number;
  afterScore: number;
  xpAwarded: number;
}

export interface ReinforcementCompletionResult {
  oldScore: number;
  newScore: number;
  xpAwarded: number;
  alreadyProcessed: boolean;
}

export interface DailyActivitySummary {
  date: string;
  activeMinutes: number;
  xpEarned: number;
  lessonsCompleted: number;
}

export interface ILearnerRepository {
  /**
   * In-memory repositories can persist roadmap-node completion locally. The
   * production contract currently persists lesson/reinforcement completion
   * through server RPCs, so callers must not manufacture a local success.
   */
  readonly supportsNodeCompletion?: boolean;
  /** Placement RPCs persist authoritative answers and completion rewards in one transaction. */
  readonly supportsServerPlacementPersistence?: boolean;
  /** Reinforcement RPCs persist authoritative scores, rewards and completion. */
  readonly supportsServerReinforcementPersistence?: boolean;
  getProfile(): Promise<LearnerProfile>;
  getCurrentProfile(): Promise<LearnerProfile>;
  updateProfile(updates: Partial<LearnerProfile>): Promise<LearnerProfile>;
  saveSkillScores(courseId: string, scores: Record<string, SkillScore>): Promise<void>;
  savePlacementAttempt(data: PlacementAttemptData): Promise<string>;
  evaluatePlacementAnswer(
    courseId: string,
    questionId: string,
    selectedIndex: number
  ): Promise<PlacementAnswerEvaluation>;
  markLessonCompleted(lessonId: string, courseId?: string | null): Promise<void>;
  markNodeCompleted(nodeId: string): Promise<void>;
  markReinforcementCompleted(reinforcementId: string, context?: ReinforcementCompletionContext): Promise<ReinforcementCompletionResult | void>;
  submitAnswerAttempt(request: SubmitAnswerAttemptRequest): Promise<SubmitAnswerAttemptResult>;
  recordAnswerAttempt(attempt: Omit<AnswerAttemptRecord, 'id' | 'timestamp'>): Promise<AnswerAttemptRecord>;
  getAnswerAttempts(limit?: number): Promise<AnswerAttemptRecord[]>;
  getDailyActivity(days?: number): Promise<DailyActivitySummary[]>;
  addXp(amount: number, actionIdempotencyKey?: string): Promise<number>;
  recordDailyActivity(dateStr?: string): Promise<number>;
  resetAll(): Promise<LearnerProfile>;
}
