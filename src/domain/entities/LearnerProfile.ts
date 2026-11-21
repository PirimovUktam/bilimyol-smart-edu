import { OnboardingGoal, DailyTimeCommitment, InitialLevel } from '@/core/types/common';
import type { CefrLevelId } from './Question';
import { SkillScore } from './SkillScore';

export type FlashcardStudyMode =
  | 'en_to_uz'
  | 'uz_to_en'
  | 'audio_to_word'
  | 'image_to_word'
  | 'random';

export type FlashcardSrsBucket = 'need_practice' | 'learning' | 'review' | 'mastered';

export interface FlashcardSrsEntry {
  cardId: string;
  status: 'need_practice' | 'remembered';
  bucket: FlashcardSrsBucket;
  reviewCount: number;
  intervalDays: number;
  lastReviewedAt: string;
  nextReviewAt: string;
}

export interface LearnerProfile {
  id: string;
  name: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  avatarUrl?: string;
  selectedCourseId: string;
  goal: OnboardingGoal;
  dailyMinutes: DailyTimeCommitment;
  initialLevel: InitialLevel;
  courseLevels?: Record<string, InitialLevel>;
  xp: number;
  streakDays: number;
  lastActiveDate: string; // YYYY-MM-DD
  scoresByCourse: Record<string, Record<string, SkillScore>>; // courseId -> { skillId: SkillScore }
  placementScoreByCourse?: Record<string, number>;
  placementCefrByCourse?: Record<string, CefrLevelId>;
  placementSkillScoresByCourse?: Record<string, Record<string, SkillScore>>;
  completedLessonIds: string[];
  completedNodeIds: string[];
  completedReinforcementIds: string[];
  flashcardSrsByCourse?: Record<string, Record<string, FlashcardSrsEntry>>;
  createdAt: number;
  updatedAt?: number;
}
