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

export interface ILearnerRepository {
  getProfile(): Promise<LearnerProfile>;
  updateProfile(updates: Partial<LearnerProfile>): Promise<LearnerProfile>;
  saveSkillScores(courseId: string, scores: Record<string, SkillScore>): Promise<void>;
  savePlacementAttempt(data: PlacementAttemptData): Promise<string>;
  markLessonCompleted(lessonId: string): Promise<void>;
  markNodeCompleted(nodeId: string): Promise<void>;
  markReinforcementCompleted(reinforcementId: string): Promise<void>;
  recordAnswerAttempt(attempt: Omit<AnswerAttemptRecord, 'id' | 'timestamp'>): Promise<AnswerAttemptRecord>;
  getAnswerAttempts(limit?: number): Promise<AnswerAttemptRecord[]>;
  addXp(amount: number, actionIdempotencyKey?: string): Promise<number>;
  recordDailyActivity(dateStr?: string): Promise<number>;
  resetAll(): Promise<LearnerProfile>;
}
