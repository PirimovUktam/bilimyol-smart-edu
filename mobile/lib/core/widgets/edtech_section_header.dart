import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class EdTechSectionHeader extends StatelessWidget {
  final String title;
  final String? highlightWord;
  final String? pillText;
  final String? subtitle;
  final IconData? pillIcon;
  final Widget? trailing;

  const EdTechSectionHeader({
    super.key,
    required this.title,
    this.highlightWord,
    this.pillText,
    this.subtitle,
    this.pillIcon = Icons.auto_awesome_rounded,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    String before = trimmed;
    String accent = '';
    String after = '';

    if (highlightWord != null &&
        highlightWord!.isNotEmpty &&
        trimmed.contains(highlightWord!)) {
      final idx = trimmed.indexOf(highlightWord!);
      before = trimmed.substring(0, idx);
      accent = highlightWord!;
      after = trimmed.substring(idx + highlightWord!.length);
    } else {
      final lastSpace = trimmed.lastIndexOf(' ');
      if (lastSpace > 0) {
        before = trimmed.substring(0, lastSpace + 1);
        accent = trimmed.substring(lastSpace + 1);
      } else {
        before = '';
        accent = trimmed;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pillText != null && pillText!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pillIcon != null) ...[
                  Icon(pillIcon, size: 13, color: AppColors.primary),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    pillText!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                  children: [
                    if (before.isNotEmpty) TextSpan(text: before),
                    if (accent.isNotEmpty)
                      TextSpan(
                        text: accent,
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    if (after.isNotEmpty) TextSpan(text: after),
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

