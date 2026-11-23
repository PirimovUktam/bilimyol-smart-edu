import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import 'session_preview.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../core/widgets/subject_icon.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/personalization/learning_start.dart';

AppStrings _resolveStrings(BuildContext context) {
  final localized = Localizations.of<AppStrings>(context, AppStrings);
  if (localized != null) return localized;
  final appLang = Localizations.maybeLocaleOf(context)?.languageCode;
  if (appLang == 'ru') return AppStrings.ru;
  if (appLang == 'uz') return AppStrings.uz;
  return WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ru'
      ? AppStrings.ru
      : AppStrings.uz;
}

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _resolveStrings(context);
    final courses = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider);
    final course = courses.activeCourse;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 96 : null,
        title: Text(
          s.studyPlanTitle,
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: learner.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: s.profileLoadFailed,
            onRetry: () =>
                ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
          ),
          data: (profile) {
            if (courses.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (course == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.chooseCoursePrompt,
                        textAlign: TextAlign.center,
                        style: AppTypography.ui(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppSemanticColors.of(context).graphite,
                        ),
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
            return _LearningPlanForm(
              key: ValueKey(course.id),
              course: course,
              profile: profile,
            );
          },
        ),
      ),
    );
  }
}

class _LearningPlanForm extends ConsumerStatefulWidget {
  const _LearningPlanForm({
    super.key,
    required this.course,
    required this.profile,
  });

  final Course course;
  final LearnerProfile profile;

  @override
  ConsumerState<_LearningPlanForm> createState() => _LearningPlanFormState();
}

enum _Start { guided, map, diagnostic }

class _LearningPlanFormState extends ConsumerState<_LearningPlanForm> {
  InitialLevel? get _saved => widget.profile.courseLevels[widget.course.id];
  late _Start? _route = _saved == null
      ? null
      : _saved == InitialLevel.beginner
      ? _Start.guided
      : _Start.map;
  InitialLevel? get _level => switch (_route) {
    null => null,
    _Start.guided => InitialLevel.beginner,
    _Start.diagnostic => _saved ?? InitialLevel.beginner,
    _Start.map =>
      _saved == InitialLevel.advanced ? _saved : InitialLevel.intermediate,
  };
  late OnboardingGoal _goal = widget.profile.goal;
  late int _minutes = [15, 30, 60].contains(widget.profile.dailyMinutes)
      ? widget.profile.dailyMinutes
      : 15;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      }
    });
  }

  Future<void> _start() async {
    final level = _level;
    final s = _resolveStrings(context);
    if (_saving || level == null) return;
    final course = widget.course;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(learnerStateNotifierProvider.notifier)
          .updateOnboarding(
            courseId: course.id,
            goal: _goal,
            dailyMinutes: _minutes,
            initialLevel: level,
          );
      if (!mounted ||
          ref.read(courseStateNotifierProvider).activeCourse?.id != course.id) {
        return;
      }
      if (_route == _Start.diagnostic) {
        context.pushReplacement('/placement');
        return;
      }

      final starter = resolveNextLearningLesson(
        course,
        ref.read(learnerStateNotifierProvider).valueOrNull,
        ref.read(roadmapStateNotifierProvider).valueOrNull,
      );
      if (level == InitialLevel.beginner && starter != null) {
        await ref
            .read(lessonSessionNotifierProvider.notifier)
            .startLesson(starter, uiLocale: s.isRu ? 'ru' : 'uz');
        if (!mounted ||
            ref.read(courseStateNotifierProvider).activeCourse?.id !=
                course.id) {
          return;
        }
        final loaded = ref.read(lessonSessionNotifierProvider).lesson;
        if (loaded?.id != starter || loaded?.courseId != course.id) {
          setState(() => _error = s.starterLessonLoadFailed);
          return;
        }
        context.pushReplacement('/lesson');
      } else {
        context.pushReplacement('/roadmap');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = s.planSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final vis = subjectVisual(widget.course.subject, c);
    final beginner = _level == InitialLevel.beginner;
    final draft = widget.profile.copyWith(
      goal: _goal,
      dailyMinutes: _minutes,
      courseLevels: {
        ...widget.profile.courseLevels,
        widget.course.id: _level ?? InitialLevel.beginner,
      },
    );
    final hasPendingStarter =
        pendingFoundationLesson(widget.course, draft) != null;
    final guidedLesson =
        beginner &&
        resolveNextLearningLesson(
              widget.course,
              draft,
              ref.watch(roadmapStateNotifierProvider).valueOrNull,
            ) !=
            null;

    final routes = [
      (
        _Start.guided,
        s.entryGuided,
        s.entryGuidedHint,
        Icons.menu_book_rounded,
      ),
      (_Start.map, s.entryMap, s.entryMapHint, Icons.route_outlined),
      (
        _Start.diagnostic,
        s.entryDiagnostic,
        s.entryDiagnosticHint,
        Icons.fact_check_outlined,
      ),
    ];
    final goals = {
      OnboardingGoal.mastery: s.entryMastery,
      OnboardingGoal.examPrep: s.entryExamPrep,
      OnboardingGoal.skillsBoost: s.entrySkillsBoost,
    };
    final goalHint = switch (_goal) {
      OnboardingGoal.examPrep => s.entryExamHint,
      OnboardingGoal.skillsBoost => s.entryPracticeHint,
      OnboardingGoal.mastery => switch (widget.course.subject) {
        SubjectType.logic => s.entryLogic,
        SubjectType.english => s.entryEnglish,
        SubjectType.mathematics => s.entryMathematics,
        SubjectType.it => s.entryIt,
      },
    };

    return Center(
      child: _PlanPanel(
        action: AppButton(
          text: _route == _Start.diagnostic
              ? s.entryTestAction
              : beginner && hasPendingStarter
              ? s.startFirstLesson
              : guidedLesson
              ? s.continueLearning
              : s.openRoadmap,
          isFullWidth: true,
          size: AppButtonSize.large,
          isLoading: _saving,
          onPressed: _level == null ? null : _start,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            EdTechReveal(
              index: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: vis.softBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: vis.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(vis.icon, size: 15, color: vis.accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            s.localizedCourseTitle(widget.course),
                            style: AppTypography.ui(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.entryStart,
                    style: AppTypography.ui(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.entryIntro,
                    style: AppTypography.ui(
                      fontSize: 14,
                      color: c.graphite,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final (route, title, hint, icon) in routes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  selected: route == _route,
                  inMutuallyExclusiveGroup: true,
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    borderColor: route == _route ? c.brand : c.hairline,
                    backgroundColor: route == _route
                        ? Color.alphaBlend(c.brandSoft, c.paper)
                        : c.paper,
                    onTap: _saving
                        ? null
                        : () => setState(() => _route = route),
                    child: Row(
                      children: [
                        Icon(icon, color: c.brand),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTypography.ui(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                hint,
                                style: AppTypography.ui(
                                  fontSize: 13,
                                  color: c.graphite,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (route == _route)
                          Icon(Icons.check_rounded, color: c.brand),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text(s.entryGoal, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final goal in goals.entries)
                  ChoiceChip(
                    label: Text(goal.value),
                    selected: _goal == goal.key,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _goal = goal.key),
                  ),
              ],
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                goalHint,
                style: AppTypography.ui(fontSize: 13, color: c.graphite),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.dailyTimeLabel,
              style: AppTypography.ui(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: c.graphite,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in [15, 30, 60])
                  Semantics(
                    button: true,
                    selected: _minutes == time,
                    inMutuallyExclusiveGroup: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _saving
                          ? null
                          : () => setState(() => _minutes = time),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _minutes == time ? c.ctaPrimary : c.subtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _minutes == time
                                  ? c.ctaPrimary
                                  : c.hairline,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: _minutes == time
                                    ? Colors.white
                                    : c.slatefine,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.minutesOption(time),
                                style: AppTypography.ui(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _minutes == time
                                      ? Colors.white
                                      : c.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              s.sharedPlanTiming,
              style: AppTypography.ui(fontSize: 12, color: c.graphite),
            ),
            const SizedBox(height: 12),
            if (_route == _Start.diagnostic)
              AppCard(
                child: ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(s.entryTestFirst),
                  subtitle: Text(s.entryTestExplain),
                ),
              )
            else
              SessionPreview(
                course: widget.course,
                profile: draft,
                sample: _level == null,
                strings: s,
              ),
            const SizedBox(height: 16),
            if (_error case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.errorSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      message,
                      style: AppTypography.ui(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.errorText,
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
}

class _PlanPanel extends StatelessWidget {
  const _PlanPanel({required this.child, required this.action});
  final Widget child;
  final Widget action;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 620),
    child: Column(
      children: [
        Expanded(child: child),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: action,
        ),
      ],
    ),
  );
}
