import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../data/datasources/english/cefr_skeleton_data.dart';
import '../../domain/entities/question.dart';
import '../../domain/personalization/learning_start.dart';
import '../lesson/audio_sim_wave_widget.dart';
import '../lesson/lesson_media_widget.dart';

class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  ConsumerState<PlacementTestScreen> createState() =>
      _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen> {
  int? _selectedOption;
  bool _submitInFlight = false;
  bool _confirmDialogOpen = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      courseStateNotifierProvider.select((state) => state.activeCourse?.id),
      (_, courseId) {
        if (courseId == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              ref.read(courseStateNotifierProvider).activeCourse?.id ==
                  courseId) {
            _load(courseId);
          }
        });
      },
      fireImmediately: true,
    );
  }

  String _resolveLang(BuildContext context) {
    if (Localizations.of<AppStrings>(context, AppStrings) case final strings?) {
      return strings.isRu ? 'ru' : 'uz';
    }
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  String _getDifficultyLabel(QuestionDifficulty diff, AppStrings s) {
    switch (diff) {
      case QuestionDifficulty.easy:
        return s.diffEasy;
      case QuestionDifficulty.medium:
        return s.diffMedium;
      case QuestionDifficulty.hard:
        return s.diffHard;
    }
  }

  Future<void> _runQuickDemo() async {
    await ref.read(learnerStateNotifierProvider.notifier).seedQuickDemo();
    if (mounted) context.go('/knowledge-map');
  }

  void _load(String courseId, {bool restart = false}) {
    setState(() {
      _selectedOption = null;
      _submitError = null;
    });
    ref
        .read(placementStateNotifierProvider.notifier)
        .loadQuestions(courseId, restart: restart);
  }

  Future<void> _submit(
    PlacementState placement,
    AppStrings s,
    String lang,
  ) async {
    final selected = _selectedOption;
    if (selected == null ||
        _submitInFlight ||
        _confirmDialogOpen ||
        placement.isSubmitting) {
      return;
    }
    final isFinalQuestion =
        placement.questionNumber >= placement.totalQuestionsToAsk;
    if (isFinalQuestion) {
      setState(() => _confirmDialogOpen = true);
      bool? confirmed;
      try {
        confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              lang == 'ru' ? 'Отправить ответы?' : 'Javoblarni topshirasizmi?',
            ),
            content: Text(s.placementConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.back),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.placementConfirmSubmit),
              ),
            ],
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _confirmDialogOpen = false);
        }
      }
      if (!mounted || confirmed != true) return;
    }
    setState(() {
      _submitInFlight = true;
      _submitError = null;
    });
    try {
      final notifier = ref.read(placementStateNotifierProvider.notifier);
      try {
        await notifier.submitAnswer(selected);
        if (!mounted) return;
        final next = ref.read(placementStateNotifierProvider);
        if (next.currentQuestion?.id != placement.currentQuestion?.id ||
            next.sessionId != placement.sessionId ||
            next.result != null) {
          setState(() => _selectedOption = null);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _submitError = s.placementSubmitError);
      }
    } finally {
      if (mounted) {
        setState(() => _submitInFlight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
    final s =
        Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings.forCode(lang);
    final courseState = ref.watch(courseStateNotifierProvider);
    final placementState = ref.watch(placementStateNotifierProvider);
    final activeCourse = courseState.activeCourse;
    final currentQ = placementState.currentQuestion;
    final qNumber = placementState.questionNumber;
    final totalQ = placementState.totalQuestionsToAsk;
    final result = placementState.result;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    if (result != null) {
      final totalSubs = result.submissions.length;
      final correct = result.submissions
          .where((answer) => answer.isCorrect)
          .length;
      final pct = totalSubs > 0 ? ((correct / totalSubs) * 100).round() : 0;
      final isEnglish = placementState.courseId == 'course_eng_01';
      final cefrTier = result.cefrLevel ?? 'Pre-A1';
      final showSkillBreakdown =
          !usesMathMastery(placementState.courseId) &&
          result.computedScores.isNotEmpty;
      final skillNames = {
        for (final skill in courseState.activeSkills) skill.id: skill.name,
      };

      return Scaffold(
        appBar: AppBar(
          toolbarHeight: isLargeText ? 96 : null,
          title: Text(
            s.diagnosticResultTitle,
            softWrap: true,
            maxLines: isLargeText ? null : 1,
            overflow: isLargeText
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: c.successSoft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: c.success.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(
                                Icons.fact_check_rounded,
                                size: 26,
                                color: c.successText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppBadge(
                                    text: s.diagnosticReadyBadge,
                                    variant: AppBadgeVariant.emerald,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    s.placementDoneTitle,
                                    style: AppTypography.ui(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: c.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              s.placementCorrectSummary(correct, totalSubs),
                              style: AppTypography.ui(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: c.brandSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$pct%',
                                style: AppTypography.mono(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: c.isDark ? c.brandStrong : c.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.diagnosticHandoffNote,
                          style: AppTypography.ui(
                            fontSize: 13,
                            color: c.graphite,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isEnglish) ...[
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      borderColor: c.brand.withValues(alpha: 0.35),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              AppBadge(
                                text: cefrTier,
                                variant: AppBadgeVariant.blue,
                              ),
                              if (result.assessedCefr != null &&
                                  result.assessedCefr != cefrTier)
                                AppBadge(
                                  text: isRu
                                      ? 'Диагностика: ${result.assessedCefr}'
                                      : 'Diagnostika: ${result.assessedCefr}',
                                  variant: AppBadgeVariant.amber,
                                ),
                              Text(
                                isRu
                                    ? 'Стартовый уровень: $cefrTier (${result.overallScore}%)'
                                    : 'Tavsiya etilgan bosqich: $cefrTier (${result.overallScore}%)',
                                style: AppTypography.ui(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: c.ink,
                                ),
                              ),
                            ],
                          ),
                          if (result.assessedCefr != null &&
                              result.unlockedCefrFloor != null &&
                              result.assessedCefr != cefrTier) ...[
                            const SizedBox(height: 8),
                            Text(
                              s.reassessmentFloorNote(
                                result.assessedCefr!,
                                result.unlockedCefrFloor!,
                              ),
                              style: AppTypography.ui(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: c.warningText,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            isRu
                                ? 'Уровни B2–C2 появятся на следующем этапе (DEFERRED). Сейчас доступен маршрут A1–B1.'
                                : 'B2–C2 darajalari keyingi bosqichda (DEFERRED) qo‘shiladi. Hozircha A1–B1 yo‘nalishida boshlashingiz mumkin.',
                            style: AppTypography.ui(
                              fontSize: 12.5,
                              color: c.graphite,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isRu
                                ? 'Результат диагностики определяет стартовый маршрут и не заменяет освоение уроков. $cefrOfficialDisclaimerRu'
                                : 'Diagnostika natijasi boshlang‘ich yo‘lni ko‘rsatadi va mustaqil dars o‘zlashtirishidan alohida saqlanadi. $cefrOfficialDisclaimerUz',
                            style: AppTypography.ui(
                              fontSize: 11.5,
                              color: c.slatefine,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppButton(
                    text: s.viewPersonalPath,
                    isFullWidth: true,
                    size: AppButtonSize.large,
                    onPressed: () => context.go('/roadmap'),
                  ),
                  if (placementState.canRetake) ...[
                    const SizedBox(height: 10),
                    AppButton(
                      text: s.retakePlacement,
                      isFullWidth: true,
                      variant: AppButtonVariant.outline,
                      onPressed: () =>
                          _load(placementState.courseId, restart: true),
                    ),
                  ],
                  if (showSkillBreakdown) ...[
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.skillBreakdownTitle,
                            style: AppTypography.ui(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final entry
                              in result.computedScores.entries) ...[
                            Builder(
                              builder: (context) {
                                final score = entry.value.score;
                                final barColor = score < 50
                                    ? c.warning
                                    : c.success;
                                final textColor = score < 50
                                    ? c.warningText
                                    : c.successText;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            skillNames[entry.key] ?? entry.key,
                                            style: AppTypography.ui(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: c.ink,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$score%',
                                          style: AppTypography.mono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: (score / 100).clamp(0.0, 1.0),
                                        minHeight: 7,
                                        backgroundColor: c.subtle,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              barColor,
                                            ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (result.review.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      s.answersReviewTitle,
                      style: AppTypography.ui(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final answer in result.review) ...[
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Material(
                          type: MaterialType.transparency,
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              leading: Icon(
                                answer.submission.isCorrect
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: answer.submission.isCorrect
                                    ? c.successText
                                    : c.errorText,
                              ),
                              title: Text(
                                answer.localizedQuestion(lang),
                                style: AppTypography.ui(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                ),
                              ),
                              subtitle: Text(
                                answer.submission.isCorrect
                                    ? s.answerCorrectTag
                                    : s.answerWrongTag,
                                style: AppTypography.ui(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: answer.submission.isCorrect
                                      ? c.successText
                                      : c.errorText,
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.yourAnswerLine(answer.selected),
                                  style: AppTypography.ui(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.graphite,
                                  ),
                                ),
                                if (!answer.submission.isCorrect) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    s.correctAnswerLine(answer.correct),
                                    style: AppTypography.ui(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: c.successText,
                                    ),
                                  ),
                                ],
                                if (answer
                                    .localizedExplanation(lang)
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    answer.localizedExplanation(lang),
                                    style: AppTypography.ui(
                                      fontSize: 12.5,
                                      color: c.slatefine,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (placementState.isSubmitting) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: c.brand),
                const SizedBox(height: 16),
                Text(
                  s.calculatingResults,
                  textAlign: TextAlign.center,
                  style: AppTypography.ui(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.buildingKnowledgeMap,
                  textAlign: TextAlign.center,
                  style: AppTypography.ui(fontSize: 13, color: c.slatefine),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (activeCourse == null && !courseState.isLoading && currentQ == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.diagnosticTitle)),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_outlined, size: 40, color: c.brand),
                      const SizedBox(height: 12),
                      Text(
                        s.chooseSubjectFirstPrompt,
                        textAlign: TextAlign.center,
                        style: AppTypography.ui(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: s.chooseSubject,
                        isFullWidth: true,
                        onPressed: () => context.go('/courses'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (currentQ == null) {
      final isLoadingQuestions = !placementState.hasLoaded;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLoadingQuestions
                      ? Icons.hourglass_top_rounded
                      : Icons.error_outline_rounded,
                  size: 44,
                  color: c.slatefine,
                ),
                const SizedBox(height: 16),
                Text(
                  isLoadingQuestions
                      ? s.preparingQuestions
                      : s.questionsLoadFailed,
                  style: AppTypography.ui(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isLoadingQuestions
                      ? s.questionsLoadingDesc
                      : s.errorSubtitle,
                  style: AppTypography.ui(fontSize: 13, color: c.slatefine),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (isLoadingQuestions)
                  CircularProgressIndicator(color: c.brand)
                else ...[
                  AppButton(
                    text: s.retry,
                    isFullWidth: true,
                    leftIcon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      final active = activeCourse ?? courseState.activeCourse;
                      if (active != null) {
                        _load(active.id);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: s.back,
                    isFullWidth: true,
                    variant: AppButtonVariant.outline,
                    onPressed: () => context.go('/courses'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final safeTotalQ = totalQ <= 0 ? 1 : totalQ;
    final progress = (qNumber / safeTotalQ).clamp(0.0, 1.0);
    final disableInteraction = placementState.isSubmitting || _submitInFlight;
    final showQuickDemo = !ref
        .watch(learnerRepositoryProvider)
        .supportsServerPlacementPersistence;
    final quickDemoButton = showQuickDemo
        ? TextButton.icon(
            onPressed: disableInteraction ? null : _runQuickDemo,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: Text(
              s.quickDemoBtn,
              style: AppTypography.ui(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 144 : null,
        title: Text(
          activeCourse == null
              ? s.diagnosticTitle
              : '${s.diagnosticTitle} · ${s.localizedCourseTitle(activeCourse)}',
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: isLargeText
              ? Theme.of(
                  context,
                ).appBarTheme.titleTextStyle?.copyWith(fontSize: 15)
              : null,
        ),
        actions: [
          if (!isLargeText && quickDemoButton != null) ...[
            quickDemoButton,
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final progressHeader = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLargeText && quickDemoButton != null) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: quickDemoButton,
                        ),
                        const SizedBox(height: 4),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              s.questionCounter(qNumber, totalQ),
                              style: AppTypography.ui(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: c.graphite,
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
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: c.subtle,
                          valueColor: AlwaysStoppedAnimation<Color>(c.brand),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );

                  final noticeBanner = placementState.notice == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: c.warningSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: c.warning.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.hourglass_bottom_rounded,
                                    size: 18,
                                    color: c.warningText,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      placementState.notice!,
                                      style: AppTypography.ui(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: c.warningText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                  final questionCard = AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: c.brandSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Q$qNumber',
                                style: AppTypography.mono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: c.isDark ? c.brandStrong : c.brand,
                                ),
                              ),
                            ),
                            if (placementState.sessionId == null)
                              AppBadge(
                                text: _getDifficultyLabel(
                                  currentQ.difficulty,
                                  s,
                                ),
                                variant: AppBadgeVariant.slate,
                              ),
                            if (currentQ.cefrLevel != null &&
                                currentQ.cefrLevel!.trim().isNotEmpty)
                              AppBadge(
                                text: currentQ.cefrLevel!,
                                variant: AppBadgeVariant.teal,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (currentQ.media != null &&
                            currentQ.media!.isApproved) ...[
                          LessonMediaWidget(
                            key: ValueKey(
                              'placement_media_${currentQ.id}_${currentQ.media!.id}',
                            ),
                            media: currentQ.media!,
                            uiLocale: lang,
                            initiallyExpandTranscript: false,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          currentQ.localizedText(lang),
                          style: AppTypography.ui(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                            height: 1.35,
                          ),
                        ),
                        if (currentQ.audioSimText != null) ...[
                          const SizedBox(height: 12),
                          AudioSimWaveWidget(
                            transcript: currentQ.audioSimText!,
                            speakerName:
                                currentQ.audioSimSpeaker ?? s.speakerDefault,
                          ),
                        ],
                        if (currentQ.formulaLatex != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.brandSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: c.brand.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              currentQ.formulaLatex!,
                              style: AppTypography.mono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.isDark ? c.brandStrong : c.brand,
                              ),
                            ),
                          ),
                        ],
                        if (currentQ.contextSnippet != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: c.subtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: c.hairline),
                            ),
                            child: Text(
                              currentQ.contextSnippet!,
                              style: AppTypography.ui(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.graphite,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ...List.generate(currentQ.options.length, (idx) {
                          final optionText = currentQ.options[idx];
                          final isSelected = _selectedOption == idx;
                          final letter = idx < 26
                              ? String.fromCharCode(65 + idx)
                              : '${idx + 1}';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Semantics(
                              button: true,
                              selected: isSelected,
                              child: Material(
                                color: isSelected
                                    ? Color.alphaBlend(c.brandSoft, c.paper)
                                    : c.paper,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: disableInteraction
                                      ? null
                                      : () {
                                          ref
                                              .read(
                                                placementStateNotifierProvider
                                                    .notifier,
                                              )
                                              .clearNotice();
                                          setState(() => _selectedOption = idx);
                                        },
                                  borderRadius: BorderRadius.circular(14),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? c.brand
                                              : c.hairline,
                                          width: isSelected ? 2 : 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? c.ctaPrimary
                                                  : c.subtle,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                letter,
                                                style: AppTypography.mono(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : c.graphite,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              optionText,
                                              style: AppTypography.ui(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: c.ink,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: c.brand,
                                              size: 20,
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
                      ],
                    ),
                  );

                  final errorBanner = _submitError == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: c.errorSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: c.error.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        size: 18,
                                        color: c.errorText,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _submitError!,
                                          style: AppTypography.ui(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: c.errorText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: TextButton(
                                      onPressed: disableInteraction
                                          ? null
                                          : () => _load(
                                              activeCourse?.id ??
                                                  placementState.courseId,
                                            ),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(44, 44),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        foregroundColor: c.errorText,
                                      ),
                                      child: Text(
                                        s.reloadSession,
                                        style: AppTypography.ui(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: c.errorText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                  final submitButton = Builder(
                    builder: (context) {
                      final lastSubmit = placementState.lastSubmittedAt;
                      final elapsedMs = lastSubmit == null
                          ? 800
                          : DateTime.now().difference(lastSubmit).inMilliseconds;
                      final remainingMs =
                          placementState.sessionId == null && elapsedMs < 800
                          ? (800 - elapsedMs).clamp(0, 800)
                          : 0;
                      final beginProgress = remainingMs == 0
                          ? 1.0
                          : (1.0 - remainingMs / 800.0).clamp(0.0, 1.0);
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(lastSubmit?.microsecondsSinceEpoch ?? 0),
                        tween: Tween<double>(begin: beginProgress, end: 1.0),
                        duration: Duration(milliseconds: remainingMs),
                        builder: (context, cooldownProgress, _) {
                          final inCooldown = cooldownProgress < 1.0;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (inCooldown) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: cooldownProgress,
                                    minHeight: 3,
                                    backgroundColor: c.subtle,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      c.warning,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              AppButton(
                                text: qNumber >= totalQ
                                    ? s.viewResults
                                    : s.nextQuestion,
                                isFullWidth: true,
                                size: AppButtonSize.large,
                                isLoading: disableInteraction,
                                rightIcon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                onPressed:
                                    _selectedOption == null ||
                                        disableInteraction ||
                                        _confirmDialogOpen
                                    ? null
                                    : () => _submit(placementState, s, lang),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );

                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final useCompactScrollableLayout =
                      constraints.maxHeight < 360 ||
                      ((errorBanner != null || noticeBanner != null) &&
                          (constraints.maxHeight < 680 || textScale > 1.3));

                  if (useCompactScrollableLayout) {
                    return SingleChildScrollView(
                      reverse: true,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                progressHeader,
                                ?noticeBanner,
                                questionCard,
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ?errorBanner,
                                const SizedBox(height: 12),
                                submitButton,
                                const SizedBox(height: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      progressHeader,
                      ?noticeBanner,
                      Expanded(
                        child: SingleChildScrollView(child: questionCard),
                      ),
                      ?errorBanner,
                      const SizedBox(height: 12),
                      submitButton,
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
