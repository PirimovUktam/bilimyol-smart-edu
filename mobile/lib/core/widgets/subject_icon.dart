import 'package:flutter/material.dart';
import '../../domain/entities/course.dart';

IconData subjectIcon(SubjectType subject) => switch (subject) {
  SubjectType.mathematics => Icons.calculate_outlined,
  SubjectType.english => Icons.headphones_outlined,
  SubjectType.it => Icons.code_rounded,
  SubjectType.logic => Icons.psychology_outlined,
};
