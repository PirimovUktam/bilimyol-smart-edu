import { ICourseRepository } from '@/domain/repositories/ICourseRepository';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { Question } from '@/domain/entities/Question';
import { SEED_COURSES } from '../datasources/courses';
import { SEED_SKILLS } from '../datasources/skills';
import { PLACEMENT_QUESTIONS } from '../datasources/questions';

export class InMemoryCourseRepository implements ICourseRepository {
  async getAllCourses(): Promise<Course[]> {
    return [...SEED_COURSES];
  }

  async getCourseById(courseId: string): Promise<Course | null> {
    const found = SEED_COURSES.find((c) => c.id === courseId);
    return found ? { ...found } : null;
  }

  async getSkillsByCourseId(courseId: string): Promise<Skill[]> {
    return SEED_SKILLS.filter((s) => s.courseId === courseId);
  }

  async getPlacementQuestions(courseId: string): Promise<Question[]> {
    return PLACEMENT_QUESTIONS[courseId] ? [...PLACEMENT_QUESTIONS[courseId]] : [];
  }
}

export const inMemoryCourseRepository = new InMemoryCourseRepository();
