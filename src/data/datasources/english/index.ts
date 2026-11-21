import type { LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { Lesson } from '@/domain/entities/Lesson';
import type { Question } from '@/domain/entities/Question';
import {
  ENGLISH_A1_CURRICULUM_META,
  ENGLISH_A1_LESSONS,
  ENGLISH_A1_LESSONS_LIST,
  ENGLISH_A1_QUESTIONS,
  ENGLISH_A1_ROADMAP_NODES,
} from './a1';
import {
  ENGLISH_A2_CURRICULUM_META,
  ENGLISH_A2_LESSONS,
  ENGLISH_A2_LESSONS_LIST,
  ENGLISH_A2_QUESTIONS,
  ENGLISH_A2_ROADMAP_NODES,
} from './a2';
import {
  ENGLISH_B1_CURRICULUM_META,
  ENGLISH_B1_LESSONS,
  ENGLISH_B1_LESSONS_LIST,
  ENGLISH_B1_QUESTIONS,
  ENGLISH_B1_ROADMAP_NODES,
} from './b1';

export * from './types';
export * from './curriculum';
export * from './a1';
export * from './a2';
export * from './b1';
export * from './flashcards';
export * from './media';

export const ENGLISH_ALL_LESSONS_ORDER: string[] = [
  ...ENGLISH_A1_CURRICULUM_META.lessonsOrder,
  ...ENGLISH_A2_CURRICULUM_META.lessonsOrder,
  ...ENGLISH_B1_CURRICULUM_META.lessonsOrder,
];

export const ENGLISH_ALL_LESSONS_LIST: Lesson[] = [
  ...ENGLISH_A1_LESSONS_LIST,
  ...ENGLISH_A2_LESSONS_LIST,
  ...ENGLISH_B1_LESSONS_LIST,
];

export const ENGLISH_ALL_LESSONS: Record<string, Lesson> = {
  ...ENGLISH_A1_LESSONS,
  ...ENGLISH_A2_LESSONS,
  ...ENGLISH_B1_LESSONS,
};

export const ENGLISH_ALL_ROADMAP_NODES: LearningPathNode[] = [
  ...ENGLISH_A1_ROADMAP_NODES,
  ...ENGLISH_A2_ROADMAP_NODES,
  ...ENGLISH_B1_ROADMAP_NODES,
];

export const ENGLISH_ALL_QUESTIONS: Question[] = [
  ...ENGLISH_A1_QUESTIONS,
  ...ENGLISH_A2_QUESTIONS,
  ...ENGLISH_B1_QUESTIONS,
];
