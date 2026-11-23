import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/edtech_section_header.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../core/widgets/subject_icon.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../data/datasources/courses_data.dart';
import '../../domain/entities/course.dart';
import '../../domain/personalization/learning_start.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import '../../domain/repositories/i_learner_repository.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _timeframe = 'week';
  List<DailyActivitySummary> _activity = [];
  bool _isLoadingActivity = true;
  bool _activityFailed = false;
  int _activityGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final generation = ++_activityGeneration;
    if (!mounted) return;
    setState(() => _isLoadingActivity = true);
    final days = _timeframe == 'week' ? 7 : 30;
    try {
      final repo = ref.read(learnerRepositoryProvider);
      final data = await repo.getDailyActivity(days);
      if (mounted && generation == _activityGeneration) {
        setState(() {
          _activity = data;
          _activityFailed = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _activityGeneration) {
        setState(() {
          _activity = [];
          _activityFailed = true;
        });
      }
    } finally {
      if (mounted && generation == _activityGeneration) {
        setState(() => _isLoadingActivity = false);
      }
    }
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

  Course _resolveCourse(List<Course> loadedCourses, String id, Course fallback) {
    return loadedCourses.where((c) => c.id == id).firstOrNull ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final courseState = ref.watch(courseStateNotifierProvider);
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final activeCourse = courseState.activeCourse;
    final mathPilot = usesMathMastery(mathMasteryCourse);
    final path =
        mathPilot ? ref.watch(roadmapStateNotifierProvider).valueOrNull : null;
    final mathProgress =
        path?.courseId == mathMasteryCourse ? path?.masteryPercent : null;

    final brandAccent = c.isDark ? c.brandStrong : c.brand;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    final timeframeToggle = Semantics(
      button: true,
      label: _timeframe == 'week' ? s.timeframeWeek : s.timeframeMonth,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(
            () => _timeframe = _timeframe == 'week' ? 'month' : 'week',
          );
          _loadActivity();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: c.brand.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeframe == 'week'
                      ? s.timeframeWeek
                      : s.timeframeMonth,
                  style: AppTypography.ui(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: brandAccent,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: brandAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 96 : null,
        title: Text(
          s.progressScreenTitle,
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        actions: [
          if (!isLargeText)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: timeframeToggle,
            ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: learnerAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => FriendlyErrorState(
                message: s.profileLoadFailed,
                onRetry: () => ref
                    .read(learnerStateNotifierProvider.notifier)
                    .loadProfile(),
              ),
              data: (profile) {
                final courseScores =
                    profile.scoresByCourse[activeCourse?.id ?? ''] ?? {};
                final overallScore = usesMathMastery(activeCourse?.id)
                    ? mathProgress
                    : SkillScoringEngine.computeOverallScore(courseScores);
                final completedLessons = profile.completedLessonIds.length;
                final totalMinutes = _activity.fold<int>(
                  0,
                  (acc, d) => acc + d.activeMinutes,
                );
                final maxMinutes = _activity.fold<int>(
                  1,
                  (acc, d) => d.activeMinutes > acc ? d.activeMinutes : acc,
                );
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);

                final statItems = [
                  _StatTile(
                    icon: Icons.check_circle_rounded,
                    iconColor: c.successText,
                    bgColor: c.successSoft,
                    value: '$completedLessons',
                    label: s.statCompletedLessons,
                  ),
                  _StatTile(
                    icon: Icons.percent_rounded,
                    iconColor: c.path,
                    bgColor: c.pathSoft,
                    value: overallScore == null ? '—' : '$overallScore%',
                    label: s.statMastery,
                  ),
                  _StatTile(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: c.warningText,
                    bgColor: c.warningSoft,
                    value: s.streakDays(profile.streakDays),
                    label: s.statStreak,
                  ),
                  _StatTile(
                    icon: Icons.stars_rounded,
                    iconColor: brandAccent,
                    bgColor: c.brandSoft,
                    value: '${profile.xp} XP',
                    label: s.statXpTotal,
                  ),
                ];

                final mathCourse = _resolveCourse(
                  courseState.courses,
                  mathMasteryCourse,
                  seedCourses[0],
                );
                final engCourse = _resolveCourse(
                  courseState.courses,
                  'course_eng_01',
                  seedCourses[1],
                );
                final itCourse = _resolveCourse(
                  courseState.courses,
                  'course_it',
                  seedCourses[2],
                );
                final logicCourse = _resolveCourse(
                  courseState.courses,
                  'course_logic',
                  seedCourses[3],
                );

                final badges = [
                  (
                    title: s.badgeFirstStepTitle,
                    desc: s.badgeFirstStepDesc,
                    icon: Icons.flag_rounded,
                    earned: completedLessons >= 1,
                  ),
                  (
                    title: s.badge3DayStreakTitle,
                    desc: s.badge3DayStreakDesc,
                    icon: Icons.local_fire_department_rounded,
                    earned: profile.streakDays >= 3,
                  ),
                  (
                    title: s.badgeExpertTitle,
                    desc: s.badgeExpertDesc,
                    icon: Icons.auto_awesome_rounded,
                    earned: profile.xp >= 100,
                  ),
                  (
                    title: s.badgeMasterTitle,
                    desc: s.badgeMasterDesc,
                    icon: Icons.workspace_premium_rounded,
                    earned: completedLessons >= 5,
                  ),
                ];
                final earnedCount = badges.where((b) => b.earned).length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLargeText) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: timeframeToggle,
                        ),
                        const SizedBox(height: 12),
                      ],
                      EdTechReveal(
                        index: 0,
                        child: EdTechSectionHeader(
                          pillText: s.progressPill,
                          title: s.progressSectionFull,
                          highlightWord: s.progressSectionHighlight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final twoCol =
                              constraints.maxWidth >= 300 && textScale < 1.35;
                          if (!twoCol) {
                            return Column(
                              children: [
                                for (final (idx, tile) in statItems.indexed) ...[
                                  tile,
                                  if (idx < statItems.length - 1)
                                    const SizedBox(height: 10),
                                ],
                              ],
                            );
                          }
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: statItems[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: statItems[1]),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: statItems[2]),
                                  const SizedBox(width: 12),
                                  Expanded(child: statItems[3]),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Study Time Bar Chart
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    s.studyTimeTitle,
                                    style: AppTypography.ui(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: c.ink,
                                    ),
                                  ),
                                  Text(
                                    s.studyTimeUnit,
                                    style: AppTypography.ui(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.slatefine,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isLoadingActivity &&
                                !_activityFailed &&
                                _activity.isNotEmpty &&
                                totalMinutes > 0 &&
                                _timeframe == 'month') ...[
                              const SizedBox(height: 6),
                              Text(
                                s.studyTimeSummary(
                                  _activity.length,
                                  totalMinutes,
                                ),
                                style: AppTypography.mono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.slatefine,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (_isLoadingActivity)
                              const SizedBox(
                                height: 130,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_activityFailed)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 130,
                                ),
                                child: Center(
                                  child: _buildActivityError(c, s),
                                ),
                              )
                            else if (_activity.isEmpty || totalMinutes == 0)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 110,
                                ),
                                child: Center(
                                  child: Text(
                                    s.progressEmptyActivity,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.ui(
                                      fontSize: 13,
                                      color: c.slatefine,
                                    ),
                                  ),
                                ),
                              )
                            else if (_timeframe == 'week')
                              _WeeklyBars(
                                activity: _activity,
                                maxMinutes: maxMinutes,
                                c: c,
                                s: s,
                              )
                            else
                              _MonthlyBars(
                                activity: _activity,
                                maxMinutes: maxMinutes,
                                c: c,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Subject Mastery Breakdown
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.subjectBreakdownTitle,
                              style: AppTypography.ui(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SubjectBar(
                              title: s.localizedCourseTitle(mathCourse),
                              percent: mathProgress ??
                                  ((profile.scoresByCourse[
                                              mathMasteryCourse] !=
                                          null)
                                      ? SkillScoringEngine.computeOverallScore(
                                          profile.scoresByCourse[
                                              mathMasteryCourse]!,
                                        )
                                      : 0),
                              visual: subjectVisual(
                                SubjectType.mathematics,
                                c,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SubjectBar(
                              title: s.localizedCourseTitle(engCourse),
                              percent: (profile.scoresByCourse['course_eng_01'] !=
                                      null)
                                  ? SkillScoringEngine.computeOverallScore(
                                      profile.scoresByCourse['course_eng_01']!,
                                    )
                                  : 0,
                              visual: subjectVisual(SubjectType.english, c),
                            ),
                            const SizedBox(height: 12),
                            _SubjectBar(
                              title: s.localizedCourseTitle(itCourse),
                              percent:
                                  (profile.scoresByCourse['course_it'] != null)
                                      ? SkillScoringEngine.computeOverallScore(
                                          profile.scoresByCourse['course_it']!,
                                        )
                                      : 0,
                              visual: subjectVisual(SubjectType.it, c),
                            ),
                            const SizedBox(height: 12),
                            _SubjectBar(
                              title: s.localizedCourseTitle(logicCourse),
                              percent: (profile.scoresByCourse['course_logic'] !=
                                      null)
                                  ? SkillScoringEngine.computeOverallScore(
                                      profile.scoresByCourse['course_logic']!,
                                    )
                                  : 0,
                              visual: subjectVisual(SubjectType.logic, c),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Achievements & Badges
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final titleWidget = Text(
                                  s.achievementsTitle,
                                  style: AppTypography.ui(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: c.ink,
                                  ),
                                );
                                final badgeWidget = AppBadge(
                                  text: s.achievementsEarned(
                                    earnedCount,
                                    badges.length,
                                  ),
                                  variant: AppBadgeVariant.emerald,
                                );
                                if (textScale >= 1.3 ||
                                    constraints.maxWidth < 260) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      titleWidget,
                                      const SizedBox(height: 8),
                                      badgeWidget,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: titleWidget),
                                    const SizedBox(width: 8),
                                    Flexible(child: badgeWidget),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final useTwoCols =
                                    constraints.maxWidth >= 300 &&
                                        textScale < 1.35;
                                final itemWidth = useTwoCols
                                    ? (constraints.maxWidth - 10) / 2
                                    : constraints.maxWidth;
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final b in badges)
                                      Container(
                                        width: itemWidth,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: b.earned
                                              ? Color.alphaBlend(
                                                  c.successSoft.withValues(
                                                    alpha: 0.45,
                                                  ),
                                                  c.subtle,
                                                )
                                              : c.subtle,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: b.earned
                                                ? c.success.withValues(
                                                    alpha: 0.35,
                                                  )
                                                : c.hairline,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: b.earned
                                                    ? c.successSoft
                                                    : c.paper,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                b.earned
                                                    ? b.icon
                                                    : Icons.lock_outline_rounded,
                                                size: 18,
                                                color: b.earned
                                                    ? c.successText
                                                    : c.slatefine,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    b.title,
                                                    style: AppTypography.ui(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: b.earned
                                                          ? c.ink
                                                          : c.graphite,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    b.desc,
                                                    style: AppTypography.ui(
                                                      fontSize: 11,
                                                      color: c.slatefine,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Yölçi Encouragement Banner
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: c.heroGradient,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            const YolchiAIMascot(
                              size: 52,
                              mood: YolchiMood.celebrating,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    completedLessons > 0
                                        ? s.progressBannerTitleActive
                                        : s.progressBannerTitleIdle,
                                    style: AppTypography.ui(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    completedLessons > 0
                                        ? s.progressBannerBodyActive(
                                            completedLessons,
                                            profile.xp,
                                          )
                                        : s.progressBannerBodyIdle,
                                    style: AppTypography.ui(
                                      fontSize: 12.5,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityError(AppSemanticColors c, AppStrings s) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_off_rounded, size: 28, color: c.slatefine),
        const SizedBox(height: 6),
        Text(
          s.progressActivityLoadFailed,
          textAlign: TextAlign.center,
          style: AppTypography.ui(fontSize: 12, color: c.slatefine),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _loadActivity,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
          ),
          child: Text(s.retry),
        ),
      ],
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  final List<DailyActivitySummary> activity;
  final int maxMinutes;
  final AppSemanticColors c;
  final AppStrings s;

  const _WeeklyBars({
    required this.activity,
    required this.maxMinutes,
    required this.c,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final weekdays = s.shortWeekdays;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final totalHeight = 88.0 + 48.0 * textScale.clamp(1.0, 2.5);
    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: activity.map((d) {
          final hrs = d.activeMinutes / 60.0;
          final peak = d.activeMinutes == maxMinutes && maxMinutes > 0;
          final heightRatio =
              maxMinutes == 0 ? 0.0 : (d.activeMinutes / maxMinutes);
          final date = DateTime.tryParse(d.date);
          final dayLabel = date != null ? weekdays[date.weekday % 7] : '';
          final desiredBarHeight =
              76 * heightRatio + (d.activeMinutes > 0 ? 6 : 2);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hrs.toStringAsFixed(1),
                      style: AppTypography.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: peak ? c.brand : c.slatefine,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxBarHeight = constraints.maxHeight;
                          final barHeight = desiredBarHeight > maxBarHeight
                              ? maxBarHeight
                              : desiredBarHeight;
                          return Container(
                            width: 24,
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: peak
                                    ? [
                                        c.isDark ? c.brandStrong : c.ctaPrimary,
                                        c.path,
                                      ]
                                    : [
                                        c.path,
                                        c.isDark
                                            ? c.brand
                                            : c.brand.withValues(alpha: 0.72),
                                      ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      dayLabel,
                      maxLines: 1,
                      style: AppTypography.ui(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: c.graphite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  final List<DailyActivitySummary> activity;
  final int maxMinutes;
  final AppSemanticColors c;

  const _MonthlyBars({
    required this.activity,
    required this.maxMinutes,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final len = activity.length;
    final labelIndices = <int>{};
    if (len > 0) {
      for (var i = 0; i < 6; i++) {
        labelIndices.add(((i * (len - 1)) / 5).round());
      }
    }
    final sortedIndices = labelIndices.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 102,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: activity.map((d) {
              final peak = d.activeMinutes == maxMinutes && maxMinutes > 0;
              final heightRatio =
                  maxMinutes == 0 ? 0.0 : (d.activeMinutes / maxMinutes);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 90 * heightRatio + (d.activeMinutes > 0 ? 5 : 2),
                      decoration: BoxDecoration(
                        color: d.activeMinutes == 0
                            ? c.subtle
                            : peak
                                ? c.ctaPrimary
                                : c.path,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: sortedIndices.map((idx) {
            final rawDate = activity[idx].date;
            final dayText =
                rawDate.length >= 2 ? rawDate.substring(rawDate.length - 2) : '';
            return Expanded(
              child: Text(
                dayText,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppTypography.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: c.slatefine,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.mono(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTypography.ui(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.slatefine,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  final String title;
  final int percent;
  final SubjectVisual visual;

  const _SubjectBar({
    required this.title,
    required this.percent,
    required this.visual,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: visual.softBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(visual.icon, size: 14, color: visual.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.ui(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: AppTypography.mono(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            backgroundColor: c.subtle,
            valueColor: AlwaysStoppedAnimation<Color>(visual.accent),
            minHeight: 7,
          ),
        ),
      ],
    );
  }
}
