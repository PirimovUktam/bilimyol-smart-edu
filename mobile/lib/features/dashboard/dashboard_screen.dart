import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/demo_control_bar.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../core/widgets/subject_icon.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/personalization/adaptive_cycle_engine.dart';
import '../../domain/personalization/learning_start.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import 'widgets/adaptive_cycle_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _courseTabIndex = 0; // 0: Aktiv, 1: Tavsiya, 2: Barchasi
  String _searchQuery = '';
  String? _requestedRoadmapCourseId;
  RoadmapStateNotifier? _requestedRoadmapNotifier;

  void _ensureRoadmapLoaded(String? courseId) {
    if (!mounted || courseId == null || courseId.isEmpty) return;
    final notifier = ref.read(roadmapStateNotifierProvider.notifier);
    final currentPath = ref.read(roadmapStateNotifierProvider).valueOrNull;
    if (currentPath?.courseId == courseId) {
      _requestedRoadmapCourseId = null;
      _requestedRoadmapNotifier = null;
      return;
    }
    if (identical(_requestedRoadmapNotifier, notifier) &&
        _requestedRoadmapCourseId == courseId) {
      return;
    }
    _requestedRoadmapNotifier = notifier;
    _requestedRoadmapCourseId = courseId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latestCourseId =
          ref.read(courseStateNotifierProvider).activeCourse?.id;
      if (latestCourseId != courseId) return;
      final latestPath = ref.read(roadmapStateNotifierProvider).valueOrNull;
      if (latestPath?.courseId == courseId) return;
      ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(courseId);
    });
  }

  static AppStrings _resolveStrings(BuildContext context) {
    final localized = Localizations.of<AppStrings>(context, AppStrings);
    if (localized != null) return localized;
    final appLang = Localizations.maybeLocaleOf(context)?.languageCode;
    if (appLang == 'ru') return AppStrings.ru;
    if (appLang == 'uz') return AppStrings.uz;
    return WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ru'
        ? AppStrings.ru
        : AppStrings.uz;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final lang = s.isRu ? 'ru' : 'uz';
    final state = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider);
    final activeCourse = state.activeCourse;
    final path = activeCourse == null
        ? null
        : ref.watch(roadmapStateNotifierProvider);
    final currentPath = path?.valueOrNull;
    final nodes =
        currentPath != null && currentPath.courseId == activeCourse?.id
        ? currentPath.nodes
              .where((node) => !node.isReinforcement && !node.isOptional)
              .toList()
        : <LearningPathNode>[];
    final next = nodes
        .where(
          (node) =>
              node.status == NodeStatus.available ||
              node.status == NodeStatus.inProgress ||
              node.status == NodeStatus.reinforcement,
        )
        .firstOrNull;
    final continuationId = next?.targetLessonId;
    final completed = nodes
        .where((node) => node.status == NodeStatus.completed)
        .length;
    final starting = ref.watch(
      lessonSessionNotifierProvider.select((state) => state.isLoading),
    );

    return Scaffold(
      appBar: AppBar(
        title: const BilimYolLogo(size: 30, showSubtitle: false),
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz_rounded, color: c.ink),
            tooltip: s.switchSubjectTooltip,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              context.go('/courses');
            },
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 0),
      body: SafeArea(
        child: learner.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: s.profileLoadFailed,
            onRetry: () =>
                ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
          ),
          data: (profile) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return FriendlyErrorState(
                message: state.error!,
                onRetry: () =>
                    ref.read(courseStateNotifierProvider.notifier).init(),
              );
            }
            if (activeCourse == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.chooseCoursePrompt,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: s.chooseSubject,
                        onPressed: () {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          context.go('/courses');
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            final needsPlan = !hasStartedCourse(activeCourse, profile);
            final mathPilot = usesMathMastery(activeCourse.id);
            final starter = pendingFoundationLesson(activeCourse, profile);
            final lessonId = starter ?? continuationId;
            final greetingName = profile.name.isEmpty
                ? s.defaultLearnerName
                : profile.name;

            final totalLessons = mathPilot
                ? nodes.length
                : activeCourse.lessons.isNotEmpty
                ? activeCourse.lessons.length
                : (nodes.isNotEmpty ? nodes.length : 5);
            final completedInCourse = activeCourse.lessons
                .where((id) => profile.completedLessonIds.contains(id))
                .length;
            final doneCount = !mathPilot && completedInCourse > 0
                ? completedInCourse
                : completed;
            final progressPct = totalLessons > 0
                ? ((100 * doneCount) / totalLessons).round().clamp(0, 100)
                : 0;

            final courseScores = profile.scoresByCourse[activeCourse.id] ?? {};
            final overallScore = !mathPilot && courseScores.isNotEmpty
                ? SkillScoringEngine.computeOverallScore(courseScores)
                : progressPct;
            _ensureRoadmapLoaded(activeCourse.id);
            final validRoadmap =
                currentPath != null && currentPath.courseId == activeCourse.id
                ? currentPath
                : null;
            final adaptiveInput = AdaptiveContextInput(
              course: activeCourse,
              profile: profile,
              skills: state.activeSkills,
              skillScores: courseScores,
              roadmap: validRoadmap,
              localeCode: lang,
            );
            final adaptiveCycle = AdaptiveCycleEngine.evaluateCycle(
              adaptiveInput,
            );
            final adaptiveFactors = AdaptiveCycleEngine.buildExplainableFactors(
              adaptiveInput,
            );
            final adaptiveTasks = AdaptiveCycleEngine.buildDailyMicroTasks(
              adaptiveInput,
            );

            final allCourses = state.courses;
            final query = _searchQuery.trim().toLowerCase();
            final filteredCourses = allCourses.where((course) {
              final matchesTab = switch (_courseTabIndex) {
                0 =>
                  course.id == activeCourse.id ||
                      hasStartedCourse(course, profile),
                1 =>
                  course.id != activeCourse.id &&
                      !hasStartedCourse(course, profile),
                _ => true,
              };
              if (!matchesTab) return false;
              if (query.isNotEmpty) {
                final localizedTitle = s.localizedCourseTitle(course).toLowerCase();
                final localizedDesc = s
                    .localizedCourseDescription(course)
                    .toLowerCase();
                return localizedTitle.contains(query) ||
                    localizedDesc.contains(query) ||
                    course.localizedTitle(lang).toLowerCase().contains(query) ||
                    course
                        .localizedDescription(lang)
                        .toLowerCase()
                        .contains(query) ||
                    course.title.toLowerCase().contains(query) ||
                    course.description.toLowerCase().contains(query);
              }
              return true;
            }).toList();

            Future<void> triggerContinueLesson() async {
              if (needsPlan) {
                ScaffoldMessenger.of(context).clearSnackBars();
                context.go('/courses');
                return;
              }
              if (lessonId == null) {
                context.push('/roadmap');
                return;
              }
              await ref
                  .read(lessonSessionNotifierProvider.notifier)
                  .startLesson(lessonId, uiLocale: lang);
              if (!context.mounted ||
                  ref.read(courseStateNotifierProvider).activeCourse?.id !=
                      activeCourse.id) {
                return;
              }
              if (ref.read(lessonSessionNotifierProvider).lesson?.id ==
                  lessonId) {
                context.push('/lesson');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.lessonLoadFailed)),
                );
              }
            }

            final heroCtaLabel = needsPlan
                ? s.chooseSubject
                : starter != null
                ? s.openFirstLesson
                : lessonId == null
                ? s.openRoadmap
                : s.continueLearning;

            final localizedNextTitle = next?.localizedTitle(lang);
            final localizedNextDesc = next?.localizedDescription(lang);
            final heroCurrentFocus = needsPlan
                ? s.heroFocusNeedsPlan
                : (localizedNextTitle != null && localizedNextTitle.isNotEmpty)
                ? localizedNextTitle
                : (next?.title ??
                      (starter != null
                          ? s.openFirstLesson
                          : s.localizedCourseTitle(activeCourse)));

            final heroSubtitle = needsPlan
                ? s.heroSubtitleNeedsPlan
                : starter != null
                ? s.heroSubtitleStarter
                : (localizedNextDesc != null && localizedNextDesc.isNotEmpty)
                ? localizedNextDesc
                : (next?.description.isNotEmpty == true
                    ? next!.description
                    : s.heroSubtitleDefault);

            final textScale = MediaQuery.textScalerOf(context).scale(1.0);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(18),
                  children: [
                    const DemoControlBar(),

                    // Search + XP & Streak Top Row (responsive, no fixed height)
                    EdTechReveal(
                      index: 0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stack =
                              textScale >= 1.35 || constraints.maxWidth < 315;
                          final searchField = Semantics(
                            textField: true,
                            label: s.searchCoursesHint,
                            child: TextField(
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: AppTypography.ui(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: c.ink,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: c.paper,
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 19,
                                  color: c.slatefine,
                                ),
                                hintText: s.searchCoursesHint,
                              ),
                            ),
                          );

                          final xpPill = ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: c.paper,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.hairline),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 18,
                                    color: c.isDark ? c.brandStrong : c.brand,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${profile.xp} XP',
                                    style: AppTypography.mono(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: c.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          final streakPill = ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: c.paper,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.hairline),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 18,
                                    color: c.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    s.streakDays(profile.streakDays),
                                    style: AppTypography.mono(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: c.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (stack) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                searchField,
                                const SizedBox(height: 8),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.end,
                                    children: [xpPill, streakPill],
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: searchField),
                              const SizedBox(width: 8),
                              xpPill,
                              const SizedBox(width: 6),
                              streakPill,
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Single Focal Hero Card ("Bugun nimani davom ettiraman?")
                    EdTechReveal(
                      index: 1,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: c.heroGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: c.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        subjectIcon(activeCourse.subject),
                                        size: 14,
                                        color: const Color(0xFF67E8F9),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          s.localizedCourseTitle(activeCourse),
                                          style: AppTypography.ui(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  s.heroGreeting(greetingName),
                                  style: AppTypography.ui(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFC7D2FE),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.heroContinuePrompt,
                              style: AppTypography.ui(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF67E8F9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              heroCurrentFocus,
                              style: AppTypography.ui(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              heroSubtitle,
                              maxLines: textScale > 1.3 ? null : 3,
                              overflow: textScale > 1.3
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: AppTypography.ui(
                                fontSize: 13.5,
                                color: Colors.white.withValues(alpha: 0.88),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: starting
                                  ? null
                                  : triggerContinueLesson,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF171A2B),
                                elevation: 0,
                                minimumSize: const Size(44, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (starting) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF5546E8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      heroCtaLabel,
                                      style: AppTypography.ui(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF171A2B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 17,
                                    color: Color(0xFF5546E8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Compact Progress & Streak Strip
                    EdTechReveal(
                      index: 2,
                      child: AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: c.brandSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.track_changes_rounded,
                                    size: 20,
                                    color: c.brand,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.todayGoal,
                                        style: AppTypography.ui(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: c.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${s.lessonsRatio(doneCount, totalLessons)} · ${s.dailyMinutesLabel(profile.dailyMinutes)}',
                                        style: AppTypography.mono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: c.slatefine,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.brandSoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$progressPct%',
                                    style: AppTypography.mono(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: c.brand,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: (progressPct / 100).clamp(0.06, 1.0),
                                minHeight: 8,
                                backgroundColor: c.subtle,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progressPct >= 100 ? c.success : c.brand,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Divider(color: c.hairline, height: 1),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final items = [
                                  _CompactMetricItem(
                                    icon: Icons.star_rounded,
                                    color: c.warning,
                                    bg: c.warningSoft,
                                    value: s.streakDays(profile.streakDays),
                                    label: s.streakSubtitle,
                                    c: c,
                                  ),
                                  _CompactMetricItem(
                                    icon: Icons.menu_book_rounded,
                                    color: c.brand,
                                    bg: c.brandSoft,
                                    value: s.completedCountLabel(
                                      profile.completedLessonIds.length,
                                    ),
                                    label: s.completedSubtitle,
                                    c: c,
                                  ),
                                  _CompactMetricItem(
                                    icon: Icons.donut_large_rounded,
                                    color: c.path,
                                    bg: c.pathSoft,
                                    value: '$overallScore%',
                                    label: s.progressLabel,
                                    c: c,
                                  ),
                                ];
                                if (textScale >= 1.45 ||
                                    constraints.maxWidth < 270) {
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: items
                                        .map(
                                          (item) => SizedBox(
                                            width:
                                                constraints.maxWidth >= 240 &&
                                                    textScale < 1.8
                                                ? (constraints.maxWidth - 12) /
                                                      2
                                                : constraints.maxWidth,
                                            child: item,
                                          ),
                                        )
                                        .toList(),
                                  );
                                }
                                return Row(
                                  children: items
                                      .map((item) => Expanded(child: item))
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Courses Switcher Section
                    EdTechReveal(
                      index: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                s.myCourses,
                                style: AppTypography.ui(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: c.ink,
                                ),
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final entry in [
                                    (0, s.tabActive),
                                    (1, s.tabRecommended),
                                    (2, s.tabAll),
                                  ])
                                    Semantics(
                                      button: true,
                                      selected: _courseTabIndex == entry.$1,
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => _courseTabIndex = entry.$1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 44,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  _courseTabIndex == entry.$1
                                                  ? c.ctaPrimary
                                                  : c.subtle,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color:
                                                    _courseTabIndex == entry.$1
                                                    ? c.ctaPrimary
                                                    : c.hairline,
                                              ),
                                            ),
                                            child: Text(
                                              entry.$2,
                                              style: AppTypography.ui(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    _courseTabIndex == entry.$1
                                                    ? Colors.white
                                                    : c.graphite,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (filteredCourses.isEmpty)
                            AppCard(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                s.noMatchingCourses,
                                style: AppTypography.ui(
                                  fontSize: 13.5,
                                  color: c.slatefine,
                                ),
                              ),
                            )
                          else
                            ...filteredCourses.map((Course course) {
                              final visual = subjectVisual(course.subject, c);
                              final cTotal = course.lessons.length;
                              final cDone = course.lessons
                                  .where(
                                    (id) =>
                                        profile.completedLessonIds.contains(id),
                                  )
                                  .length;
                              final cPct = cTotal > 0
                                  ? ((100 * cDone) / cTotal).round()
                                  : 0;
                              final isSelected = course.id == activeCourse.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AppCard(
                                  borderColor: isSelected
                                      ? visual.accent.withValues(alpha: 0.45)
                                      : c.hairline,
                                  padding: const EdgeInsets.all(14),
                                  onTap: () async {
                                    await ref
                                        .read(
                                          courseStateNotifierProvider.notifier,
                                        )
                                        .selectCourse(course.id);
                                    if (!context.mounted) return;
                                    if (!hasStartedCourse(course, profile)) {
                                      context.push('/onboarding');
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: visual.softBg,
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                          border: Border.all(
                                            color: visual.border,
                                          ),
                                        ),
                                        child: Icon(
                                          visual.icon,
                                          size: 22,
                                          color: visual.accent,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    s.localizedCourseTitle(
                                                      course,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTypography.ui(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: c.ink,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '$cPct%',
                                                  style: AppTypography.mono(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: visual.accent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: (cPct / 100).clamp(
                                                  0.06,
                                                  1.0,
                                                ),
                                                minHeight: 6,
                                                backgroundColor: c.subtle,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(visual.accent),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: visual.softBg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          size: 22,
                                          color: visual.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 5-Step Adaptive Cycle & 6-Input Explainable AI Card
                    EdTechReveal(
                      index: 4,
                      child: AdaptiveCycleCard(
                        cycle: adaptiveCycle,
                        factors: adaptiveFactors,
                        dailyTasks: adaptiveTasks,
                        localeCode: lang,
                        onStepAction: (stepKey) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          switch (stepKey) {
                            case AdaptiveStepKey.diagnostic:
                              context.push('/placement');
                            case AdaptiveStepKey.profile:
                              context.go('/knowledge-map');
                            case AdaptiveStepKey.path:
                              context.go('/roadmap');
                            case AdaptiveStepKey.practice:
                              triggerContinueLesson();
                            case AdaptiveStepKey.progress:
                              context.go('/progress');
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Yo‘lchi AI & Quick Actions Card
                    EdTechReveal(
                      index: 5,
                      child: AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const YolchiAIMascot(
                                  size: 46,
                                  mood: YolchiMood.happy,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.yolchiTutorHeader,
                                        style: AppTypography.ui(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: c.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        s.yolchiTutorDesc,
                                        style: AppTypography.ui(
                                          fontSize: 12.5,
                                          color: c.slatefine,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AppButton(
                                  text: s.openChat,
                                  onPressed: () => context.go('/ai-tutor'),
                                ),
                                if (!needsPlan)
                                  AppButton(
                                    text: s.startLevelBtn,
                                    variant: AppButtonVariant.outline,
                                    onPressed: () =>
                                        context.push('/onboarding'),
                                  ),
                                if (!needsPlan)
                                  AppButton(
                                    text: s.optionalDiagnosticBtn,
                                    variant: AppButtonVariant.outline,
                                    onPressed: () => context.push('/placement'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompactMetricItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String value;
  final String label;
  final AppSemanticColors c;

  const _CompactMetricItem({
    required this.icon,
    required this.color,
    required this.bg,
    required this.value,
    required this.label,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: c.slatefine,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
