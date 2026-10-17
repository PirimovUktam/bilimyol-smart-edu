import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';

class FriendlyErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const FriendlyErrorState({
    super.key,
    this.message = 'Ma’lumotlarni yuklab bo‘lmadi.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Internet aloqasini tekshirib, qayta urinib ko‘ring.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                text: 'Qayta urinish',
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
