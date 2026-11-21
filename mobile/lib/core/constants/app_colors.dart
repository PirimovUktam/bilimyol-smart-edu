import 'package:flutter/material.dart';

class AppColors {
  // Primary & Secondary EdTech Brand Colors (M-SoftTech Style)
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryHover = Color(0xFF4338CA); // Indigo 700
  static const Color primaryLight = Color(0xFFEEF2FF); // Indigo 50

  static const Color secondary = Color(0xFF0EA5E9); // Sky Blue 500
  static const Color secondaryHover = Color(0xFF0284C7); // Sky Blue 600
  static const Color secondaryLight = Color(0xFFE0F2FE); // Sky Blue 100

  // Surface & Neutral Colors (Anti-Boring Slate 50 & Crisp White)
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0F172A); // Slate 900
  static const Color cardBorder = Color(0xCCE2E8F0); // rgba(226, 232, 240, 0.8)

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF5B6B82); // WCAG >= 4.5:1 on light surfaces

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFE11D48); // Rose 600
  static const Color errorLight = Color(0xFFFFF1F2);
  static const Color accent = Color(0xFF6366F1); // Indigo 500

  // Coral & Sunset
  static const Color coral = Color(0xFFFF7043);
  static const Color coralLight = Color(0xFFFFF5F2);
  static const Color coralBorder = Color(0xFFFFCCBC);

  // EdTech Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coralGradient = LinearGradient(
    colors: [Color(0xFFFFF5F2), Color(0xFFFFEBE5), Color(0xFFFFDDD4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cyanMintGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // EdTech Multi-Layer Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F0F172A), // rgba(15, 23, 42, 0.06)
      blurRadius: 32,
      spreadRadius: -4,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> commonBtnShadow = [
    BoxShadow(
      color: Color(0x664F46E5), // rgba(79, 70, 229, 0.4)
      blurRadius: 20,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
  ];

  // Theme-aware surface & typography tokens (Light & Dark WCAG >= 4.5:1)
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSubtleSurface = Color(0xFF0F172A);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color subtleSurface(BuildContext context) =>
      isDark(context) ? darkSubtleSurface : const Color(0xFFF1F5F9);

  static Color borderColor(BuildContext context) =>
      isDark(context) ? darkBorder : cardBorder;

  static Color textPrimaryColor(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textMutedColor(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color primaryTint(BuildContext context) =>
      isDark(context) ? const Color(0xFF312E81) : primaryLight;

  static Color successTint(BuildContext context) =>
      isDark(context) ? const Color(0xFF064E3B) : successLight;

  static Color warningTint(BuildContext context) =>
      isDark(context) ? const Color(0xFF78350F) : warningLight;

  static Color errorTint(BuildContext context) =>
      isDark(context) ? const Color(0xFF881337) : errorLight;

  static Color primaryAccentOnSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFFA5B4FC) : primary;

  static Color successTextOnTint(BuildContext context) =>
      isDark(context) ? const Color(0xFF6EE7B7) : const Color(0xFF047857);

  static Color errorTextOnTint(BuildContext context) =>
      isDark(context) ? const Color(0xFFFECDD3) : const Color(0xFFBE123C);

  static Color secondaryTextOnTint(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textMuted;
}
