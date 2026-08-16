import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

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
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AppBadgeVariant.blue:
        bg = AppColors.primaryLight;
        fg = AppColors.primary;
        border = AppColors.primary.withValues(alpha: 0.3);
        break;
      case AppBadgeVariant.teal:
        bg = AppColors.secondaryLight;
        fg = AppColors.secondary;
        border = AppColors.secondary.withValues(alpha: 0.3);
        break;
      case AppBadgeVariant.amber:
        bg = AppColors.warningLight;
        fg = const Color(0xFFB45309);
        border = AppColors.warning.withValues(alpha: 0.3);
        break;
      case AppBadgeVariant.rose:
        bg = AppColors.errorLight;
        fg = AppColors.error;
        border = AppColors.error.withValues(alpha: 0.3);
        break;
      case AppBadgeVariant.emerald:
        bg = AppColors.successLight;
        fg = AppColors.success;
        border = AppColors.success.withValues(alpha: 0.3);
        break;
      case AppBadgeVariant.slate:
        bg = const Color(0xFFF1F5F9);
        fg = AppColors.textSecondary;
        border = AppColors.cardBorder;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
