import '../repositories/i_learner_repository.dart';
import '../repositories/i_lesson_repository.dart';
import '../entities/question.dart';
import '../entities/skill_score.dart';
import '../entities/learning_path_node.dart';
import '../personalization/skill_scoring_engine.dart';
import '../personalization/progress_engine.dart';
import '../personalization/route_engine.dart';

class ReinforcementResult {
  final bool isCorrect;
  final int oldScore;
  final int newScore;
  final int xpAwarded;
  final LearningPath updatedRoadmap;

  const ReinforcementResult({
    required this.isCorrect,
    required this.oldScore,
    required this.newScore,
    required this.xpAwarded,
    required this.updatedRoadmap,
  });
}

class SubmitReinforcementUseCase {
  final ILearnerRepository learnerRepository;
  final ILessonRepository lessonRepository;

  const SubmitReinforcementUseCase(this.learnerRepository, this.lessonRepository);

  Future<ReinforcementResult> execute({
    required String courseId,
    required String skillId,
    required String reinforcementNodeId,
    required Question reinforcementQuestion,
    required int selectedIndex,
  }) async {
    final isCorrect = selectedIndex == reinforcementQuestion.correctIndex;
    final profile = await learnerRepository.getProfile();
    final courseScores = profile.scoresByCourse[courseId] ?? {};
    final currentSkillScore = courseScores[skillId]?.score ?? 41;

    if (!isCorrect) {
      final baseNodes = await lessonRepository.getBaseRoadmapNodes(courseId);
      final currentRoadmap = RouteEngine.adaptRoadmap(
        courseId: courseId,
        baseNodes: baseNodes,
        skillScores: courseScores,
        completedNodeIds: profile.completedNodeIds,
        completedReinforcementIds: profile.completedReinforcementIds,
      );
      return ReinforcementResult(
        isCorrect: false,
        oldScore: currentSkillScore,
        newScore: currentSkillScore,
        xpAwarded: 0,
        updatedRoadmap: currentRoadmap,
      );
    }

    // 1. Calculate new score deterministically
    final newScore = SkillScoringEngine.calculateReinforcementScore(currentSkillScore);

    // 2. Mark reinforcement node as completed
    await learnerRepository.markReinforcementCompleted(reinforcementNodeId);

    // Also mark target node as completed
    final targetNodeId = reinforcementNodeId.replaceAll('reinf_', '');
    await learnerRepository.markNodeCompleted(targetNodeId);

    // 3. Save new score
    final updatedSkillScore = SkillScore(
      skillId: skillId,
      courseId: courseId,
      score: newScore,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      masteryLevel: SkillScoringEngine.getMasteryLevel(newScore),
      isWeakestFocus: false,
    );

    await learnerRepository.saveSkillScores(courseId, {
      skillId: updatedSkillScore,
    });

    // 4. Calculate XP idempotently
    final xpCalc = ProgressEngine.calculateNewXP(
      currentXP: profile.xp,
      actionType: 'reinforcement_completion',
      actionId: reinforcementNodeId,
      completedActionIds: profile.completedReinforcementIds,
    );

    if (xpCalc.wasAwarded) {
      final updatedProfile = await learnerRepository.getProfile();
      await learnerRepository.updateProfile(updatedProfile.copyWith(xp: xpCalc.newXP));
    }

    // 5. Adapt updated roadmap
    final finalProfile = await learnerRepository.getProfile();
    final baseNodes = await lessonRepository.getBaseRoadmapNodes(courseId);
    final updatedScores = finalProfile.scoresByCourse[courseId] ?? {};

    final updatedRoadmap = RouteEngine.adaptRoadmap(
      courseId: courseId,
      baseNodes: baseNodes,
      skillScores: updatedScores,
      completedNodeIds: finalProfile.completedNodeIds,
      completedReinforcementIds: finalProfile.completedReinforcementIds,
    );

    return ReinforcementResult(
      isCorrect: true,
      oldScore: currentSkillScore,
      newScore: newScore,
      xpAwarded: xpCalc.wasAwarded ? 30 : 0,
      updatedRoadmap: updatedRoadmap,
    );
  }
}
