import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/demo_control_bar.dart';
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
            const DemoControlBar(),
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
                        final isSelected = courseState.activeCourse?.id == course.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: AppCard(
                            padding: const EdgeInsets.all(18),
                            borderColor: isSelected
                                ? (isMath ? AppColors.primary : AppColors.secondary)
                                : AppColors.cardBorder,
                            borderWidth: isSelected ? 2 : 1.2,
                            backgroundColor: isSelected
                                ? (isMath ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.secondaryLight.withValues(alpha: 0.5))
                                : AppColors.surface,
                            onTap: isMath
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
                                        color: isMath ? AppColors.primaryLight : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isMath ? Icons.calculate_rounded : Icons.headphones_rounded,
                                        color: isMath ? AppColors.primary : AppColors.textMuted,
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
                                                  color: isMath ? AppColors.textPrimary : AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (isMath)
                                                const AppBadge(
                                                  text: 'Faol Kurs',
                                                  variant: AppBadgeVariant.blue,
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
                                            isMath ? 'Full Adaptive Learning Engine' : 'Ushbu kurs tez orada ishga tushadi',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isMath)
                                      Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: isSelected ? AppColors.primary : AppColors.cardBorder,
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
