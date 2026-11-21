import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
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
  final VoidCallback onGoToDashboard;

  const ReinforcementSheet({
    super.key,
    required this.question,
    required this.onSubmit,
    this.onSubmitRich,
    required this.onGoToDashboard,
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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _resolveLang(BuildContext context) {
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  @override
  Widget build(BuildContext context) {
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
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
    final hasValidCorrectIndex =
        q.correctIndex >= 0 && q.correctIndex < q.options.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
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
                    color: AppColors.borderColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_result == null || !_result!.isCorrect) ...[
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warningTint(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: AppColors.isDark(context)
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFB45309),
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
                                    : 'Mustahkamlash Mashqi',
                                variant: AppBadgeVariant.amber,
                              ),
                              AppBadge(
                                text: isRu ? 'Награда XP' : 'XP mukofoti',
                                variant: AppBadgeVariant.emerald,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRu
                                ? 'Проверьте свои знания на практике'
                                : 'Bilimingizni amalda sinab ko‘ring',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textMutedColor(context),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (q.dialogueContext.isNotEmpty) ...[
                        for (final line in q.dialogueContext)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              line,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textSecondaryColor(context),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      if (q.sentenceWithError != null &&
                          q.sentenceWithError!.trim().isNotEmpty) ...[
                        Text(
                          q.sentenceWithError!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.isDark(context)
                                ? const Color(0xFFFDA4AF)
                                : const Color(0xFFBE123C),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (q.blankTemplate != null &&
                          q.blankTemplate!.trim().isNotEmpty) ...[
                        Text(
                          q.blankTemplate!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryAccentOnSurface(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        q.localizedText(lang),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryColor(context),
                          height: 1.35,
                        ),
                      ),
                      if (q.formulaLatex != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            q.formulaLatex!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryAccentOnSurface(context),
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
                      color: AppColors.subtleSurface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor(context)),
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
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryColor(context),
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
                                ? AppColors.primaryTint(context)
                                : matchedRight != null
                                ? AppColors.successTint(context)
                                : AppColors.subtleSurface(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primaryAccentOnSurface(context)
                                  : matchedRight != null
                                  ? AppColors.successTextOnTint(context)
                                  : AppColors.borderColor(context),
                              width: isActive ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pair.left,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryColor(context),
                                  ),
                                ),
                              ),
                              if (matchedRight != null) ...[
                                const Icon(Icons.arrow_forward_rounded, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    matchedRight,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.successTextOnTint(
                                        context,
                                      ),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                            backgroundColor: used
                                ? AppColors.primaryTint(context)
                                : AppColors.surfaceColor(context),
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
                        color: AppColors.warningTint(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        q.localizedSelfAssessmentNotice(lang)!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
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
                        color: AppColors.successTint(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRu ? 'Пример ответа:' : 'Namuna javob:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.successTextOnTint(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            q.sampleResponse!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (q.rubricCriteria.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final c in q.rubricCriteria)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _checkedRubricIds.contains(c.id),
                        onChanged: (_) => setState(() {
                          if (_checkedRubricIds.contains(c.id)) {
                            _checkedRubricIds.remove(c.id);
                          } else {
                            _checkedRubricIds.add(c.id);
                          }
                        }),
                        title: Text(
                          c.localizedLabel(lang),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryColor(context),
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
                    final correctText = hasValidCorrectIndex
                        ? q.options[q.correctIndex]
                        : '';
                    final isCorrectOption =
                        wrong && correctText.isNotEmpty && opt == correctText;
                    final isWrongPick =
                        wrong && isSelected && !isCorrectOption;
                    final letter = idx < 26
                        ? String.fromCharCode(65 + idx)
                        : '${idx + 1}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isCorrectOption
                            ? AppColors.successTint(context)
                            : isWrongPick
                            ? AppColors.errorTint(context)
                            : isSelected
                            ? AppColors.primaryTint(context)
                            : AppColors.surfaceColor(context),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCorrectOption
                                    ? AppColors.successTextOnTint(context)
                                    : isWrongPick
                                    ? AppColors.errorTextOnTint(context)
                                    : isSelected
                                    ? AppColors.primaryAccentOnSurface(context)
                                    : AppColors.borderColor(context),
                                width:
                                    (isSelected ||
                                        isCorrectOption ||
                                        isWrongPick)
                                    ? 2
                                    : 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isCorrectOption
                                        ? const Color(0xFF047857)
                                        : isWrongPick
                                        ? AppColors.error
                                        : isSelected
                                        ? AppColors.primary
                                        : AppColors.subtleSurface(context),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            (isSelected ||
                                                isCorrectOption ||
                                                isWrongPick)
                                            ? Colors.white
                                            : AppColors.textMutedColor(
                                                context,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isCorrectOption)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.successTextOnTint(context),
                                    size: 20,
                                  )
                                else if (isWrongPick)
                                  Icon(
                                    Icons.cancel_rounded,
                                    color: AppColors.errorTextOnTint(context),
                                    size: 20,
                                  )
                                else if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryAccentOnSurface(
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
                if (_result != null && !_result!.isCorrect) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorTint(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.35),
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
                              isRu
                                  ? 'Вы выбрали: ${q.options[_selectedOption!]}'
                                  : 'Siz tanladingiz: ${q.options[_selectedOption!]}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.errorTextOnTint(context),
                              ),
                            ),
                          if (hasValidCorrectIndex) ...[
                            const SizedBox(height: 3),
                            Text(
                              isRu
                                  ? 'Правильный ответ: ${q.options[q.correctIndex]}'
                                  : 'To‘g‘ri javob: ${q.options[q.correctIndex]}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.successTextOnTint(context),
                              ),
                            ),
                          ],
                        ] else if (isOrder) ...[
                          Text(
                            isRu
                                ? 'Правильный порядок: ${q.orderedTokens.join(' ')}'
                                : 'To‘g‘ri tartib: ${q.orderedTokens.join(' ')}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.successTextOnTint(context),
                            ),
                          ),
                        ],
                        if (q.localizedExplanation(lang).trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            q.localizedExplanation(lang),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.secondaryTextOnTint(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                AppButton(
                  text: isRu ? 'Проверить ответ' : 'Javobni Tekshirish',
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  isLoading: _isSubmitting,
                  onPressed: !canSubmit
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          ReinforcementResult? res;
                          try {
                            if (widget.onSubmitRich != null) {
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
                              _error = isRu
                                  ? 'Не удалось сохранить результат. Проверьте интернет и попробуйте снова.'
                                  : 'Natijani saqlab bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.';
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
                            _error = res == null
                                ? (isRu
                                      ? 'Не удалось получить результат. Попробуйте снова.'
                                      : 'Natijani olishning imkoni bo‘lmadi. Qayta urinib ko‘ring.')
                                : null;
                          });
                        },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.errorTextOnTint(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ] else ...[
                // SUCCESS CELEBRATION MODAL VIEW
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  tween: Tween(begin: 0.7, end: 1.0),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.successTint(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.successTextOnTint(context),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.celebration_rounded,
                        color: AppColors.successTextOnTint(context),
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    isRu ? 'Отличный результат!' : 'Ajoyib Natija!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    isRu
                        ? 'Тема успешно закреплена, балл знаний повышен.'
                        : 'Tushuncha muvaffaqiyatli o‘zlashtirildi va bilim bali oshdi.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondaryColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 18),

                // Score Boost Animation Card
                AppCard(
                  backgroundColor: AppColors.surfaceDark,
                  borderColor: const Color(0xFF334155),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          Column(
                            children: [
                              Text(
                                isRu ? 'Прежний балл' : 'Eski Bal',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                '${_result!.oldScore}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF38BDF8),
                            size: 24,
                          ),
                          Column(
                            children: [
                              Text(
                                isRu ? 'Новый балл' : 'Yangi Bal',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                '${_result!.newScore}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
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
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isRu
                                    ? '+${_result!.xpAwarded} XP добавлено в награду!'
                                    : '+${_result!.xpAwarded} XP mukofoti qo‘shildi!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFBBF24),
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

                // Unlocked route notification
                AppCard(
                  backgroundColor: AppColors.primaryTint(context),
                  borderColor: AppColors.primary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_open_rounded,
                        color: AppColors.primaryAccentOnSurface(context),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isRu
                              ? 'Следующая тема разблокирована в учебном маршруте!'
                              : 'Navbatdagi mavzu yo‘l xaritasida blokdan ochildi!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryAccentOnSurface(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                AppButton(
                  text: isRu ? 'Перейти на главную' : 'Dashboardga O‘tish',
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
