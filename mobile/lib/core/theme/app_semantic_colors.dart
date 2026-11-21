import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Brightness brightness;
  final Color canvas;
  final Color paper;
  final Color subtle;
  final Color mutedSurface;
  final Color hairline;
  final Color ink;
  final Color graphite;
  final Color slatefine;
  final Color faint;
  final Color brand;
  final Color brandStrong;
  final Color brandSoft;
  final Color path;
  final Color pathSoft;
  final Color success;
  final Color successText;
  final Color successSoft;
  final Color warning;
  final Color warningText;
  final Color warningSoft;
  final Color error;
  final Color errorText;
  final Color errorSoft;
  final Color ctaPrimary;
  final Color ctaPrimaryHover;
  final List<BoxShadow> cardShadow;
  final LinearGradient heroGradient;

  const AppSemanticColors({
    required this.brightness,
    required this.canvas,
    required this.paper,
    required this.subtle,
    required this.mutedSurface,
    required this.hairline,
    required this.ink,
    required this.graphite,
    required this.slatefine,
    required this.faint,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.path,
    required this.pathSoft,
    required this.success,
    required this.successText,
    required this.successSoft,
    required this.warning,
    required this.warningText,
    required this.warningSoft,
    required this.error,
    required this.errorText,
    required this.errorSoft,
    required this.ctaPrimary,
    required this.ctaPrimaryHover,
    required this.cardShadow,
    required this.heroGradient,
  });

  bool get isDark => brightness == Brightness.dark;

  static const AppSemanticColors light = AppSemanticColors(
    brightness: Brightness.light,
    canvas: AppColors.background,
    paper: AppColors.surface,
    subtle: AppColors.subtle,
    mutedSurface: AppColors.mutedSurface,
    hairline: AppColors.cardBorder,
    ink: AppColors.textPrimary,
    graphite: AppColors.textSecondary,
    slatefine: AppColors.textMuted,
    faint: AppColors.textFaint,
    brand: AppColors.primary,
    brandStrong: AppColors.primaryHover,
    brandSoft: Color(0x1A5546E8),
    path: AppColors.secondary,
    pathSoft: AppColors.secondaryLight,
    success: AppColors.success,
    successText: Color(0xFF047857),
    successSoft: AppColors.successLight,
    warning: AppColors.warning,
    warningText: Color(0xFFB45309),
    warningSoft: AppColors.warningLight,
    error: AppColors.error,
    errorText: Color(0xFFBE123C),
    errorSoft: AppColors.errorLight,
    ctaPrimary: AppColors.ctaPrimary,
    ctaPrimaryHover: AppColors.ctaPrimaryHover,
    cardShadow: AppColors.cardShadow,
    heroGradient: AppColors.heroGradient,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    brightness: Brightness.dark,
    canvas: AppColors.darkCanvas,
    paper: AppColors.darkPaper,
    subtle: AppColors.darkSubtle,
    mutedSurface: AppColors.darkMutedSurface,
    hairline: AppColors.darkHairline,
    ink: AppColors.darkInk,
    graphite: AppColors.darkGraphite,
    slatefine: AppColors.darkSlatefine,
    faint: AppColors.darkFaint,
    brand: AppColors.darkBrand,
    brandStrong: AppColors.darkBrandStrong,
    brandSoft: Color(0x2EA69AFF),
    path: AppColors.darkPath,
    pathSoft: Color(0x2967D9E9),
    success: Color(0xFF34D399),
    successText: Color(0xFF6EE7B7),
    successSoft: Color(0x2610B981),
    warning: Color(0xFFFBBF24),
    warningText: Color(0xFFFDE68A),
    warningSoft: Color(0x26F59E0B),
    error: Color(0xFFFB7185),
    errorText: Color(0xFFFDA4AF),
    errorSoft: Color(0x26E11D48),
    ctaPrimary: AppColors.ctaPrimary,
    ctaPrimaryHover: AppColors.ctaPrimaryHover,
    cardShadow: [
      BoxShadow(
        color: Color(0x4D020617),
        blurRadius: 28,
        spreadRadius: -4,
        offset: Offset(0, 12),
      ),
    ],
    heroGradient: LinearGradient(
      colors: [Color(0xFF1A2137), Color(0xFF282068), Color(0xFF4636CB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>() ?? light;
  }

  @override
  AppSemanticColors copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? paper,
    Color? subtle,
    Color? mutedSurface,
    Color? hairline,
    Color? ink,
    Color? graphite,
    Color? slatefine,
    Color? faint,
    Color? brand,
    Color? brandStrong,
    Color? brandSoft,
    Color? path,
    Color? pathSoft,
    Color? success,
    Color? successText,
    Color? successSoft,
    Color? warning,
    Color? warningText,
    Color? warningSoft,
    Color? error,
    Color? errorText,
    Color? errorSoft,
    Color? ctaPrimary,
    Color? ctaPrimaryHover,
    List<BoxShadow>? cardShadow,
    LinearGradient? heroGradient,
  }) {
    return AppSemanticColors(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      paper: paper ?? this.paper,
      subtle: subtle ?? this.subtle,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      graphite: graphite ?? this.graphite,
      slatefine: slatefine ?? this.slatefine,
      faint: faint ?? this.faint,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandSoft: brandSoft ?? this.brandSoft,
      path: path ?? this.path,
      pathSoft: pathSoft ?? this.pathSoft,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      warningSoft: warningSoft ?? this.warningSoft,
      error: error ?? this.error,
      errorText: errorText ?? this.errorText,
      errorSoft: errorSoft ?? this.errorSoft,
      ctaPrimary: ctaPrimary ?? this.ctaPrimary,
      ctaPrimaryHover: ctaPrimaryHover ?? this.ctaPrimaryHover,
      cardShadow: cardShadow ?? this.cardShadow,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      graphite: Color.lerp(graphite, other.graphite, t)!,
      slatefine: Color.lerp(slatefine, other.slatefine, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      path: Color.lerp(path, other.path, t)!,
      pathSoft: Color.lerp(pathSoft, other.pathSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      ctaPrimary: Color.lerp(ctaPrimary, other.ctaPrimary, t)!,
      ctaPrimaryHover: Color.lerp(ctaPrimaryHover, other.ctaPrimaryHover, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
    );
  }
}
