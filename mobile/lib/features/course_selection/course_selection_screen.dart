import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../app/providers.dart';
import '../../domain/entities/course.dart';

class CourseSelectionScreen extends ConsumerWidget {
  const CourseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseState = ref.watch(courseStateNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Center(child: BilimYolLogo(size: 40)),
                    const SizedBox(height: 24),
                    Text(
                      'Qaysi fanni o‘rganishni istaysiz?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'BilimYo‘l sizning bilim darajangizni aniqlab, shaxsiy o‘quv yo‘l xaritangizni tuzadi.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (courseState.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      ...courseState.courses.map((course) {
                        final isMath = course.subject == SubjectType.mathematics;
                        final isEnglish = course.subject == SubjectType.english;
                        final isAvailable = isMath || isEnglish;
                        final isSelected = courseState.activeCourse?.id == course.id;

                        final activeBorderColor = isMath ? AppColors.primary : AppColors.secondary;
                        final activeBgColor = isMath
                            ? AppColors.primaryLight.withValues(alpha: 0.5)
                            : AppColors.secondaryLight.withValues(alpha: 0.5);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: AppCard(
                            padding: const EdgeInsets.all(18),
                            borderColor: isSelected ? activeBorderColor : AppColors.cardBorder,
                            borderWidth: isSelected ? 2 : 1.2,
                            backgroundColor: isSelected ? activeBgColor : AppColors.surface,
                            onTap: isAvailable
                                ? () async {
                                    await ref.read(courseStateNotifierProvider.notifier).selectCourse(course.id);
                                  }
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isMath
                                            ? AppColors.primaryLight
                                            : isEnglish
                                                ? AppColors.secondaryLight
                                                : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isMath
                                            ? Icons.calculate_rounded
                                            : isEnglish
                                                ? Icons.headphones_rounded
                                                : Icons.code_rounded,
                                        color: isMath
                                            ? AppColors.primary
                                            : isEnglish
                                                ? AppColors.secondary
                                                : AppColors.textMuted,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                course.title,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  color: isAvailable ? AppColors.textPrimary : AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (isAvailable)
                                                AppBadge(
                                                  text: 'Faol Kurs',
                                                  variant: isMath ? AppBadgeVariant.blue : AppBadgeVariant.rose,
                                                )
                                              else
                                                const AppBadge(
                                                  text: 'Tez kunda',
                                                  variant: AppBadgeVariant.slate,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isAvailable
                                                ? 'Full Adaptive Learning Engine'
                                                : 'Ushbu kurs tez orada ishga tushadi',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isAvailable)
                                      Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: isSelected ? activeBorderColor : AppColors.cardBorder,
                                        size: 24,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  course.description,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                if (isAvailable) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: (isMath
                                            ? ['Algebra', 'Tenglamalar', 'Funksiyalar', 'Grafiklar']
                                            : ['Vocabulary', 'Grammar', 'Listening', 'Reading'])
                                        .map((s) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isMath
                                                    ? AppColors.primaryLight.withValues(alpha: 0.6)
                                                    : AppColors.secondaryLight.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 12,
                                                    color: isMath ? AppColors.primary : AppColors.secondary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    s,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: isMath ? AppColors.primary : AppColors.secondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Tanlash va Davom Etish',
                      isFullWidth: true,
                      size: AppButtonSize.large,
                      rightIcon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                      onPressed: courseState.activeCourse == null
                          ? null
                          : () {
                              context.push('/onboarding');
                            },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
