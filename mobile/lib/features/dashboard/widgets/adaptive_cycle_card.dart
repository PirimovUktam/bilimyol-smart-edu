import 'package:flutter/material.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/personalization/adaptive_cycle_engine.dart';

class AdaptiveCycleCard extends StatelessWidget {
  final AdaptiveCycleSnapshot cycle;
  final List<ExplainableFactor> factors;
  final List<DailyMicroTask> dailyTasks;
  final String localeCode;
  final ValueChanged<AdaptiveStepKey> onStepAction;

  const AdaptiveCycleCard({
    super.key,
    required this.cycle,
    required this.factors,
    required this.dailyTasks,
    required this.localeCode,
    required this.onStepAction,
  });

  String _stepTitle(AdaptiveStepKey key, bool isRu) => switch (key) {
    AdaptiveStepKey.diagnostic => isRu ? 'Диагностика' : 'Diagnostika',
    AdaptiveStepKey.profile => isRu ? 'Профиль навыков' : 'Bilim profili',
    AdaptiveStepKey.path => isRu ? 'Личный путь' : 'Moslashuvchan reja',
    AdaptiveStepKey.practice => isRu ? 'Практика' : 'Maqsadli mashq',
    AdaptiveStepKey.progress => isRu ? 'Динамика' : 'Natija tahlili',
  };

  IconData _factorIcon(ExplainableFactorKey key) => switch (key) {
    ExplainableFactorKey.goal => Icons.flag_rounded,
    ExplainableFactorKey.skillProfile => Icons.explore_rounded,
    ExplainableFactorKey.knowledgeLevel => Icons.speed_rounded,
    ExplainableFactorKey.errorPattern => Icons.tune_rounded,
    ExplainableFactorKey.learningSpeed => Icons.bolt_rounded,
    ExplainableFactorKey.dailyTime => Icons.schedule_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final isRu = localeCode == 'ru';
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.autorenew_rounded,
                      size: 14,
                      color: c.isDark ? c.brandStrong : c.brand,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isRu ? '5-шаговый адаптивный цикл' : '5 bosqichli adaptiv sikl',
                        style: AppTypography.ui(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.isDark ? c.brandStrong : c.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge(
                text: '0${cycle.activeStep}/05',
                variant: AppBadgeVariant.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isRu
                ? 'Персональная траектория и Explainable AI'
                : 'Shaxsiy ta’lim sikli va Explainable AI',
            style: AppTypography.ui(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: c.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn =
                  constraints.maxWidth >= 320 && textScale < 1.45;
              final tileWidth = twoColumn
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cycle.steps.map((step) {
                  final isActive = step.status == AdaptiveStepStatus.active;
                  final isDone = step.status == AdaptiveStepStatus.completed;
                  final statusText = isActive
                      ? (isRu ? 'Активно' : 'Faol')
                      : isDone
                      ? (isRu ? 'Готово' : 'Bajarildi')
                      : (isRu ? 'Далее' : 'Keyingi');
                  final borderColor = isActive
                      ? c.ctaPrimary
                      : isDone
                      ? c.success.withValues(alpha: 0.45)
                      : c.hairline;
                  final bgColor = isActive
                      ? c.brandSoft
                      : isDone
                      ? c.successSoft
                      : c.subtle;

                  return SizedBox(
                    width: step.step == 5 && twoColumn
                        ? constraints.maxWidth
                        : tileWidth,
                    child: Semantics(
                      button: true,
                      selected: isActive,
                      label:
                          '${step.code} ${_stepTitle(step.key, isRu)} — $statusText',
                      child: InkWell(
                        onTap: () => onStepAction(step.key),
                        borderRadius: BorderRadius.circular(14),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? c.success
                                            : c.ctaPrimary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        step.code,
                                        style: AppTypography.mono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      statusText,
                                      style: AppTypography.ui(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isActive
                                            ? (c.isDark ? c.brandStrong : c.brand)
                                            : isDone
                                            ? c.successText
                                            : c.slatefine,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _stepTitle(step.key, isRu),
                                  style: AppTypography.ui(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: c.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  step.metricLabel,
                                  maxLines: textScale > 1.35 ? 3 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.mono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: c.graphite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.subtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: c.isDark ? c.brandStrong : c.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cycle.loopUpdateSummary,
                    style: AppTypography.ui(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.graphite,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (factors.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: c.hairline, height: 1),
            const SizedBox(height: 12),
            Text(
              isRu
                  ? '6 факторов персонализации (XAI)'
                  : '6 ta shaxsiylashtirish omili (XAI)',
              style: AppTypography.ui(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: factors.map((factor) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.subtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        factor.key == ExplainableFactorKey.errorPattern
                            ? Icons.tune_rounded
                            : _factorIcon(factor.key),
                        size: 15,
                        color: c.isDark ? c.brandStrong : c.brand,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${factor.label}: ${factor.value}',
                          style: AppTypography.ui(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
          ],

          if (dailyTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              isRu ? 'План микро-шагов на сегодня' : 'Bugungi mikro-vazifalar',
              style: AppTypography.ui(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final task in dailyTasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: c.subtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: AppTypography.ui(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isRu ? '${task.minutes} мин' : '${task.minutes} daq',
                        style: AppTypography.mono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.isDark ? c.brandStrong : c.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
