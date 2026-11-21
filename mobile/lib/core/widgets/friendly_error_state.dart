import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';

class FriendlyErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final bool onDark;

  const FriendlyErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final useDarkTokens = onDark || AppColors.isDark(context);
    final mutedColor = useDarkTokens
        ? AppColors.darkTextMuted
        : AppColors.textMuted;
    final primaryColor = useDarkTokens
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    final displayMessage =
        message ??
        (isRu
            ? 'Не удалось загрузить данные.'
            : 'Ma’lumotlarni yuklab bo‘lmadi.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: mutedColor,
            ),
            const SizedBox(height: 12),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isRu
                  ? 'Проверьте подключение к интернету и попробуйте снова.'
                  : 'Internet aloqasini tekshirib, qayta urinib ko‘ring.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedColor,
                fontSize: 12,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                text: isRu ? 'Повторить' : 'Qayta urinish',
                leftIcon: const Icon(
                  Icons.refresh_rounded,
                  size: 17,
                  color: Colors.white,
                ),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
