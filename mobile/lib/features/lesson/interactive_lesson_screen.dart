import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../app/providers.dart';
import 'math_function_graph_widget.dart';
import 'audio_sim_wave_widget.dart';
import '../ai_tutor/yolchi_ai_sheet.dart';
import '../reinforcement/reinforcement_sheet.dart';

class InteractiveLessonScreen extends ConsumerStatefulWidget {
  const InteractiveLessonScreen({super.key});

  @override
  ConsumerState<InteractiveLessonScreen> createState() =>
      _InteractiveLessonScreenState();
}

class _InteractiveLessonScreenState
    extends ConsumerState<InteractiveLessonScreen> {
  @override
  Widget build(BuildContext context) {
    final lessonState = ref.watch(lessonSessionNotifierProvider);
    final lesson = lessonState.lesson;

    if (lessonState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dars')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (lesson == null && lessonState.lessonError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dars')),
        body: FriendlyErrorState(
          message: lessonState.lessonError!,
          onRetry: () => ref
              .read(lessonSessionNotifierProvider.notifier)
              .retryStartLesson(),
        ),
      );
    }

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

    // Cross-course isolation: refuse to render a lesson from a different course.
    final activeCourse = ref.watch(courseStateNotifierProvider).activeCourse;
    if (activeCourse != null && lesson.courseId != activeCourse.id) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dars')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ushbu dars boshqa fanga tegishli va ko‘rsatilmaydi.\nIltimos, yo‘nalishingizni tanlab qayta urinib ko‘ring.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Yo‘l xaritasiga qaytish',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Step Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
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
                        backgroundColor: AppColors.primaryLight.withValues(
                          alpha: 0.5,
                        ),
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
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
                    if (currentStep.visualModelData?.type ==
                        'function_graph') ...[
                      const MathFunctionGraphWidget(),
                      const SizedBox(height: 16),
                    ],

                    // Visual model: Audio wave simulation
                    if (currentStep.visualModelData?.type == 'audio_wave') ...[
                      AudioSimWaveWidget(
                        transcript:
                            currentStep.visualModelData?.audioTranscript ?? '',
                        speakerName:
                            currentStep.visualModelData?.speakerName ??
                            'Speaker',
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Interactive Quiz Step
                    if (currentStep.interactiveQuestion != null) ...[
                      _buildInteractiveQuizCard(
                        context,
                        currentStep.interactiveQuestion!,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (lessonState.answerError != null)
                      _buildAnswerError(lessonState.answerError!),
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
                      onPressed: lessonState.isSubmittingAnswer
                          ? null
                          : () {
                              ref
                                  .read(lessonSessionNotifierProvider.notifier)
                                  .previousStep();
                            },
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: currentStep.interactiveQuestion != null
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            onPressed:
                                lessonState.selectedOptionIndex == null ||
                                    lessonState.isSubmittingAnswer
                                ? null
                                : () => _handleQuizSubmit(context),
                            child: lessonState.isSubmittingAnswer
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'TEKSHIRISH',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          )
                        : AppButton(
                            text: currentStepIndex < totalSteps - 1
                                ? 'Keyingi qadam'
                                : 'Yakunlash',
                            isFullWidth: true,
                            isLoading: lessonState.isSubmittingAnswer,
                            size: AppButtonSize.large,
                            rightIcon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: lessonState.isSubmittingAnswer
                                ? null
                                : () => _handleNextStep(context),
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
          const Align(
            alignment: Alignment.centerLeft,
            child: AppBadge(
              text: 'Interaktiv Savol',
              variant: AppBadgeVariant.blue,
            ),
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
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isSelected ? const Color(0xFFEEF2FF) : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: lessonState.isSubmittingAnswer
                      ? null
                      : () {
                          ref
                              .read(lessonSessionNotifierProvider.notifier)
                              .selectOption(idx);
                        },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : AppColors.cardBorder,
                        width: isSelected ? 2 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'tanlangan ✓',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  ['A', 'B', 'C', 'D'][idx],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                opt,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFF1E293B)
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                          ],
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
    );
  }

  Future<void> _handleQuizSubmit(BuildContext context) async {
    final notifier = ref.read(lessonSessionNotifierProvider.notifier);
    final session = notifier.sessionGeneration;
    final step = notifier.stepGeneration;
    await notifier.submitInteractiveQuiz();
    if (!context.mounted ||
        !identical(
          ref.read(lessonSessionNotifierProvider.notifier),
          notifier,
        ) ||
        notifier.sessionGeneration != session ||
        notifier.stepGeneration != step) {
      return;
    }
    final lessonState = ref.read(lessonSessionNotifierProvider);
    final answerResult = lessonState.answerResult;

    if (answerResult != null &&
        !answerResult.isCorrect &&
        answerResult.aiExplanation != null) {
      HapticFeedback.heavyImpact();
      // Trigger Yo'lchi AI bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => YolchiAiSheet(
          explanation: answerResult.aiExplanation!,
          onStartReinforcement: () {
            Navigator.pop(ctx);
            if (!context.mounted ||
                !identical(
                  ref.read(lessonSessionNotifierProvider.notifier),
                  notifier,
                ) ||
                notifier.sessionGeneration != session ||
                notifier.stepGeneration != step) {
              return;
            }
            _openReinforcementModal(context);
          },
        ),
      );
    } else if (answerResult != null && answerResult.isCorrect) {
      HapticFeedback.lightImpact();
      if (lessonState.isCompleted) {
        _showLessonCompleted(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('To‘g‘ri javob!'),
            backgroundColor: AppColors.success,
          ),
        );
        await notifier.nextStep();
      }
    }
  }

  Future<void> _handleNextStep(BuildContext context) async {
    final notifier = ref.read(lessonSessionNotifierProvider.notifier);
    final session = notifier.sessionGeneration;
    await notifier.nextStep();
    if (!context.mounted ||
        !identical(
          ref.read(lessonSessionNotifierProvider.notifier),
          notifier,
        ) ||
        notifier.sessionGeneration != session) {
      return;
    }
    if (ref.read(lessonSessionNotifierProvider).isCompleted) {
      _showLessonCompleted(context);
    }
  }

  void _showLessonCompleted(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
        backgroundColor: AppColors.success,
      ),
    );
    context.go('/roadmap');
  }

  Widget _buildAnswerError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openReinforcementModal(BuildContext context) {
    final notifier = ref.read(lessonSessionNotifierProvider.notifier);
    final session = notifier.sessionGeneration;
    final step = notifier.stepGeneration;
    final lesson = ref.read(lessonSessionNotifierProvider).lesson;
    if (lesson == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReinforcementSheet(
        question: lesson.reinforcementExercise,
        onSubmit: (selectedIndex) async {
          if (!context.mounted ||
              !identical(
                ref.read(lessonSessionNotifierProvider.notifier),
                notifier,
              ) ||
              notifier.sessionGeneration != session ||
              notifier.stepGeneration != step) {
            return null;
          }
          return await notifier.submitReinforcement(selectedIndex);
        },
        onGoToDashboard: () {
          Navigator.pop(ctx);
          if (!context.mounted ||
              !identical(
                ref.read(lessonSessionNotifierProvider.notifier),
                notifier,
              ) ||
              notifier.sessionGeneration != session ||
              notifier.stepGeneration != step) {
            return;
          }
          context.go('/dashboard');
        },
      ),
    );
  }
}
