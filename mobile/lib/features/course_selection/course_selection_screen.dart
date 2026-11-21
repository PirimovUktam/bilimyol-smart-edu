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

  String _resolveLang(BuildContext context) {
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  String _subjectBadgeText(SubjectType subject, bool isRu) {
    switch (subject) {
      case SubjectType.mathematics:
        return isRu ? 'Точные науки' : 'Aniq fanlar';
      case SubjectType.english:
        return isRu ? 'Иностранный язык' : 'Xorijiy til';
      case SubjectType.it:
        return isRu ? 'Программирование' : 'Dasturlash';
      case SubjectType.logic:
        return isRu ? 'Мышление' : 'Tafakkur';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider).value;
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
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
                EdTechReveal(
                  index: 0,
                  child: EdTechSectionHeader(
                    pillText: isRu ? 'Каталог предметов' : 'Fanlar katalogi',
                    title: isRu
                        ? 'Какой предмет вы хотите изучать?'
                        : 'Qaysi fanni o‘rganishni istaysiz?',
                    highlightWord: isRu ? 'изучать?' : 'istaysiz?',
                    subtitle: isRu
                        ? 'Для каждого предмета сохраняются отдельный маршрут и результаты.'
                        : 'Har bir fan uchun alohida ta’lim yo‘li va natijalar saqlanadi.',
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
                        final bodyTextColor =
                            (isSelected && !AppColors.isDark(context))
                            ? AppColors.textMuted
                            : AppColors.textSecondaryColor(context);

                        return AppCard(
                          borderColor: isSelected
                              ? AppColors.primaryAccentOnSurface(context)
                              : AppColors.borderColor(context),
                          borderWidth: isSelected ? 1.8 : 1.0,
                          backgroundColor: isSelected
                              ? AppColors.primaryTint(context).withValues(alpha: 0.45)
                              : AppColors.surfaceColor(context),
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
                                  ScaffoldMessenger.of(
                                    context,
                                  ).clearSnackBars();
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
                                      color: AppColors.primaryTint(context),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      subjectIcon(course.subject),
                                      color: AppColors.primaryAccentOnSurface(
                                        context,
                                      ),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      alignment: WrapAlignment.end,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        AppBadge(
                                          text: isSelected
                                              ? (isRu ? 'Выбрано' : 'Tanlangan')
                                              : _subjectBadgeText(
                                                  course.subject,
                                                  isRu,
                                                ),
                                          variant: isSelected
                                              ? AppBadgeVariant.emerald
                                              : AppBadgeVariant.blue,
                                        ),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked,
                                          color: isSelected
                                              ? AppColors.primaryAccentOnSurface(
                                                  context,
                                                )
                                              : AppColors.textMutedColor(context),
                                          semanticLabel: isSelected
                                              ? (isRu ? 'Выбрано' : 'Tanlangan')
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // (b) Middle: Title, 2-line description & Visual progress
                              Text(
                                course.localizedTitle(lang),
                                style: theme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                course.localizedDescription(lang),
                                style: theme.bodySmall?.copyWith(
                                  color: bodyTextColor,
                                ),
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
                                    backgroundColor: AppColors.isDark(context)
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress >= 0.8
                                          ? AppColors.successTextOnTint(context)
                                          : AppColors.primaryAccentOnSurface(
                                              context,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),

                              // (c) Bottom: Meta data & Action indicator (.commonBtn style)
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (totalLessons > 0)
                                      Text(
                                        isRu
                                            ? '$completedLessons / $totalLessons уроков · +${totalLessons * 20} XP'
                                            : '$completedLessons / $totalLessons dars · +${totalLessons * 20} XP',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: bodyTextColor,
                                        ),
                                      ),
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
                                          Flexible(
                                            child: Text(
                                              isSelected
                                                  ? (isRu
                                                        ? 'Продолжить'
                                                        : 'Davom etish')
                                                  : (isRu
                                                        ? 'Начать'
                                                        : 'Boshlash'),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
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
