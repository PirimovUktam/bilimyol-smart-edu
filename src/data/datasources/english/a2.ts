import a2CurriculumJson from '../../../../content/english/a2-curriculum.json';
import type { LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { Lesson } from '@/domain/entities/Lesson';
import type { Question } from '@/domain/entities/Question';
import type { CanonicalLevelCurriculum } from './types';

export const ENGLISH_A2_CURRICULUM = a2CurriculumJson as unknown as CanonicalLevelCurriculum;

export const ENGLISH_A2_CURRICULUM_META = {
  courseId: ENGLISH_A2_CURRICULUM.courseId,
  cefrLevel: ENGLISH_A2_CURRICULUM.cefrLevel,
  starterLessonId: ENGLISH_A2_CURRICULUM.starterLessonId,
  foundationLessonIds: ENGLISH_A2_CURRICULUM.foundationLessonIds,
  skills: ENGLISH_A2_CURRICULUM.skills,
  lessonsOrder: ENGLISH_A2_CURRICULUM.lessonsOrder,
  modules: ENGLISH_A2_CURRICULUM.modules,
  officialCefrDisclaimerUz: ENGLISH_A2_CURRICULUM.officialCefrDisclaimerUz,
  officialCefrDisclaimerRu: ENGLISH_A2_CURRICULUM.officialCefrDisclaimerRu,
};

export const ENGLISH_A2_LESSONS_LIST: Lesson[] = ENGLISH_A2_CURRICULUM.lessons;

export const ENGLISH_A2_LESSONS: Record<string, Lesson> = Object.fromEntries(
  ENGLISH_A2_LESSONS_LIST.map((lesson) => [lesson.id, lesson]),
);

export const ENGLISH_A2_ROADMAP_NODES: LearningPathNode[] = ENGLISH_A2_CURRICULUM.roadmapNodes;

export const ENGLISH_A2_QUESTIONS: Question[] = ENGLISH_A2_LESSONS_LIST.flatMap((lesson) => [
  ...lesson.steps.flatMap((step) => (step.interactiveQuestion ? [step.interactiveQuestion] : [])),
  ...(lesson.reinforcementExercise ? [lesson.reinforcementExercise] : []),
  ...(lesson.alternateExercise ? [lesson.alternateExercise] : []),
]);
