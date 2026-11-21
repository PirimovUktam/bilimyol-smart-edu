import 'package:flutter/material.dart';
import '../../domain/entities/course.dart';
import '../theme/app_semantic_colors.dart';

IconData subjectIcon(SubjectType subject) => switch (subject) {
  SubjectType.mathematics => Icons.calculate_outlined,
  SubjectType.english => Icons.headphones_outlined,
  SubjectType.it => Icons.code_rounded,
  SubjectType.logic => Icons.psychology_outlined,
};

class SubjectVisual {
  final Color accent;
  final Color softBg;
  final Color border;
  final IconData icon;

  const SubjectVisual({
    required this.accent,
    required this.softBg,
    required this.border,
    required this.icon,
  });
}

SubjectVisual subjectVisual(SubjectType subject, AppSemanticColors c) {
  return switch (subject) {
    SubjectType.mathematics => SubjectVisual(
      accent: c.brand,
      softBg: c.brandSoft,
      border: c.brand.withValues(alpha: 0.28),
      icon: subjectIcon(subject),
    ),
    SubjectType.english => SubjectVisual(
      accent: c.isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
      softBg: c.isDark ? const Color(0x26FB7185) : const Color(0x1AE11D48),
      border: (c.isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48))
          .withValues(alpha: 0.28),
      icon: subjectIcon(subject),
    ),
    SubjectType.it => SubjectVisual(
      accent: c.path,
      softBg: c.pathSoft,
      border: c.path.withValues(alpha: 0.28),
      icon: subjectIcon(subject),
    ),
    SubjectType.logic => SubjectVisual(
      accent: c.isDark ? c.success : c.successText,
      softBg: c.successSoft,
      border: (c.isDark ? c.success : c.successText).withValues(alpha: 0.28),
      icon: subjectIcon(subject),
    ),
  };
}

