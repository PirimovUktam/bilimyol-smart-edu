import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../data/services/i_ai_tutor_service.dart';

class YolchiAiSheet extends StatefulWidget {
  final Future<AIExplanationResponse> Function() loadExplanation;
  final VoidCallback onStartReinforcement;

  const YolchiAiSheet({
    super.key,
    required this.loadExplanation,
    required this.onStartReinforcement,
  });

  @override
  State<YolchiAiSheet> createState() => _YolchiAiSheetState();
}

class _YolchiAiSheetState extends State<YolchiAiSheet> {
  late Future<AIExplanationResponse> _request;

  @override
  void initState() {
    super.initState();
    _request = widget.loadExplanation()..ignore();
  }

  static AppStrings _resolveStrings(BuildContext context) {
    final registered = Localizations.of<AppStrings>(context, AppStrings);
    if (registered != null) return registered;
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    return isRu ? AppStrings.ru : AppStrings.uz;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const YolchiAIMascot(
                      size: 40,
                      mood: YolchiMood.explaining,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.yolchiMistakeAnalysisTitle,
                        style: AppTypography.ui(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<AIExplanationResponse>(
                  future: _request,
                  builder: (context, snapshot) {
                    final explanation = snapshot.data;
                    if (snapshot.connectionState != ConnectionState.done) {
                      return AppCard(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: c.subtle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.yolchiAnalyzingLabel,
                              style: AppTypography.ui(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.slatefine,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                semanticsLabel: s.yolchiAnalyzingLabel,
                                color: c.brand,
                                backgroundColor: c.hairline,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (explanation == null) {
                      return AppCard(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: c.errorSoft,
                        borderColor: c.error.withValues(alpha: 0.3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.yolchiExplanationLoadFailed,
                              style: AppTypography.ui(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.errorText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _request = widget.loadExplanation()..ignore();
                                });
                              },
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(s.retry),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: c.subtle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppBadge(
                                text: explanation.isDeterministicFallback
                                    ? s.yolchiReadyExplanation
                                    : s.yolchiAiExplanation,
                                variant: AppBadgeVariant.blue,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                explanation.title,
                                style: AppTypography.ui(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: c.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                explanation.explanation,
                                style: AppTypography.ui(
                                  fontSize: 13.5,
                                  color: c.graphite,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (explanation.remediationStep.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          AppCard(
                            padding: const EdgeInsets.all(14),
                            backgroundColor: c.pathSoft,
                            borderColor: c.path.withValues(alpha: 0.3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lightbulb_rounded,
                                  size: 18,
                                  color: c.path,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.nextStep,
                                        style: AppTypography.ui(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: c.path,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        explanation.remediationStep,
                                        style: AppTypography.ui(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: c.ink,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (explanation.suggestedAction.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          AppCard(
                            padding: const EdgeInsets.all(14),
                            backgroundColor: c.subtle,
                            child: Text(
                              explanation.suggestedAction,
                              style: AppTypography.ui(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.graphite,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                AppButton(
                  text: s.reinforceTopicBtn,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  onPressed: widget.onStartReinforcement,
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: c.slatefine,
                  ),
                  child: Text(s.backToLesson),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
