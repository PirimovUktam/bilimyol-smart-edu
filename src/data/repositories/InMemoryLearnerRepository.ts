import { ILearnerRepository } from '@/domain/repositories/ILearnerRepository';
import { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { SkillScore } from '@/domain/entities/SkillScore';

const DEFAULT_PROFILE: LearnerProfile = {
  id: 'learner_demo_01',
  name: 'Azizbek',
  selectedCourseId: 'course_math_01',
  goal: 'mastery',
  dailyMinutes: 15,
  initialLevel: 'intermediate',
  xp: 120,
  streakDays: 3,
  lastActiveDate: new Date().toISOString().split('T')[0],
  scoresByCourse: {},
  completedLessonIds: [],
  completedNodeIds: ['node_math_alg', 'node_math_eq'], // Math baseline completed
  completedReinforcementIds: [],
  createdAt: Date.now(),
};

export class InMemoryLearnerRepository implements ILearnerRepository {
  private profile: LearnerProfile = { ...DEFAULT_PROFILE };

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

  async markLessonCompleted(lessonId: string): Promise<void> {
    if (!this.profile.completedLessonIds.includes(lessonId)) {
      this.profile.completedLessonIds.push(lessonId);
    }
  }

  async markNodeCompleted(nodeId: string): Promise<void> {
    if (!this.profile.completedNodeIds.includes(nodeId)) {
      this.profile.completedNodeIds.push(nodeId);
    }
  }

  async markReinforcementCompleted(reinforcementId: string): Promise<void> {
    if (!this.profile.completedReinforcementIds.includes(reinforcementId)) {
      this.profile.completedReinforcementIds.push(reinforcementId);
    }
  }

  async resetAll(): Promise<LearnerProfile> {
    this.profile = {
      ...DEFAULT_PROFILE,
      scoresByCourse: {},
      completedLessonIds: [],
      completedNodeIds: ['node_math_alg', 'node_math_eq'],
      completedReinforcementIds: [],
    };
    return this.getProfile();
  }
}

export const inMemoryLearnerRepository = new InMemoryLearnerRepository();
