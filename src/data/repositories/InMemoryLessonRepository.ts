import { ILessonRepository } from '@/domain/repositories/ILessonRepository';
import { Lesson } from '@/domain/entities/Lesson';
import { LearningPathNode } from '@/domain/entities/LearningPathNode';
import { SEED_LESSONS } from '../datasources/lessons';
import { SEED_ROADMAP_NODES } from '../datasources/roadmaps';

export class InMemoryLessonRepository implements ILessonRepository {
  private runtimeLessons: Map<string, Lesson> = new Map();

  async getLessonById(lessonId: string): Promise<Lesson | null> {
    if (this.runtimeLessons.has(lessonId)) {
      return { ...this.runtimeLessons.get(lessonId)! };
    }
    const lesson = SEED_LESSONS[lessonId];
    return lesson ? { ...lesson } : null;
  }

  async getLessonByCourseAndSkill(courseId: string, skillId: string): Promise<Lesson | null> {
    for (const l of this.runtimeLessons.values()) {
      if (l.courseId === courseId && l.skillId === skillId) {
        return { ...l };
      }
    }
    const lesson = Object.values(SEED_LESSONS).find(
      (l) => l.courseId === courseId && l.skillId === skillId
    );
    return lesson ? { ...lesson } : null;
  }

  async getBaseRoadmapNodes(courseId: string): Promise<LearningPathNode[]> {
    const nodes = SEED_ROADMAP_NODES[courseId];
    return nodes ? nodes.map((n) => ({ ...n })) : [];
  }

  async saveLesson(lesson: Lesson): Promise<void> {
    this.runtimeLessons.set(lesson.id, { ...lesson });
  }

  clearRuntimeCache(): void {
    this.runtimeLessons.clear();
  }
}

export const inMemoryLessonRepository = new InMemoryLessonRepository();

