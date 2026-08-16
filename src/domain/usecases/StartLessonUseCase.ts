import { ILessonRepository } from '../repositories/ILessonRepository';
import { Lesson } from '../entities/Lesson';
import { EntityNotFoundError } from '@/core/errors/DomainError';

export class StartLessonUseCase {
  constructor(private lessonRepo: ILessonRepository) {}

  async execute(lessonId: string): Promise<Lesson> {
    const lesson = await this.lessonRepo.getLessonById(lessonId);
    if (!lesson) {
      throw new EntityNotFoundError('Dars', lessonId);
    }
    return lesson;
  }
}
