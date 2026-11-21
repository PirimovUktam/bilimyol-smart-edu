import b1CurriculumJson from '../../../../content/english/b1-curriculum.json';
import type { LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { Lesson } from '@/domain/entities/Lesson';
import type { Question } from '@/domain/entities/Question';
import type { CanonicalLevelCurriculum } from './types';

export const ENGLISH_B1_CURRICULUM = b1CurriculumJson as unknown as CanonicalLevelCurriculum;

export const ENGLISH_B1_CURRICULUM_META = {
  courseId: ENGLISH_B1_CURRICULUM.courseId,
  cefrLevel: ENGLISH_B1_CURRICULUM.cefrLevel,
  starterLessonId: ENGLISH_B1_CURRICULUM.starterLessonId,
  foundationLessonIds: ENGLISH_B1_CURRICULUM.foundationLessonIds,
  skills: ENGLISH_B1_CURRICULUM.skills,
  lessonsOrder: ENGLISH_B1_CURRICULUM.lessonsOrder,
  modules: ENGLISH_B1_CURRICULUM.modules,
  officialCefrDisclaimerUz: ENGLISH_B1_CURRICULUM.officialCefrDisclaimerUz,
  officialCefrDisclaimerRu: ENGLISH_B1_CURRICULUM.officialCefrDisclaimerRu,
};

export const ENGLISH_B1_LESSONS_LIST: Lesson[] = ENGLISH_B1_CURRICULUM.lessons;

export const ENGLISH_B1_LESSONS: Record<string, Lesson> = Object.fromEntries(
  ENGLISH_B1_LESSONS_LIST.map((lesson) => [lesson.id, lesson]),
);

export const ENGLISH_B1_ROADMAP_NODES: LearningPathNode[] = ENGLISH_B1_CURRICULUM.roadmapNodes;

export const ENGLISH_B1_QUESTIONS: Question[] = ENGLISH_B1_LESSONS_LIST.flatMap((lesson) => [
  ...lesson.steps.flatMap((step) => (step.interactiveQuestion ? [step.interactiveQuestion] : [])),
  ...(lesson.reinforcementExercise ? [lesson.reinforcementExercise] : []),
  ...(lesson.alternateExercise ? [lesson.alternateExercise] : []),
]);
