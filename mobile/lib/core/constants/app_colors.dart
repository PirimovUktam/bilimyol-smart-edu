import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors (Deep Indigo & Royal Blue)
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryHover = Color(0xFF4338CA); // Indigo 700
  static const Color primaryLight = Color(0xFFEEF2FF); // Indigo 50

  static const Color secondary = Color(0xFF06B6D4); // Cyan 500
  static const Color secondaryHover = Color(0xFF0891B2);
  static const Color secondaryLight = Color(0xFFECFEFF);

  // Surface & Neutral Colors
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF0F172A); // Slate 900
  static const Color cardBorder = Color(0xFFE2E8F0); // Slate 200

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFE11D48); // Rose 600
  static const Color errorLight = Color(0xFFFFF1F2);
  static const Color accent = Color(0xFF6366F1); // Indigo 500

  // Coral & Sunset (Reference 4 Error Diagnosis)
  static const Color coral = Color(0xFFFF7043);
  static const Color coralLight = Color(0xFFFFF5F2);
  static const Color coralBorder = Color(0xFFFFCCBC);

  // Reference 2 Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF3B82F6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coralGradient = LinearGradient(
    colors: [Color(0xFFFFF5F2), Color(0xFFFFEBE5), Color(0xFFFFDDD4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cyanMintGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
