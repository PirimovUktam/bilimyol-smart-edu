import 'package:flutter/material.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_typography.dart';

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
    final c = AppSemanticColors.of(context);
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

    final titleWidget = Text.rich(
      TextSpan(
        style: AppTypography.ui(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: c.ink,
          height: 1.2,
          letterSpacing: -0.4,
        ),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          if (accent.isNotEmpty)
            TextSpan(
              text: accent,
              style: TextStyle(color: c.brand),
            ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pillText != null && pillText!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pillIcon != null) ...[
                  Icon(pillIcon, size: 13, color: c.brand),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    pillText!,
                    style: AppTypography.ui(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (trailing == null)
          titleWidget
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final stackVertically =
                  textScale >= 1.25 || constraints.maxWidth < 320;
              if (stackVertically) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget,
                    const SizedBox(height: 10),
                    trailing!,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: titleWidget),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (constraints.maxWidth - 12) * 0.52,
                    ),
                    child: trailing!,
                  ),
                ],
              );
            },
          ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: AppTypography.ui(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: c.graphite,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}
