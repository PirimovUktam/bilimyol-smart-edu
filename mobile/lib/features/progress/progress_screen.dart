import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../app/providers.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import '../../domain/repositories/i_learner_repository.dart';

const _dayNames = ['Yak', 'Dsh', 'Ssh', 'Chor', 'Pay', 'Jum', 'Shan'];

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _timeframe = 'week';
  List<DailyActivitySummary> _activity = [];
  bool _isLoadingActivity = true;
  String? _activityError;
  int _activityGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final generation = ++_activityGeneration;
    if (!mounted) return;
    setState(() => _isLoadingActivity = true);
    final days = _timeframe == 'week' ? 7 : 30;
    try {
      final repo = ref.read(learnerRepositoryProvider);
      final data = await repo.getDailyActivity(days);
      if (mounted && generation == _activityGeneration) {
        setState(() {
          _activity = data;
          _activityError = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _activityGeneration) {
        setState(() {
          _activity = [];
          _activityError = 'Faollik ma’lumotlarini yuklab bo‘lmadi.';
        });
      }
    } finally {
      if (mounted && generation == _activityGeneration) {
        setState(() => _isLoadingActivity = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseState = ref.watch(courseStateNotifierProvider);
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final activeCourse = courseState.activeCourse;

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
          GestureDetector(
            onTap: () {
              setState(
                () => _timeframe = _timeframe == 'week' ? 'month' : 'week',
              );
              _loadActivity();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _timeframe == 'week' ? 'Bu hafta' : 'Bu oy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 3),
      body: SafeArea(
        child: learnerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: 'Profil natijalarini yuklab bo‘lmadi.',
            onRetry: () =>
                ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
          ),
          data: (profile) {
            final courseScores =
                profile.scoresByCourse[activeCourse?.id ?? ''] ?? {};
            final overallScore = SkillScoringEngine.computeOverallScore(
              courseScores,
            );
            final completedLessons = profile.completedLessonIds.length;
            final totalMinutes = _activity.fold<int>(
              0,
              (acc, d) => acc + d.activeMinutes,
            );
            final maxMinutes = _activity.fold<int>(
              1,
              (acc, d) => d.activeMinutes > acc ? d.activeMinutes : acc,
            );

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
                          value: '$completedLessons',
                          label: 'Bajarilgan dars',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.percent_rounded,
                          iconColor: const Color(0xFF06B6D4),
                          bgColor: const Color(0xFFECFEFF),
                          value: '$overallScore%',
                          label: 'O‘zlashtirish',
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
                          child: _isLoadingActivity
                              ? const Center(child: CircularProgressIndicator())
                              : _activityError != null
                              ? _buildActivityError()
                              : (_activity.isEmpty || totalMinutes == 0)
                              ? Center(
                                  child: Text(
                                    'Hali o‘quv faoliyati qayd etilmagan.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: _activity.map((d) {
                                    final hrs = d.activeMinutes / 60;
                                    final peak =
                                        d.activeMinutes == maxMinutes &&
                                        maxMinutes > 0;
                                    final heightRatio = maxMinutes == 0
                                        ? 0.0
                                        : d.activeMinutes / maxMinutes;
                                    final date = DateTime.tryParse(d.date);
                                    final dayLabel = date != null
                                        ? _dayNames[date.weekday % 7]
                                        : '';

                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          hrs.toStringAsFixed(1),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: peak
                                                ? AppColors.primary
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: _timeframe == 'week' ? 26 : 8,
                                          height:
                                              80 * heightRatio +
                                              (d.activeMinutes > 0 ? 6 : 0),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: peak
                                                  ? [
                                                      const Color(0xFF4F46E5),
                                                      const Color(0xFF06B6D4),
                                                    ]
                                                  : [
                                                      const Color(0xFF38BDF8),
                                                      const Color(0xFF0284C7),
                                                    ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(8),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _timeframe == 'week' ? dayLabel : '',
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
                          percent:
                              (profile.scoresByCourse['course_math_01'] != null)
                              ? SkillScoringEngine.computeOverallScore(
                                  profile.scoresByCourse['course_math_01']!,
                                )
                              : 0,
                          color: AppColors.primary,
                          iconText: '📐',
                        ),
                        const SizedBox(height: 12),
                        _SubjectBar(
                          title: 'Ingliz tili',
                          percent:
                              (profile.scoresByCourse['course_eng_01'] != null)
                              ? SkillScoringEngine.computeOverallScore(
                                  profile.scoresByCourse['course_eng_01']!,
                                )
                              : 0,
                          color: const Color(0xFFF43F5E),
                          iconText: '🇬🇧',
                        ),
                        const SizedBox(height: 12),
                        _SubjectBar(
                          title: 'IT & Algoritmlar',
                          percent: (profile.scoresByCourse['course_it'] != null)
                              ? SkillScoringEngine.computeOverallScore(
                                  profile.scoresByCourse['course_it']!,
                                )
                              : 0,
                          color: const Color(0xFF06B6D4),
                          iconText: '💻',
                        ),
                        const SizedBox(height: 12),
                        _SubjectBar(
                          title: 'Mantiqiy fikrlash',
                          percent:
                              (profile.scoresByCourse['course_logic'] != null)
                              ? SkillScoringEngine.computeOverallScore(
                                  profile.scoresByCourse['course_logic']!,
                                )
                              : 0,
                          color: const Color(0xFFF59E0B),
                          iconText: '🧩',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Gamified Badges (derived from real learner metrics)
                  (() {
                    final realBadges = <Map<String, dynamic>>[
                      {
                        'title': 'Muntazam O‘quvchi',
                        'icon': '🏆',
                        'desc': '7 kun uzluksiz o‘qish',
                        'earned': profile.streakDays >= 7,
                      },
                      {
                        'title': 'Tushunish Chempioni',
                        'icon': '🎯',
                        'desc': '90%+ o‘zlashtirish',
                        'earned': overallScore >= 90,
                      },
                      {
                        'title': 'Mavzu Master',
                        'icon': '⭐',
                        'desc': '5+ dars tugatilgan',
                        'earned': completedLessons >= 5,
                      },
                      {
                        'title': 'Ilk Qadam',
                        'icon': '🤖',
                        'desc': 'Birinchi dars yakunlandi',
                        'earned': completedLessons >= 1,
                      },
                    ];
                    final earnedCount = realBadges
                        .where((b) => b['earned'] == true)
                        .length;

                    return AppCard(
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
                              AppBadge(
                                text:
                                    '$earnedCount/${realBadges.length} Olingan',
                                variant: AppBadgeVariant.emerald,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: realBadges.map((b) {
                              final earned = b['earned'] == true;
                              return Container(
                                width:
                                    (MediaQuery.of(context).size.width - 72) /
                                    2,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Opacity(
                                      opacity: earned ? 1.0 : 0.4,
                                      child: Text(
                                        earned ? b['icon']! : '🔒',
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                    );
                  })(),
                  const SizedBox(height: 20),

                  // Yo'lchi AI Mascot Tip Banner (honest, data-driven)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const YolchiAIMascot(
                          size: 52,
                          mood: YolchiMood.celebrating,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                completedLessons > 0
                                    ? 'Ajoyib natija! 🚀'
                                    : 'Boshlashga tayyormisiz? 🚀',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                completedLessons > 0
                                    ? 'Siz $completedLessons ta darsni yakunlab, ${profile.xp} XP to‘pladingiz. Shu sur’atda davom eting!'
                                    : 'Birinchi darsni yakunlab, XP yig‘ishni boshlang!',
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

  Widget _buildActivityError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          size: 28,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 6),
        Text(
          _activityError!,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            color: AppColors.textMuted,
          ),
        ),
        TextButton(
          onPressed: _loadActivity,
          child: const Text('Qayta urinish'),
        ),
      ],
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
