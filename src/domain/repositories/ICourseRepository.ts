import { Course } from '../entities/Course';
import { Skill } from '../entities/Skill';
import { Question } from '../entities/Question';

export interface ICourseRepository {
  getAllCourses(): Promise<Course[]>;
  getCourseById(courseId: string): Promise<Course | null>;
  getSkillsByCourseId(courseId: string): Promise<Skill[]>;
  getPlacementQuestions(courseId: string): Promise<Question[]>;
}
