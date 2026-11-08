import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.leftIcon,
    this.rightIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;
    Gradient? gradient;
    List<BoxShadow>? shadows;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = AppColors.primary;
        foregroundColor = Colors.white;
        gradient = const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryHover],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        shadows = AppColors.commonBtnShadow;
        break;
      case AppButtonVariant.secondary:
        backgroundColor = AppColors.secondary;
        foregroundColor = Colors.white;
        shadows = [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ];
        break;
      case AppButtonVariant.outline:
        backgroundColor = Colors.white;
        foregroundColor = AppColors.textPrimary;
        borderSide = const BorderSide(color: AppColors.cardBorder, width: 1.2);
        break;
      case AppButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.textSecondary;
        break;
      case AppButtonVariant.danger:
        backgroundColor = AppColors.error;
        foregroundColor = Colors.white;
        shadows = [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.32),
            blurRadius: 16,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ];
        break;
    }

    final double verticalPadding = size == AppButtonSize.small
        ? 8
        : size == AppButtonSize.large
        ? 15
        : 12;

    final double horizontalPadding = size == AppButtonSize.small
        ? 14
        : size == AppButtonSize.large
        ? 24
        : 18;

    final double fontSize = size == AppButtonSize.small
        ? 12.5
        : size == AppButtonSize.large
        ? 15.5
        : 14;

    final Widget buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: fontSize + 2,
            height: fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: foregroundColor,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (leftIcon != null) ...[
          leftIcon!,
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ),
        if (!isLoading && rightIcon != null) ...[
          const SizedBox(width: 8),
          rightIcon!,
        ],
      ],
    );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: Material(
        color: gradient == null ? backgroundColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding,
              horizontal: horizontalPadding,
            ),
            decoration: BoxDecoration(
              color: gradient == null ? backgroundColor : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
              border: borderSide != null
                  ? Border.all(color: borderSide.color, width: borderSide.width)
                  : null,
              boxShadow: onPressed == null ? null : shadows,
            ),
            child: buttonContent,
          ),
        ),
      ),
    );
  }
}
