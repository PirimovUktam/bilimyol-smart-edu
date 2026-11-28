import '../repositories/i_lesson_repository.dart';
import '../repositories/i_learner_repository.dart';
import '../entities/learning_path_node.dart';
import '../entities/skill_score.dart';
import '../personalization/route_engine.dart';

class GetRoadmapUseCase {
  final ILessonRepository lessonRepository;
  final ILearnerRepository learnerRepository;

  const GetRoadmapUseCase(this.lessonRepository, this.learnerRepository);

  Future<LearningPath> execute(String courseId) async {
    final baseNodes = await lessonRepository.getBaseRoadmapNodes(courseId);
    if (baseNodes.any((node) => node.serverMastery)) {
      try {
        final profile = await learnerRepository.getProfile();
        final combinedScores = <String, SkillScore>{
          ...(profile.placementSkillScoresByCourse[courseId] ?? const {}),
          ...(profile.scoresByCourse[courseId] ?? const {}),
        };
        return RouteEngine.adaptRoadmap(
          courseId: courseId,
          baseNodes: baseNodes,
          skillScores: combinedScores,
          completedNodeIds: const [],
          completedReinforcementIds: const [],
          goal: profile.goal,
          dailyMinutes: profile.dailyMinutes,
        );
      } catch (_) {
        return RouteEngine.adaptRoadmap(
          courseId: courseId,
          baseNodes: baseNodes,
          skillScores: const {},
          completedNodeIds: const [],
          completedReinforcementIds: const [],
        );
      }
    }
    final profile = await learnerRepository.getProfile();
    final scores = profile.scoresByCourse[courseId] ?? {};

    return RouteEngine.adaptRoadmap(
      courseId: courseId,
      baseNodes: baseNodes,
      skillScores: scores,
      completedNodeIds: profile.completedNodeIds,
      completedReinforcementIds: profile.completedReinforcementIds,
      placementCefrTier: profile.placementCefrByCourse[courseId],
      goal: profile.goal,
      dailyMinutes: profile.dailyMinutes,
    );
  }
}
