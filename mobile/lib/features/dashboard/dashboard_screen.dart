import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../app/providers.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import '../../domain/entities/learning_path_node.dart';

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
        title: Text(
          'BilimYo‘l Smart Edu',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Natijalar',
            onPressed: () => context.go('/progress'),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Fanni almashtirish',
            onPressed: () => context.go('/courses'),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 0),
      body: SafeArea(
        child: learnerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Xatolik: $e')),
          data: (profile) {
            final courseScores = profile.scoresByCourse[activeCourse?.id ?? ''] ?? {};
            final overallScore = SkillScoringEngine.computeOverallScore(courseScores);

            // Find weakest and strongest skills dynamically
            final defaultWeak = activeCourse?.id == 'course_eng_01' ? 'Listening' : 'Funksiyalar';
            final defaultStrong = activeCourse?.id == 'course_eng_01' ? 'Vocabulary' : 'Algebra';
            String weakestSkillName = courseState.activeSkills.isNotEmpty ? courseState.activeSkills.first.name : defaultWeak;
            int weakestScore = 100;
            String strongestSkillName = courseState.activeSkills.isNotEmpty ? courseState.activeSkills.first.name : defaultStrong;
            int strongestScore = 0;

            for (final sk in courseState.activeSkills) {
              final sc = courseScores[sk.id]?.score ?? 0;
              if (sc >= strongestScore) {
                strongestScore = sc;
                strongestSkillName = sk.name;
              }
              if (sc <= weakestScore) {
                weakestScore = sc;
                weakestSkillName = sk.name;
              }
            }

            final currentUserName = profile.name.isNotEmpty ? profile.name : 'O‘ktam';

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Reference 2 Top Bar: Avatar, Greeting, Daily Goal, Streak & XP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                currentUserName.isNotEmpty ? currentUserName.substring(0, 1) : 'O',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assalomu alaykum,',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$currentUserName! 👋',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Streak pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFEA580C)),
                            const SizedBox(width: 4),
                            Text(
                              '${profile.streakDays} kun',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFC2410C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Goal pill banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.track_changes_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Bugungi maqsad: 3/5 dars',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${profile.xp} XP',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Reference 2 Subject Selector Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SubjectChip(
                          title: 'Matematika',
                          icon: '📐',
                          isSelected: activeCourse?.id == 'course_math_01',
                          onTap: () => ref.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01'),
                        ),
                        const SizedBox(width: 8),
                        _SubjectChip(
                          title: 'Ingliz tili',
                          icon: '🇬🇧',
                          isSelected: activeCourse?.id == 'course_eng_01',
                          onTap: () => ref.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01'),
                        ),
                        const SizedBox(width: 8),
                        _SubjectChip(
                          title: 'IT & Kod',
                          icon: '💻',
                          isSelected: activeCourse?.id == 'course_it',
                          onTap: () => ref.read(courseStateNotifierProvider.notifier).selectCourse('course_it'),
                        ),
                        const SizedBox(width: 8),
                        _SubjectChip(
                          title: 'Mantiq',
                          icon: '🧩',
                          isSelected: activeCourse?.id == 'course_logic',
                          onTap: () => ref.read(courseStateNotifierProvider.notifier).selectCourse('course_logic'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Dynamic Centerpiece: Hero "Davom etish" Card
                  () {
                    final roadmapAsync = ref.watch(roadmapStateNotifierProvider);
                    final roadmapNodes = roadmapAsync.value?.nodes ?? [];
                    final activeNode = roadmapNodes.where((n) => n.status == NodeStatus.reinforcement || n.status == NodeStatus.available).firstOrNull ?? (roadmapNodes.isNotEmpty ? roadmapNodes.first : null);
                    final targetLessonId = activeNode?.targetLessonId ?? (activeCourse?.lessons.isNotEmpty == true ? activeCourse!.lessons.first : null);
                    final hasLessons = targetLessonId != null;

                    final completedCount = roadmapNodes.where((n) => n.status == NodeStatus.completed).length;
                    final totalCount = roadmapNodes.length;
                    final heroProgress = totalCount > 0 ? (completedCount / totalCount) : 0.0;
                    final lessonCountStr = totalCount > 0 ? '${completedCount + (activeNode != null ? 1 : 0)}/$totalCount dars' : (hasLessons ? '1/1 dars' : '0 dars');

                    final heroTitle = hasLessons
                        ? (activeCourse?.id == 'course_eng_01'
                            ? 'Ingliz tili: ${activeNode?.title ?? "Listening ko‘nikmasi"}'
                            : '${activeCourse?.title ?? "Matematika"}: ${activeNode?.title ?? "Funksiyalar va formulalar"}')
                        : '${activeCourse?.title ?? "Tanlangan fan"}: Darslar tayyorlanmoqda';

                    final heroSubtitle = hasLessons
                        ? (activeNode?.description ?? 'Yo‘lchi AI sizning bilim darajangizga moslashtirgan dars')
                        : 'Ushbu fan bo‘yicha darslar tayyorlanmoqda. Yo‘lchi AI yordamida yangi dars yaratishingiz mumkin.';

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  hasLessons ? 'Davom etish' : 'Yangi fan',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                lessonCountStr,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            heroTitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            heroSubtitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: heroProgress,
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              InkWell(
                                onTap: () async {
                                  if (targetLessonId != null) {
                                    await ref.read(lessonSessionNotifierProvider.notifier).startLesson(targetLessonId);
                                    if (context.mounted) {
                                      context.push('/lesson');
                                    }
                                  } else {
                                    context.push('/ai-tutor');
                                  }
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    hasLessons ? Icons.play_arrow_rounded : Icons.auto_awesome_rounded,
                                    color: const Color(0xFF4F46E5),
                                    size: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }(),
                  const SizedBox(height: 20),

                  // 4. Reference 2 "Siz uchun tavsiya" Recommendations
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Siz uchun tavsiya',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.go('/roadmap'),
                        child: Text(
                          'Barchasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final isEng = activeCourse?.id == 'course_eng_01';
                      final isIt = activeCourse?.id == 'course_it';
                      final isLog = activeCourse?.id == 'course_logic';

                      final rec1Title = isEng
                          ? 'Essential Vocabulary'
                          : isIt
                              ? 'Python asoslari'
                              : isLog
                                  ? 'Mantiqiy fikrlash'
                                  : 'Algebra formulalari';
                      final rec1Desc = isEng
                          ? '10 dars • Lug‘at boyligi'
                          : isIt
                              ? '8 dars • Dasturlash'
                              : isLog
                                  ? '12 dars • Deduksiya'
                                  : '8 dars • Qisqa ko‘paytirish';
                      final rec1Icon = isEng
                          ? '📖'
                          : isIt
                              ? '🐍'
                              : isLog
                                  ? '🧩'
                                  : '📐';
                      final rec1Bg = isEng
                          ? const Color(0xFFFFE4E6)
                          : isIt
                              ? const Color(0xFFECFEFF)
                              : isLog
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFEFF6FF);

                      final rec2Title = isEng
                          ? 'Grammar & Rules'
                          : isIt
                              ? 'Algoritmik mantiq'
                              : isLog
                                  ? 'Boshqotirmalar'
                                  : 'Chiziqli tenglamalar';
                      final rec2Desc = isEng
                          ? '8 dars • Conditionals'
                          : isIt
                              ? '10 dars • Sikllar'
                              : isLog
                                  ? '8 dars • Zanjirlar'
                                  : '10 dars • Tenglamalar';
                      final rec2Icon = isEng
                          ? '✍️'
                          : isIt
                              ? '💻'
                              : isLog
                                  ? '💡'
                                  : '⚖️';
                      final rec2Bg = isEng
                          ? const Color(0xFFEEF2FF)
                          : isIt
                              ? const Color(0xFFE0F2FE)
                              : isLog
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFEEF2FF);

                      return Row(
                        children: [
                          Expanded(
                            child: AppCard(
                              padding: const EdgeInsets.all(14),
                              onTap: () => context.go('/roadmap'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: rec1Bg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(rec1Icon, style: const TextStyle(fontSize: 18)),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    rec1Title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    rec1Desc,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppCard(
                              padding: const EdgeInsets.all(14),
                              onTap: () => context.go('/roadmap'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: rec2Bg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(rec2Icon, style: const TextStyle(fontSize: 18)),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    rec2Title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    rec2Desc,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 5. Reference 2 & 3: Yo‘lchi AI Interactive Assistant Dialogue
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    borderColor: AppColors.primary.withValues(alpha: 0.3),
                    backgroundColor: const Color(0xFFF8FAFC),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const YolchiAIMascot(size: 44, mood: YolchiMood.waving),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Yo‘lchi AI Mentor',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const AppBadge(text: 'Online', variant: AppBadgeVariant.emerald, fontSize: 10),
                                    ],
                                  ),
                                  Text(
                                    'Individual o‘quv yo‘ldoshi',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Text(
                            'Salom, $currentUserName! Umumiy darajangiz $overallScore%. Kuchli yo‘nalishingiz: $strongestSkillName ($strongestScore%). Bugun $weakestSkillName mavzusini birgalikda oson o‘rganamiz. Qanday topshiriq tayyorlay? 💡',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _PromptChip(title: 'Tushuntirish', onTap: () => context.go('/ai-tutor')),
                            _PromptChip(title: 'Misollar', onTap: () => context.go('/ai-tutor')),
                            _PromptChip(title: 'Mashq qilish', onTap: () => context.push('/lesson')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. Navigation Actions (Roadmap / Bilim xaritasi)
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
                          text: 'Ta’lim Yo‘li',
                          variant: AppButtonVariant.primary,
                          rightIcon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                          onPressed: () => context.push('/roadmap'),
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
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String title;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _PromptChip({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
