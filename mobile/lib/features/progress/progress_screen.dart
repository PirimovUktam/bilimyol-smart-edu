import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../app/providers.dart';
import '../../domain/personalization/skill_scoring_engine.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseState = ref.watch(courseStateNotifierProvider);
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final activeCourse = courseState.activeCourse;

    final weeklyHours = [
      {'day': 'Dsh', 'hours': 1.2, 'peak': false},
      {'day': 'Ssh', 'hours': 0.8, 'peak': false},
      {'day': 'Chor', 'hours': 1.5, 'peak': false},
      {'day': 'Pay', 'hours': 2.1, 'peak': true},
      {'day': 'Jum', 'hours': 1.8, 'peak': false},
      {'day': 'Shan', 'hours': 1.0, 'peak': false},
      {'day': 'Yak', 'hours': 1.3, 'peak': false},
    ];

    final badges = [
      {'title': 'Muntazam O‘quvchi', 'icon': '🏆', 'desc': '7 kun uzluksiz o‘qish'},
      {'title': 'Tushunish Chempioni', 'icon': '🎯', 'desc': '90%+ to‘g‘ri javoblar'},
      {'title': 'Mavzu Master', 'icon': '⭐', 'desc': 'Modul 100% bajarildi'},
      {'title': 'Yo‘lchi AI Do‘sti', 'icon': '🤖', 'desc': 'AI bilan o‘rganish'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Mening natijalarim',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Text(
                  'Bu oy',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 3),
      body: SafeArea(
        child: learnerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Xatolik: $e')),
          data: (profile) {
            final courseScores = profile.scoresByCourse[activeCourse?.id ?? ''] ?? {};
            final overallScore = SkillScoringEngine.computeOverallScore(courseScores);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4 Stat Cards Grid (Reference 2 style)
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xFF10B981),
                          bgColor: const Color(0xFFECFDF5),
                          value: '28',
                          label: 'Bajarilgan dars',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.percent_rounded,
                          iconColor: const Color(0xFF06B6D4),
                          bgColor: const Color(0xFFECFEFF),
                          value: '92%',
                          label: 'To‘g‘ri javoblar',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFEA580C),
                          bgColor: const Color(0xFFFFF7ED),
                          value: '${profile.streakDays} kun',
                          label: 'Kun ketma-ket 🔥',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.stars_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          bgColor: const Color(0xFFFFFBEB),
                          value: '${profile.xp} XP',
                          label: 'Umumiy ballar ✨',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Weekly Study Time Bar Chart (Reference 2 style)
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'O‘qish vaqti',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Soat / kun',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 130,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: weeklyHours.map((wh) {
                              final hrs = wh['hours'] as double;
                              final peak = wh['peak'] as bool;
                              final heightRatio = hrs / 2.1;

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    hrs.toString(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: peak ? AppColors.primary : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 26,
                                    height: 80 * heightRatio,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: peak
                                            ? [const Color(0xFF4F46E5), const Color(0xFF06B6D4)]
                                            : [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    wh['day'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Subject Mastery Breakdown (Reference 2 style)
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mavzular bo‘yicha natija',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SubjectBar(
                          title: 'Matematika',
                          percent: overallScore > 0 ? overallScore : 85,
                          color: AppColors.primary,
                          iconText: '📐',
                        ),
                        const SizedBox(height: 12),
                        _SubjectBar(
                          title: 'Ingliz tili',
                          percent: 70,
                          color: const Color(0xFFF43F5E),
                          iconText: '🇬🇧',
                        ),
                        const SizedBox(height: 12),
                        _SubjectBar(
                          title: 'IT & Algoritmlar',
                          percent: 90,
                          color: const Color(0xFF06B6D4),
                          iconText: '💻',
                        ),
                        const SizedBox(height: 12),
                        _SubjectBar(
                          title: 'Mantiqiy fikrlash',
                          percent: 65,
                          color: const Color(0xFFF59E0B),
                          iconText: '🧩',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Gamified Badges
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Yutuqlar va nishonlar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const AppBadge(text: '4/4 Olingan', variant: AppBadgeVariant.emerald),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: badges.map((b) {
                            return Container(
                              width: (MediaQuery.of(context).size.width - 72) / 2,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Text(b['icon']!, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b['title']!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          b['desc']!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            color: AppColors.textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Yo'lchi AI Mascot Tip Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const YolchiAIMascot(size: 52, mood: YolchiMood.celebrating),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ajoyib natija! 🚀',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tenglamalar bo‘yicha ko‘nikmangiz 22% ga oshdi. Darslarni davom ettiring!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.9),
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
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
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
  final Color color;
  final String iconText;

  const _SubjectBar({
    required this.title,
    required this.percent,
    required this.color,
    required this.iconText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(iconText, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              '$percent%',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: AppColors.cardBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 7,
          ),
        ),
      ],
    );
  }
}
