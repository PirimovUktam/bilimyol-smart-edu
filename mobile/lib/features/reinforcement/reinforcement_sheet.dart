import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/entities/question.dart';
import '../../domain/usecases/submit_reinforcement_use_case.dart';

class ReinforcementSheet extends StatefulWidget {
  final Question question;
  final Future<ReinforcementResult?> Function(int selectedIndex) onSubmit;
  final Future<ReinforcementResult?> Function({
    required int selectedIndex,
    String? selectedText,
    Map<String, String>? matchedPairs,
    List<String>? orderedTokens,
  })? onSubmitRich;
  final Future<ReinforcementResult?> Function({
    required int selectedIndex,
    String? selectedText,
    Map<String, String>? matchedPairs,
    List<String>? orderedTokens,
    List<String>? checkedCriteriaIds,
  })? onSubmitRichWithRubric;
  final VoidCallback onGoToDashboard;
  final String? completionActionLabel;

  const ReinforcementSheet({
    super.key,
    required this.question,
    required this.onSubmit,
    this.onSubmitRich,
    this.onSubmitRichWithRubric,
    required this.onGoToDashboard,
    this.completionActionLabel,
  });

  @override
  State<ReinforcementSheet> createState() => _ReinforcementSheetState();
}

class _ReinforcementSheetState extends State<ReinforcementSheet> {
  int? _selectedOption;
  final TextEditingController _textController = TextEditingController();
  final List<String> _selectedTokens = [];
  final Map<String, String> _matchedPairs = {};
  String? _activeMatchLeftId;
  final Set<String> _checkedRubricIds = {};
  bool _isSubmitting = false;
  ReinforcementResult? _result;
  String? _error;

  static String _optionLabel(int idx) =>
      idx < 26 ? String.fromCharCode(65 + idx) : '${idx + 1}';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
    final s =
        Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings.forCode(lang);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final q = widget.question;
    final isOrder = q.mode == QuestionMode.sentenceOrder;
    final isWordMatch = q.mode == QuestionMode.wordMatch;
    final isText = q.usesTextEvaluation;
    final isSelfAssessed = q.isSelfAssessed;
    final canSubmit = isOrder
        ? _selectedTokens.isNotEmpty
        : isWordMatch
            ? _matchedPairs.isNotEmpty
            : (isText || isSelfAssessed)
                ? _textController.text.trim().isNotEmpty
                : _selectedOption != null;
    final hasValidCorrectIdx =
        q.correctIndex >= 0 && q.correctIndex < q.options.length;
    final correctText = hasValidCorrectIdx ? q.options[q.correctIndex] : '';

    return Container(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_result == null || !_result!.isCorrect) ...[
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: c.warningSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: c.warningText,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              AppBadge(
                                text: isRu
                                    ? 'Тренировка закрепления'
                                    : s.reinforcementBadge,
                                variant: AppBadgeVariant.amber,
                              ),
                              AppBadge(
                                text: s.xpRewardBadge,
                                variant: AppBadgeVariant.emerald,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.reinforcementSubtitle,
                            style: AppTypography.ui(
                              fontSize: 12.5,
                              color: c.slatefine,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Question Card
                AppCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: c.subtle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (q.dialogueContext.isNotEmpty) ...[
                        for (final line in q.dialogueContext)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              line,
                              style: AppTypography.ui(
                                fontSize: 13,
                                color: c.graphite,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      if (q.sentenceWithError != null &&
                          q.sentenceWithError!.trim().isNotEmpty) ...[
                        Text(
                          q.sentenceWithError!,
                          style: AppTypography.ui(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: c.errorText,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (q.blankTemplate != null &&
                          q.blankTemplate!.trim().isNotEmpty) ...[
                        Text(
                          q.blankTemplate!,
                          style: AppTypography.ui(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: c.isDark ? c.brandStrong : c.brand,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        q.localizedText(lang),
                        style: AppTypography.ui(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                          height: 1.35,
                        ),
                      ),
                      if (q.formulaLatex != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.brandSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            q.formulaLatex!,
                            style: AppTypography.mono(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: c.isDark ? c.brandStrong : c.brand,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (isOrder) ...[
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 50),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.subtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.hairline),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(
                        _selectedTokens.length,
                        (i) => InputChip(
                          label: Text(_selectedTokens[i]),
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                    _selectedTokens.removeAt(i);
                                    _result = null;
                                    _error = null;
                                  }),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (List<String>.from(q.orderedTokens)..sort())
                        .map(
                          (token) => ActionChip(
                            label: Text(token),
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() {
                                      _selectedTokens.add(token);
                                      _result = null;
                                      _error = null;
                                    }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ] else if (isWordMatch) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isRu
                              ? 'Выберите пару слева и справа:'
                              : 'Chapdan so‘zni tanlang va o‘ngdagi mosini bosing:',
                          style: AppTypography.ui(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.graphite,
                          ),
                        ),
                      ),
                      if (_matchedPairs.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                    _matchedPairs.clear();
                                    _activeMatchLeftId = null;
                                    _result = null;
                                    _error = null;
                                  }),
                          child: Text(isRu ? 'Сбросить' : 'Tozalash'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...q.matchPairs.map((pair) {
                    final isActive = _activeMatchLeftId == pair.id;
                    final matchedRight = _matchedPairs[pair.id];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: _isSubmitting
                            ? null
                            : () => setState(() {
                                  _activeMatchLeftId = pair.id;
                                  _result = null;
                                  _error = null;
                                }),
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
                                      ? c.success
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
                                  color: c.successText,
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (q.matchPairs.map((p) => p.right).toList()..sort())
                        .map((rightText) {
                          final used = _matchedPairs.values.contains(rightText);
                          return ActionChip(
                            label: Text(
                              rightText,
                              style: AppTypography.ui(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                            backgroundColor: used
                                ? Color.alphaBlend(c.brandSoft, c.paper)
                                : c.paper,
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() {
                                      var targetLeftId = _activeMatchLeftId;
                                      if (targetLeftId == null) {
                                        for (final pair in q.matchPairs) {
                                          if (!_matchedPairs.containsKey(
                                            pair.id,
                                          )) {
                                            targetLeftId = pair.id;
                                            break;
                                          }
                                        }
                                        targetLeftId ??= q.matchPairs.isNotEmpty
                                            ? q.matchPairs.first.id
                                            : null;
                                      }
                                      if (targetLeftId != null) {
                                        _matchedPairs[targetLeftId] = rightText;
                                        _activeMatchLeftId = null;
                                        _result = null;
                                        _error = null;
                                      }
                                    }),
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ] else if (isSelfAssessed) ...[
                  TextField(
                    controller: _textController,
                    enabled: !_isSubmitting,
                    maxLines: 3,
                    onChanged: (_) => setState(() {
                      _result = null;
                      _error = null;
                    }),
                    decoration: InputDecoration(
                      hintText: isRu
                          ? 'Напишите ваш ответ на английском...'
                          : 'Javobingizni ingliz tilida yozing...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (q.localizedSelfAssessmentNotice(lang) != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.warningSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: c.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        q.localizedSelfAssessmentNotice(lang)!,
                        style: AppTypography.ui(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                  if (q.sampleResponse != null &&
                      q.sampleResponse!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.successSoft,
                        borderRadius: BorderRadius.circular(10),
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
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: c.successText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            q.sampleResponse!,
                            style: AppTypography.ui(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (q.rubricCriteria.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final criterion in q.rubricCriteria)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _checkedRubricIds.contains(criterion.id),
                        onChanged: (_) => setState(() {
                          if (_checkedRubricIds.contains(criterion.id)) {
                            _checkedRubricIds.remove(criterion.id);
                          } else {
                            _checkedRubricIds.add(criterion.id);
                          }
                        }),
                        title: Text(
                          criterion.localizedLabel(lang),
                          style: AppTypography.ui(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                ] else if (isText) ...[
                  TextField(
                    controller: _textController,
                    enabled: !_isSubmitting,
                    onChanged: (_) => setState(() {
                      _result = null;
                      _error = null;
                    }),
                    decoration: InputDecoration(
                      hintText: isRu ? 'Введите ответ...' : 'Javobni yozing...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  ...List.generate(q.options.length, (idx) {
                    final opt = q.options[idx];
                    final isSelected = _selectedOption == idx;
                    final wrong = _result != null && !_result!.isCorrect;
                    final isCorrectOption =
                        wrong && correctText.isNotEmpty && opt == correctText;
                    final isWrongPick =
                        wrong && isSelected && !isCorrectOption;
                    final solidSuccessBg = c.isDark ? c.success : c.successText;
                    final solidErrorBg = c.isDark ? c.error : c.errorText;
                    final solidBrandBg = c.isDark ? c.brand : c.ctaPrimary;
                    final solidFg = c.isDark ? c.canvas : Colors.white;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        child: Material(
                          color: isCorrectOption
                              ? c.successSoft
                              : isWrongPick
                                  ? c.errorSoft
                                  : isSelected
                                      ? c.brandSoft
                                      : c.paper,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _isSubmitting
                                ? null
                                : () => setState(() {
                                      _selectedOption = idx;
                                      _error = null;
                                      _result = null;
                                    }),
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCorrectOption
                                        ? c.success
                                        : isWrongPick
                                            ? c.error
                                            : isSelected
                                                ? c.brand
                                                : c.hairline,
                                    width: (isSelected ||
                                            isCorrectOption ||
                                            isWrongPick)
                                        ? 2
                                        : 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: isCorrectOption
                                            ? solidSuccessBg
                                            : isWrongPick
                                                ? solidErrorBg
                                                : isSelected
                                                    ? solidBrandBg
                                                    : c.subtle,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _optionLabel(idx),
                                          style: AppTypography.mono(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: (isSelected ||
                                                    isCorrectOption ||
                                                    isWrongPick)
                                                ? solidFg
                                                : c.graphite,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        opt,
                                        style: AppTypography.ui(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
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
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                if (_result != null && !_result!.isCorrect) ...[
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final serverCorrect = (_result?.correctOption ?? '')
                          .trim();
                      final effectiveCorrectText = correctText.isNotEmpty
                          ? correctText
                          : serverCorrect;
                      final orderCorrectText = q.correctIndex >= 0
                          ? q.orderedTokens.join(' ')
                          : serverCorrect;
                      final selectedChoiceText =
                          (q.usesOptionSelection &&
                              _selectedOption != null &&
                              _selectedOption! >= 0 &&
                              _selectedOption! < q.options.length)
                          ? q.options[_selectedOption!]
                          : '';
                      final serverExplanation = (_result?.explanation ?? '')
                          .trim();
                      final localWrongHint =
                          (q.localizedOptionFeedback(selectedChoiceText, lang) ??
                                  q.localizedWrongFeedback(lang) ??
                                  q.localizedExplanation(lang))
                              .trim();
                      final effectiveExplanation = serverExplanation.isNotEmpty
                          ? serverExplanation
                          : localWrongHint;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.errorSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: c.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (q.usesOptionSelection) ...[
                              if (_selectedOption != null &&
                                  _selectedOption! >= 0 &&
                                  _selectedOption! < q.options.length)
                                Text(
                                  s.youSelected(q.options[_selectedOption!]),
                                  style: AppTypography.ui(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.errorText,
                                  ),
                                ),
                              if (effectiveCorrectText.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  s.correctAnswerIs(effectiveCorrectText),
                                  style: AppTypography.ui(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: c.successText,
                                  ),
                                ),
                              ],
                            ] else if (isOrder &&
                                orderCorrectText.isNotEmpty) ...[
                              Text(
                                isRu
                                    ? 'Правильный порядок: $orderCorrectText'
                                    : 'To‘g‘ri tartib: $orderCorrectText',
                                style: AppTypography.ui(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: c.successText,
                                ),
                              ),
                            ] else if ((isText || isWordMatch) &&
                                serverCorrect.isNotEmpty) ...[
                              Text(
                                s.correctAnswerIs(serverCorrect),
                                style: AppTypography.ui(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: c.successText,
                                ),
                              ),
                            ],
                            if (effectiveExplanation.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                effectiveExplanation,
                                style: AppTypography.ui(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: c.graphite,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),

                AppButton(
                  text: s.checkAnswerBtn,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  isLoading: _isSubmitting,
                  onPressed: !canSubmit
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          ReinforcementResult? res;
                          try {
                            if (widget.onSubmitRichWithRubric != null) {
                              res = await widget.onSubmitRichWithRubric!(
                                selectedIndex: _selectedOption ?? 0,
                                selectedText: (isText || isSelfAssessed)
                                    ? _textController.text.trim()
                                    : null,
                                matchedPairs: isWordMatch
                                    ? Map<String, String>.from(_matchedPairs)
                                    : null,
                                orderedTokens: isOrder ? _selectedTokens : null,
                                checkedCriteriaIds: isSelfAssessed
                                    ? (_checkedRubricIds.toList()..sort())
                                    : null,
                              );
                            } else if (widget.onSubmitRich != null) {
                              res = await widget.onSubmitRich!(
                                selectedIndex: _selectedOption ?? 0,
                                selectedText: (isText || isSelfAssessed)
                                    ? _textController.text.trim()
                                    : null,
                                matchedPairs: isWordMatch
                                    ? Map<String, String>.from(_matchedPairs)
                                    : null,
                                orderedTokens: isOrder ? _selectedTokens : null,
                              );
                            } else {
                              res = await widget.onSubmit(_selectedOption ?? 0);
                            }
                          } catch (_) {
                            if (!mounted) return;
                            setState(() {
                              _isSubmitting = false;
                              _error = s.reinforcementSaveFailed;
                            });
                            return;
                          }
                          if (!mounted) return;
                          if (res?.isCorrect == true) {
                            HapticFeedback.mediumImpact();
                          } else {
                            HapticFeedback.heavyImpact();
                          }
                          setState(() {
                            _isSubmitting = false;
                            _result = res;
                            _error = res == null ? s.reinforcementLoadFailed : null;
                          });
                        },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: AppTypography.ui(
                        color: c.errorText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // SUCCESS CELEBRATION VIEW
                TweenAnimationBuilder<double>(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  tween: Tween(
                    begin: disableAnimations ? 1.0 : 0.75,
                    end: 1.0,
                  ),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: c.successSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.success, width: 2),
                      ),
                      child: Icon(
                        Icons.celebration_rounded,
                        color: c.successText,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    s.greatResultTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    s.reinforcementSuccessBody,
                    style: AppTypography.ui(
                      fontSize: 13,
                      color: c.slatefine,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 18),

                // Score Boost Card
                AppCard(
                  backgroundColor: c.subtle,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isRu ? 'Прежний балл' : s.oldScoreLabel,
                                style: AppTypography.ui(
                                  fontSize: 11.5,
                                  color: c.slatefine,
                                ),
                              ),
                              Text(
                                '${_result!.oldScore}%',
                                style: AppTypography.mono(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: c.errorText,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: c.path,
                            size: 24,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isRu ? 'Новый балл' : s.newScoreLabel,
                                style: AppTypography.ui(
                                  fontSize: 11.5,
                                  color: c.slatefine,
                                ),
                              ),
                              Text(
                                '${_result!.newScore}%',
                                style: AppTypography.mono(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: c.successText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: c.warningSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: c.warningText,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                s.xpAddedBadge(_result!.xpAwarded),
                                style: AppTypography.mono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.warningText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AppCard(
                  backgroundColor: c.brandSoft,
                  borderColor: c.brand.withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_open_rounded,
                        color: c.isDark ? c.brandStrong : c.brand,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.nextTopicUnlockedMsg,
                          style: AppTypography.ui(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.isDark ? c.brandStrong : c.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                AppButton(
                  text:
                      widget.completionActionLabel ??
                      (isRu ? 'Перейти на главную' : s.goToDashboardBtn),
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  rightIcon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  onPressed: widget.onGoToDashboard,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
