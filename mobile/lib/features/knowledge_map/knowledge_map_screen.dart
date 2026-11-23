import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/edtech_section_header.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/entities/skill.dart';
import '../../domain/entities/skill_score.dart';
import '../../domain/personalization/learning_start.dart';
import '../../domain/personalization/skill_scoring_engine.dart';

class KnowledgeMapScreen extends ConsumerStatefulWidget {
  const KnowledgeMapScreen({super.key});

  @override
  ConsumerState<KnowledgeMapScreen> createState() => _KnowledgeMapScreenState();
}

class _KnowledgeMapScreenState extends ConsumerState<KnowledgeMapScreen> {
  String? _requestedRoadmapCourseId;
  bool _isStartingLesson = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRoadmapLoaded());
  }

  String _resolveLang(BuildContext context) {
    if (Localizations.of<AppStrings>(context, AppStrings) case final strings?) {
      return strings.isRu ? 'ru' : 'uz';
    }
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  void _ensureRoadmapLoaded({String? courseId, bool force = false}) {
    if (!mounted) return;
    final resolvedCourseId =
        courseId ?? ref.read(courseStateNotifierProvider).activeCourse?.id;
    if (resolvedCourseId == null || resolvedCourseId.isEmpty) return;
    final currentPath = ref.read(roadmapStateNotifierProvider).valueOrNull;
    if (!force &&
        (currentPath?.courseId == resolvedCourseId ||
            _requestedRoadmapCourseId == resolvedCourseId)) {
      return;
    }
    _requestedRoadmapCourseId = resolvedCourseId;
    ref
        .read(roadmapStateNotifierProvider.notifier)
        .loadRoadmap(resolvedCourseId);
  }

  Future<void> _startFirstExercise(
    Course course,
    LearnerProfile profile,
    LearningPath path,
    AppStrings s,
    String lang,
  ) async {
    if (_isStartingLesson) return;
    final lessonId = resolveNextLearningLesson(course, profile, path);
    if (lessonId == null) {
      context.push('/roadmap');
      return;
    }
    setState(() => _isStartingLesson = true);
    try {
      await ref
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson(lessonId, uiLocale: lang);
      if (!mounted ||
          ref.read(courseStateNotifierProvider).activeCourse?.id != course.id) {
        return;
      }
      if (ref.read(lessonSessionNotifierProvider).lesson?.id == lessonId) {
        await context.push('/lesson');
        if (mounted) {
          _ensureRoadmapLoaded(courseId: course.id, force: true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.lessonLoadFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingLesson = false);
      }
    }
  }

  ({String label, IconData icon, AppBadgeVariant variant, Color accent})
  _nodeStatusMeta(LearningPathNode node, AppStrings s, AppSemanticColors c) {
    if (node.reviewDue) {
      return (
        label: s.statusReviewDue,
        icon: Icons.schedule_rounded,
        variant: AppBadgeVariant.amber,
        accent: c.warningText,
      );
    }
    return switch (node.status) {
      NodeStatus.completed => (
        label: s.statusMastered,
        icon: Icons.check_circle_rounded,
        variant: AppBadgeVariant.emerald,
        accent: c.successText,
      ),
      NodeStatus.reinforcement => (
        label: s.statusReinforcement,
        icon: Icons.refresh_rounded,
        variant: AppBadgeVariant.amber,
        accent: c.warningText,
      ),
      NodeStatus.inProgress => (
        label: s.statusInProgress,
        icon: Icons.play_circle_outline_rounded,
        variant: AppBadgeVariant.blue,
        accent: c.isDark ? c.brandStrong : c.brand,
      ),
      NodeStatus.available => (
        label: s.statusAvailable,
        icon: Icons.play_arrow_rounded,
        variant: AppBadgeVariant.blue,
        accent: c.isDark ? c.brandStrong : c.brand,
      ),
      NodeStatus.locked => (
        label: s.statusPrerequisiteNeeded,
        icon: Icons.lock_outline_rounded,
        variant: AppBadgeVariant.slate,
        accent: c.slatefine,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
    final s =
        Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings.forCode(lang);
    final courseState = ref.watch(courseStateNotifierProvider);
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final roadmapAsync = ref.watch(roadmapStateNotifierProvider);
    final activeCourse = courseState.activeCourse;
    final isMathPilot = usesMathMastery(activeCourse?.id);
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    ref.listen<String?>(
      courseStateNotifierProvider.select((st) => st.activeCourse?.id),
      (prev, nextId) {
        if (nextId != null && nextId != prev && nextId != _requestedRoadmapCourseId) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _ensureRoadmapLoaded(courseId: nextId),
          );
        }
      },
    );

    final baseTitle = isRu ? s.knowledgeMapTitle : 'Bilim Xaritasi';

    return Scaffold(
      backgroundColor: c.isDark ? AppColors.darkBackground : c.canvas,
      appBar: AppBar(
        toolbarHeight: isLargeText ? 144 : null,
        title: Text(
          activeCourse == null
              ? baseTitle
              : '$baseTitle • ${s.localizedCourseTitle(activeCourse)}',
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route_rounded),
            tooltip: s.navRoadmap,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => context.go('/roadmap'),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: courseState.isLoading
                ? Column(
                    children: [
                      _buildViewSwitcher(context, c, s),
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  )
                : courseState.error != null
                ? Column(
                    children: [
                      _buildViewSwitcher(context, c, s),
                      Expanded(
                        child: FriendlyErrorState(
                          message: courseState.error!,
                          onRetry: () => ref
                              .read(courseStateNotifierProvider.notifier)
                              .init(),
                        ),
                      ),
                    ],
                  )
                : activeCourse == null
                ? Column(
                    children: [
                      _buildViewSwitcher(context, c, s),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: AppCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.hub_outlined,
                                    size: 38,
                                    color: c.brand,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    s.chooseCoursePrompt,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.ui(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  AppButton(
                                    text: s.chooseSubject,
                                    onPressed: () => context.go('/courses'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : isMathPilot
                ? roadmapAsync.when(
                    loading: () => Column(
                      children: [
                        _buildViewSwitcher(context, c, s),
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    ),
                    error: (_, _) => Column(
                      children: [
                        _buildViewSwitcher(context, c, s),
                        Expanded(
                          child: FriendlyErrorState(
                            message: s.roadmapLoadError,
                            onRetry: () => _ensureRoadmapLoaded(
                              courseId: activeCourse.id,
                              force: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    data: (path) => learnerAsync.when(
                      loading: () => Column(
                        children: [
                          _buildViewSwitcher(context, c, s),
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ],
                      ),
                      error: (_, _) => Column(
                        children: [
                          _buildViewSwitcher(context, c, s),
                          Expanded(
                            child: FriendlyErrorState(
                              message: s.profileLoadFailed,
                              onRetry: () => ref
                                  .read(learnerStateNotifierProvider.notifier)
                                  .loadProfile(),
                            ),
                          ),
                        ],
                      ),
                      data: (profile) => _buildMathPilotBody(
                        context: context,
                        c: c,
                        s: s,
                        lang: lang,
                        course: activeCourse,
                        skills: courseState.activeSkills,
                        profile: profile,
                        path: path,
                      ),
                    ),
                  )
                : _buildRegularSkillsView(
                    context: context,
                    c: c,
                    s: s,
                    courseState: courseState,
                    learnerAsync: learnerAsync,
                    roadmapNodes:
                        roadmapAsync.valueOrNull?.courseId == activeCourse.id
                        ? roadmapAsync.valueOrNull?.nodes ?? const []
                        : const [],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewSwitcher(
    BuildContext context,
    AppSemanticColors c,
    AppStrings s, {
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 8,
    ),
  }) {
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                selected: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.ctaPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.knowledgeMapTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                button: true,
                selected: false,
                child: InkWell(
                  onTap: () => context.go('/roadmap'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s.navRoadmap,
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.graphite,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMathPilotBody({
    required BuildContext context,
    required AppSemanticColors c,
    required AppStrings s,
    required String lang,
    required Course course,
    required List<Skill> skills,
    required LearnerProfile profile,
    required LearningPath path,
  }) {
    final isRu = lang == 'ru';
    if (path.courseId != course.id) {
      return const Center(child: CircularProgressIndicator());
    }
    if (path.nodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.knowledgeMapEmptyPrompt,
                  textAlign: TextAlign.center,
                  style: AppTypography.ui(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.graphite,
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  text: s.openRoadmap,
                  onPressed: () => context.push('/roadmap'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final scores =
        profile.scoresByCourse[course.id] ?? const <String, SkillScore>{};
    final diagnosticScores = scores.values.toList();
    final hasDiagnosticScores = diagnosticScores.isNotEmpty;
    final hasPilotAnswers = path.nodes.any(
      (node) => node.mastery != null
          ? node.mastery!.answered > 0
          : (!node.isOptional &&
                (node.status == NodeStatus.inProgress ||
                    node.status == NodeStatus.completed)),
    );
    final overallMastery = path.masteryPercent ?? 0;
    final diagnosticAvg = SkillScoringEngine.computeOverallScore(scores);
    final diagnosticGaps = diagnosticScores.where((sk) => sk.score < 100).toList()
      ..sort((a, b) {
        final scoreOrder = a.score.compareTo(b.score);
        return scoreOrder != 0 ? scoreOrder : a.skillId.compareTo(b.skillId);
      });
    final evaluatedTopicsCount = path.nodes
        .where(
          (node) =>
              !node.isOptional &&
              (node.mastery != null
                  ? node.mastery!.answered > 0
                  : (node.status != NodeStatus.locked &&
                        node.status != NodeStatus.available)),
        )
        .length;

    String resolveSkillName(String skillId) =>
        skills.where((sk) => sk.id == skillId).firstOrNull?.name ??
        path.nodes.where((n) => n.skillId == skillId).firstOrNull?.title ??
        skillId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _buildViewSwitcher(
          context,
          c,
          s,
          padding: const EdgeInsets.only(bottom: 12),
        ),
        if (!hasDiagnosticScores && !hasPilotAnswers)
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBadge(
                  text: isRu ? 'Статус диагностики' : 'Diagnostika holati',
                  variant: AppBadgeVariant.blue,
                ),
                const SizedBox(height: 10),
                Text(
                  isRu ? 'Оценённые темы' : 'Baholangan mavzular',
                  style: AppTypography.ui(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isRu
                      ? 'Диагностика помогает настроить ваш учебный план.'
                      : 'Diagnostika öquv rejangizni moslaştirişga yordam beradi.',
                  style: AppTypography.ui(
                    fontSize: 13,
                    color: c.graphite,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  text: isRu ? 'Начать диагностику' : 'Diagnostikani boşlaş',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.small,
                  onPressed: () => context.push('/placement'),
                ),
              ],
            ),
          )
        else if (hasDiagnosticScores && !hasPilotAnswers) ...[
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge(
                      text: isRu ? 'Статус диагностики' : 'Diagnostika holati',
                      variant: AppBadgeVariant.blue,
                    ),
                    Text(
                      '$overallMastery%',
                      style: AppTypography.mono(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.isDark ? c.brandStrong : c.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.diagnosticResultTitle,
                  style: AppTypography.ui(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isRu
                      ? 'Диагностика: $diagnosticAvg% (${diagnosticScores.length} навыков). Освоение уроков: $overallMastery%.'
                      : 'Diagnostika: $diagnosticAvg% (${diagnosticScores.length} ta könikma). Darslardagi özlaştiriş: $overallMastery%.',
                  style: AppTypography.ui(
                    fontSize: 13,
                    color: c.graphite,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBadge(
                  text: isRu ? 'Зона внимания' : 'Diqqat markazi',
                  variant: diagnosticGaps.isNotEmpty
                      ? AppBadgeVariant.rose
                      : AppBadgeVariant.emerald,
                ),
                const SizedBox(height: 10),
                Text(
                  isRu ? 'Следующий шаг' : 'Keyingi qadam',
                  style: AppTypography.ui(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 6),
                if (diagnosticGaps.isNotEmpty) ...[
                  Text(
                    isRu
                        ? 'По результатам диагностики требуется дополнительная практика по следующим навыкам:'
                        : 'Diagnostikada quyidagi könikmalar böyiça qöşimça maşq kerak:',
                    style: AppTypography.ui(
                      fontSize: 13,
                      color: c.graphite,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final gap in diagnosticGaps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: c.errorText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${resolveSkillName(gap.skillId)} · ${gap.score}%',
                              style: AppTypography.ui(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    isRu
                        ? 'Следующий шаг: выполните первое упражнение базового урока, чтобы укрепить знания.'
                        : 'Keyingi qadam: tayanç darsdagi birinçi maşqni bajarib, bilimingizni mustahkamlang.',
                    style: AppTypography.ui(
                      fontSize: 13,
                      color: c.graphite,
                      height: 1.4,
                    ),
                  ),
                ] else
                  Text(
                    isRu
                        ? 'Вы ответили верно на все вопросы диагностики. Подтвердите знания в базовом упражнении, чтобы открыть следующую тему.'
                        : 'Diagnostikadagi barça savollarga töğri javob berdingiz. Bilimingizni amalda tasdiqlaş uçun tayanç maşq beriladi, şundan söng keyingi mavzu oçiladi.',
                    style: AppTypography.ui(
                      fontSize: 13,
                      color: c.graphite,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 14),
                AppButton(
                  text: isRu
                      ? 'Начать первое упражнение'
                      : 'Birinçi maşqni boşlaş',
                  isFullWidth: true,
                  isLoading: _isStartingLesson,
                  rightIcon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      _startFirstExercise(course, profile, path, s, lang),
                ),
              ],
            ),
          ),
        ] else
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge(
                      text: isRu
                          ? 'Общее освоение'
                          : 'Umumiy özlaştiriş',
                      variant: AppBadgeVariant.emerald,
                    ),
                    Text(
                      '$overallMastery%',
                      style: AppTypography.mono(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.isDark ? c.brandStrong : c.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isRu
                      ? '$evaluatedTopicsCount · Оценённые темы'
                      : '$evaluatedTopicsCount · Baholangan mavzular',
                  style: AppTypography.ui(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (overallMastery / 100).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: c.subtle,
                    valueColor: AlwaysStoppedAnimation<Color>(c.brand),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        EdTechReveal(
          index: 0,
          child: EdTechSectionHeader(
            pillText: isRu ? 'Учебные цели' : 'Öquv maqsadlari',
            title: isRu
                ? 'Темы и освоение'
                : 'Mavzular va özlaştiriş',
            highlightWord: isRu ? 'освоение' : 'özlaştiriş',
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < path.nodes.length; i++) ...[
          EdTechReveal(
            index: i + 1,
            child: _buildMathNodeCard(
              context,
              c,
              s,
              lang,
              path.nodes[i],
              i + 1,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        AppButton(
          text: s.adaptiveRoadmapCta,
          isFullWidth: true,
          size: AppButtonSize.large,
          rightIcon: const Icon(
            Icons.alt_route_rounded,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => context.go('/roadmap'),
        ),
      ],
    );
  }

  Widget _buildMathNodeCard(
    BuildContext context,
    AppSemanticColors c,
    AppStrings s,
    String lang,
    LearningPathNode node,
    int topicNumber,
  ) {
    final isRu = lang == 'ru';
    final label = node.reviewDue
        ? s.statusReviewDue
        : switch (node.status) {
            NodeStatus.locked =>
              isRu
                  ? 'Требуется базовая тема'
                  : 'Tayanç mavzu talab qilinadi',
            NodeStatus.completed => s.statusMastered,
            NodeStatus.reinforcement => s.statusReinforcement,
            NodeStatus.inProgress => s.statusInProgress,
            NodeStatus.available => s.statusAvailable,
          };
    final mastery = node.mastery;
    final requiredItems = mastery != null && mastery.requiredItems > 0
        ? mastery.requiredItems
        : 5;
    final answered = mastery?.answered ?? 0;
    final accuracy = mastery != null && mastery.answered > 0
        ? ((100 * mastery.correct) / mastery.answered).round()
        : null;
    final isCompleted = node.status == NodeStatus.completed;
    final isLocked = node.status == NodeStatus.locked;
    final iconColor = isCompleted
        ? c.successText
        : isLocked
            ? c.slatefine
            : (c.isDark ? c.brandStrong : c.brand);
    final iconBg = isCompleted
        ? c.successSoft
        : isLocked
            ? c.subtle
            : c.brandSoft;
    final iconData = isLocked
        ? Icons.lock_outline_rounded
        : isCompleted
            ? Icons.check_rounded
            : Icons.explore_outlined;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge(
                      text: isRu ? 'Тема $topicNumber' : '$topicNumber-mavzu',
                      variant: isCompleted
                          ? AppBadgeVariant.emerald
                          : isLocked
                              ? AppBadgeVariant.slate
                              : AppBadgeVariant.blue,
                    ),
                    if (node.isOptional)
                      AppBadge(
                        text: s.optionalTag,
                        variant: AppBadgeVariant.blue,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            node.localizedTitle(lang),
            style: AppTypography.ui(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          if (node.localizedDescription(lang).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              node.localizedDescription(lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.ui(
                fontSize: 12,
                color: c.graphite,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.ui(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isLocked
                  ? c.slatefine
                  : (c.isDark ? c.brandStrong : c.brand),
            ),
          ),
          if (mastery != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$answered/$requiredItems',
                  style: AppTypography.mono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                if (accuracy != null)
                  Text(
                    '$accuracy%',
                    style: AppTypography.mono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.successText,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (answered / requiredItems).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: c.subtle,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? c.success : c.brand,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: c.hairline),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  node.prerequisites.isEmpty
                      ? (isRu
                            ? 'Независимый стартовый модуль'
                            : 'Mustaqil boşlanğiç modul')
                      : (isRu
                            ? 'Базовый этап: ${node.prerequisites.length}'
                            : 'Tayanç bosqiç: ${node.prerequisites.length} ta'),
                  style: AppTypography.ui(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.slatefine,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                s.minutesDuration(node.estimatedMinutes),
                style: AppTypography.mono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: c.isDark ? c.brandStrong : c.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegularSkillsView({
    required BuildContext context,
    required AppSemanticColors c,
    required AppStrings s,
    required CourseState courseState,
    required AsyncValue<LearnerProfile> learnerAsync,
    required List<LearningPathNode> roadmapNodes,
  }) {
    final activeCourse = courseState.activeCourse;
    return learnerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => FriendlyErrorState(
        message: s.profileLoadFailed,
        onRetry: () =>
            ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
      ),
      data: (profile) {
        final scores =
            profile.scoresByCourse[activeCourse?.id ?? ''] ??
            const <String, SkillScore>{};
        final skills = courseState.activeSkills;

        SkillScore? weakestSkill;
        for (final score in scores.values) {
          if (weakestSkill == null || score.score < weakestSkill.score) {
            weakestSkill = score;
          }
        }

        final avgScore = SkillScoringEngine.computeOverallScore(scores);
        final weakestSkillObj =
            skills.where((sk) => sk.id == weakestSkill?.skillId).firstOrNull;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildViewSwitcher(
                context,
                c,
                s,
                padding: const EdgeInsets.only(bottom: 12),
              ),
              _KnowledgeOverviewHero(
                c: c,
                s: s,
                percent: avgScore,
                xp: profile.xp,
              ),
              if (weakestSkill != null && weakestSkill.score < 50) ...[
                const SizedBox(height: 16),
                _WeakSkillCallout(
                  c: c,
                  s: s,
                  badgeText: s.weakLinkBadge,
                  scoreText: '${weakestSkill.score}%',
                  titleText: s.weakSkillPrompt(
                    weakestSkillObj?.name ?? s.lessonLabel,
                  ),
                  subtitleText: s.isRu
                      ? s.weakSkillRoadmapNote
                      : 'Yöl xaritasida uşbu mavzuga maxsus mustahkamlaş qadami qöşildi.',
                ),
              ],
              const SizedBox(height: 20),
              EdTechReveal(
                index: 1,
                child: EdTechSectionHeader(
                  pillText: s.skillsAnalysisPill,
                  title:
                      '${s.skillsAnalysisTitle} ${s.skillsAnalysisHighlight}',
                  highlightWord: s.skillsAnalysisHighlight,
                ),
              ),
              const SizedBox(height: 12),
              if (skills.isEmpty)
                AppCard(
                  child: Text(
                    s.knowledgeMapEmptyPrompt,
                    style: AppTypography.ui(
                      fontSize: 14,
                      color: c.graphite,
                    ),
                  ),
                ),
              ...skills.indexed.map((entry) {
                final index = entry.$1;
                final skill = entry.$2;
                final scoreObj = scores[skill.id];
                final score = scoreObj?.score ?? 0;
                final isWeak =
                    weakestSkill?.skillId == skill.id && score < 50;
                final linkedNode = roadmapNodes
                    .where((n) => n.skillId == skill.id)
                    .firstOrNull;

                final Color barColor;
                final Color scoreTextColor;
                final AppBadgeVariant masteryVariant;
                final IconData masteryIcon;
                if (score < 40) {
                  barColor = c.error;
                  scoreTextColor = c.errorText;
                  masteryVariant = AppBadgeVariant.rose;
                  masteryIcon = Icons.warning_amber_rounded;
                } else if (score < 60) {
                  barColor = c.warning;
                  scoreTextColor = c.warningText;
                  masteryVariant = AppBadgeVariant.amber;
                  masteryIcon = Icons.trending_up_rounded;
                } else if (score >= 80) {
                  barColor = c.success;
                  scoreTextColor = c.successText;
                  masteryVariant = AppBadgeVariant.emerald;
                  masteryIcon = Icons.check_circle_rounded;
                } else {
                  barColor = c.brand;
                  scoreTextColor = c.isDark ? c.brandStrong : c.brand;
                  masteryVariant = AppBadgeVariant.blue;
                  masteryIcon = Icons.auto_awesome_rounded;
                }

                final nodeMeta = linkedNode != null
                    ? _nodeStatusMeta(linkedNode, s, c)
                    : null;
                final showNodeBadge =
                    nodeMeta != null &&
                    !(!isWeak &&
                        masteryVariant == AppBadgeVariant.emerald &&
                        nodeMeta.variant == AppBadgeVariant.emerald);

                return EdTechReveal(
                  index: index + 2,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      borderColor: isWeak
                          ? c.error.withValues(alpha: 0.45)
                          : c.hairline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      skill.name,
                                      style: AppTypography.ui(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: c.ink,
                                      ),
                                    ),
                                    AppBadge(
                                      text: s.masteryLabel(score),
                                      variant: isWeak
                                          ? AppBadgeVariant.rose
                                          : masteryVariant,
                                      icon: Icon(
                                        masteryIcon,
                                        size: 12,
                                        color: isWeak
                                            ? c.errorText
                                            : scoreTextColor,
                                      ),
                                    ),
                                    if (showNodeBadge)
                                      AppBadge(
                                        text: nodeMeta.label,
                                        variant: nodeMeta.variant,
                                        icon: Icon(
                                          nodeMeta.icon,
                                          size: 12,
                                          color: nodeMeta.accent,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$score%',
                                style: AppTypography.mono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: scoreTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            skill.description,
                            style: AppTypography.ui(
                              fontSize: 12.5,
                              color: c.slatefine,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (score / 100).clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: c.subtle,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                barColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              AppButton(
                text: s.adaptiveRoadmapCta,
                isFullWidth: true,
                size: AppButtonSize.large,
                rightIcon: const Icon(
                  Icons.alt_route_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: () => context.go('/roadmap'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _KnowledgeOverviewHero extends StatelessWidget {
  final AppSemanticColors c;
  final AppStrings s;
  final int percent;
  final int xp;

  const _KnowledgeOverviewHero({
    required this.c,
    required this.s,
    required this.percent,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final xpChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 16,
            color: Color(0xFFFBBF24),
          ),
          const SizedBox(width: 4),
          Text(
            '+$xp XP',
            style: AppTypography.mono(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFDE68A),
            ),
          ),
        ],
      ),
    );

    final metricColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.overallMastery,
          style: AppTypography.ui(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFE2E8F0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$percent%',
          style: AppTypography.mono(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: c.heroGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (textScale >= 1.4)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                metricColumn,
                const SizedBox(height: 10),
                xpChip,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: metricColumn),
                const SizedBox(width: 10),
                xpChip,
              ],
            ),
          const SizedBox(height: 12),
          Text(
            s.isRu
                ? s.knowledgeMapBannerDesc
                : 'Haqiqiy javoblaringiz tahlili asosida bilim xaritangiz şakllantirildi.',
            style: AppTypography.ui(
              fontSize: 12.5,
              color: const Color(0xFFE2E8F0),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakSkillCallout extends StatelessWidget {
  final AppSemanticColors c;
  final AppStrings s;
  final String badgeText;
  final String scoreText;
  final String titleText;
  final String subtitleText;

  const _WeakSkillCallout({
    required this.c,
    required this.s,
    required this.badgeText,
    required this.scoreText,
    required this.titleText,
    required this.subtitleText,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: Color.alphaBlend(c.errorSoft, c.paper),
      borderColor: c.error.withValues(alpha: 0.35),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.error.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: c.errorText,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge(
                      text: badgeText,
                      variant: AppBadgeVariant.rose,
                    ),
                    if (scoreText.isNotEmpty)
                      Text(
                        scoreText,
                        style: AppTypography.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.errorText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  titleText,
                  style: AppTypography.ui(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: AppTypography.ui(
                    fontSize: 12,
                    color: c.graphite,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
