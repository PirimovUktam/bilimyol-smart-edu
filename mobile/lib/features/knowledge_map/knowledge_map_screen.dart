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
import '../../domain/entities/skill_score.dart';

class KnowledgeMapScreen extends ConsumerWidget {
  const KnowledgeMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseState = ref.watch(courseStateNotifierProvider);
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final activeCourse = courseState.activeCourse;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Bilim Xaritasi • ${activeCourse?.title ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_rounded),
            onPressed: () => context.go('/dashboard'),
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
                  final scores = profile.scoresByCourse[activeCourse?.id ?? ''] ?? {};
                  final skills = courseState.activeSkills;

                  SkillScore? weakestSkill;
                  int totalScore = 0;
                  int count = 0;

                  for (final s in scores.values) {
                    totalScore += s.score;
                    count++;
                    if (weakestSkill == null || s.score < weakestSkill.score) {
                      weakestSkill = s;
                    }
                  }

                  final avgScore = count > 0 ? (totalScore / count).round() : 0;
                  final weakestSkillObj = skills.where((s) => s.id == weakestSkill?.skillId).firstOrNull;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview Card
                        AppCard(
                          backgroundColor: AppColors.surfaceDark,
                          borderColor: const Color(0xFF334155),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Umumiy O‘zlashtirish',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$avgScore%',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF475569)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFBBF24)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+${profile.xp} XP',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFFBBF24),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Diagnostic Placement natijalari asosida shaxsiy o‘quv yo‘nalishingiz shakllantirildi.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFFCBD5E1),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // WEAKEST SKILL ALERT BANNER
                        if (weakestSkill != null && weakestSkill.score < 50)
                          AppCard(
                            backgroundColor: AppColors.errorLight,
                            borderColor: AppColors.error.withValues(alpha: 0.3),
                            borderWidth: 1.5,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.error,
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
                                          const AppBadge(
                                            text: 'DIQQAT: Zaif Bo‘g‘in',
                                            variant: AppBadgeVariant.rose,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${weakestSkill.score}%',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${weakestSkillObj?.name ?? "Mavzu"} bo‘yicha tushunchalarni mustahkamlash talab etiladi.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Yo‘l xaritasida ushbu mavzuga maxsus mustahkamlash qadami qo‘shildi.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Skills Breakdown List
                        Text(
                          'Ko‘nikmalar Tahlili',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ...skills.map((skill) {
                          final scoreObj = scores[skill.id];
                          final score = scoreObj?.score ?? 50;
                          final isWeak = weakestSkill?.skillId == skill.id && score < 50;

                          Color progressColor = AppColors.primary;
                          if (score < 50) {
                            progressColor = AppColors.error;
                          } else if (score < 70) {
                            progressColor = AppColors.warning;
                          } else if (score >= 80) {
                            progressColor = AppColors.success;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              padding: const EdgeInsets.all(16),
                              borderColor: isWeak ? AppColors.error.withValues(alpha: 0.4) : AppColors.cardBorder,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  skill.name,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (isWeak) ...[
                                                  const SizedBox(width: 6),
                                                  const AppBadge(
                                                    text: 'Fokus',
                                                    variant: AppBadgeVariant.rose,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              skill.description,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                color: AppColors.textMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '$score%',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: progressColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: score / 100,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 16),
                        // Roadmap Navigation Button
                        AppButton(
                          text: 'Moslashuvchan Yo‘l Xaritasi',
                          isFullWidth: true,
                          size: AppButtonSize.large,
                          rightIcon: const Icon(Icons.alt_route_rounded, size: 18, color: Colors.white),
                          onPressed: () {
                            context.push('/roadmap');
                          },
                        ),
                        const SizedBox(height: 20),
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
