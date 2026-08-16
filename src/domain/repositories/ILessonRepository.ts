import { Lesson } from '../entities/Lesson';
import { LearningPathNode } from '../entities/LearningPathNode';

export interface ILessonRepository {
  getLessonById(lessonId: string): Promise<Lesson | null>;
  getLessonByCourseAndSkill(courseId: string, skillId: string): Promise<Lesson | null>;
  getBaseRoadmapNodes(courseId: string): Promise<LearningPathNode[]>;
}
