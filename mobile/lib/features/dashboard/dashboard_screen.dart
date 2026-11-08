import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/demo_control_bar.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/edtech_section_header.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/personalization/learning_start.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider);
    final activeCourse = state.activeCourse;
    final theme = Theme.of(context).textTheme;
    final path = activeCourse == null
        ? null
        : ref.watch(roadmapStateNotifierProvider);
    final currentPath = path?.valueOrNull;
    final nodes =
        currentPath != null && currentPath.courseId == activeCourse?.id
        ? currentPath.nodes.where((node) => !node.isReinforcement).toList()
        : <LearningPathNode>[];
    final next = nodes
        .where(
          (node) =>
              node.status == NodeStatus.available ||
              node.status == NodeStatus.inProgress ||
              node.status == NodeStatus.reinforcement,
        )
        .firstOrNull;
    final continuationId = next?.targetLessonId;
    final completed = nodes
        .where((node) => node.status == NodeStatus.completed)
        .length;
    final starting = ref.watch(
      lessonSessionNotifierProvider.select((state) => state.isLoading),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('BilimYo‘l Smart Edu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Fanni almashtirish',
            onPressed: () => context.go('/courses'),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 0),
      body: SafeArea(
        child: learner.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: 'Profil ma’lumotlarini yuklab bo‘lmadi.',
            onRetry: () =>
                ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
          ),
          data: (profile) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return FriendlyErrorState(
                message: state.error!,
                onRetry: () =>
                    ref.read(courseStateNotifierProvider.notifier).init(),
              );
            }
            if (activeCourse == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Davom etish uchun mavjud fanlardan birini tanlang.',
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Fan tanlash',
                        onPressed: () => context.go('/courses'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final needsPlan = !hasStartedCourse(activeCourse, profile);
            final starter = pendingFoundationLesson(activeCourse, profile);
            final lessonId = starter ?? continuationId;
            final greetingName =
                profile.name.isEmpty ? 'O‘quvchi' : profile.name;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const DemoControlBar(),
                    EdTechReveal(
                      index: 0,
                      child: EdTechSectionHeader(
                        pillText: 'Mening o‘qishim',
                        title: 'Assalomu alaykum, $greetingName!',
                        highlightWord: '$greetingName!',
                        subtitle:
                            'Ta’lim yo‘lingizda navbatdagi qadamni qo‘ying.',
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Hero Section
                    EdTechReveal(
                      index: 1,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 28,
                              spreadRadius: -6,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    needsPlan
                                        ? 'Shu yerdan boshlang'
                                        : activeCourse.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.24,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '⚡ ${profile.xp} XP · 🔥 ${profile.streakDays} kun',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              needsPlan
                                  ? 'Birinchi faningizni tanlang'
                                  : starter != null
                                  ? 'Boshlang‘ich darslar'
                                  : next?.title ?? 'Ta’lim yo‘lingiz',
                              style: theme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (needsPlan ||
                                starter != null ||
                                (next?.description.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 8),
                              Text(
                                needsPlan
                                    ? 'Fan va darajani tanlang. Keyingi darsni BilimYo‘l ko‘rsatadi.'
                                    : starter != null
                                    ? 'Tushuntirish va ishlangan misoldan boshlang.'
                                    : next!.description,
                                style: theme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            AppButton(
                              text: needsPlan
                                  ? 'Fan tanlash'
                                  : starter != null
                                  ? 'Birinchi darsni ochish'
                                  : lessonId == null
                                  ? 'Ta’lim yo‘lini ochish'
                                  : 'Davom etish',
                              variant: AppButtonVariant.outline,
                              rightIcon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                              isLoading:
                                  starting ||
                                  (!needsPlan &&
                                      starter == null &&
                                      (path?.isLoading ?? false)),
                              onPressed: () async {
                                if (needsPlan) {
                                  context.go('/courses');
                                  return;
                                }
                                if (lessonId == null) {
                                  context.push('/roadmap');
                                  return;
                                }
                                await ref
                                    .read(
                                      lessonSessionNotifierProvider.notifier,
                                    )
                                    .startLesson(lessonId);
                                if (!context.mounted ||
                                    ref
                                            .read(courseStateNotifierProvider)
                                            .activeCourse
                                            ?.id !=
                                        activeCourse.id) {
                                  return;
                                }
                                if (ref
                                        .read(lessonSessionNotifierProvider)
                                        .lesson
                                        ?.id ==
                                    lessonId) {
                                  context.push('/lesson');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Dars yuklanmadi. Qayta urinib ko‘ring.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Progress Card
                    EdTechReveal(
                      index: 2,
                      child: AppCard(
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
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.insights_rounded,
                                        size: 18,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Bugungi maqsad',
                                      style: theme.titleMedium,
                                    ),
                                  ],
                                ),
                                const AppBadge(
                                  text: 'Faol',
                                  variant: AppBadgeVariant.emerald,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${profile.dailyMinutes} daqiqa · ${profile.xp} XP · ${profile.streakDays} kun ketma-ket',
                              style: theme.bodyMedium,
                            ),
                            if (nodes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: completed / nodes.length,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.success,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$completed / ${nodes.length} mavzu yakunlangan',
                                style: theme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI & Diagnostic Block
                    EdTechReveal(
                      index: 3,
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const YolchiAIMascot(
                                  size: 46,
                                  mood: YolchiMood.explaining,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const AppBadge(
                                        text: 'AI Ustoz va Diagnostika',
                                        variant: AppBadgeVariant.blue,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Yo‘lchi AI bilan mavzuni birga o‘rganing',
                                        style: theme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AppButton(
                                  text: 'Suhbatni ochish',
                                  onPressed: () => context.go('/ai-tutor'),
                                ),
                                if (!needsPlan)
                                  AppButton(
                                    text: 'Boshlash darajasi',
                                    variant: AppButtonVariant.outline,
                                    onPressed: () =>
                                        context.push('/onboarding'),
                                  ),
                                if (!needsPlan)
                                  AppButton(
                                    text: 'Ixtiyoriy diagnostika',
                                    variant: AppButtonVariant.outline,
                                    onPressed: () => context.push('/placement'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
