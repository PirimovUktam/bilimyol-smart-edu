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

  const SubmitReinforcementUseCase(
    this.learnerRepository,
    this.lessonRepository,
  );

  Future<ReinforcementResult> execute({
    required String courseId,
    required String skillId,
    required String reinforcementNodeId,
    required Question reinforcementQuestion,
    required int selectedIndex,
  }) async {
    if (courseId.isEmpty ||
        skillId.isEmpty ||
        reinforcementNodeId.isEmpty ||
        reinforcementQuestion.id.isEmpty ||
        reinforcementQuestion.courseId != courseId ||
        reinforcementQuestion.skillId != skillId) {
      throw ArgumentError('Mustahkamlash savoli kontekstga mos emas.');
    }
    if (selectedIndex < 0 ||
        selectedIndex >= reinforcementQuestion.options.length) {
      throw ArgumentError.value(selectedIndex, 'selectedIndex');
    }
    final profile = await learnerRepository.getProfile();
    final courseScores = profile.scoresByCourse[courseId] ?? {};
    final currentSkillScore = courseScores[skillId]?.score ?? 0;

    // Correctness is deliberately absent from this call. The repository owns
    // the source of truth (server RPC when authenticated, demo data offline).
    final answerAttempt = await learnerRepository.submitAnswerAttempt(
      courseId: courseId,
      skillId: skillId,
      lessonId: reinforcementNodeId,
      questionId: reinforcementQuestion.id,
      selectedIndex: selectedIndex,
      selectedAnswer: reinforcementQuestion.options[selectedIndex],
    );
    final isCorrect = answerAttempt.isCorrect;

    if (!isCorrect) {
      final currentProfile =
          learnerRepository.supportsServerReinforcementPersistence
          ? await learnerRepository.getProfile()
          : profile;
      final currentScores = currentProfile.scoresByCourse[courseId] ?? {};
      final actualScore = currentScores[skillId]?.score ??
          answerAttempt.newSkillScore ??
          currentSkillScore;
      final baseNodes = await lessonRepository.getBaseRoadmapNodes(courseId);
      final currentRoadmap = RouteEngine.adaptRoadmap(
        courseId: courseId,
        baseNodes: baseNodes,
        skillScores: currentScores,
        completedNodeIds: currentProfile.completedNodeIds,
        completedReinforcementIds: currentProfile.completedReinforcementIds,
      );
      return ReinforcementResult(
        isCorrect: false,
        oldScore: currentSkillScore,
        newScore: actualScore,
        xpAwarded: 0,
        updatedRoadmap: currentRoadmap,
      );
    }

    // Calculate all persistence context before writing the completion row.
    final newScore = SkillScoringEngine.calculateReinforcementScore(
      currentSkillScore,
    );
    final xpCalc = ProgressEngine.calculateNewXP(
      currentXP: profile.xp,
      actionType: 'reinforcement_completion',
      actionId: reinforcementNodeId,
      completedActionIds: profile.completedReinforcementIds,
    );
    final xpAwarded = xpCalc.wasAwarded ? xpCalc.newXP - profile.xp : 0;

    // The repository must persist the remote row or throw; success is not
    // reported when the Supabase write fails.
    final completion = await learnerRepository.markReinforcementCompleted(
      reinforcementId: reinforcementNodeId,
      courseId: courseId,
      skillId: skillId,
      questionId: reinforcementQuestion.id,
      beforeScore: currentSkillScore,
      afterScore: newScore,
      xpAwarded: xpAwarded,
    );

    if (learnerRepository.supportsServerReinforcementPersistence) {
      if (completion == null) {
        throw StateError('Server reinforcement completion result is missing.');
      }
      final persistedProfile = await learnerRepository.getProfile();
      final baseNodes = await lessonRepository.getBaseRoadmapNodes(courseId);
      return ReinforcementResult(
        isCorrect: true,
        oldScore: completion.oldScore,
        newScore: completion.newScore,
        xpAwarded: completion.alreadyProcessed ? 0 : completion.xpAwarded,
        updatedRoadmap: RouteEngine.adaptRoadmap(
          courseId: courseId,
          baseNodes: baseNodes,
          skillScores: persistedProfile.scoresByCourse[courseId] ?? {},
          completedNodeIds: persistedProfile.completedNodeIds,
          completedReinforcementIds: persistedProfile.completedReinforcementIds,
        ),
      );
    }

    // Demo repositories can persist roadmap-node completion locally. The
    // production repository must not manufacture a local success after a
    // remote reinforcement write; the server owns that state.
    final targetNodeId = reinforcementNodeId.replaceAll('reinf_', '');
    if (learnerRepository.supportsNodeCompletion) {
      await learnerRepository.markNodeCompleted(targetNodeId, courseId: courseId);
    }

    // Save the new skill score.
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

    if (xpCalc.wasAwarded) {
      // Preserve completion/score changes made by the repositories above.
      final currentProfile = await learnerRepository.getProfile();
      await learnerRepository.updateProfile(
        currentProfile.copyWith(xp: xpCalc.newXP),
      );
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
      xpAwarded: xpAwarded,
      updatedRoadmap: updatedRoadmap,
    );
  }
}
