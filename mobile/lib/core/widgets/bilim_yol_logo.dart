import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../l10n/app_strings.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_typography.dart';

class BilimYolLogo extends StatelessWidget {
  final double size;
  final bool showSubtitle;
  final bool onDark;

  const BilimYolLogo({
    super.key,
    this.size = 36,
    this.showSubtitle = true,
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
    final primaryText = onDark ? AppColors.darkInk : c.ink;
    final accentColor = onDark ? AppColors.darkBrand : c.brand;
    final tagBg = onDark ? AppColors.darkSubtle : c.brandSoft;
    final subtitleColor = onDark ? AppColors.darkSlatefine : c.slatefine;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.35),
            gradient: const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.accent,
                AppColors.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: size * 0.58,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      style: AppTypography.ui(
                        fontSize: size * 0.48,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                      children: [
                        const TextSpan(text: 'Bilim'),
                        TextSpan(
                          text: 'Yöl',
                          style: TextStyle(color: accentColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      s.brandTag,
                      style: AppTypography.ui(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (showSubtitle)
                Text(
                  s.brandSubtitle,
                  style: AppTypography.ui(
                    fontSize: size * 0.26,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
