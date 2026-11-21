import 'package:flutter/material.dart';
import 'app_semantic_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(AppSemanticColors.light);

  static ThemeData get darkTheme => _buildTheme(AppSemanticColors.dark);

  static ThemeData get light => lightTheme;

  static ThemeData get dark => darkTheme;

  static ThemeData _buildTheme(AppSemanticColors c) {
    final isDark = c.isDark;
    final textTheme = AppTypography.buildTextTheme(c);

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: c.brand,
            secondary: c.path,
            surface: c.paper,
            error: c.error,
            onPrimary: c.canvas,
            onSecondary: c.canvas,
            onSurface: c.ink,
            onError: c.canvas,
            outline: c.hairline,
            surfaceContainerHighest: c.subtle,
          )
        : ColorScheme.light(
            primary: c.brand,
            secondary: c.path,
            surface: c.paper,
            error: c.error,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: c.ink,
            onError: Colors.white,
            outline: c.hairline,
            surfaceContainerHighest: c.subtle,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      scaffoldBackgroundColor: c.canvas,
      colorScheme: colorScheme,
      extensions: [c],
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: c.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.hairline, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper.withValues(alpha: 0.94),
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.ink),
        titleTextStyle: AppTypography.ui(
          color: c.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.ctaPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: c.ctaPrimary.withValues(alpha: 0.35),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: AppTypography.ui(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ctaPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: AppTypography.ui(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          backgroundColor: c.paper,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: c.hairline, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: AppTypography.ui(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.subtle,
        hintStyle: AppTypography.ui(fontSize: 13.5, color: c.faint),
        labelStyle: AppTypography.ui(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: c.slatefine,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.slatefine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.slatefine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.brand, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.error, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.subtle : c.ink,
        contentTextStyle: AppTypography.ui(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.hairline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.slatefine,
        textColor: c.ink,
      ),
      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
