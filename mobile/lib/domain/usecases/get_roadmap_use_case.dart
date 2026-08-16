import '../repositories/i_lesson_repository.dart';
import '../repositories/i_learner_repository.dart';
import '../entities/learning_path_node.dart';
import '../personalization/route_engine.dart';

class GetRoadmapUseCase {
  final ILessonRepository lessonRepository;
  final ILearnerRepository learnerRepository;

  const GetRoadmapUseCase(this.lessonRepository, this.learnerRepository);

  Future<LearningPath> execute(String courseId) async {
    final baseNodes = await lessonRepository.getBaseRoadmapNodes(courseId);
    final profile = await learnerRepository.getProfile();
    final scores = profile.scoresByCourse[courseId] ?? {};

    return RouteEngine.adaptRoadmap(
      courseId: courseId,
      baseNodes: baseNodes,
      skillScores: scores,
      completedNodeIds: profile.completedNodeIds,
      completedReinforcementIds: profile.completedReinforcementIds,
    );
  }
}
