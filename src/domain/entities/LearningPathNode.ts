import { NodeStatus } from '@/core/types/common';

export interface LearningPathNode {
  id: string;
  courseId: string;
  skillId: string;
  title: string;
  description?: string;
  prerequisites: string[];
  requiredScore: number;
  status: NodeStatus;
  score?: number;
  isReinforcement: boolean;
  targetLessonId?: string;
  estimatedMinutes: number;
  order: number;
  orderIndex?: number;
  isOptional?: boolean;
  mastery?: {
    state: 'not_started' | 'practicing' | 'needs_review' | 'mastered';
    answered: number;
    correct: number;
    requiredItems: number;
    passedCheckpoints: number;
    requiredCheckpoints: number;
    reviewDue: boolean;
  };
}

export interface LearningPath {
  id: string;
  courseId: string;
  title: string;
  nodes: LearningPathNode[];
  activeNodeId: string;
  updatedAt: number;
}
