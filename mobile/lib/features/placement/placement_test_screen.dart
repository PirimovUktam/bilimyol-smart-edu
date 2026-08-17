import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../domain/entities/question.dart';
import '../../app/providers.dart';

class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  ConsumerState<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen> {
  int? _selectedOption;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeCourse = ref.read(courseStateNotifierProvider).activeCourse;
      if (activeCourse != null) {
        ref.read(placementStateNotifierProvider.notifier).loadQuestions(activeCourse.id);
      }
    });
  }

  String _getDifficultyLabel(QuestionDifficulty diff) {
    switch (diff) {
      case QuestionDifficulty.easy:
        return 'Oson';
      case QuestionDifficulty.medium:
        return 'O‘rta';
      case QuestionDifficulty.hard:
        return 'Qiyin';
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseState = ref.watch(courseStateNotifierProvider);
    final placementState = ref.watch(placementStateNotifierProvider);
    final activeCourse = courseState.activeCourse;

    final currentQ = placementState.currentQuestion;
    final qNumber = placementState.questionNumber;
    final totalQ = placementState.totalQuestionsToAsk;

    if (placementState.isSubmitting || currentQ == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Natijalar hisoblanmoqda...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Haqiqiy javoblaringiz asosida bilim xaritasi tuzilmoqda',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progress = qNumber / totalQ;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Diagnostika • ${activeCourse?.title ?? ""}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar & Counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Savol $qNumber / $totalQ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),

              // Question Card
              Expanded(
                child: SingleChildScrollView(
                  child: AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Q$qNumber',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppBadge(
                              text: currentQ.skillId.replaceAll('skill_math_', '').replaceAll('skill_eng_', '').toUpperCase(),
                              variant: AppBadgeVariant.blue,
                            ),
                            const SizedBox(width: 6),
                            AppBadge(
                              text: _getDifficultyLabel(currentQ.difficulty),
                              variant: AppBadgeVariant.slate,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentQ.text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        if (currentQ.formulaLatex != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              currentQ.formulaLatex!,
                              style: GoogleFonts.firaCode(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        if (currentQ.contextSnippet != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Text(
                              currentQ.contextSnippet!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Options
                        ...List.generate(currentQ.options.length, (idx) {
                          final optionText = currentQ.options[idx];
                          final isSelected = _selectedOption == idx;
                          final letter = ['A', 'B', 'C', 'D'][idx];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.7) : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedOption = idx);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                                      width: isSelected ? 2 : 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            letter,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected ? Colors.white : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          optionText,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Submit button
              AppButton(
                text: qNumber >= totalQ ? 'Natijalarni Ko‘rish' : 'Keyingi Savol',
                isFullWidth: true,
                size: AppButtonSize.large,
                rightIcon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                onPressed: _selectedOption == null
                    ? null
                    : () async {
                        final picked = _selectedOption!;
                        setState(() => _selectedOption = null);
                        final isFinished = await ref.read(placementStateNotifierProvider.notifier).submitAnswer(picked);
                        if (isFinished && context.mounted) {
                          context.go('/knowledge-map');
                        }
                      },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
