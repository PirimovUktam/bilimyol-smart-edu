import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/providers.dart';
import '../../domain/entities/course.dart';
import '../../domain/personalization/learning_start.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/edtech_section_header.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../core/widgets/subject_icon.dart';

class CourseSelectionScreen extends ConsumerWidget {
  const CourseSelectionScreen({super.key});

  String _subjectBadgeText(SubjectType subject) {
    switch (subject) {
      case SubjectType.mathematics:
        return 'Aniq fanlar';
      case SubjectType.english:
        return 'Xorijiy til';
      case SubjectType.it:
        return 'Dasturlash';
      case SubjectType.logic:
        return 'Tafakkur';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider).value;
    final activeCourse = state.activeCourse;
    final selectedId =
        activeCourse != null && hasStartedCourse(activeCourse, learner)
        ? activeCourse.id
        : null;
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const BilimYolLogo(size: 40),
                const SizedBox(height: 24),
                const EdTechReveal(
                  index: 0,
                  child: EdTechSectionHeader(
                    pillText: 'Fanlar katalogi',
                    title: 'Qaysi fanni o‘rganishni istaysiz?',
                    highlightWord: 'istaysiz?',
                    subtitle:
                        'Har bir fan uchun alohida ta’lim yo‘li va natijalar saqlanadi.',
                  ),
                ),
                const SizedBox(height: 20),
                if (state.error != null)
                  FriendlyErrorState(
                    message: state.error!,
                    onRetry: () =>
                        ref.read(courseStateNotifierProvider.notifier).init(),
                  ),
                if (state.isLoading && state.courses.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                for (final (index, course) in state.courses.indexed) ...[
                  EdTechReveal(
                    index: index + 1,
                    child: Builder(
                      builder: (context) {
                        final isSelected = selectedId == course.id;
                        final totalLessons = course.lessons.length;
                        final completedLessons = course.lessons
                            .where(
                              (id) =>
                                  learner?.completedLessonIds.contains(id) ??
                                  false,
                            )
                            .length;
                        final progress = totalLessons > 0
                            ? completedLessons / totalLessons
                            : 0.0;

                        return AppCard(
                          borderColor: isSelected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                          borderWidth: isSelected ? 1.8 : 1.0,
                          backgroundColor: isSelected
                              ? AppColors.primaryLight.withValues(alpha: 0.45)
                              : AppColors.surface,
                          onTap: state.isLoading
                              ? null
                              : () async {
                                  await ref
                                      .read(
                                        courseStateNotifierProvider.notifier,
                                      )
                                      .selectCourse(course.id);
                                  if (!context.mounted) return;
                                  final updated = ref.read(
                                    courseStateNotifierProvider,
                                  );
                                  if (updated.error != null ||
                                      updated.activeCourse?.id != course.id) {
                                    return;
                                  }
                                  final profile = ref
                                      .read(learnerStateNotifierProvider)
                                      .value;
                                  if (hasStartedCourse(course, profile)) {
                                    context.go('/dashboard');
                                  } else {
                                    context.push('/onboarding');
                                  }
                                },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // (a) Top: Colored Icon Container + Category/Status Badge
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      subjectIcon(course.subject),
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      AppBadge(
                                        text: isSelected
                                            ? 'Tanlangan'
                                            : _subjectBadgeText(course.subject),
                                        variant: isSelected
                                            ? AppBadgeVariant.emerald
                                            : AppBadgeVariant.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textMuted,
                                        semanticLabel: isSelected
                                            ? 'Tanlangan'
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // (b) Middle: Title, 2-line description & Visual progress
                              Text(course.title, style: theme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                course.description,
                                style: theme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (totalLessons > 0) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress >= 0.8
                                          ? AppColors.success
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),

                              // (c) Bottom: Meta data & Action indicator (.commonBtn style)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: totalLessons > 0
                                        ? Text(
                                            '$completedLessons / $totalLessons dars · +${totalLessons * 20} XP',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.primaryHover,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: AppColors.commonBtnShadow,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isSelected ? 'Davom etish' : 'Boshlash',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
