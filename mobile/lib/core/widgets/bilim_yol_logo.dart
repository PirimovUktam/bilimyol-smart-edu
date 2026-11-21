import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final effectiveDark = onDark || AppColors.isDark(context);
    final bilimColor = effectiveDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final yolColor = effectiveDark
        ? const Color(0xFFA5B4FC)
        : AppColors.primary;
    final badgeBg = effectiveDark
        ? const Color(0xFF312E81)
        : AppColors.primaryLight;
    final badgeBorder = effectiveDark
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.3);
    final badgeTextColor = effectiveDark
        ? const Color(0xFFC7D2FE)
        : AppColors.primary;
    final subtitleColor = effectiveDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: size * 0.48,
                        fontWeight: FontWeight.w800,
                        color: bilimColor,
                      ),
                      children: [
                        const TextSpan(text: 'Bilim'),
                        TextSpan(
                          text: 'Yo‘l',
                          style: TextStyle(color: yolColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      'SMART EDU',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w800,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (showSubtitle)
                Text(
                  'Moslashuvchan ta’lim platformasi',
                  style: GoogleFonts.plusJakartaSans(
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
