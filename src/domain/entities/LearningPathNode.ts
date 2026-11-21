import { NodeStatus } from '@/core/types/common';
import type { RouteStrategy } from '@/core/constants/adaptiveThresholds';
import type { CefrLevelId } from './Question';

export type RoadmapNodeKind = 'lesson' | 'unit_checkpoint' | 'level_assessment';
export type RoadmapTaskKind = 'standard' | 'speaking_prompt' | 'writing_prompt';

export interface LearningPathNode {
  id: string;
  courseId: string;
  skillId: string;
  skillDomain?: string;
  cefrLevel?: CefrLevelId;
  moduleId?: string;
  moduleTitle?: string;
  moduleTitleRu?: string;
  unitId?: string;
  canDoObjective?: string;
  canDoObjectiveRu?: string;
  nodeKind?: RoadmapNodeKind;
  isCheckpoint?: boolean;
  hasRichExercise?: boolean;
  taskKind?: RoadmapTaskKind;
  title: string;
  titleRu?: string;
  description?: string;
  descriptionRu?: string;
  prerequisites: string[];
  requiredScore: number;
  status: NodeStatus;
  score?: number;
  routeStrategy?: RouteStrategy;
  isPlacementRecommended?: boolean;
  isPlacementUnlocked?: boolean;
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
