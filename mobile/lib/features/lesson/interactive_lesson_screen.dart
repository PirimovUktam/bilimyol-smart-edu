import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../app/providers.dart';
import 'math_function_graph_widget.dart';
import 'audio_sim_wave_widget.dart';
import '../ai_tutor/yolchi_ai_sheet.dart';
import '../reinforcement/reinforcement_sheet.dart';

class InteractiveLessonScreen extends ConsumerStatefulWidget {
  const InteractiveLessonScreen({super.key});

  @override
  ConsumerState<InteractiveLessonScreen> createState() => _InteractiveLessonScreenState();
}

class _InteractiveLessonScreenState extends ConsumerState<InteractiveLessonScreen> {
  @override
  Widget build(BuildContext context) {
    final lessonState = ref.watch(lessonSessionNotifierProvider);
    final lesson = lessonState.lesson;

    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dars')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Dars ma’lumotlari yuklanmadi'),
              const SizedBox(height: 12),
              AppButton(
                text: 'Yo‘l xaritasiga qaytish',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      );
    }

    final currentStepIndex = lessonState.currentStepIndex;
    final currentStep = lesson.steps[currentStepIndex];
    final totalSteps = lesson.steps.length;
    final progress = (currentStepIndex + 1) / totalSteps;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(lesson.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Qadam ${currentStepIndex + 1} / $totalSteps',
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
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppColors.cardBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            // Step Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step Title & Subtitle
                    Text(
                      currentStep.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (currentStep.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        currentStep.subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Content text
                    Text(
                      currentStep.content,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Concept Highlights
                    if (currentStep.highlightNotes != null) ...[
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        backgroundColor: const Color(0xFFF1F5F9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: currentStep.highlightNotes!.map((note) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Formula Card
                    if (currentStep.formulaData != null) ...[
                      AppCard(
                        backgroundColor: AppColors.primaryLight.withValues(alpha: 0.5),
                        borderColor: AppColors.primary.withValues(alpha: 0.3),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStep.formulaData!.description,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  currentStep.formulaData!.latex,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...currentStep.formulaData!.variables.map((v) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• ${v['symbol']}: ${v['meaning']}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Visual model: Math function graph
                    if (currentStep.visualModelData?.type == 'function_graph') ...[
                      const MathFunctionGraphWidget(),
                      const SizedBox(height: 16),
                    ],

                    // Visual model: Audio wave simulation
                    if (currentStep.visualModelData?.type == 'audio_wave') ...[
                      AudioSimWaveWidget(
                        transcript: currentStep.visualModelData?.audioTranscript ?? '',
                        speakerName: currentStep.visualModelData?.speakerName ?? 'Speaker',
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Interactive Quiz Step
                    if (currentStep.interactiveQuestion != null) ...[
                      _buildInteractiveQuizCard(context, currentStep.interactiveQuestion!),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Navigation Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (currentStepIndex > 0) ...[
                    AppButton(
                      text: 'Orqaga',
                      variant: AppButtonVariant.outline,
                      onPressed: () {
                        ref.read(lessonSessionNotifierProvider.notifier).previousStep();
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: currentStep.interactiveQuestion != null
                        ? AppButton(
                            text: 'Javobni Tekshirish',
                            isFullWidth: true,
                            size: AppButtonSize.large,
                            isLoading: lessonState.isSubmittingAnswer,
                            onPressed: lessonState.selectedOptionIndex == null
                                ? null
                                : () => _handleQuizSubmit(context),
                          )
                        : AppButton(
                            text: currentStepIndex < totalSteps - 1 ? 'Keyingi qadam' : 'Yakunlash',
                            isFullWidth: true,
                            size: AppButtonSize.large,
                            rightIcon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                            onPressed: () {
                              ref.read(lessonSessionNotifierProvider.notifier).nextStep();
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveQuizCard(BuildContext context, question) {
    final lessonState = ref.watch(lessonSessionNotifierProvider);
    final selectedIdx = lessonState.selectedOptionIndex;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppBadge(text: 'Interaktiv Savol', variant: AppBadgeVariant.blue),
              // Shortcut helper for testing wrong answer
              TextButton(
                onPressed: () {
                  // Select deliberate wrong answer (Index 0 in Math: '8')
                  ref.read(lessonSessionNotifierProvider.notifier).selectOption(0);
                },
                child: Text(
                  'Xato javobni tanlash',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          ...List.generate(question.options.length, (idx) {
            final opt = question.options[idx];
            final isSelected = selectedIdx == idx;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.7) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    ref.read(lessonSessionNotifierProvider.notifier).selectOption(idx);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.cardBorder,
                        width: isSelected ? 2 : 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              ['A', 'B', 'C', 'D'][idx],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            opt,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _handleQuizSubmit(BuildContext context) async {
    await ref.read(lessonSessionNotifierProvider.notifier).submitInteractiveQuiz();
    final lessonState = ref.read(lessonSessionNotifierProvider);
    final answerResult = lessonState.answerResult;

    if (!context.mounted) return;

    if (answerResult != null && !answerResult.isCorrect && answerResult.aiExplanation != null) {
      // Trigger Yo'lchi AI bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => YolchiAiSheet(
          explanation: answerResult.aiExplanation!,
          onStartReinforcement: () {
            Navigator.pop(ctx);
            _openReinforcementModal(context);
          },
        ),
      );
    } else if (answerResult != null && answerResult.isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/roadmap');
    }
  }

  void _openReinforcementModal(BuildContext context) {
    final lesson = ref.read(lessonSessionNotifierProvider).lesson;
    if (lesson == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReinforcementSheet(
        question: lesson.reinforcementExercise,
        onSubmit: (selectedIndex) async {
          return await ref.read(lessonSessionNotifierProvider.notifier).submitReinforcement(selectedIndex);
        },
        onGoToDashboard: () {
          Navigator.pop(ctx);
          context.go('/dashboard');
        },
      ),
    );
  }
}
