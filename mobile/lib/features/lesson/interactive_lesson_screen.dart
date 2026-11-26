import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../data/services/i_ai_tutor_service.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/question.dart';
import '../../domain/usecases/submit_lesson_answer_use_case.dart';
import '../ai_tutor/ai_tutor_screen.dart';
import '../ai_tutor/yolchi_ai_sheet.dart';
import '../reinforcement/reinforcement_sheet.dart';
import 'audio_sim_wave_widget.dart';
import 'dictionary_sheet.dart';
import 'flashcard_deck_widget.dart';
import 'lesson_media_widget.dart';
import 'math_function_graph_widget.dart';

class InteractiveLessonScreen extends ConsumerStatefulWidget {
  const InteractiveLessonScreen({super.key});

  @override
  ConsumerState<InteractiveLessonScreen> createState() =>
      _InteractiveLessonScreenState();
}

class _InteractiveLessonScreenState
    extends ConsumerState<InteractiveLessonScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _lastTextStepKey;
  String? _inlineSuccessMessage;
  Timer? _successBannerTimer;

  static AppStrings _resolveStrings(BuildContext context) {
    final registered = Localizations.of<AppStrings>(context, AppStrings);
    if (registered != null) return registered;
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    return isRu ? AppStrings.ru : AppStrings.uz;
  }

  static String _optionLabel(int idx) =>
      idx < 26 ? String.fromCharCode(65 + idx) : '${idx + 1}';

  @override
  void dispose() {
    _successBannerTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _showInlineSuccess(String message) {
    _successBannerTimer?.cancel();
    setState(() => _inlineSuccessMessage = message);
    _successBannerTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _inlineSuccessMessage = null);
    });
  }

  void _clearInlineSuccess() {
    _successBannerTimer?.cancel();
    if (_inlineSuccessMessage != null && mounted) {
      setState(() => _inlineSuccessMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final lessonState = ref.watch(lessonSessionNotifierProvider);
    final lesson = lessonState.lesson;
    final lang = s.isRu ? 'ru' : 'uz';
    final isRu = s.isRu;

    if (lessonState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(s.lessonLabel)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (lesson == null && lessonState.lessonError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.lessonLabel)),
        body: FriendlyErrorState(
          message: lessonState.lessonError!,
          onRetry: () => ref
              .read(lessonSessionNotifierProvider.notifier)
              .retryStartLesson(uiLocale: lang),
        ),
      );
    }

    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.lessonLabel)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.lessonDataMissing, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                AppButton(
                  text: s.returnToRoadmap,
                  onPressed: () {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/roadmap');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Cross-course isolation: refuse to render a lesson from a different course.
    final activeCourse = ref.watch(courseStateNotifierProvider).activeCourse;
    if (activeCourse != null && lesson.courseId != activeCourse.id) {
      return Scaffold(
        appBar: AppBar(title: Text(s.lessonLabel)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.crossCourseLessonError, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                AppButton(
                  text: s.returnToRoadmap,
                  onPressed: () {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/roadmap');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isLargeText = textScale > 1.35;

    if (lesson.steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: isLargeText ? 64 : null,
          title: isLargeText
              ? Text(
                  s.lessonLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(lesson.localizedTitle(lang)),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLargeText) ...[
                  Text(
                    lesson.localizedTitle(lang),
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.brand,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  isRu
                      ? 'Шаги урока не найдены.'
                      : 'Dars bosqichlari topilmadi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: s.returnToRoadmap,
                  onPressed: () {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    context.go('/roadmap');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentStepIndex = lessonState.currentStepIndex.clamp(
      0,
      lesson.steps.length - 1,
    );
    final currentStep = lesson.steps[currentStepIndex];
    final totalSteps = lesson.steps.length;
    final progress = (currentStepIndex + 1) / totalSteps;
    final stepKey = '${lesson.id}:${currentStep.id}';
    if (_lastTextStepKey != stepKey) {
      _lastTextStepKey = stepKey;
      if (_textController.text != lessonState.textAnswer) {
        _textController.text = lessonState.textAnswer;
      }
    } else if (lessonState.textAnswer.isEmpty &&
        _textController.text.isNotEmpty) {
      _textController.clear();
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 64 : null,
        title: isLargeText
            ? Text(
                s.lessonLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                lesson.localizedTitle(lang),
                softWrap: true,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: s.backToRoadmapTooltip,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            context.go('/roadmap');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: s.askYolchiTooltip,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => AITutorScreen(
                    lesson: lesson,
                    activeQuestion: currentStep.interactiveQuestion,
                  ),
                ),
              );
            },
          ),
          if (activeCourse?.subject == SubjectType.english)
            IconButton(
              icon: const Icon(Icons.menu_book_rounded),
              tooltip: s.dictionaryTooltip,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const DictionarySheet(),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // Step Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              s.stepOf(currentStepIndex + 1, totalSteps),
                              style: AppTypography.ui(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: c.slatefine,
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: AppTypography.mono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: c.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: c.hairline,
                          valueColor: AlwaysStoppedAnimation<Color>(c.brand),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_inlineSuccessMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(c.successSoft, c.paper),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: c.success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: c.successText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _inlineSuccessMessage!,
                              style: AppTypography.ui(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _clearInlineSuccess,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: c.graphite,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            tooltip: isRu ? 'Закрыть' : 'Yopish',
                          ),
                        ],
                      ),
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
                        if (isLargeText) ...[
                          Text(
                            lesson.localizedTitle(lang),
                            style: AppTypography.ui(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.brand,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          currentStep.localizedTitle(lang),
                          style: AppTypography.ui(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                            height: 1.22,
                          ),
                        ),
                        if (currentStep.localizedSubtitle(lang) != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            currentStep.localizedSubtitle(lang)!,
                            style: AppTypography.ui(
                              fontSize: 13.5,
                              color: c.slatefine,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Content text
                        Text(
                          currentStep.localizedContent(lang),
                          style: AppTypography.ui(
                            fontSize: 15,
                            color: c.graphite,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Concept Highlights
                        if (currentStep.localizedHighlightNotes(lang) !=
                            null) ...[
                          AppCard(
                            padding: const EdgeInsets.all(14),
                            backgroundColor: c.subtle,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: currentStep
                                  .localizedHighlightNotes(lang)!
                                  .map((note) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 17,
                                        color: c.brand,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          note,
                                          style: AppTypography.ui(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: c.ink,
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
                            backgroundColor: Color.alphaBlend(
                              c.brandSoft,
                              c.paper,
                            ),
                            borderColor: c.brand.withValues(alpha: 0.3),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentStep.formulaData!.description,
                                  style: AppTypography.ui(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.graphite,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.paper,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: c.brand.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    currentStep.formulaData!.latex,
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    style: AppTypography.mono(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: c.brand,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...currentStep.formulaData!.variables.map((v) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• ${v['symbol']}: ${v['meaning']}',
                                      style: AppTypography.ui(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: c.ink,
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

                        // Lesson Media (approved real audio / illustration) or legacy Audio wave fallback
                        if (currentStep.media != null &&
                            currentStep.media!.isApproved) ...[
                          LessonMediaWidget(
                            key: ValueKey(
                              'media_${lesson.id}_${currentStep.id}',
                            ),
                            media: currentStep.media!,
                            uiLocale: lang,
                          ),
                          const SizedBox(height: 16),
                        ] else if (currentStep.visualModelData?.type ==
                            'audio_wave') ...[
                          AudioSimWaveWidget(
                            transcript:
                                currentStep.visualModelData?.audioTranscript ??
                                '',
                            speakerName:
                                currentStep.visualModelData?.speakerName ??
                                s.speakerDefault,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Flashcard Deck Step
                        if (currentStep.type == LessonStepType.flashcard &&
                            (currentStep.flashcards?.isNotEmpty ?? false)) ...[
                          FlashcardDeckWidget(
                            key: ValueKey(
                              'flashcard_${lesson.id}_${currentStep.id}',
                            ),
                            flashcards: currentStep.flashcards!,
                            courseId: lesson.courseId,
                            uiLocale: lang,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Interactive Quiz Step
                        if (currentStep.interactiveQuestion != null) ...[
                          _buildInteractiveQuizCard(
                            context,
                            currentStep.interactiveQuestion!,
                            lang,
                            c,
                            s,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (lessonState.answerError != null)
                          _buildAnswerError(lessonState.answerError!, c),
                      ],
                    ),
                  ),
                ),

                // Bottom Navigation Actions (responsive at 360dp @ 2.0x)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final q = currentStep.interactiveQuestion;
                      final hasQuizInput = q != null &&
                          ((q.usesTextEvaluation || q.isSelfAssessed)
                              ? lessonState.textAnswer.trim().isNotEmpty
                              : q.mode == QuestionMode.wordMatch
                              ? lessonState.selectedMatchPairs.values.any(
                                  (v) => v.trim().isNotEmpty,
                                )
                              : q.mode == QuestionMode.sentenceOrder
                              ? lessonState.selectedOrderTokens.any(
                                  (t) => t.trim().isNotEmpty,
                                )
                              : lessonState.selectedOptionIndex != null);
                      final canAdvanceAfterQuiz = q != null &&
                          lessonState.answerResult != null &&
                          ((q.isSelfAssessed &&
                                  lessonState.answerResult!.isCorrect) ||
                              (lesson.requiresMastery &&
                                  lesson.alternateExercise == null));
                      final wrongRevealNonMastery =
                          !lesson.requiresMastery &&
                          lessonState.answerResult != null &&
                          !lessonState.answerResult!.isCorrect;
                      final quizCtaDisabled =
                          ((!hasQuizInput || lessonState.isSubmittingAnswer) &&
                              !canAdvanceAfterQuiz) ||
                          (!canAdvanceAfterQuiz && wrongRevealNonMastery);

                      final primaryAction = q != null
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.ctaPrimary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(44, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: quizCtaDisabled
                                    ? null
                                    : canAdvanceAfterQuiz
                                    ? () => _handleNextStep(context)
                                    : () => _handleQuizSubmit(context, lang),
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
                                        canAdvanceAfterQuiz
                                            ? (currentStepIndex < totalSteps - 1
                                                  ? s.nextStep
                                                  : s.lessonFinish)
                                            : s.checkAnswer,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.ui(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                          color: quizCtaDisabled
                                              ? c.slatefine
                                              : Colors.white,
                                        ),
                                      ),
                              ),
                            )
                          : AppButton(
                              text: currentStepIndex < totalSteps - 1
                                  ? s.nextStep
                                  : s.lessonFinish,
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
                            );

                      if (currentStepIndex == 0) {
                        return primaryAction;
                      }

                      final backButton = AppButton(
                        text: s.back,
                        isFullWidth: true,
                        variant: AppButtonVariant.outline,
                        onPressed: lessonState.isSubmittingAnswer
                            ? null
                            : () {
                                _clearInlineSuccess();
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ref
                                    .read(
                                      lessonSessionNotifierProvider.notifier,
                                    )
                                    .previousStep();
                              },
                      );

                      if (textScale >= 1.7 && constraints.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            primaryAction,
                            const SizedBox(height: 8),
                            backButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Flexible(flex: 2, child: backButton),
                          const SizedBox(width: 10),
                          Expanded(flex: 3, child: primaryAction),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveQuizCard(
    BuildContext context,
    Question question,
    String lang,
    AppSemanticColors c,
    AppStrings s,
  ) {
    final lessonState = ref.watch(lessonSessionNotifierProvider);
    final notifier = ref.read(lessonSessionNotifierProvider.notifier);
    final selectedIdx = lessonState.selectedOptionIndex;
    final result = lessonState.answerResult;
    final reveal = result != null && !result.isCorrect;
    final correctText = result?.correctOption ?? '';
    final isRu = lang == 'ru';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              AppBadge(
                text: s.interactiveQuestionBadge,
                variant: AppBadgeVariant.blue,
              ),
              if (_richModeLabel(question.mode, isRu) != null)
                AppBadge(
                  text: _richModeLabel(question.mode, isRu)!,
                  variant: AppBadgeVariant.slate,
                ),
              if (question.cefrLevel != null &&
                  question.cefrLevel!.trim().isNotEmpty)
                AppBadge(
                  text: question.cefrLevel!,
                  variant: AppBadgeVariant.teal,
                ),
              if (question.isSelfAssessed)
                AppBadge(
                  text: isRu ? 'Самооценка' : 'O‘z-o‘zini baholash',
                  variant: AppBadgeVariant.amber,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (question.media != null && question.media!.isApproved) ...[
            LessonMediaWidget(
              key: ValueKey('q_media_${question.id}'),
              media: question.media!,
              uiLocale: lang,
            ),
            const SizedBox(height: 12),
          ],
          if (question.contextSnippet != null &&
              question.contextSnippet!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: c.subtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.hairline),
              ),
              child: Text(
                question.contextSnippet!,
                style: AppTypography.ui(
                  fontSize: 13,
                  height: 1.45,
                  color: c.ink,
                ),
              ),
            ),
          ],
          if (question.dialogueContext.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: c.subtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: question.dialogueContext
                    .map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: AppTypography.ui(
                            fontSize: 13,
                            height: 1.4,
                            color: c.ink,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (question.sentenceWithError != null &&
              question.sentenceWithError!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Color.alphaBlend(c.errorSoft, c.paper),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.error.withValues(alpha: 0.35)),
              ),
              child: Text(
                question.sentenceWithError!,
                style: AppTypography.ui(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ),
          ],
          if (question.blankTemplate != null &&
              question.blankTemplate!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Color.alphaBlend(c.brandSoft, c.paper),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.brand.withValues(alpha: 0.3)),
              ),
              child: Text(
                question.blankTemplate!,
                style: AppTypography.ui(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ),
          ],
          Text(
            question.localizedText(lang),
            style: AppTypography.ui(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: c.ink,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          if (question.usesTextEvaluation) ...[
            TextField(
              key: const Key('free_text_answer_input'),
              controller: _textController,
              enabled: !lessonState.isSubmittingAnswer,
              textInputAction: TextInputAction.done,
              style: AppTypography.ui(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
              decoration: InputDecoration(
                hintText: question.mode == QuestionMode.fillBlank
                    ? (isRu
                          ? 'Введите пропущенное слово...'
                          : 'Bo‘sh joyga mos so‘zni yozing...')
                    : (isRu
                          ? 'Напишите ответ на английском...'
                          : 'Javobingizni ingliz tilida yozing...'),
                hintStyle: AppTypography.ui(
                  fontSize: 13.5,
                  color: c.slatefine,
                ),
                filled: true,
                fillColor: c.subtle,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.slatefine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.slatefine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.brand, width: 1.8),
                ),
              ),
              onChanged: notifier.setTextAnswer,
              onSubmitted: (_) => _handleQuizSubmit(context, lang),
            ),
            const SizedBox(height: 10),
          ] else if (question.isSelfAssessed) ...[
            TextField(
              key: const Key('self_assessed_text_input'),
              controller: _textController,
              enabled: !lessonState.isSubmittingAnswer,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              style: AppTypography.ui(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
              decoration: InputDecoration(
                hintText: question.mode == QuestionMode.speakingPrompt
                    ? (isRu
                          ? 'Запишите краткие тезисы устного ответа на английском...'
                          : 'Og‘zaki javobingiz matnini ingliz tilida yozing...')
                    : (isRu
                          ? 'Напишите ваш короткий текст на английском...'
                          : 'Qisqa matningizni ingliz tilida yozing...'),
                hintStyle: AppTypography.ui(
                  fontSize: 13,
                  color: c.slatefine,
                ),
                filled: true,
                fillColor: c.subtle,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.slatefine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.slatefine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.brand, width: 1.8),
                ),
              ),
              onChanged: notifier.setTextAnswer,
            ),
            if (result != null) ...[
              const SizedBox(height: 14),
              if (question.localizedSelfAssessmentNotice(lang) != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(c.warningSoft, c.paper),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: c.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    question.localizedSelfAssessmentNotice(lang)!,
                    style: AppTypography.ui(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
              if (question.sampleResponse != null &&
                  question.sampleResponse!.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(c.successSoft, c.paper),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: c.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Пример ответа:' : 'Namuna javob:',
                        style: AppTypography.ui(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: c.successText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question.sampleResponse!,
                        style: AppTypography.ui(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (question.rubricCriteria.isNotEmpty) ...[
                Text(
                  isRu ? 'Чек-лист самопроверки:' : 'O‘zini tekshirish mezoni:',
                  style: AppTypography.ui(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 6),
                ...question.rubricCriteria.map(
                  (crit) => Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: lessonState.checkedRubricIds.contains(crit.id),
                      onChanged: (_) => notifier.toggleRubricCriterion(crit.id),
                      title: Text(
                        crit.localizedLabel(lang),
                        style: AppTypography.ui(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ] else if (question.mode == QuestionMode.wordMatch) ...[
            _buildWordMatchUi(context, question, lessonState, notifier, isRu, c),
          ] else if (question.mode == QuestionMode.sentenceOrder) ...[
            _buildSentenceOrderUi(
              context,
              question,
              lessonState,
              notifier,
              isRu,
              c,
            ),
          ] else
            ...List.generate(question.options.length, (idx) {
              final opt = question.options[idx];
              final isSelected = selectedIdx == idx;
              final isCorrectOption =
                  reveal && correctText.isNotEmpty && opt == correctText;
              final isWrongPick = reveal && isSelected && !isCorrectOption;
              final solidSuccessBg = c.isDark ? c.success : c.successText;
              final solidErrorBg = c.isDark ? c.error : c.errorText;
              final solidBrandBg = c.isDark ? c.brand : c.ctaPrimary;
              final solidFg = c.isDark ? c.canvas : Colors.white;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  child: Material(
                    color: isCorrectOption
                        ? Color.alphaBlend(c.successSoft, c.paper)
                        : isWrongPick
                        ? Color.alphaBlend(c.errorSoft, c.paper)
                        : isSelected
                        ? Color.alphaBlend(c.brandSoft, c.paper)
                        : c.paper,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: lessonState.isSubmittingAnswer
                          ? null
                          : () => notifier.selectOption(idx),
                      borderRadius: BorderRadius.circular(14),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCorrectOption
                                  ? c.success
                                  : isWrongPick
                                  ? c.error
                                  : isSelected
                                  ? c.brand
                                  : c.hairline,
                              width:
                                  (isSelected || isCorrectOption || isWrongPick)
                                  ? 2
                                  : 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isSelected || isCorrectOption || isWrongPick)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCorrectOption
                                          ? solidSuccessBg
                                          : isWrongPick
                                          ? solidErrorBg
                                          : solidBrandBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isCorrectOption
                                          ? s.correctOptionBadge
                                          : isWrongPick
                                          ? s.yourChoiceBadge
                                          : s.selectedBadge,
                                      style: AppTypography.ui(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: solidFg,
                                      ),
                                    ),
                                  ),
                                ),
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isCorrectOption
                                          ? solidSuccessBg
                                          : isWrongPick
                                          ? solidErrorBg
                                          : isSelected
                                          ? solidBrandBg
                                          : c.subtle,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _optionLabel(idx),
                                        style: AppTypography.mono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              (isSelected ||
                                                  isCorrectOption ||
                                                  isWrongPick)
                                              ? solidFg
                                              : c.graphite,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      opt,
                                      style: AppTypography.ui(
                                        fontSize: 14.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: c.ink,
                                      ),
                                    ),
                                  ),
                                  if (isCorrectOption)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: c.successText,
                                      size: 20,
                                    )
                                  else if (isWrongPick)
                                    Icon(
                                      Icons.cancel_rounded,
                                      color: c.errorText,
                                      size: 20,
                                    )
                                  else if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: c.brandStrong,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          if (reveal) _buildInlineAnswerReveal(question, lang, c, s),
        ],
      ),
    );
  }

  String? _richModeLabel(QuestionMode mode, bool isRu) {
    switch (mode) {
      case QuestionMode.fillBlank:
        return isRu ? 'Заполните пропуск' : 'Bo‘sh joyni to‘ldiring';
      case QuestionMode.wordMatch:
        return isRu ? 'Сопоставьте слова' : 'So‘zlarni moslang';
      case QuestionMode.sentenceOrder:
        return isRu ? 'Составьте предложение' : 'So‘zlarni tartiblang';
      case QuestionMode.errorCorrection:
        return isRu ? 'Исправьте ошибку' : 'Xatoni tuzating';
      case QuestionMode.conversationCompletion:
        return isRu ? 'Дополните диалог' : 'Suhbatni to‘ldiring';
      case QuestionMode.speakingPrompt:
        return isRu ? 'Устная речь' : 'Og‘zaki nutq';
      case QuestionMode.writingPrompt:
        return isRu ? 'Письмо' : 'Yozma ish';
      case QuestionMode.multipleChoice:
      case QuestionMode.textInput:
        return null;
    }
  }

  Widget _buildWordMatchUi(
    BuildContext context,
    Question question,
    LessonSessionState lessonState,
    LessonSessionNotifier notifier,
    bool isRu,
    AppSemanticColors c,
  ) {
    final sortedRights = question.matchPairs.map((p) => p.right).toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isRu
                    ? 'Выберите пару слева и справа:'
                    : 'Chapdan so‘zni tanlang va o‘ngdagi mosini bosing:',
                style: AppTypography.ui(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.graphite,
                ),
              ),
            ),
            if (lessonState.selectedMatchPairs.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: lessonState.isSubmittingAnswer
                    ? null
                    : notifier.clearMatchPairs,
                child: Text(isRu ? 'Сбросить' : 'Tozalash'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...question.matchPairs.map((pair) {
          final isActive = lessonState.activeMatchLeftId == pair.id;
          final matchedRight = lessonState.selectedMatchPairs[pair.id];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: lessonState.isSubmittingAnswer
                  ? null
                  : () => notifier.selectMatchLeft(pair.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Color.alphaBlend(c.brandSoft, c.paper)
                      : matchedRight != null
                      ? Color.alphaBlend(c.successSoft, c.paper)
                      : c.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? c.brand
                        : matchedRight != null
                        ? c.successText
                        : c.hairline,
                    width: isActive ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pair.left,
                        style: AppTypography.ui(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                    ),
                    if (matchedRight != null) ...[
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: c.ink,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          matchedRight,
                          style: AppTypography.ui(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: c.successText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxLabelWidth =
                (constraints.maxWidth - 36).clamp(80.0, double.infinity);
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedRights.map((rightText) {
                final used = lessonState.selectedMatchPairs.values.contains(
                  rightText,
                );
                return ActionChip(
                  label: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxLabelWidth),
                    child: Builder(
                      builder: (chipCtx) => DefaultTextStyle(
                        style: DefaultTextStyle.of(chipCtx).style,
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        child: Text(
                          rightText,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          style: AppTypography.ui(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  backgroundColor: used
                      ? Color.alphaBlend(c.brandSoft, c.paper)
                      : c.paper,
                  onPressed: lessonState.isSubmittingAnswer
                      ? null
                      : () => notifier.selectMatchRight(rightText),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSentenceOrderUi(
    BuildContext context,
    Question question,
    LessonSessionState lessonState,
    LessonSessionNotifier notifier,
    bool isRu,
    AppSemanticColors c,
  ) {
    final sortedBank = List<String>.from(question.orderedTokens)..sort();
    final remainingCounts = <String, int>{};
    for (final t in sortedBank) {
      remainingCounts[t] = (remainingCounts[t] ?? 0) + 1;
    }
    for (final picked in lessonState.selectedOrderTokens) {
      final count = remainingCounts[picked] ?? 0;
      if (count > 0) remainingCounts[picked] = count - 1;
    }
    final availableTokens = <String>[];
    final seenCounts = <String, int>{};
    for (final t in sortedBank) {
      final used = seenCounts[t] ?? 0;
      if (used < (remainingCounts[t] ?? 0)) {
        availableTokens.add(t);
        seenCounts[t] = used + 1;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isRu ? 'Соберите предложение:' : 'Gapni tartib bilan tuzing:',
                style: AppTypography.ui(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.graphite,
                ),
              ),
            ),
            if (lessonState.selectedOrderTokens.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: lessonState.isSubmittingAnswer
                    ? null
                    : notifier.resetOrderTokens,
                child: Text(isRu ? 'Сбросить' : 'Tozalash'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.subtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.hairline),
          ),
          child: lessonState.selectedOrderTokens.isEmpty
              ? Text(
                  isRu
                      ? 'Нажимайте на слова ниже по порядку'
                      : 'Quyidagi so‘zlarni ketma-ket bosing',
                  style: AppTypography.ui(
                    fontSize: 12.5,
                    color: c.slatefine,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxLabelWidth =
                        (constraints.maxWidth - 36).clamp(80.0, double.infinity);
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(
                        lessonState.selectedOrderTokens.length,
                        (i) => InputChip(
                          label: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxLabelWidth,
                            ),
                            child: Builder(
                              builder: (chipCtx) => DefaultTextStyle(
                                style: DefaultTextStyle.of(chipCtx).style,
                                softWrap: true,
                                maxLines: null,
                                overflow: TextOverflow.visible,
                                child: Text(
                                  lessonState.selectedOrderTokens[i],
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  style: AppTypography.ui(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          onPressed: lessonState.isSubmittingAnswer
                              ? null
                              : () => notifier.removeOrderTokenAt(i),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxLabelWidth =
                (constraints.maxWidth - 36).clamp(80.0, double.infinity);
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableTokens
                  .map(
                    (token) => ActionChip(
                      label: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxLabelWidth),
                        child: Builder(
                          builder: (chipCtx) => DefaultTextStyle(
                            style: DefaultTextStyle.of(chipCtx).style,
                            softWrap: true,
                            maxLines: null,
                            overflow: TextOverflow.visible,
                            child: Text(
                              token,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                              style: AppTypography.ui(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      backgroundColor: c.paper,
                      onPressed: lessonState.isSubmittingAnswer
                          ? null
                          : () => notifier.addOrderToken(token),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInlineAnswerReveal(
    Question question,
    String lang,
    AppSemanticColors c,
    AppStrings s,
  ) {
    final lessonState = ref.read(lessonSessionNotifierProvider);
    final result = lessonState.answerResult;
    final lesson = lessonState.lesson;
    if (result == null || result.isCorrect) return const SizedBox.shrink();
    final isRu = lang == 'ru';
    final isTextOrRich = !question.usesOptionSelection;
    final correctText = result.correctOption.isNotEmpty
        ? result.correctOption
        : '—';
    final optionFeedback =
        (result.optionFeedback != null &&
            result.optionFeedback!.trim().isNotEmpty)
        ? result.optionFeedback
        : question.localizedOptionFeedback(result.selectedOption, lang);
    final wrongFeedback =
        optionFeedback ?? question.localizedWrongFeedback(lang);
    final explanation = isTextOrRich
        ? (result.explanation.trim().isNotEmpty &&
                  result.explanation.trim() !=
                      question.localizedExplanation(lang).trim()
              ? result.explanation
              : '')
        : (question.localizedExplanation(lang).trim().isNotEmpty
              ? question.localizedExplanation(lang)
              : result.explanation);
    final isCheckpointOrAlt =
        lesson != null &&
        (lesson.alternateExercise != null ||
            lesson.id.contains('checkpoint') ||
            lesson.id.contains('exit'));
    final skillMistakeStreak =
        lessonState.consecutiveMistakesBySkill[question.skillId] ?? 0;
    final questionMistakeStreak =
        lessonState.consecutiveMistakesByQuestion[question.id] ?? 0;
    final hasRepeatedMistake =
        skillMistakeStreak >= 2 || questionMistakeStreak >= 2;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.errorSoft, c.paper),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTextOrRich
                  ? (isRu
                        ? 'Ваш ответ: ${result.selectedOption}'
                        : 'Sizning javobingiz: ${result.selectedOption}')
                  : s.youSelected(result.selectedOption),
              style: AppTypography.ui(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.errorText,
              ),
            ),
            if (!isTextOrRich) ...[
              const SizedBox(height: 3),
              Text(
                s.correctAnswerIs(correctText),
                style: AppTypography.ui(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: c.successText,
                ),
              ),
            ],
            if (wrongFeedback != null) ...[
              const SizedBox(height: 6),
              Text(
                wrongFeedback,
                style: AppTypography.ui(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: c.ink,
                ),
              ),
            ],
            if (explanation.trim().isNotEmpty &&
                explanation != wrongFeedback) ...[
              const SizedBox(height: 6),
              Text(
                explanation,
                style: AppTypography.ui(
                  fontSize: 12.5,
                  height: 1.4,
                  color: c.graphite,
                ),
              ),
            ],
            if (hasRepeatedMistake) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(c.warningSoft, c.paper),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.warning.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRu ? 'Повторная ошибка' : 'Takroriy xato aniqlandi',
                      style: AppTypography.ui(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRu
                          ? 'Несколько ошибок подряд. Выполните дополнительное упражнение для закрепления.'
                          : 'Ketma-ket xato qilindi. Mavzuni mustahkamlash uchun qo‘shimcha mashqni bajaring.',
                      style: AppTypography.ui(
                        fontSize: 12,
                        height: 1.35,
                        color: c.graphite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AppButton(
                          text: isRu
                              ? 'Дополнительное упражнение'
                              : 'Qo‘shimcha mashq',
                          size: AppButtonSize.small,
                          variant: AppButtonVariant.primary,
                          onPressed: () => _openReinforcementModal(
                            context,
                            useAlternate: isCheckpointOrAlt,
                          ),
                        ),
                        AppButton(
                          text: isRu
                              ? 'Посмотреть пример'
                              : 'Namuna misolni ko‘rish',
                          size: AppButtonSize.small,
                          variant: AppButtonVariant.outline,
                          onPressed: () => ref
                              .read(lessonSessionNotifierProvider.notifier)
                              .reviewWorkedExample(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Divider(color: c.error.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 10),
            Text(
              s.nextStepHint,
              style: AppTypography.ui(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              s.nextStepWrongGuidance,
              style: AppTypography.ui(
                fontSize: 12,
                color: c.slatefine,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openMistakeAnalysis(question, result, lang),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: c.brand,
                  ),
                  label: Text(s.yolchiAnalysisBtn),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openReinforcementModal(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: Text(s.reinforceTopicBtn),
                ),
                if (isCheckpointOrAlt)
                  TextButton(
                    onPressed: () =>
                        _openReinforcementModal(context, useAlternate: true),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(isRu ? 'Повторить упражнение' : 'Qayta mashq'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openMistakeAnalysis(
    Question question,
    LessonAnswerResult answer,
    String lang,
  ) {
    final tutor = ref.read(aiTutorServiceProvider);
    final notifier = ref.read(lessonSessionNotifierProvider.notifier);
    final session = notifier.sessionGeneration;
    final step = notifier.stepGeneration;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => YolchiAiSheet(
        loadExplanation: () => tutor.explainMistake(
          AIExplanationRequest(
            courseId: question.courseId,
            skillId: question.skillId,
            questionId: question.id,
            questionText: question.localizedText(lang),
            selectedOption: answer.selectedOption,
            correctOption: answer.correctOption,
            language: lang,
            lessonId: ref.read(lessonSessionNotifierProvider).lesson?.id,
            topic:
                question.topic ??
                ref
                    .read(lessonSessionNotifierProvider)
                    .lesson
                    ?.localizedTitle(lang),
          ),
        ),
        onStartReinforcement: () {
          Navigator.pop(sheet);
          if (!mounted ||
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
  }

  Future<void> _handleQuizSubmit(BuildContext context, String lang) async {
    _clearInlineSuccess();
    ScaffoldMessenger.of(context).clearSnackBars();
    final s = _resolveStrings(context);
    final notifier = ref.read(lessonSessionNotifierProvider.notifier);
    final session = notifier.sessionGeneration;
    final step = notifier.stepGeneration;
    await notifier.submitInteractiveQuiz(uiLocale: lang);
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
    final steps = lessonState.lesson?.steps;
    final stepIndex = lessonState.currentStepIndex;
    final currentQuestion =
        (steps != null &&
            steps.isNotEmpty &&
            stepIndex >= 0 &&
            stepIndex < steps.length)
        ? steps[stepIndex].interactiveQuestion
        : null;

    if (answerResult != null && !answerResult.isCorrect) {
      HapticFeedback.heavyImpact();
    } else if (answerResult != null && answerResult.isCorrect) {
      HapticFeedback.lightImpact();
      if (lessonState.isCompleted) {
        _showLessonCompleted(context);
      } else if (currentQuestion?.isSelfAssessed == true) {
        // Leave self-assessed sample response & rubric checklist visible without blocking bottom actions.
        _showInlineSuccess(
          lang == 'ru'
              ? 'Сравните ответ с образцом и отметьте критерии.'
              : 'Javobingizni namuna bilan solishtirib, mezonlarni belgilang.',
        );
      } else {
        _showInlineSuccess(s.correctAnswerToast);
        await notifier.nextStep(uiLocale: lang);
      }
    }
  }

  Future<void> _handleNextStep(BuildContext context) async {
    _clearInlineSuccess();
    ScaffoldMessenger.of(context).clearSnackBars();
    final s = _resolveStrings(context);
    final lang = s.isRu ? 'ru' : 'uz';
    final notifier = ref.read(lessonSessionNotifierProvider.notifier);
    final session = notifier.sessionGeneration;
    await notifier.nextStep(uiLocale: lang);
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
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final snackBg = c.isDark ? c.success : c.successText;
    final snackFg = c.isDark ? c.canvas : Colors.white;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            s.lessonCompletedToast,
            style: AppTypography.ui(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: snackFg,
            ),
          ),
          backgroundColor: snackBg,
        ),
      );
    context.go('/roadmap');
  }

  Widget _buildAnswerError(String message, AppSemanticColors c) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.errorSoft, c.paper),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: c.errorText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTypography.ui(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.errorText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReinforcementModal(
    BuildContext context, {
    bool useAlternate = false,
  }) {
    final notifier = ref.read(lessonSessionNotifierProvider.notifier);
    final session = notifier.sessionGeneration;
    final step = notifier.stepGeneration;
    final lesson = ref.read(lessonSessionNotifierProvider).lesson;
    if (lesson == null) return;
    if (lesson.requiresMastery && lesson.alternateExercise == null) {
      notifier.reviewWorkedExample();
      return;
    }

    final targetQuestion = (useAlternate && lesson.alternateExercise != null)
        ? lesson.alternateExercise!
        : lesson.reinforcementExercise;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReinforcementSheet(
        question: targetQuestion,
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
          return await notifier.submitReinforcement(
            selectedIndex,
            useAlternate: useAlternate,
          );
        },
        onSubmitRichWithRubric: ({
          required int selectedIndex,
          String? selectedText,
          Map<String, String>? matchedPairs,
          List<String>? orderedTokens,
          List<String>? checkedCriteriaIds,
        }) async {
          if (!context.mounted ||
              !identical(
                ref.read(lessonSessionNotifierProvider.notifier),
                notifier,
              ) ||
              notifier.sessionGeneration != session ||
              notifier.stepGeneration != step) {
            return null;
          }
          return await notifier.submitReinforcement(
            selectedIndex,
            selectedText: selectedText,
            matchedPairs: matchedPairs,
            orderedTokens: orderedTokens,
            checkedCriteriaIds: checkedCriteriaIds,
            useAlternate: useAlternate,
          );
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
          context.go('/roadmap');
        },
      ),
    );
  }
}
