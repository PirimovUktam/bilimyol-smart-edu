import { ILearnerRepository } from '../repositories/ILearnerRepository';
import { LearnerProfile } from '../entities/LearnerProfile';

export class ResetDemoUseCase {
  constructor(private learnerRepo: ILearnerRepository) {}

  async execute(): Promise<LearnerProfile> {
    return this.learnerRepo.resetAll();
  }
}
