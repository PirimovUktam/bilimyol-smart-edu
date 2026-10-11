import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
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
    final roadmapAsync = ref.watch(roadmapStateNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Mening ta’lim yo‘lim',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded),
            tooltip: 'Bilim Xaritasi',
            onPressed: () => context.push('/knowledge-map'),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            // Reference 2 Top Toggle Switch: [Bilim xaritasi | Roadmap]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/knowledge-map'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: Text(
                            'Bilim xaritasi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Roadmap',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: roadmapAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Xatolik: $e')),
                data: (roadmap) {
                  final nodes = roadmap.nodes;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vertical Connected Nodes (Reference 2 style)
                        ...List.generate(nodes.length, (index) {
                          final node = nodes[index];
                          final isLast = index == nodes.length - 1;

                          return _buildTimelineItem(context, node, isLast, index + 1);
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

  Widget _buildTimelineItem(BuildContext context, LearningPathNode node, bool isLast, int stepNum) {
    final isCompleted = node.status == NodeStatus.completed;
    final isReinforcement = node.status == NodeStatus.reinforcement || node.isReinforcement;
    final isLocked = node.status == NodeStatus.locked;
    final isAvailable = node.status == NodeStatus.available || node.status == NodeStatus.inProgress;

    Color iconBg;
    IconData iconData;
    Color iconColor;

    if (isCompleted) {
      iconBg = const Color(0xFF10B981);
      iconData = Icons.check_rounded;
      iconColor = Colors.white;
    } else if (isReinforcement) {
      iconBg = const Color(0xFFFF7043);
      iconData = Icons.warning_amber_rounded;
      iconColor = Colors.white;
    } else if (isLocked) {
      iconBg = const Color(0xFFF1F5F9);
      iconData = Icons.lock_outline_rounded;
      iconColor = AppColors.textMuted;
    } else {
      iconBg = AppColors.primary;
      iconData = Icons.play_arrow_rounded;
      iconColor = Colors.white;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Node
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                boxShadow: isAvailable || isCompleted
                    ? [
                        BoxShadow(
                          color: (isCompleted ? const Color(0xFF10B981) : AppColors.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(iconData, color: iconColor, size: 20),
              ),
            ),
            if (!isLast)
              Container(
                width: 2.5,
                height: 80,
                color: isCompleted
                    ? const Color(0xFF10B981)
                    : isAvailable
                        ? AppColors.primary
                        : AppColors.cardBorder,
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
                  ? const Color(0xFFFFCCBC)
                  : isAvailable
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : isCompleted
                          ? const Color(0xFFA7F3D0)
                          : AppColors.cardBorder,
              borderWidth: isAvailable ? 1.5 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$stepNum-Bosqich',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isReinforcement)
                        const AppBadge(text: 'Mustahkamlash', variant: AppBadgeVariant.amber)
                      else if (isCompleted)
                        const AppBadge(text: 'Bajarildi (100%)', variant: AppBadgeVariant.emerald)
                      else if (isAvailable)
                        const AppBadge(text: 'Faol dars', variant: AppBadgeVariant.blue)
                      else
                        const AppBadge(text: 'Bloklangan', variant: AppBadgeVariant.slate),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    node.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isLocked ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                  if (node.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      node.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${node.estimatedMinutes} daqiqa',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (isAvailable)
                        AppButton(
                          text: isReinforcement ? 'Mashq qilish' : 'Boshlash',
                          size: AppButtonSize.small,
                          variant: isReinforcement ? AppButtonVariant.primary : AppButtonVariant.primary,
                          rightIcon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                          onPressed: () {
                            ref.read(lessonSessionNotifierProvider.notifier).startLesson(node.id);
                            context.push('/lesson');
                          },
                        )
                      else if (isCompleted)
                        AppButton(
                          text: 'Takrorlash',
                          size: AppButtonSize.small,
                          variant: AppButtonVariant.outline,
                          onPressed: () {
                            ref.read(lessonSessionNotifierProvider.notifier).startLesson(node.id);
                            context.push('/lesson');
                          },
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
