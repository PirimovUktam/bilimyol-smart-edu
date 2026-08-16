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
import '../../domain/entities/learning_path_node.dart';

class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeCourse = ref.read(courseStateNotifierProvider).activeCourse;
      if (activeCourse != null) {
        ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(activeCourse.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final courseState = ref.watch(courseStateNotifierProvider);
    final roadmapAsync = ref.watch(roadmapStateNotifierProvider);
    final activeCourse = courseState.activeCourse;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Yo‘l Xaritasi • ${activeCourse?.title ?? ""}'),
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
              child: roadmapAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Xatolik: $e')),
                data: (roadmap) {
                  final nodes = roadmap.nodes;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Roadmap header banner
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.6),
                          borderColor: AppColors.primary.withValues(alpha: 0.3),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.alt_route_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Moslashuvchan Marshrut',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Zaif bo‘g‘inlar avtomatik mustahkamlash qadami bilan ta’minlandi.',
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

                        // Vertical Timeline List
                        ...List.generate(nodes.length, (index) {
                          final node = nodes[index];
                          final isLast = index == nodes.length - 1;

                          return _buildTimelineItem(context, node, isLast);
                        }),

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

  Widget _buildTimelineItem(BuildContext context, LearningPathNode node, bool isLast) {
    final isCompleted = node.status == NodeStatus.completed;
    final isReinforcement = node.status == NodeStatus.reinforcement || node.isReinforcement;
    final isLocked = node.status == NodeStatus.locked;
    final isAvailable = node.status == NodeStatus.available || node.status == NodeStatus.inProgress;

    Color iconBg;
    IconData iconData;
    Color iconColor;

    if (isCompleted) {
      iconBg = AppColors.successLight;
      iconData = Icons.check_rounded;
      iconColor = AppColors.success;
    } else if (isReinforcement) {
      iconBg = AppColors.warningLight;
      iconData = Icons.psychology_rounded;
      iconColor = AppColors.warning;
    } else if (isLocked) {
      iconBg = const Color(0xFFF1F5F9);
      iconData = Icons.lock_outline_rounded;
      iconColor = AppColors.textMuted;
    } else {
      iconBg = AppColors.primaryLight;
      iconData = Icons.play_arrow_rounded;
      iconColor = AppColors.primary;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Track Column
        Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isReinforcement
                      ? AppColors.warning
                      : isCompleted
                          ? AppColors.success
                          : isAvailable
                              ? AppColors.primary
                              : AppColors.cardBorder,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(iconData, color: iconColor, size: 20),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 70,
                color: isCompleted ? AppColors.success : AppColors.cardBorder,
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Node Content Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              borderColor: isReinforcement
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : isAvailable
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.cardBorder,
              borderWidth: (isReinforcement || isAvailable) ? 1.8 : 1.2,
              backgroundColor: isLocked ? const Color(0xFFF8FAFC) : AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          node.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isLocked ? AppColors.textMuted : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        const AppBadge(text: '✓ O‘zlashtirilgan', variant: AppBadgeVariant.emerald)
                      else if (isReinforcement)
                        const AppBadge(text: 'Mustahkamlash', variant: AppBadgeVariant.amber)
                      else if (isLocked)
                        const AppBadge(text: 'Qulflangan', variant: AppBadgeVariant.slate)
                      else
                        const AppBadge(text: 'Faol', variant: AppBadgeVariant.blue),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    node.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isLocked ? AppColors.textMuted : AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  if (isReinforcement || isAvailable)
                    AppButton(
                      text: isReinforcement ? 'Darsni Boshlash (Fokus)' : 'Darsni Boshlash',
                      size: AppButtonSize.small,
                      variant: isReinforcement ? AppButtonVariant.primary : AppButtonVariant.secondary,
                      rightIcon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      onPressed: () {
                        final lessonId = node.targetLessonId ??
                            (node.courseId == 'course_math_01'
                                ? 'lesson_math_functions_01'
                                : 'lesson_eng_listening_01');
                        ref.read(lessonSessionNotifierProvider.notifier).startLesson(lessonId);
                        context.push('/lesson');
                      },
                    )
                  else if (isLocked)
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Avvalgi mavzuni o‘zlashtirgach ochiladi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
