import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
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

class _LearningPlanFormState extends ConsumerState<_LearningPlanForm> {
  late InitialLevel? _level = widget.profile.courseLevels[widget.course.id];
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

  Future<void> _start({bool diagnostic = false}) async {
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
      if (diagnostic && level != InitialLevel.beginner) {
        context.pushReplacement('/placement');
        return;
      }

      final starter = pendingFoundationLesson(
        course,
        ref.read(learnerStateNotifierProvider).valueOrNull,
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
        if (ref.read(lessonSessionNotifierProvider).lesson?.id != starter) {
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
    final hasPendingStarter = pendingFoundationLesson(
          widget.course,
          widget.profile.copyWith(
            courseLevels: {
              ...widget.profile.courseLevels,
              widget.course.id: ?_level,
            },
          ),
        ) !=
        null;

    final levelChoices = [
      (
        level: InitialLevel.beginner,
        title: s.startFromZero,
        detail: s.levelBeginnerDesc,
        pill: s.levelPillBeginner,
        badgeVariant: AppBadgeVariant.emerald,
        icon: Icons.spa_outlined,
      ),
      (
        level: InitialLevel.intermediate,
        title: s.levelIntermediateTitle,
        detail: s.levelIntermediateDesc,
        pill: s.levelPillIntermediate,
        badgeVariant: AppBadgeVariant.blue,
        icon: Icons.trending_up_rounded,
      ),
      (
        level: InitialLevel.advanced,
        title: s.levelAdvancedTitle,
        detail: s.levelAdvancedDesc,
        pill: s.levelPillAdvanced,
        badgeVariant: AppBadgeVariant.teal,
        icon: Icons.bolt_rounded,
      ),
    ];

    final goals = {
      OnboardingGoal.mastery: s.goalMastery,
      OnboardingGoal.examPrep: s.goalExamPrep,
      OnboardingGoal.skillsBoost: s.goalSkillsBoost,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
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
                    s.onboardingQuestion,
                    style: AppTypography.ui(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.onboardingSubtitle,
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
            for (final (idx, choice) in levelChoices.indexed) ...[
              EdTechReveal(
                index: idx + 1,
                child: Semantics(
                  button: true,
                  selected: _level == choice.level,
                  inMutuallyExclusiveGroup: true,
                  label: '${choice.title}, ${choice.pill}',
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    borderColor:
                        _level == choice.level ? c.brand : c.hairline,
                    borderWidth: _level == choice.level ? 1.8 : 1.0,
                    backgroundColor: _level == choice.level
                        ? Color.alphaBlend(c.brandSoft, c.paper)
                        : c.paper,
                    onTap: _saving
                        ? null
                        : () => setState(() => _level = choice.level),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            _level == choice.level
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _level == choice.level
                                ? c.brand
                                : c.slatefine,
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
                                  Text(
                                    choice.title,
                                    style: AppTypography.ui(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: c.ink,
                                    ),
                                  ),
                                  AppBadge(
                                    text: choice.pill,
                                    variant: choice.badgeVariant,
                                    icon: Icon(
                                      choice.icon,
                                      size: 12,
                                      color: switch (choice.badgeVariant) {
                                        AppBadgeVariant.emerald =>
                                          c.successText,
                                        AppBadgeVariant.teal => c.path,
                                        _ => c.isDark
                                            ? c.brandStrong
                                            : c.brand,
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                choice.detail,
                                style: AppTypography.ui(
                                  fontSize: 13,
                                  color: c.graphite,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<OnboardingGoal>(
              initialValue: _goal,
              isExpanded: true,
              dropdownColor: c.paper,
              style: AppTypography.ui(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
              decoration: InputDecoration(labelText: s.goalLabel),
              items: [
                for (final entry in goals.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _goal = value ?? _goal),
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
            if (_level != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.subtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.hairline),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      beginner && hasPendingStarter
                          ? Icons.auto_awesome_rounded
                          : Icons.alt_route_rounded,
                      size: 18,
                      color: c.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        beginner && hasPendingStarter
                            ? s.beginnerTrackNote
                            : s.adaptiveTrackNote,
                        style: AppTypography.ui(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.graphite,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
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
            AppButton(
              text: beginner && hasPendingStarter
                  ? s.startFirstLesson
                  : s.openRoadmap,
              isFullWidth: true,
              size: AppButtonSize.large,
              isLoading: _saving,
              onPressed: _level == null ? null : _start,
            ),
            if (_level != null && !beginner) ...[
              const SizedBox(height: 10),
              AppButton(
                text: s.optionalDiagnosticBtn,
                isFullWidth: true,
                variant: AppButtonVariant.outline,
                onPressed: _saving ? null : () => _start(diagnostic: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
