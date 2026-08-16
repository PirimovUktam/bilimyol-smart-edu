import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/demo_control_bar.dart';
import '../../app/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseState = ref.watch(courseStateNotifierProvider);
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final activeCourse = courseState.activeCourse;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Boshqaruv Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Fanni almashtirish',
            onPressed: () => context.go('/courses'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const DemoControlBar(),
            Expanded(
              child: learnerAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Xatolik: $e')),
                data: (profile) {
                  final courseScores = profile.scoresByCourse[activeCourse?.id ?? ''] ?? {};

                  // Get focus skill score
                  final focusSkillId = activeCourse?.id == 'course_math_01'
                      ? 'skill_math_functions'
                      : 'skill_eng_listening';
                  final focusScore = courseScores[focusSkillId]?.score ?? 63;

                  final nextActionTitle = activeCourse?.id == 'course_math_01'
                      ? 'Grafiklar: Koordinatalar tekisligida chizish'
                      : 'Reading: Matnni chuqur tahlil qilish';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Banner
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assalomu alaykum, ${profile.name}! 👋',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bugungi rejangiz muvaffaqiyatli yangilandi.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${profile.xp} XP',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stats Summary Row
                        Row(
                          children: [
                            Expanded(
                              child: AppCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 20),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${profile.streakDays} kun',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Faol streak',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.timer_rounded, color: AppColors.secondary, size: 20),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${profile.dailyMinutes} daqiqa',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Kunlik vaqt',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 20),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$focusScore%',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    Text(
                                      'Joriy fokus',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Current Subject Focus Card
                        AppCard(
                          padding: const EdgeInsets.all(18),
                          borderColor: AppColors.primary.withValues(alpha: 0.4),
                          borderWidth: 1.5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeCourse?.title ?? 'Fan',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            'Mustahkamlangan ko‘nikma',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  AppBadge(
                                    text: '$focusScore%',
                                    variant: AppBadgeVariant.emerald,
                                    fontSize: 13,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                activeCourse?.id == 'course_math_01'
                                    ? 'Funksiyalar mavzusi 41% dan 63% ga ko‘tarildi va muvaffaqiyatli mustahkamlandi.'
                                    : 'Listening ko‘nikmasi 43% dan 65% ga ko‘tarildi va mustahkamlandi.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Next Recommended Action Card
                        AppCard(
                          backgroundColor: AppColors.surfaceDark,
                          borderColor: const Color(0xFF334155),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF38BDF8), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Navbatdagi Qadam',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  const AppBadge(text: 'Blokdan ochildi', variant: AppBadgeVariant.blue),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                nextActionTitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Oldingi dars yakunlangani sababli keyingi mavzu darsi faollashdi.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                text: 'Yo‘l Xaritasiga O‘tish',
                                isFullWidth: true,
                                size: AppButtonSize.medium,
                                rightIcon: const Icon(Icons.alt_route_rounded, size: 16, color: Colors.white),
                                onPressed: () => context.push('/roadmap'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Quick Navigation Grid
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                text: 'Bilim Xaritasi',
                                variant: AppButtonVariant.outline,
                                leftIcon: const Icon(Icons.hub_rounded, size: 16, color: AppColors.primary),
                                onPressed: () => context.push('/knowledge-map'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton(
                                text: 'Fan Tanlash',
                                variant: AppButtonVariant.outline,
                                leftIcon: const Icon(Icons.school_rounded, size: 16, color: AppColors.secondary),
                                onPressed: () => context.go('/courses'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
