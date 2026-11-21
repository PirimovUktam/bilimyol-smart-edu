import 'package:flutter/material.dart';
import 'app_semantic_colors.dart';

/// Offline-safe typography helper with system font fallbacks.
///
/// Never makes runtime HTTP calls to `fonts.gstatic.com`.
class AppTypography {
  static const List<String> uiFontFallback = [
    'Plus Jakarta Sans',
    'Roboto',
    'Segoe UI',
    'sans-serif',
  ];

  static const List<String> monoFontFallback = [
    'JetBrains Mono',
    'Fira Code',
    'Roboto Mono',
    'monospace',
  ];

  static TextStyle ui({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontFamilyFallback: uiFontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
      fontFeatures: fontFeatures,
    );
  }

  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: monoFontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextTheme buildTextTheme(AppSemanticColors c) {
    return TextTheme(
      displayLarge: ui(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: c.ink,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      displayMedium: ui(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: c.ink,
        letterSpacing: -0.5,
        height: 1.18,
      ),
      headlineLarge: ui(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: c.ink,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      headlineMedium: ui(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: c.ink,
        letterSpacing: -0.3,
        height: 1.22,
      ),
      headlineSmall: ui(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: c.ink,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      titleLarge: ui(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: c.ink,
        height: 1.3,
      ),
      titleMedium: ui(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: c.ink,
        height: 1.35,
      ),
      titleSmall: ui(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: c.ink,
        height: 1.35,
      ),
      bodyLarge: ui(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: c.graphite,
        height: 1.45,
      ),
      bodyMedium: ui(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: c.graphite,
        height: 1.45,
      ),
      bodySmall: ui(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: c.slatefine,
        height: 1.4,
      ),
      labelLarge: ui(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
      labelMedium: ui(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: c.slatefine,
      ),
      labelSmall: ui(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c.faint,
      ),
    );
  }
}
