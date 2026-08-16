import { NodeStatus } from '@/core/types/common';

export interface LearningPathNode {
  id: string;
  courseId: string;
  skillId: string;
  title: string;
  description?: string;
  prerequisites: string[]; // Node IDs that must be completed
  requiredScore: number;
  status: NodeStatus;
  score?: number;
  isReinforcement: boolean;
  targetLessonId?: string;
  estimatedMinutes: number;
  order: number;
}

export interface LearningPath {
  id: string;
  courseId: string;
  title: string;
  nodes: LearningPathNode[];
  activeNodeId: string;
  updatedAt: number;
}
