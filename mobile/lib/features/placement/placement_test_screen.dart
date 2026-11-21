import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../data/datasources/english/cefr_skeleton_data.dart';
import '../../domain/entities/question.dart';
import '../../app/providers.dart';
import '../lesson/lesson_media_widget.dart';

class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  ConsumerState<PlacementTestScreen> createState() =>
      _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen> {
  int? _selectedOption;
  bool _isConfirmingOrSubmitting = false;

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
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  String _getDifficultyLabel(QuestionDifficulty diff, bool isRu) {
    switch (diff) {
      case QuestionDifficulty.easy:
        return isRu ? 'Лёгкий' : 'Oson';
      case QuestionDifficulty.medium:
        return isRu ? 'Средний' : 'O‘rta';
      case QuestionDifficulty.hard:
        return isRu ? 'Сложный' : 'Qiyin';
    }
  }

  Future<void> _runQuickDemo() async {
    await ref.read(learnerStateNotifierProvider.notifier).seedQuickDemo();
    if (mounted) context.go('/knowledge-map');
  }

  void _load(String courseId, {bool restart = false}) {
    setState(() => _selectedOption = null);
    ref
        .read(placementStateNotifierProvider.notifier)
        .loadQuestions(courseId, restart: restart);
  }

  Future<void> _submit(PlacementState placement, bool isRu) async {
    final selected = _selectedOption;
    if (_isConfirmingOrSubmitting ||
        placement.isSubmitting ||
        selected == null) {
      return;
    }
    setState(() => _isConfirmingOrSubmitting = true);
    try {
      final isFinalQuestion =
          placement.questionNumber >= placement.totalQuestionsToAsk;
      if (isFinalQuestion) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              isRu ? 'Отправить ответы?' : 'Javoblarni topshirasizmi?',
            ),
            content: Text(
              isRu
                  ? 'После отправки последнего ответа результат будет сохранён.'
                  : 'Oxirgi javob yuborilgach, natijangiz saqlanadi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(isRu ? 'Назад' : 'Qaytish'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(isRu ? 'Отправить' : 'Topshirish'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      final notifier = ref.read(placementStateNotifierProvider.notifier);
      try {
        await notifier.submitAnswer(
          selected,
          bypassRateLimit: isFinalQuestion,
        );
        if (!mounted) return;
        final next = ref.read(placementStateNotifierProvider);
        if (next.currentQuestion?.id != placement.currentQuestion?.id ||
            next.sessionId != placement.sessionId ||
            next.result != null) {
          setState(() => _selectedOption = null);
        } else if (next.result == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  isRu
                      ? 'Подождите немного и попробуйте снова.'
                      : 'Iltimos, biroz kuting va qayta urinib ko‘ring.',
                ),
              ),
            );
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRu
                  ? 'Не удалось отправить ответ. Попробуйте ещё раз.'
                  : 'Javob yuborilmadi. Qayta urinib ko‘ring.',
            ),
            action: SnackBarAction(
              label: isRu ? 'Обновить сессию' : 'Sessiyani yuklash',
              onPressed: () => _load(placement.courseId),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirmingOrSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseState = ref.watch(courseStateNotifierProvider);
    final placementState = ref.watch(placementStateNotifierProvider);
    final activeCourse = courseState.activeCourse;
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';

    final currentQ = placementState.currentQuestion;
    final qNumber = placementState.questionNumber;
    final totalQ = placementState.totalQuestionsToAsk;
    final result = placementState.result;

    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    if (result != null) {
      final correct = result.submissions
          .where((answer) => answer.isCorrect)
          .length;
      final isEnglish = placementState.courseId == 'course_eng_01';
      final cefrTier = result.cefrLevel ?? 'Pre-A1';
      final skillNamesById = {
        for (final s in courseState.activeSkills) s.id: s.name,
      };
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(
          toolbarHeight: isLargeText ? 96 : null,
          title: Text(
            isRu ? 'Результат диагностики' : 'Diagnostika natijasi',
            softWrap: true,
            maxLines: isLargeText ? null : 1,
            overflow: isLargeText
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 36,
              color: AppColors.primaryAccentOnSurface(context),
            ),
            const SizedBox(height: 12),
            Text(
              isRu ? 'Диагностика завершена' : 'Diagnostika yakunlandi',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isRu
                  ? '$correct / ${result.submissions.length} ответов верно.'
                  : '$correct / ${result.submissions.length} javob to‘g‘ri.',
              textAlign: TextAlign.center,
            ),
            if (isEnglish) ...[
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.all(16),
                borderColor: AppColors.primary.withValues(alpha: 0.35),
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
                        Text(
                          isRu
                              ? 'Стартовый уровень: $cefrTier (${result.overallScore}%)'
                              : 'Tavsiya etilgan bosqich: $cefrTier (${result.overallScore}%)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRu
                          ? 'Уровни B2–C2 появятся на следующем этапе (DEFERRED). Сейчас доступен маршрут A1–B1.'
                          : 'B2–C2 darajalari keyingi bosqichda (DEFERRED) qo‘shiladi. Hozircha A1–B1 yo‘nalishida boshlashingiz mumkin.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isRu
                          ? 'Результат диагностики определяет стартовый маршрут и не заменяет освоение уроков. $cefrOfficialDisclaimerRu'
                          : 'Diagnostika natijasi boshlang‘ich yo‘lni ko‘rsatadi va mustaqil dars o‘zlashtirishidan alohida saqlanadi. $cefrOfficialDisclaimerUz',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textMutedColor(context),
                      ),
                    ),
                    if (result.computedScores.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final entry in result.computedScores.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      skillNamesById[entry.key] ?? entry.key,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${entry.value.score}%',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryAccentOnSurface(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (entry.value.score / 100).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  minHeight: 5,
                                  backgroundColor: AppColors.borderColor(
                                    context,
                                  ),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryAccentOnSurface(
                                          context,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              text: isRu
                  ? 'Открыть личный маршрут'
                  : 'Shaxsiy yo‘lni ko‘rish',
              onPressed: () => context.go('/roadmap'),
            ),
            if (placementState.canRetake) ...[
              const SizedBox(height: 8),
              AppButton(
                text: isRu ? 'Пройти заново' : 'Qayta topshirish',
                variant: AppButtonVariant.outline,
                onPressed: () => _load(placementState.courseId, restart: true),
              ),
            ],
            if (result.review.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                isRu ? 'Разбор ответов' : 'Javoblar tahlili',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final answer in result.review)
                ExpansionTile(
                  title: Text(answer.localizedQuestion(lang)),
                  subtitle: Text(
                    answer.submission.isCorrect
                        ? (isRu ? 'Верно' : 'To‘g‘ri')
                        : (isRu ? 'Ошибка' : 'Xato'),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRu
                          ? 'Ваш ответ — ${answer.selected}'
                          : 'Siz belgilagan javob — ${answer.selected}',
                    ),
                    if (!answer.submission.isCorrect)
                      Text(
                        isRu
                            ? 'Правильный ответ — ${answer.correct}'
                            : 'To‘g‘ri javob — ${answer.correct}',
                      ),
                    if (answer.localizedExplanation(lang).isNotEmpty)
                      Text(answer.localizedExplanation(lang)),
                  ],
                ),
            ],
          ],
        ),
      );
    }

    if (placementState.isSubmitting) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppColors.primaryAccentOnSurface(context),
              ),
              const SizedBox(height: 16),
              Text(
                isRu
                    ? 'Подсчёт результатов...'
                    : 'Natijalar hisoblanmoqda...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isRu
                    ? 'Строим карту знаний на основе ваших ответов'
                    : 'Haqiqiy javoblaringiz asosida bilim xaritasi tuzilmoqda',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textMutedColor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (currentQ == null) {
      final isLoadingQuestions = !placementState.hasLoaded;
      return Scaffold(
        backgroundColor: AppColors.bg(context),
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
                  color: AppColors.textMutedColor(context),
                ),
                const SizedBox(height: 16),
                Text(
                  isLoadingQuestions
                      ? (isRu
                            ? 'Вопросы загружаются...'
                            : 'Savollar tayyorlanmoqda...')
                      : (isRu
                            ? 'Не удалось загрузить вопросы'
                            : 'Savollarni yuklab bo‘lmadi'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isLoadingQuestions
                      ? (isRu
                            ? 'Загружаем задания для определения уровня знаний.'
                            : 'Bilim darajasini aniqlash uchun savollar yuklanmoqda.')
                      : (isRu
                            ? 'Проверьте подключение к интернету и попробуйте снова.'
                            : 'Internet aloqasini tekshirib, qayta urinib ko‘ring.'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textMutedColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (isLoadingQuestions)
                  CircularProgressIndicator(
                    color: AppColors.primaryAccentOnSurface(context),
                  )
                else ...[
                  AppButton(
                    text: isRu ? 'Повторить' : 'Qayta urinish',
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
                    text: isRu ? 'Назад' : 'Orqaga',
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

    final progress = totalQ > 0 ? qNumber / totalQ : 0.0;
    final showQuickDemo = !ref
        .watch(learnerRepositoryProvider)
        .supportsServerPlacementPersistence;
    final quickDemoButton = showQuickDemo
        ? TextButton.icon(
            onPressed: _runQuickDemo,
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: Text(
              isRu ? 'Быстрое демо' : 'Tezkor demo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        toolbarHeight: isLargeText ? 144 : null,
        title: Text(
          '${isRu ? 'Диагностика' : 'Diagnostika'} · ${activeCourse?.localizedTitle(lang) ?? ""}',
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLargeText && quickDemoButton != null) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: quickDemoButton,
                ),
                const SizedBox(height: 4),
              ],
              // Progress Bar & Counter
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      isRu
                          ? 'Вопрос $qNumber / $totalQ'
                          : 'Savol $qNumber / $totalQ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryAccentOnSurface(context),
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
                  backgroundColor: AppColors.borderColor(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryAccentOnSurface(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (placementState.notice case final notice?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(notice),
                ),

              // Question Card
              Expanded(
                child: SingleChildScrollView(
                  child: AppCard(
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint(context),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Q$qNumber',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryAccentOnSurface(
                                    context,
                                  ),
                                ),
                              ),
                            ),
                            if (placementState.sessionId == null)
                              AppBadge(
                                text: _getDifficultyLabel(
                                  currentQ.difficulty,
                                  isRu,
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
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryColor(context),
                            height: 1.35,
                          ),
                        ),
                        if (currentQ.formulaLatex != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint(context).withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              currentQ.formulaLatex!,
                              style: GoogleFonts.firaCode(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryAccentOnSurface(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (currentQ.contextSnippet != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.subtleSurface(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.borderColor(context),
                              ),
                            ),
                            child: Text(
                              currentQ.contextSnippet!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMutedColor(context),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Options
                        ...List.generate(currentQ.options.length, (idx) {
                          final optionText = currentQ.options[idx];
                          final isSelected = _selectedOption == idx;
                          final letter = idx < 26
                              ? String.fromCharCode(65 + idx)
                              : '${idx + 1}';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: isSelected
                                  ? AppColors.primaryTint(context).withValues(
                                      alpha: 0.7,
                                    )
                                  : AppColors.surfaceColor(context),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedOption = idx);
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
                                          ? AppColors.primaryAccentOnSurface(
                                              context,
                                            )
                                          : AppColors.borderColor(context),
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
                                              ? AppColors.primary
                                              : AppColors.subtleSurface(
                                                  context,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            letter,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.textMutedColor(
                                                      context,
                                                    ),
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
                                            color: AppColors.textPrimaryColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color:
                                              AppColors.primaryAccentOnSurface(
                                                context,
                                              ),
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
                text: qNumber >= totalQ
                    ? (isRu ? 'Посмотреть результаты' : 'Natijalarni Ko‘rish')
                    : (isRu ? 'Следующий вопрос' : 'Keyingi Savol'),
                isFullWidth: true,
                isLoading: placementState.isSubmitting,
                size: AppButtonSize.large,
                rightIcon: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: (_selectedOption == null ||
                        placementState.isSubmitting ||
                        _isConfirmingOrSubmitting)
                    ? null
                    : () => _submit(placementState, isRu),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
