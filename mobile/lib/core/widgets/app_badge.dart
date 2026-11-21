import 'package:flutter/material.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_typography.dart';

enum AppBadgeVariant {
  blue,
  teal,
  amber,
  rose,
  emerald,
  slate,
}

class AppBadge extends StatelessWidget {
  final String text;
  final AppBadgeVariant variant;
  final Widget? icon;
  final double fontSize;

  const AppBadge({
    super.key,
    required this.text,
    this.variant = AppBadgeVariant.blue,
    this.icon,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AppBadgeVariant.blue:
        bg = c.brandSoft;
        fg = c.isDark ? c.brandStrong : c.brand;
        border = c.brand.withValues(alpha: 0.28);
        break;
      case AppBadgeVariant.teal:
        bg = c.pathSoft;
        fg = c.path;
        border = c.path.withValues(alpha: 0.28);
        break;
      case AppBadgeVariant.amber:
        bg = c.warningSoft;
        fg = c.warningText;
        border = c.warning.withValues(alpha: 0.3);
        break;
      case AppBadgeVariant.rose:
        bg = c.errorSoft;
        fg = c.errorText;
        border = c.error.withValues(alpha: 0.28);
        break;
      case AppBadgeVariant.emerald:
        bg = c.successSoft;
        fg = c.successText;
        border = c.success.withValues(alpha: 0.3);
        break;
      case AppBadgeVariant.slate:
        bg = c.subtle;
        fg = c.graphite;
        border = c.hairline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: AppTypography.ui(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
