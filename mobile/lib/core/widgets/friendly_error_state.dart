import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../l10n/app_strings.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class FriendlyErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final bool onDark;

  const FriendlyErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.onDark = false,
  });

  static AppStrings _resolveStrings(BuildContext context) {
    final localized = Localizations.of<AppStrings>(context, AppStrings);
    if (localized != null) return localized;
    final appLang = Localizations.maybeLocaleOf(context)?.languageCode;
    if (appLang == 'ru') return AppStrings.ru;
    if (appLang == 'uz') return AppStrings.uz;
    return WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ru'
        ? AppStrings.ru
        : AppStrings.uz;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final titleColor = onDark ? AppColors.darkInk : c.ink;
    final subColor = onDark ? AppColors.darkSlatefine : c.slatefine;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: subColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message ?? s.errorTitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.errorSubtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(
                        color: subColor,
                        fontSize: 12,
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 16),
                      AppButton(
                        text: s.retry,
                        leftIcon: const Icon(
                          Icons.refresh_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        onPressed: onRetry,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
