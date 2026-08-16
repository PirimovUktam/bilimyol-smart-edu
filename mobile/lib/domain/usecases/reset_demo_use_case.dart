import '../repositories/i_learner_repository.dart';
import '../entities/learner_profile.dart';

class ResetDemoUseCase {
  final ILearnerRepository learnerRepository;

  const ResetDemoUseCase(this.learnerRepository);

  Future<LearnerProfile> execute() async {
    return learnerRepository.resetAll();
  }
}
