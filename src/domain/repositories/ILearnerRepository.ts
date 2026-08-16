import { LearnerProfile } from '../entities/LearnerProfile';
import { SkillScore } from '../entities/SkillScore';

export interface ILearnerRepository {
  getProfile(): Promise<LearnerProfile>;
  updateProfile(updates: Partial<LearnerProfile>): Promise<LearnerProfile>;
  saveSkillScores(courseId: string, scores: Record<string, SkillScore>): Promise<void>;
  markLessonCompleted(lessonId: string): Promise<void>;
  markNodeCompleted(nodeId: string): Promise<void>;
  markReinforcementCompleted(reinforcementId: string): Promise<void>;
  resetAll(): Promise<LearnerProfile>;
}
