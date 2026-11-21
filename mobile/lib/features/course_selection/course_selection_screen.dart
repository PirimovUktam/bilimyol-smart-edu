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
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/edtech_section_header.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../core/widgets/subject_icon.dart';
import '../../domain/entities/course.dart';
import '../../domain/personalization/learning_start.dart';

class CourseSelectionScreen extends ConsumerWidget {
  const CourseSelectionScreen({super.key});

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

  AppBadgeVariant _subjectBadgeVariant(SubjectType subject) {
    return switch (subject) {
      SubjectType.mathematics => AppBadgeVariant.blue,
      SubjectType.english => AppBadgeVariant.rose,
      SubjectType.it => AppBadgeVariant.teal,
      SubjectType.logic => AppBadgeVariant.emerald,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final state = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider).value;
    final activeCourse = state.activeCourse;
    final selectedId =
        activeCourse != null && hasStartedCourse(activeCourse, learner)
            ? activeCourse.id
            : null;
    final hasStartedAny = state.courses.any(
      (course) => hasStartedCourse(course, learner),
    );
    final canPop =
        GoRouter.maybeOf(context)?.canPop() ?? Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                tooltip: s.back,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : hasStartedAny
                ? IconButton(
                    tooltip: s.back,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      context.go('/dashboard');
                    },
                  )
                : null,
        title: const BilimYolLogo(size: 28, showSubtitle: false),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                EdTechReveal(
                  index: 0,
                  child: EdTechSectionHeader(
                    pillText: s.coursesCatalogPill,
                    title: '${s.coursesHeading} ${s.coursesHighlight}',
                    highlightWord: s.coursesHighlight,
                    subtitle: s.coursesSubtitle,
                  ),
                ),
                const SizedBox(height: 20),
                if (state.error != null && state.courses.isEmpty)
                  FriendlyErrorState(
                    message: s.courseLoadError,
                    onRetry: () =>
                        ref.read(courseStateNotifierProvider.notifier).init(),
                  )
                else if (state.error != null && state.courses.isNotEmpty) ...[
                  _InlineErrorBanner(
                    c: c,
                    message: s.courseSelectError,
                    retryLabel: s.retry,
                    onRetry: () =>
                        ref.read(courseStateNotifierProvider.notifier).init(),
                  ),
                  const SizedBox(height: 14),
                ],
                if (state.isLoading && state.courses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: c.brand),
                        const SizedBox(height: 12),
                        Text(
                          s.loading,
                          style: AppTypography.ui(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.slatefine,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!state.isLoading &&
                    state.error == null &&
                    state.courses.isEmpty)
                  AppCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 36,
                          color: c.slatefine,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.coursesEmptyTitle,
                          textAlign: TextAlign.center,
                          style: AppTypography.ui(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppButton(
                          text: s.retry,
                          variant: AppButtonVariant.outline,
                          onPressed: () => ref
                              .read(courseStateNotifierProvider.notifier)
                              .init(),
                        ),
                      ],
                    ),
                  ),
                for (final (index, course) in state.courses.indexed) ...[
                  EdTechReveal(
                    index: index + 1,
                    child: _CourseCatalogCard(
                      course: course,
                      c: c,
                      s: s,
                      isSelected: selectedId == course.id,
                      isBusy: state.isLoading,
                      completedLessons: course.lessons
                          .where(
                            (id) =>
                                learner?.completedLessonIds.contains(id) ??
                                false,
                          )
                          .length,
                      subjectBadgeVariant: _subjectBadgeVariant(course.subject),
                      onSelect: () async {
                        await ref
                            .read(courseStateNotifierProvider.notifier)
                            .selectCourse(course.id);
                        if (!context.mounted) return;
                        final updated = ref.read(courseStateNotifierProvider);
                        if (updated.error != null ||
                            updated.activeCourse?.id != course.id) {
                          return;
                        }
                        final profile =
                            ref.read(learnerStateNotifierProvider).value;
                        ScaffoldMessenger.of(context).clearSnackBars();
                        if (hasStartedCourse(course, profile)) {
                          context.go('/dashboard');
                        } else {
                          context.push('/onboarding');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseCatalogCard extends StatelessWidget {
  final Course course;
  final AppSemanticColors c;
  final AppStrings s;
  final bool isSelected;
  final bool isBusy;
  final int completedLessons;
  final AppBadgeVariant subjectBadgeVariant;
  final VoidCallback onSelect;

  const _CourseCatalogCard({
    required this.course,
    required this.c,
    required this.s,
    required this.isSelected,
    required this.isBusy,
    required this.completedLessons,
    required this.subjectBadgeVariant,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final vis = subjectVisual(course.subject, c);
    final totalLessons = course.lessons.length;
    final progress = totalLessons > 0 ? completedLessons / totalLessons : 0.0;
    final lang = s.isRu ? 'ru' : 'uz';
    final rawTitle = s.localizedCourseTitle(course);
    final title =
        s.isRu &&
            rawTitle == course.title &&
            course.titleRu != null &&
            course.titleRu!.trim().isNotEmpty
        ? course.localizedTitle(lang)
        : rawTitle;
    final rawDescription = s.localizedCourseDescription(course);
    final description =
        s.isRu &&
            rawDescription == course.description &&
            course.descriptionRu != null &&
            course.descriptionRu!.trim().isNotEmpty
        ? course.localizedDescription(lang)
        : rawDescription;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title, ${s.subjectBadgeLabel(course.subject)}',
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: isSelected ? vis.accent : c.hairline,
        borderWidth: isSelected ? 1.8 : 1.0,
        backgroundColor: isSelected
            ? Color.alphaBlend(vis.softBg, c.paper)
            : c.paper,
        onTap: isBusy ? null : onSelect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Distinct top accent bar per subject
              Container(height: 4, color: vis.accent),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Subject Icon + Category/Selected Pill (overflow-safe)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: vis.softBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: vis.border),
                          ),
                          child: Icon(
                            vis.icon,
                            color: vis.accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.topEnd,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.end,
                              children: [
                                AppBadge(
                                  text: isSelected
                                      ? s.selectedBadgeLabel
                                      : s.subjectBadgeLabel(course.subject),
                                  variant: isSelected
                                      ? AppBadgeVariant.emerald
                                      : subjectBadgeVariant,
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: isSelected
                                      ? c.successText
                                      : c.slatefine,
                                  semanticLabel: isSelected
                                      ? s.selectedBadgeLabel
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: AppTypography.ui(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui(
                        fontSize: 13.5,
                        color: c.graphite,
                        height: 1.4,
                      ),
                    ),
                    if (totalLessons > 0) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: c.subtle,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 0.8 ? c.success : vis.accent,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (totalLessons > 0)
                            Text(
                              s.lessonsXpMeta(
                                completedLessons,
                                totalLessons,
                                totalLessons * 20,
                              ),
                              style: AppTypography.mono(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.slatefine,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          Container(
                            constraints: const BoxConstraints(minHeight: 38),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.ctaPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    isSelected
                                        ? s.continueLearning
                                        : s.startNode,
                                    style: AppTypography.ui(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final AppSemanticColors c;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _InlineErrorBanner({
    required this.c,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.errorSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: c.errorText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.ui(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.errorText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: c.errorText,
            ),
            child: Text(
              retryLabel,
              style: AppTypography.ui(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
