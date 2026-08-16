import { ICourseRepository } from '../repositories/ICourseRepository';
import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { Course } from '../entities/Course';
import { EntityNotFoundError } from '@/core/errors/DomainError';

export class SelectCourseUseCase {
  constructor(
    private courseRepo: ICourseRepository,
    private learnerRepo: ILearnerRepository
  ) {}

  async execute(courseId: string): Promise<Course> {
    const course = await this.courseRepo.getCourseById(courseId);
    if (!course) {
      throw new EntityNotFoundError('Kurs', courseId);
    }

    await this.learnerRepo.updateProfile({ selectedCourseId: courseId });
    return course;
  }
}
