import { OnboardingGoal, DailyTimeCommitment, InitialLevel } from '@/core/types/common';
import { SkillScore } from './SkillScore';

export interface LearnerProfile {
  id: string;
  name: string;
  avatarUrl?: string;
  selectedCourseId: string;
  goal: OnboardingGoal;
  dailyMinutes: DailyTimeCommitment;
  initialLevel: InitialLevel;
  xp: number;
  streakDays: number;
  lastActiveDate: string; // YYYY-MM-DD
  scoresByCourse: Record<string, Record<string, SkillScore>>; // courseId -> { skillId: SkillScore }
  completedLessonIds: string[];
  completedNodeIds: string[];
  completedReinforcementIds: string[];
  createdAt: number;
}
