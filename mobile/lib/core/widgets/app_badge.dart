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
    final dark = AppColors.isDark(context);
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AppBadgeVariant.blue:
        bg = AppColors.primary.withValues(alpha: dark ? 0.24 : 0.1);
        fg = dark ? const Color(0xFFC7D2FE) : AppColors.primary;
        border = AppColors.primary.withValues(alpha: dark ? 0.4 : 0.22);
        break;
      case AppBadgeVariant.teal:
        bg = dark ? const Color(0xFF0C4A6E) : AppColors.secondaryLight;
        fg = dark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1);
        border = AppColors.secondary.withValues(alpha: dark ? 0.45 : 0.25);
        break;
      case AppBadgeVariant.amber:
        bg = dark ? const Color(0xFF78350F) : AppColors.warningLight;
        fg = dark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
        border = AppColors.warning.withValues(alpha: dark ? 0.5 : 0.28);
        break;
      case AppBadgeVariant.rose:
        bg = dark ? const Color(0xFF881337) : AppColors.errorLight;
        fg = dark ? const Color(0xFFFECDD3) : const Color(0xFFBE123C);
        border = AppColors.error.withValues(alpha: dark ? 0.5 : 0.25);
        break;
      case AppBadgeVariant.emerald:
        bg = dark ? const Color(0xFF064E3B) : AppColors.successLight;
        fg = dark ? const Color(0xFFA7F3D0) : const Color(0xFF047857);
        border = AppColors.success.withValues(alpha: dark ? 0.5 : 0.28);
        break;
      case AppBadgeVariant.slate:
        bg = AppColors.subtleSurface(context);
        fg = dark ? AppColors.darkTextSecondary : const Color(0xFF475569);
        border = AppColors.borderColor(context);
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
              softWrap: true,
              style: GoogleFonts.plusJakartaSans(
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
