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
  beforeScore: number;
  afterScore: number;
  xpAwarded: number;
}

export interface ILearnerRepository {
  getProfile(): Promise<LearnerProfile>;
  getCurrentProfile(): Promise<LearnerProfile>;
  updateProfile(updates: Partial<LearnerProfile>): Promise<LearnerProfile>;
  saveSkillScores(courseId: string, scores: Record<string, SkillScore>): Promise<void>;
  savePlacementAttempt(data: PlacementAttemptData): Promise<string>;
  markLessonCompleted(lessonId: string, courseId?: string | null): Promise<void>;
  markNodeCompleted(nodeId: string): Promise<void>;
  markReinforcementCompleted(reinforcementId: string, context?: ReinforcementCompletionContext): Promise<void>;
  submitAnswerAttempt(request: SubmitAnswerAttemptRequest): Promise<SubmitAnswerAttemptResult>;
  recordAnswerAttempt(attempt: Omit<AnswerAttemptRecord, 'id' | 'timestamp'>): Promise<AnswerAttemptRecord>;
  getAnswerAttempts(limit?: number): Promise<AnswerAttemptRecord[]>;
  addXp(amount: number, actionIdempotencyKey?: string): Promise<number>;
  recordDailyActivity(dateStr?: string): Promise<number>;
  resetAll(): Promise<LearnerProfile>;
}
