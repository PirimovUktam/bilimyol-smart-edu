import '../../core/constants/adaptive_thresholds.dart';
import '../entities/course.dart';
import '../entities/learner_profile.dart';
import '../entities/learning_path_node.dart';
import '../entities/skill.dart';
import '../entities/skill_score.dart';
import 'skill_scoring_engine.dart';

enum AdaptiveStepKey {
  diagnostic,
  profile,
  path,
  practice,
  progress,
}

enum AdaptiveStepStatus {
  completed,
  active,
  upcoming,
}

enum ExplainableFactorKey {
  goal,
  skillProfile,
  knowledgeLevel,
  errorPattern,
  learningSpeed,
  dailyTime,
}

enum AdaptiveSkillDeltaStatus {
  gapDetected,
  reinforcing,
  closedGap,
  mastered,
  unassessed,
}

class AdaptiveStepState {
  final int step;
  final String code;
  final AdaptiveStepKey key;
  final AdaptiveStepStatus status;
  final String metricLabel;

  const AdaptiveStepState({
    required this.step,
    required this.code,
    required this.key,
    required this.status,
    required this.metricLabel,
  });
}

class AdaptiveCycleSnapshot {
  final int activeStep;
  final List<AdaptiveStepState> steps;
  final String loopUpdateSummary;
  final String? weakestSkillName;
  final int? weakestScore;
  final int strongSkillsCount;
  final int weakSkillsCount;
  final bool needsReinforcement;
  final String? activeNodeTitle;

  const AdaptiveCycleSnapshot({
    required this.activeStep,
    required this.steps,
    required this.loopUpdateSummary,
    required this.weakestSkillName,
    required this.weakestScore,
    required this.strongSkillsCount,
    required this.weakSkillsCount,
    required this.needsReinforcement,
    required this.activeNodeTitle,
  });
}

class ExplainableFactor {
  final ExplainableFactorKey key;
  final String label;
  final String value;
  final String impact;

  const ExplainableFactor({
    required this.key,
    required this.label,
    required this.value,
    required this.impact,
  });
}

class DailyMicroTask {
  final String id;
  final String title;
  final int minutes;
  final String type; // 'diagnostic' | 'reinforcement' | 'lesson'
  final String? targetNodeId;
  final String reason;

  const DailyMicroTask({
    required this.id,
    required this.title,
    required this.minutes,
    required this.type,
    this.targetNodeId,
    required this.reason,
  });
}

class AdaptiveSkillDelta {
  final String skillId;
  final String skillName;
  final int baseline;
  final int current;
  final int delta;
  final AdaptiveSkillDeltaStatus status;

  const AdaptiveSkillDelta({
    required this.skillId,
    required this.skillName,
    required this.baseline,
    required this.current,
    required this.delta,
    required this.status,
  });
}

class AdaptiveEffectivenessMetrics {
  final bool hasDiagnosticBaseline;
  final int baselineScore;
  final int currentScore;
  final int growthDelta;
  final int detectedGapsCount;
  final int closedGapsCount;
  final int adaptiveUpdatesCount;
  final int dailyMinutesBudget;
  final int paceEfficiencyPct;
  final List<AdaptiveSkillDelta> skillDeltas;

  const AdaptiveEffectivenessMetrics({
    required this.hasDiagnosticBaseline,
    required this.baselineScore,
    required this.currentScore,
    required this.growthDelta,
    required this.detectedGapsCount,
    required this.closedGapsCount,
    required this.adaptiveUpdatesCount,
    required this.dailyMinutesBudget,
    required this.paceEfficiencyPct,
    required this.skillDeltas,
  });
}

class AdaptiveContextInput {
  final Course? course;
  final LearnerProfile? profile;
  final List<Skill> skills;
  final Map<String, SkillScore> skillScores;
  final LearningPath? roadmap;
  final String localeCode;

  const AdaptiveContextInput({
    this.course,
    this.profile,
    this.skills = const [],
    this.skillScores = const {},
    this.roadmap,
    this.localeCode = 'uz',
  });
}

class _ResolvedAdaptiveContext {
  final String? courseId;
  final List<Skill> skills;
  final Map<String, SkillScore> skillScores;
  final Map<String, SkillScore> placementSkillScores;
  final bool isMathPilot;
  final List<LearningPathNode> mathObjectives;

  const _ResolvedAdaptiveContext({
    required this.courseId,
    required this.skills,
    required this.skillScores,
    required this.placementSkillScores,
    required this.isMathPilot,
    required this.mathObjectives,
  });
}

/// Pure Dart domain engine implementing BilimYo‘l's 5-step Adaptive Learning Cycle,
/// 6-input Explainable AI transparent reasoning, and honest effectiveness metrics.
class AdaptiveCycleEngine {
  static String _goalLabel(OnboardingGoal goal, bool isRu) => switch (goal) {
    OnboardingGoal.examPrep =>
      isRu ? 'Подготовка к экзаменам' : 'Imtihon va testlarga tayyorgarlik',
    OnboardingGoal.skillsBoost =>
      isRu ? 'Усиление практических навыков' : 'Amaliy ko‘nikmalarni kuchaytirish',
    OnboardingGoal.mastery =>
      isRu ? 'Освоение базовых тем' : 'Asosiy mavzularni o‘zlashtirish',
  };

  static String _masteryLabel(int score, bool isRu) {
    if (score >= 80) return isRu ? 'Освоено' : 'Mukammal';
    if (score >= 70) return isRu ? 'Уверенно' : 'Mustahkam';
    if (score >= 50) return isRu ? 'Развивается' : 'Rivojlanmoqda';
    return isRu ? 'Требует укрепления' : 'Mustahkamlash kerak';
  }

  static _ResolvedAdaptiveContext _resolveEffectiveContext(
    AdaptiveContextInput input,
  ) {
    final isRu = input.localeCode == 'ru';
    final courseId =
        input.course?.id ??
        input.roadmap?.courseId ??
        input.profile?.selectedCourseId;
    final placementSkillScores = courseId != null
        ? (input.profile?.placementSkillScoresByCourse[courseId] ??
              const <String, SkillScore>{})
        : const <String, SkillScore>{};
    final mergedScores = <String, SkillScore>{
      ...placementSkillScores,
      ...input.skillScores,
    };
    final mergedSkills = <Skill>[...input.skills];
    final mathObjectives = (input.roadmap?.nodes ?? const <LearningPathNode>[])
        .where((node) => (node.serverMastery || node.mastery != null) && !node.isOptional)
        .toList();
    final isMathPilot = mathObjectives.isNotEmpty;

    if (isMathPilot) {
      for (final node in mathObjectives) {
        if (!mergedSkills.any((s) => s.id == node.skillId)) {
          mergedSkills.add(
            Skill(
              id: node.skillId,
              courseId: node.courseId,
              name: node.localizedTitle(isRu ? 'ru' : 'uz'),
              code: node.skillId.toUpperCase(),
              description: node.localizedDescription(isRu ? 'ru' : 'uz'),
              order: node.order.round(),
              iconName: 'calculator',
            ),
          );
        }
        final m = node.mastery;
        if (m != null && m.answered > 0) {
          final rawPct = ((100 * m.correct) / m.answered).round();
          final pilotScore =
              node.status == NodeStatus.reinforcement || m.state == 'needs_review'
              ? (rawPct < 45 ? rawPct : 45)
              : rawPct;
          mergedScores[node.skillId] = SkillScore(
            skillId: node.skillId,
            courseId: node.courseId,
            score: pilotScore,
            lastUpdated:
                input.roadmap?.updatedAt ?? DateTime.now().millisecondsSinceEpoch,
            masteryLevel: SkillScoringEngine.getMasteryLevel(pilotScore),
          );
        }
      }
    }

    return _ResolvedAdaptiveContext(
      courseId: courseId,
      skills: mergedSkills,
      skillScores: mergedScores,
      placementSkillScores: placementSkillScores,
      isMathPilot: isMathPilot,
      mathObjectives: mathObjectives,
    );
  }

  static ({Skill? skill, SkillScore? scoreObj}) _findWeakestSkill(
    List<Skill> skills,
    Map<String, SkillScore> skillScores,
  ) {
    SkillScore? weakest;
    for (final sc in skillScores.values) {
      if (weakest == null || sc.score < weakest.score) {
        weakest = sc;
      }
    }
    if (weakest == null) return (skill: null, scoreObj: null);
    final skill = skills.where((s) => s.id == weakest!.skillId).firstOrNull;
    return (skill: skill, scoreObj: weakest);
  }

  static LearningPathNode? _resolveActiveNode(LearningPath? roadmap) {
    if (roadmap == null || roadmap.nodes.isEmpty) return null;
    return roadmap.nodes.where((n) => n.id == roadmap.activeNodeId).firstOrNull ??
        roadmap.nodes
            .where(
              (n) =>
                  n.status == NodeStatus.reinforcement ||
                  n.status == NodeStatus.available ||
                  n.status == NodeStatus.inProgress,
            )
            .firstOrNull ??
        roadmap.nodes.first;
  }

  static String _resolveReinforcementTargetNodeId(
    LearningPath? roadmap,
    String weakestSkillId,
  ) {
    if (roadmap != null) {
      final activeReinf = roadmap.nodes
          .where(
            (n) =>
                n.isReinforcement &&
                n.skillId == weakestSkillId &&
                n.status != NodeStatus.completed,
          )
          .firstOrNull;
      if (activeReinf != null) return activeReinf.id;

      final anyReinf = roadmap.nodes
          .where((n) => n.isReinforcement && n.skillId == weakestSkillId)
          .firstOrNull;
      if (anyReinf != null) return anyReinf.id;

      final baseNode =
          roadmap.nodes
              .where(
                (n) =>
                    !n.isReinforcement &&
                    n.skillId == weakestSkillId &&
                    n.status != NodeStatus.completed,
              )
              .firstOrNull ??
          roadmap.nodes
              .where((n) => !n.isReinforcement && n.skillId == weakestSkillId)
              .firstOrNull;
      if (baseNode != null) {
        return (baseNode.serverMastery || baseNode.mastery != null)
            ? baseNode.id
            : 'reinf_${baseNode.id}';
      }
    }
    return 'reinf_$weakestSkillId';
  }

  static Set<String> _collectCourseCompletedReinforcements({
    required String? courseId,
    required Course? course,
    required LearningPath? roadmap,
    required List<Skill> skills,
    required LearnerProfile? profile,
  }) {
    final result = <String>{};
    final rawCompleted = profile?.completedReinforcementIds ?? const <String>[];
    final rawSet = rawCompleted.toSet();

    if (roadmap != null) {
      for (final node in roadmap.nodes) {
        if (node.isReinforcement &&
            (node.status == NodeStatus.completed || rawSet.contains(node.id))) {
          result.add(node.id);
        }
      }
    }

    if (roadmap == null && course == null && courseId == null) {
      result.addAll(rawCompleted);
      return result;
    }

    for (final rid in rawCompleted) {
      final matchesRoadmapNode =
          roadmap?.nodes.any(
            (n) =>
                n.id == rid ||
                (!n.isReinforcement && rid == 'reinf_${n.id}') ||
                (n.targetLessonId?.isNotEmpty == true &&
                    rid == 'reinf_lesson_${n.targetLessonId}'),
          ) ??
          false;
      final matchesCourseLesson =
          course?.lessons.any((lid) => rid == 'reinf_lesson_$lid') ?? false;
      final matchesCoursePrefix =
          courseId != null && rid.startsWith('reinf_${courseId}_');
      final matchesSkillFallback =
          roadmap == null && skills.any((sk) => rid == 'reinf_${sk.id}');

      if (matchesRoadmapNode ||
          matchesCourseLesson ||
          matchesCoursePrefix ||
          matchesSkillFallback) {
        result.add(rid);
      }
    }

    return result;
  }

  static bool _hasSkillCompletedReinforcement({
    required String skillId,
    required String? courseId,
    required LearningPath? roadmap,
    required Set<String> completedCourseReinfIds,
  }) {
    for (final rid in completedCourseReinfIds) {
      if (rid == 'reinf_$skillId' ||
          (courseId != null && rid == 'reinf_${courseId}_$skillId')) {
        return true;
      }
      if (roadmap?.nodes.any(
            (n) =>
                n.skillId == skillId &&
                (n.id == rid || (!n.isReinforcement && rid == 'reinf_${n.id}')),
          ) ==
          true) {
        return true;
      }
    }
    return false;
  }

  static AdaptiveCycleSnapshot evaluateCycle(AdaptiveContextInput input) {
    final isRu = input.localeCode == 'ru';
    final lang = isRu ? 'ru' : 'uz';
    final ctx = _resolveEffectiveContext(input);
    final profile = input.profile;
    final course = input.course;
    final roadmap = input.roadmap;

    final scoreValues = ctx.skillScores.values.toList();
    final hasDiagnostics =
        scoreValues.isNotEmpty ||
        (ctx.courseId != null &&
            profile?.placementScoreByCourse.containsKey(ctx.courseId) == true);

    final completedLessonsCount = course != null
        ? course.lessons
              .where((id) => profile?.completedLessonIds.contains(id) == true)
              .length
        : (profile?.completedLessonIds.length ?? 0);
    final completedNodesCount = roadmap != null
        ? roadmap.nodes
              .where(
                (n) =>
                    !n.isReinforcement &&
                    !n.isOptional &&
                    n.status == NodeStatus.completed,
              )
              .length
        : (profile?.completedNodeIds.length ?? 0);
    final completedReinforcementsCount = _collectCourseCompletedReinforcements(
      courseId: ctx.courseId,
      course: course,
      roadmap: roadmap,
      skills: ctx.skills,
      profile: profile,
    ).length;

    final weakScores = scoreValues
        .where((s) => s.score < AdaptiveThresholds.targetedPracticeMin)
        .toList();
    final strongScores = scoreValues
        .where((s) => s.score >= AdaptiveThresholds.standardMin)
        .toList();
    final weakest = _findWeakestSkill(ctx.skills, ctx.skillScores);
    final activeNode = _resolveActiveNode(roadmap);

    final hasPilotRemediation = ctx.mathObjectives.any(
      (n) =>
          n.status == NodeStatus.reinforcement ||
          n.mastery?.state == 'needs_review' ||
          n.reviewDue ||
          n.mastery?.reviewDue == true,
    );
    final needsReinforcement =
        weakScores.isNotEmpty ||
        hasPilotRemediation ||
        (activeNode != null &&
            (activeNode.isReinforcement ||
                activeNode.status == NodeStatus.reinforcement ||
                activeNode.mastery?.state == 'needs_review'));

    final hasPracticeActivity =
        completedLessonsCount > 0 ||
        completedReinforcementsCount > 0 ||
        completedNodesCount > 0;
    final hasCourseConfigured =
        (course != null && profile?.courseLevels.containsKey(course.id) == true) ||
        hasDiagnostics ||
        hasPracticeActivity ||
        ctx.isMathPilot;
    final hasPathSelected =
        hasCourseConfigured &&
        ((roadmap?.nodes.isNotEmpty == true) || activeNode != null);
    final hasProgressMeasured =
        hasPracticeActivity && (hasDiagnostics || ctx.isMathPilot);

    int activeStep = 1;
    if (!hasDiagnostics && !hasPracticeActivity) {
      activeStep = 1;
    } else if (hasPracticeActivity && hasProgressMeasured) {
      activeStep = 5;
    } else if (hasPracticeActivity) {
      activeStep = 4;
    } else if (hasPathSelected) {
      activeStep = 3;
    } else {
      activeStep = 2;
    }

    AdaptiveStepStatus stepStatus(int stepNum, bool _) {
      if (activeStep == stepNum) return AdaptiveStepStatus.active;
      if (stepNum < activeStep) {
        return AdaptiveStepStatus.completed;
      }
      return AdaptiveStepStatus.upcoming;
    }

    final overall = scoreValues.isNotEmpty
        ? SkillScoringEngine.computeOverallScore(ctx.skillScores)
        : (ctx.isMathPilot && ctx.mathObjectives.isNotEmpty
              ? ((100 * completedNodesCount) / ctx.mathObjectives.length).round()
              : 0);

    final activeNodeTitle = activeNode?.localizedTitle(lang);
    final doneTasks =
        (completedLessonsCount > completedNodesCount
            ? completedLessonsCount
            : completedNodesCount) +
        completedReinforcementsCount;

    final steps = <AdaptiveStepState>[
      AdaptiveStepState(
        step: 1,
        code: '01',
        key: AdaptiveStepKey.diagnostic,
        status: stepStatus(1, hasDiagnostics || hasPracticeActivity),
        metricLabel: hasDiagnostics
            ? (isRu
                  ? 'Оценено навыков: ${scoreValues.length}'
                  : '${scoreValues.length} ko‘nikma baholangan')
            : hasCourseConfigured
            ? (isRu ? 'План выбран' : 'Reja tanlangan')
            : (isRu ? 'Стартовая проверка' : 'Boshlang‘ich tekshiruv'),
      ),
      AdaptiveStepState(
        step: 2,
        code: '02',
        key: AdaptiveStepKey.profile,
        status: stepStatus(2, hasDiagnostics || hasPracticeActivity),
        metricLabel: hasDiagnostics || hasPracticeActivity
            ? (weakScores.isNotEmpty
                  ? (isRu
                        ? '${weakScores.length} пробел · ${strongScores.length} сильных'
                        : '${weakScores.length} bo‘shliq · ${strongScores.length} kuchli')
                  : (isRu
                        ? 'Сильных тем: ${strongScores.length}'
                        : '${strongScores.length} kuchli mavzu'))
            : (isRu ? 'Анализ пробелов' : 'Bo‘shliqlar tahlili'),
      ),
      AdaptiveStepState(
        step: 3,
        code: '03',
        key: AdaptiveStepKey.path,
        status: stepStatus(3, hasPathSelected),
        metricLabel: activeNodeTitle ??
            (isRu ? 'Подбор следующего шага' : 'Mos qadam tanlanadi'),
      ),
      AdaptiveStepState(
        step: 4,
        code: '04',
        key: AdaptiveStepKey.practice,
        status: stepStatus(4, hasPracticeActivity),
        metricLabel: needsReinforcement
            ? (isRu
                  ? 'Закрепление: ${weakest.skill?.name ?? activeNodeTitle ?? 'слабая тема'}'
                  : 'Mustahkamlash: ${weakest.skill?.name ?? activeNodeTitle ?? 'zaif mavzu'}')
            : (isRu
                  ? 'Выполнено шагов: $doneTasks'
                  : '$doneTasks mashq bajarilgan'),
      ),
      AdaptiveStepState(
        step: 5,
        code: '05',
        key: AdaptiveStepKey.progress,
        status: stepStatus(5, hasProgressMeasured),
        metricLabel: hasProgressMeasured
            ? (isRu ? 'Освоение: $overall%' : '$overall% o‘zlashtirish')
            : (isRu ? 'Повторная оценка' : 'Qayta o‘lchash'),
      ),
    ];

    final hasTargetedPractice =
        !needsReinforcement &&
        weakest.skill != null &&
        weakest.scoreObj != null &&
        weakest.scoreObj!.score >= AdaptiveThresholds.targetedPracticeMin &&
        weakest.scoreObj!.score <= AdaptiveThresholds.targetedPracticeMax;

    final String loopUpdateSummary;
    if (!hasDiagnostics && !hasPracticeActivity) {
      loopUpdateSummary = isRu
          ? 'Сразу после диагностики или первого урока следующий персональный шаг обновится автоматически.'
          : 'Diagnostika yoki ilk dars natijasi profilga yozilishi bilan keyingi shaxsiy qadam avtomatik yangilanadi.';
    } else if (needsReinforcement && (weakest.skill != null || activeNode != null)) {
      final focusName = weakest.skill?.name ?? activeNodeTitle ?? (isRu ? 'Тема' : 'Mavzu');
      final sc = weakest.scoreObj?.score ?? 0;
      loopUpdateSummary = isRu
          ? 'По теме «$focusName» зафиксирован результат $sc% — следующим шагом выбрано упражнение на закрепление.'
          : '"$focusName" mavzusida $sc% ko‘rsatkich qayd etildi — shu sababli keyingi qadam sifatida mustahkamlash mashqi tanlandi.';
    } else if (hasTargetedPractice && weakest.skill != null) {
      final sc = weakest.scoreObj?.score ?? 0;
      loopUpdateSummary = isRu
          ? 'Тема «${weakest.skill!.name}» на уровне $sc% (50–69%) — рекомендована целевая практика для выхода на 70%+.'
          : '"${weakest.skill!.name}" mavzusi $sc% (50–69%) darajada — 70%+ mustahkam natija uchun maqsadli mashq tavsiya qilindi.';
    } else {
      final nextLabel = activeNodeTitle ?? (isRu ? 'следующая тема' : 'keyingi mavzu');
      loopUpdateSummary = isRu
          ? 'По итогам практики общее освоение достигло $overall%, открыт этап «$nextLabel».'
          : 'So‘nggi natijalar asosida umumiy o‘zlashtirish $overall% ga yetdi va navbatdagi bosqich "$nextLabel" ochildi.';
    }

    return AdaptiveCycleSnapshot(
      activeStep: activeStep,
      steps: steps,
      loopUpdateSummary: loopUpdateSummary,
      weakestSkillName: weakest.skill?.name,
      weakestScore: weakest.scoreObj?.score,
      strongSkillsCount: strongScores.length,
      weakSkillsCount: weakScores.length,
      needsReinforcement: needsReinforcement,
      activeNodeTitle: activeNodeTitle,
    );
  }

  static List<ExplainableFactor> buildExplainableFactors(
    AdaptiveContextInput input,
  ) {
    final isRu = input.localeCode == 'ru';
    final lang = isRu ? 'ru' : 'uz';
    final ctx = _resolveEffectiveContext(input);
    final profile = input.profile;
    final course = input.course;
    final roadmap = input.roadmap;

    final scoreValues = ctx.skillScores.values.toList();
    final completedNodesCount = ctx.mathObjectives
        .where((n) => n.status == NodeStatus.completed)
        .length;
    final overall = scoreValues.isNotEmpty
        ? SkillScoringEngine.computeOverallScore(ctx.skillScores)
        : (ctx.isMathPilot && ctx.mathObjectives.isNotEmpty
              ? ((100 * completedNodesCount) / ctx.mathObjectives.length).round()
              : 0);
    final weakest = _findWeakestSkill(ctx.skills, ctx.skillScores);
    final goal = profile?.goal ?? OnboardingGoal.mastery;
    final dailyMinutes = profile?.dailyMinutes ?? 15;
    final completedLessons = course != null
        ? course.lessons
              .where((id) => profile?.completedLessonIds.contains(id) == true)
              .length
        : (profile?.completedLessonIds.length ?? 0);
    final completedCount = completedLessons > completedNodesCount
        ? completedLessons
        : completedNodesCount;
    final streakDays = profile?.streakDays ?? 0;
    final activeNode = _resolveActiveNode(roadmap);

    final speedLabel = completedCount >= 4 || streakDays >= 5
        ? (isRu ? 'Высокий темп' : 'Yuqori sur’at')
        : completedCount >= 1
        ? (isRu ? 'Стабильный ритм' : 'Barqaror ritm')
        : (isRu ? 'Стартовый темп' : 'Boshlang‘ich temp');

    final weakCount = scoreValues
        .where((s) => s.score < AdaptiveThresholds.targetedPracticeMin)
        .length;
    final targetedCount = scoreValues
        .where(
          (s) =>
              s.score >= AdaptiveThresholds.targetedPracticeMin &&
              s.score <= AdaptiveThresholds.targetedPracticeMax,
        )
        .length;

    return [
      ExplainableFactor(
        key: ExplainableFactorKey.goal,
        label: isRu ? 'Цель' : 'Maqsad',
        value: _goalLabel(goal, isRu),
        impact: switch (goal) {
          OnboardingGoal.examPrep =>
            isRu
                ? 'Приоритет отдан контрольным точкам и самым слабым темам.'
                : 'Nazorat bosqichlari va eng zaif mavzular birinchi o‘ringa qo‘yiladi.',
          OnboardingGoal.skillsBoost =>
            isRu
                ? 'Увеличена доля практических и интерактивных заданий.'
                : 'Amaliy mashqlar va interaktiv topshiriqlar ulushi oshiriladi.',
          OnboardingGoal.mastery =>
            isRu
                ? 'Последовательное и прочное освоение базовых тем.'
                : 'Tayanch tushunchalar ketma-ket va mustahkam o‘zlashtiriladi.',
        },
      ),
      ExplainableFactor(
        key: ExplainableFactorKey.skillProfile,
        label: isRu ? 'Профиль навыков' : 'Ko‘nikmalar profili',
        value: weakest.skill != null
            ? (isRu ? 'Фокус: ${weakest.skill!.name}' : 'Fokus: ${weakest.skill!.name}')
            : (isRu
                  ? 'Базовых навыков: ${ctx.skills.length}'
                  : '${ctx.skills.length} ta tayanch ko‘nikma'),
        impact: weakest.skill != null
            ? (isRu
                  ? 'Выбран приоритетом из-за наименьшего балла (${weakest.scoreObj?.score ?? 0}%).'
                  : 'Eng past ko‘rsatkich (${weakest.scoreObj?.score ?? 0}%) shu mavzuda aniqlangani uchun ustuvor etib belgilandi.')
            : (isRu
                  ? 'Карта сильных и слабых сторон строится после диагностики.'
                  : 'Diagnostikadan so‘ng kuchli va zaif mavzular xaritasi shakllanadi.'),
      ),
      ExplainableFactor(
        key: ExplainableFactorKey.knowledgeLevel,
        label: isRu ? 'Уровень знаний' : 'Bilim darajasi',
        value: scoreValues.isNotEmpty
            ? '$overall% (${_masteryLabel(overall, isRu)})'
            : (isRu ? 'Ожидается диагностика' : 'Boshlang‘ich baholash kutilmoqda'),
        impact: scoreValues.isNotEmpty && overall < 50
            ? (isRu
                  ? 'Рекомендуется закрыть базовый пробел перед переходом дальше.'
                  : 'Murakkab bosqichga o‘tishdan oldin asosiy bo‘shliqni yopish tavsiya qilinadi.')
            : (isRu
                  ? 'Подобрано задание подходящей сложности для следующего шага.'
                  : 'Keyingi bosqichga chiqish uchun mos qiyinlikdagi topshiriq tanlandi.'),
      ),
      ExplainableFactor(
        key: ExplainableFactorKey.errorPattern,
        label: isRu ? 'Ошибки и пробелы' : 'Xatolar va bo‘shliq',
        value: weakCount > 0
            ? (isRu ? 'Пробелов (<50%): $weakCount' : '$weakCount ta bo‘shliq (<50%)')
            : targetedCount > 0
            ? (isRu
                  ? 'Целевая практика (50–69%): $targetedCount'
                  : '$targetedCount ta maqsadli mashq (50–69%)')
            : scoreValues.isNotEmpty
            ? (isRu ? 'Критических пробелов нет' : 'Kritik bo‘shliq yo‘q')
            : (isRu ? 'Ошибки пока не зафиксированы' : 'Xatolar hali qayd etilmagan'),
        impact: weakCount > 0
            ? (isRu
                  ? 'Добавлено закрепление по теме «${weakest.skill?.name ?? activeNode?.localizedTitle(lang) ?? 'Тема'}».'
                  : '"${weakest.skill?.name ?? activeNode?.localizedTitle(lang) ?? 'Mavzu'}" bo‘yicha mustahkamlash mashqi yo‘l xaritasiga qo‘shildi.')
            : targetedCount > 0
            ? (isRu
                  ? 'Рекомендована практика для выхода на 70%+.'
                  : '"${weakest.skill?.name ?? activeNode?.localizedTitle(lang) ?? 'Mavzu'}" bo‘yicha 70%+ ga chiqish uchun maqsadli mashq tavsiya etildi.')
            : (isRu
                  ? 'При обнаружении ошибки система автоматически назначит практику.'
                  : 'Xato aniqlanishi bilan tizim avtomatik tarzda qayta mashq tavsiya qiladi.'),
      ),
      ExplainableFactor(
        key: ExplainableFactorKey.learningSpeed,
        label: isRu ? 'Темп обучения' : 'O‘rganish tezligi',
        value: speedLabel,
        impact: isRu
            ? 'Завершено уроков: $completedCount · серия дней: $streakDays.'
            : '$completedCount dars yakunlangan · $streakDays kun ketma-ket faollik asosida qadam yuklamasi moslandi.',
      ),
      ExplainableFactor(
        key: ExplainableFactorKey.dailyTime,
        label: isRu ? 'Дневной бюджет' : 'Kunlik vaqt',
        value: isRu ? '$dailyMinutes мин / день' : '$dailyMinutes daqiqa / kun',
        impact: dailyMinutes <= 5
            ? (isRu
                  ? 'Выделена 1 короткая микро-задача на 5 минут.'
                  : '5 daqiqalik mikro-byudjetga mos bitta aniq vazifa ajratildi.')
            : (isRu
                  ? 'Урок и контрольная практика распределены под бюджет $dailyMinutes мин.'
                  : '$dailyMinutes daqiqalik byudjetga mos dars va nazorat mashqlari taqsimlandi.'),
      ),
    ];
  }

  static List<DailyMicroTask> buildDailyMicroTasks(
    AdaptiveContextInput input,
  ) {
    final isRu = input.localeCode == 'ru';
    final lang = isRu ? 'ru' : 'uz';
    final ctx = _resolveEffectiveContext(input);
    final dailyMinutes = input.profile?.dailyMinutes ?? 15;
    final roadmap = input.roadmap;
    final activeNode = _resolveActiveNode(roadmap);
    final weakest = _findWeakestSkill(ctx.skills, ctx.skillScores);
    final hasScores = ctx.skillScores.isNotEmpty;
    final tasks = <DailyMicroTask>[];
    final usedNodeIds = <String>{};

    if (!hasScores) {
      tasks.add(
        DailyMicroTask(
          id: 'micro_diag',
          title: isRu
              ? '5-минутная адаптивная диагностика'
              : '5 daqiqalik adaptiv diagnostika',
          minutes: 5,
          type: 'diagnostic',
          reason: isRu
              ? 'Стартовый шаг для точного определения сильных и слабых тем.'
              : 'Bilim profili va zaif mavzularni aniq xaritalash uchun boshlang‘ich qadam.',
        ),
      );
    } else if (weakest.skill != null &&
        weakest.scoreObj != null &&
        weakest.scoreObj!.score < AdaptiveThresholds.targetedPracticeMin) {
      final reinfNodeId = _resolveReinforcementTargetNodeId(
        roadmap,
        weakest.skill!.id,
      );
      usedNodeIds.add(reinfNodeId);
      tasks.add(
        DailyMicroTask(
          id: 'micro_reinf',
          title: isRu
              ? 'Закрыть пробел: ${weakest.skill!.name}'
              : 'Bo‘shliqni yopish: ${weakest.skill!.name}',
          minutes: 5,
          type: 'reinforcement',
          targetNodeId: reinfNodeId,
          reason: isRu
              ? 'Целевое упражнение для подъёма результата ${weakest.scoreObj!.score}% выше 50%.'
              : '${weakest.scoreObj!.score}% natijani 50%+ darajaga ko‘tarish uchun maqsadli mashq.',
        ),
      );
    } else if (weakest.skill != null &&
        weakest.scoreObj != null &&
        weakest.scoreObj!.score <= AdaptiveThresholds.targetedPracticeMax) {
      final targetedNode =
          roadmap?.nodes
              .where(
                (n) =>
                    !n.isReinforcement &&
                    n.skillId == weakest.skill!.id &&
                    n.status != NodeStatus.completed &&
                    n.status != NodeStatus.locked,
              )
              .firstOrNull ??
          activeNode;
      if (targetedNode != null) usedNodeIds.add(targetedNode.id);
      tasks.add(
        DailyMicroTask(
          id: 'micro_targeted',
          title: isRu
              ? 'Целевая практика: ${weakest.skill!.name}'
              : 'Maqsadli mashq: ${weakest.skill!.name}',
          minutes: 5,
          type: 'reinforcement',
          targetNodeId: targetedNode?.id,
          reason: isRu
              ? 'Дополнительная практика для выхода с ${weakest.scoreObj!.score}% на 70%+.'
              : '${weakest.scoreObj!.score}% (50–69%) natijani 70%+ mustahkam darajaga olib chiqish uchun qo‘shimcha mashq.',
        ),
      );
    }

    final nextLessonNode =
        activeNode != null && !usedNodeIds.contains(activeNode.id)
        ? activeNode
        : roadmap?.nodes
              .where(
                (n) =>
                    !n.isOptional &&
                    !usedNodeIds.contains(n.id) &&
                    (n.status == NodeStatus.available ||
                        n.status == NodeStatus.reinforcement ||
                        n.status == NodeStatus.inProgress),
              )
              .firstOrNull;

    if (nextLessonNode != null) {
      final cap = dailyMinutes >= 30 ? 15 : 10;
      tasks.add(
        DailyMicroTask(
          id: 'micro_node_${nextLessonNode.id}',
          title: nextLessonNode.localizedTitle(lang),
          minutes: nextLessonNode.estimatedMinutes < cap
              ? nextLessonNode.estimatedMinutes
              : cap,
          type: nextLessonNode.isReinforcement ? 'reinforcement' : 'lesson',
          targetNodeId: nextLessonNode.id,
          reason: nextLessonNode.isReinforcement
              ? (isRu
                    ? 'Этап закрепления предыдущих ошибок.'
                    : 'Oldingi xatolarni qayta mustahkamlash bosqichi.')
              : (isRu
                    ? 'Следующий основной этап вашего учебного пути.'
                    : 'Ta’lim yo‘lingizdagi navbatdagi asosiy bosqich.'),
        ),
      );
    }

    tasks.add(
      DailyMicroTask(
        id: 'micro_review',
        title: isRu
            ? 'Быстрый разбор 1 вопроса с Yo‘lchi AI'
            : 'Yo‘lchi AI bilan 1 ta tezkor savol-javob tahlili',
        minutes: dailyMinutes >= 60 ? 15 : (dailyMinutes >= 30 ? 10 : 5),
        type: 'lesson',
        reason: isRu
            ? 'Формативная обратная связь: проверка понимания правила.'
            : 'Formative feedback: qoidani mustaqil tushuntira olish darajasini tekshirish.',
      ),
    );

    final maxTasks = dailyMinutes <= 5 ? 1 : (dailyMinutes <= 15 ? 2 : 3);
    return tasks.take(maxTasks).toList(growable: false);
  }

  static AdaptiveEffectivenessMetrics measureEffectiveness(
    AdaptiveContextInput input,
  ) {
    final ctx = _resolveEffectiveContext(input);
    final profile = input.profile;
    final course = input.course;
    final roadmap = input.roadmap;

    final scoreValues = ctx.skillScores.values.toList();
    final hasScores = scoreValues.isNotEmpty;
    final currentScore = hasScores
        ? SkillScoringEngine.computeOverallScore(ctx.skillScores)
        : 0;

    final explicitPlacementScore = ctx.courseId != null
        ? profile?.placementScoreByCourse[ctx.courseId]
        : null;
    final hasPlacementSkills = ctx.placementSkillScores.isNotEmpty;
    final hasDiagnosticBaseline =
        explicitPlacementScore != null || hasPlacementSkills;

    final completedCourseReinfIds = _collectCourseCompletedReinforcements(
      courseId: ctx.courseId,
      course: course,
      roadmap: roadmap,
      skills: ctx.skills,
      profile: profile,
    );
    final completedLessons = course != null
        ? course.lessons
              .where((id) => profile?.completedLessonIds.contains(id) == true)
              .length
        : (profile?.completedLessonIds.length ?? 0);
    final completedNodesCount = roadmap != null
        ? roadmap.nodes
              .where(
                (n) =>
                    !n.isReinforcement &&
                    !n.isOptional &&
                    n.status == NodeStatus.completed,
              )
              .length
        : ctx.mathObjectives
              .where((n) => n.status == NodeStatus.completed)
              .length;
    final completedCourseReinforcements = completedCourseReinfIds.length;

    final hasPracticeActivity =
        completedLessons > 0 ||
        completedCourseReinforcements > 0 ||
        completedNodesCount > 0;

    final baselineScore = hasDiagnosticBaseline
        ? (explicitPlacementScore ??
              SkillScoringEngine.computeOverallScore(ctx.placementSkillScores))
        : 0;

    final growthDelta =
        hasDiagnosticBaseline && hasPracticeActivity && hasScores
        ? (currentScore > baselineScore ? currentScore - baselineScore : 0)
        : 0;

    var detectedGapsCount = 0;
    var closedGapsCount = 0;

    final skillDeltas = ctx.skills.map((skill) {
      final scoreObj = ctx.skillScores[skill.id];
      final plcObj = ctx.placementSkillScores[skill.id];
      final hasReinforcementCompleted = _hasSkillCompletedReinforcement(
        skillId: skill.id,
        courseId: ctx.courseId,
        roadmap: roadmap,
        completedCourseReinfIds: completedCourseReinfIds,
      );

      if (scoreObj == null) {
        return AdaptiveSkillDelta(
          skillId: skill.id,
          skillName: skill.name,
          baseline: plcObj?.score ?? 0,
          current: 0,
          delta: 0,
          status: AdaptiveSkillDeltaStatus.unassessed,
        );
      }

      final skillBaseline = plcObj?.score ?? 0;
      final isGapNow = scoreObj.score < AdaptiveThresholds.targetedPracticeMin;
      final hadDiagnosticGap =
          plcObj != null &&
          plcObj.score < AdaptiveThresholds.targetedPracticeMin;
      final wasGapClosed =
          hasPracticeActivity &&
          (hasReinforcementCompleted || hadDiagnosticGap) &&
          scoreObj.score >= AdaptiveThresholds.targetedPracticeMin;

      if (isGapNow || hasReinforcementCompleted || hadDiagnosticGap) {
        detectedGapsCount += 1;
      }
      if (wasGapClosed) {
        closedGapsCount += 1;
      }

      final status = scoreObj.score >= AdaptiveThresholds.standardMin
          ? (wasGapClosed
                ? AdaptiveSkillDeltaStatus.closedGap
                : AdaptiveSkillDeltaStatus.mastered)
          : isGapNow
          ? AdaptiveSkillDeltaStatus.gapDetected
          : wasGapClosed
          ? AdaptiveSkillDeltaStatus.closedGap
          : AdaptiveSkillDeltaStatus.reinforcing;

      final rawDelta = plcObj != null && hasPracticeActivity
          ? scoreObj.score - skillBaseline
          : 0;

      return AdaptiveSkillDelta(
        skillId: skill.id,
        skillName: skill.name,
        baseline: skillBaseline,
        current: scoreObj.score,
        delta: rawDelta > 0 ? rawDelta : 0,
        status: status,
      );
    }).toList(growable: false);

    final effectiveDone = completedLessons > completedNodesCount
        ? completedLessons
        : completedNodesCount;
    final adaptiveUpdatesCount =
        effectiveDone +
        completedCourseReinforcements +
        (hasDiagnosticBaseline ? 1 : 0);
    final dailyMinutesBudget = profile?.dailyMinutes ?? 15;
    final rawPace =
        45 +
        ((effectiveDone * 14 + completedCourseReinforcements * 18).clamp(
          0,
          55,
        ));
    final paceEfficiencyPct = hasPracticeActivity ? rawPace.clamp(0, 100) : 0;

    return AdaptiveEffectivenessMetrics(
      hasDiagnosticBaseline: hasDiagnosticBaseline,
      baselineScore: baselineScore,
      currentScore: currentScore,
      growthDelta: growthDelta,
      detectedGapsCount: detectedGapsCount,
      closedGapsCount: closedGapsCount,
      adaptiveUpdatesCount: adaptiveUpdatesCount,
      dailyMinutesBudget: dailyMinutesBudget,
      paceEfficiencyPct: paceEfficiencyPct,
      skillDeltas: skillDeltas,
    );
  }
}
