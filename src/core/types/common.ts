export type SubjectType = 'mathematics' | 'english';

export type DifficultyLevel = 'easy' | 'medium' | 'hard';

export type NodeStatus = 'locked' | 'available' | 'in_progress' | 'completed' | 'reinforcement';

export type OnboardingGoal = 'mastery' | 'exam_prep' | 'skills_boost';

export type DailyTimeCommitment = 15 | 30 | 60;

export type InitialLevel = 'beginner' | 'intermediate' | 'advanced';

export interface BaseEntity {
  id: string;
  createdAt: number;
  updatedAt: number;
}
