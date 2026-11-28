import 'dart:collection';
import 'dart:convert';

import '../../core/utils/attempt_uuid.dart';
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
  final String? correctOption;
  final String? explanation;

  const ReinforcementResult({
    required this.isCorrect,
    required this.oldScore,
    required this.newScore,
    required this.xpAwarded,
    required this.updatedRoadmap,
    this.correctOption,
    this.explanation,
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
    String? selectedText,
    Map<String, String>? matchedPairs,
    List<String>? orderedTokens,
    List<String>? checkedCriteriaIds,
    String? idempotencyKey,
    AnswerAttemptRecord? cachedAttempt,
    void Function(AnswerAttemptRecord)? onAttemptGraded,
  }) async {
    if (courseId.isEmpty ||
        skillId.isEmpty ||
        reinforcementNodeId.isEmpty ||
        reinforcementQuestion.id.isEmpty ||
        reinforcementQuestion.courseId != courseId ||
        reinforcementQuestion.skillId != skillId) {
      throw ArgumentError('Mustahkamlash savoli kontekstga mos emas.');
    }
    late final String serializedAnswer;
    late final int effectiveIndex;
    if (reinforcementQuestion.isSelfAssessed) {
      final text = (selectedText ?? '').trim();
      if (text.isEmpty) throw ArgumentError.value(selectedText, 'selectedText');
      final sortedCriteria = [...(checkedCriteriaIds ?? const <String>[])]
        ..sort();
      serializedAnswer = jsonEncode({
        'response': text,
        'criteria': sortedCriteria,
      });
      effectiveIndex = 0;
    } else if (reinforcementQuestion.usesTextEvaluation) {
      final text = (selectedText ?? '').trim();
      if (text.isEmpty) throw ArgumentError.value(selectedText, 'selectedText');
      serializedAnswer = text;
      effectiveIndex = 0;
    } else if (reinforcementQuestion.mode == QuestionMode.sentenceOrder) {
      final tokens = orderedTokens ?? const <String>[];
      if (tokens.isEmpty) {
        throw ArgumentError.value(orderedTokens, 'orderedTokens');
      }
      serializedAnswer = jsonEncode(tokens);
      effectiveIndex = 0;
    } else if (reinforcementQuestion.mode == QuestionMode.wordMatch) {
      final pairs = matchedPairs ?? const <String, String>{};
      if (pairs.isEmpty) {
        throw ArgumentError.value(matchedPairs, 'matchedPairs');
      }
      serializedAnswer = jsonEncode(SplayTreeMap<String, String>.from(pairs));
      effectiveIndex = 0;
    } else {
      if (selectedIndex < 0 ||
          selectedIndex >= reinforcementQuestion.options.length) {
        throw ArgumentError.value(selectedIndex, 'selectedIndex');
      }
      serializedAnswer = reinforcementQuestion.options[selectedIndex];
      effectiveIndex = selectedIndex;
    }
    final profile = await learnerRepository.getProfile();
    final courseScores = profile.scoresByCourse[courseId] ?? {};
    final hadPriorSkillScore = courseScores.containsKey(skillId);
    final currentSkillScore = courseScores[skillId]?.score ?? 0;

    Map<String, SkillScore> resolveEffectiveScores(
      Map<String, Map<String, SkillScore>> placementByCourse,
      Map<String, Map<String, SkillScore>> scoresByCourse,
    ) {
      if (courseId == 'course_eng_01') {
        return scoresByCourse[courseId] ?? const {};
      }
      return <String, SkillScore>{
        ...(placementByCourse[courseId] ?? const {}),
        ...(scoresByCourse[courseId] ?? const {}),
      };
    }

    final resolvedKey =
        (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        ? idempotencyKey.trim()
        : generateAttemptUuidV4();

    // Correctness is deliberately absent from this call. The repository owns
    // the source of truth (server RPC when authenticated, demo data offline).
    final answerAttempt = cachedAttempt ??
        await learnerRepository.submitAnswerAttemptIdempotent(
          courseId: courseId,
          skillId: skillId,
          lessonId: reinforcementNodeId,
          questionId: reinforcementQuestion.id,
          selectedIndex: effectiveIndex,
          selectedAnswer: serializedAnswer,
          idempotencyKey: resolvedKey,
        );
    if (cachedAttempt == null) {
      onAttemptGraded?.call(answerAttempt);
    }
    final isCorrect = answerAttempt.isCorrect;

    if (!isCorrect) {
      final currentProfile = await learnerRepository.getProfile();
      final currentScores = resolveEffectiveScores(
        currentProfile.placementSkillScoresByCourse,
        currentProfile.scoresByCourse,
      );
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
        placementCefrTier: currentProfile.placementCefrByCourse[courseId],
        goal: currentProfile.goal,
        dailyMinutes: currentProfile.dailyMinutes,
      );
      return ReinforcementResult(
        isCorrect: false,
        oldScore: currentSkillScore,
        newScore: actualScore,
        xpAwarded: 0,
        updatedRoadmap: currentRoadmap,
        correctOption: answerAttempt.correctOption,
        explanation: answerAttempt.explanation,
      );
    }

    // Calculate all persistence context before writing the completion row
    // (preserving multi-skill parent remediation parity with Web & SQL).
    final postAttemptProfile = await learnerRepository.getProfile();
    final baseNodes = await lessonRepository.getBaseRoadmapNodes(courseId);
    final parentBase = baseNodes
        .where(
          (n) =>
              !n.isReinforcement &&
              (reinforcementNodeId == 'reinf_${n.id}' ||
                  n.id == reinforcementNodeId),
        )
        .firstOrNull;
    final isMultiSkillParent =
        parentBase != null && parentBase.skillId != skillId;
    final postAttemptSkillScore =
        postAttemptProfile.scoresByCourse[courseId]?[skillId]?.score ??
        answerAttempt.newSkillScore ??
        0;
    final bumpedSkillScore = SkillScoringEngine.calculateReinforcementScore(
      currentSkillScore,
    );
    final exerciseNewScore = isMultiSkillParent
        ? (hadPriorSkillScore
              ? (postAttemptSkillScore > bumpedSkillScore
                    ? postAttemptSkillScore
                    : bumpedSkillScore)
              : [50, postAttemptSkillScore, bumpedSkillScore].reduce(
                  (a, b) => a > b ? a : b,
                ))
        : bumpedSkillScore;

    final parentExisting = isMultiSkillParent
        ? courseScores[parentBase.skillId]
        : null;
    final remediateParent =
        parentBase != null &&
        parentExisting != null &&
        parentExisting.score < parentBase.requiredScore;
    final parentOldScore = parentExisting?.score ?? 0;
    final parentNewScore = remediateParent
        ? SkillScoringEngine.calculateReinforcementScore(parentOldScore)
        : parentOldScore;
    final useParentReport =
        remediateParent &&
        (!hadPriorSkillScore ||
            currentSkillScore >= parentBase.requiredScore);
    final reportedOldScore =
        useParentReport ? parentOldScore : currentSkillScore;
    final reportedNewScore =
        useParentReport ? parentNewScore : exerciseNewScore;

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
      beforeScore: reportedOldScore,
      afterScore: reportedNewScore,
      xpAwarded: xpAwarded,
    );

    if (learnerRepository.supportsServerReinforcementPersistence) {
      if (completion == null) {
        throw StateError('Server reinforcement completion result is missing.');
      }
      final persistedProfile = await learnerRepository.getProfile();
      return ReinforcementResult(
        isCorrect: true,
        oldScore: completion.oldScore,
        newScore: completion.newScore,
        xpAwarded: completion.alreadyProcessed ? 0 : completion.xpAwarded,
        updatedRoadmap: RouteEngine.adaptRoadmap(
          courseId: courseId,
          baseNodes: baseNodes,
          skillScores: resolveEffectiveScores(
            persistedProfile.placementSkillScoresByCourse,
            persistedProfile.scoresByCourse,
          ),
          completedNodeIds: persistedProfile.completedNodeIds,
          completedReinforcementIds: persistedProfile.completedReinforcementIds,
          placementCefrTier: persistedProfile.placementCefrByCourse[courseId],
          goal: persistedProfile.goal,
          dailyMinutes: persistedProfile.dailyMinutes,
        ),
      );
    }

    // Save the new skill score (and remediate parent node's weak skill when exercise skill differs).
    final now = DateTime.now().millisecondsSinceEpoch;
    final scoresToSave = <String, SkillScore>{
      skillId: SkillScore(
        skillId: skillId,
        courseId: courseId,
        score: exerciseNewScore,
        lastUpdated: now,
        masteryLevel: SkillScoringEngine.getMasteryLevel(exerciseNewScore),
        isWeakestFocus: false,
      ),
      if (remediateParent)
        parentBase.skillId: SkillScore(
          skillId: parentBase.skillId,
          courseId: courseId,
          score: parentNewScore,
          lastUpdated: now,
          masteryLevel: SkillScoringEngine.getMasteryLevel(parentNewScore),
          isWeakestFocus: false,
        ),
    };

    await learnerRepository.saveSkillScores(courseId, scoresToSave);

    if (xpCalc.wasAwarded) {
      // Preserve completion/score changes made by the repositories above.
      final currentProfile = await learnerRepository.getProfile();
      await learnerRepository.updateProfile(
        currentProfile.copyWith(xp: xpCalc.newXP),
      );
    }

    // 5. Adapt updated roadmap
    final finalProfile = await learnerRepository.getProfile();
    final updatedScores = resolveEffectiveScores(
      finalProfile.placementSkillScoresByCourse,
      finalProfile.scoresByCourse,
    );

    final updatedRoadmap = RouteEngine.adaptRoadmap(
      courseId: courseId,
      baseNodes: baseNodes,
      skillScores: updatedScores,
      completedNodeIds: finalProfile.completedNodeIds,
      completedReinforcementIds: finalProfile.completedReinforcementIds,
      placementCefrTier: finalProfile.placementCefrByCourse[courseId],
      goal: finalProfile.goal,
      dailyMinutes: finalProfile.dailyMinutes,
    );

    return ReinforcementResult(
      isCorrect: true,
      oldScore: reportedOldScore,
      newScore: reportedNewScore,
      xpAwarded: xpAwarded,
      updatedRoadmap: updatedRoadmap,
    );
  }
}
