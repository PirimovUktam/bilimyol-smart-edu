import 'package:flutter/material.dart';

class AppColors {
  // Primary & Secondary Brand Colors aligned with Web src/theme.css
  static const Color primary = Color(0xFF5546E8); // --color-brand
  static const Color primaryHover = Color(0xFF4636CB); // --color-brand-dark
  static const Color primaryLight = Color(0xFFEEF2FF);

  static const Color secondary = Color(0xFF076B82); // --color-path (WCAG AA on #E0F7FA & #F5F6FC)
  static const Color secondaryHover = Color(0xFF055466);
  static const Color secondaryLight = Color(0xFFE0F7FA);

  // Light Surface & Neutral Colors aligned with Web src/theme.css
  static const Color background = Color(0xFFF5F6FC); // --color-canvas
  static const Color surface = Color(0xFFFFFFFF); // --color-paper
  static const Color subtle = Color(0xFFEDF0FA); // --color-sand
  static const Color mutedSurface = Color(0xFFE4E8F5); // --color-muted
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardBorder = Color(0xFFD5DBEA); // --color-hairline

  // Light Text Colors (WCAG AA compliant)
  static const Color textPrimary = Color(0xFF171A2B); // --color-ink
  static const Color textSecondary = Color(0xFF344056); // --color-graphite
  static const Color textMuted = Color(0xFF52617A); // --color-slatefine (6.27:1 on #FFFFFF)
  static const Color textFaint = Color(0xFF576680); // --color-faint (5.10:1 on #EDF0FA, 5.81:1 on #FFFFFF)

  // Dark Palette Tokens aligned with Web :root[data-theme="dark"]
  static const Color darkCanvas = Color(0xFF101426);
  static const Color darkPaper = Color(0xFF1A2137);
  static const Color darkSubtle = Color(0xFF242D46);
  static const Color darkMutedSurface = Color(0xFF303B56);
  static const Color darkHairline = Color(0xFF39445E);
  static const Color darkInk = Color(0xFFEEF1FA);
  static const Color darkGraphite = Color(0xFFD3DCED);
  static const Color darkSlatefine = Color(0xFFAEBBD2);
  static const Color darkFaint = Color(0xFF9BAAC4);
  static const Color darkBrand = Color(0xFFA69AFF);
  static const Color darkBrandStrong = Color(0xFFB9AFFF);
  static const Color darkPath = Color(0xFF67D9E9);

  // Filled primary CTA colors (6.13:1 white text contrast in both modes)
  static const Color ctaPrimary = Color(0xFF5546E8);
  static const Color ctaPrimaryHover = Color(0xFF4636CB);

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFE11D48);
  static const Color errorLight = Color(0xFFFFF1F2);
  static const Color accent = Color(0xFF6366F1);

  // Coral & Sunset
  static const Color coral = Color(0xFFFF7043);
  static const Color coralLight = Color(0xFFFFF5F2);
  static const Color coralBorder = Color(0xFFFFCCBC);

  // EdTech Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF101426), Color(0xFF1E1B4B), Color(0xFF4636CB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coralGradient = LinearGradient(
    colors: [Color(0xFFFFF5F2), Color(0xFFFFEBE5), Color(0xFFFFDDD4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cyanMintGradient = LinearGradient(
    colors: [secondary, success],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Multi-Layer Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 32,
      spreadRadius: -4,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> commonBtnShadow = [
    BoxShadow(
      color: Color(0x525546E8),
      blurRadius: 20,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
  ];

  // Backward-compatible theme-aware surface & typography tokens (:2: aliases
  // mapped onto :3: dark palette so all tests and dark modules stay aligned).
  static const Color darkBackground = darkCanvas;
  static const Color darkSurface = darkPaper;
  static const Color darkSubtleSurface = darkSubtle;
  static const Color darkBorder = darkHairline;
  static const Color darkTextPrimary = darkInk;
  static const Color darkTextSecondary = darkGraphite;
  static const Color darkTextMuted = darkSlatefine;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color subtleSurface(BuildContext context) =>
      isDark(context) ? darkSubtleSurface : subtle;

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
