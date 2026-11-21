import 'dart:convert';

import 'package:flutter/foundation.dart';

final demoSessionActive = ValueNotifier<bool>(false);
final productTourCompleted = ValueNotifier<bool>(false);
final activeSessionHasStartedCourse = ValueNotifier<bool>(false);

bool hasStartedCourseInDemoSnapshot(String? rawJson) {
  if (rawJson == null || rawJson.trim().isEmpty) return false;
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) return false;
    final profile = decoded['profile'];
    if (profile is! Map<String, dynamic>) return false;

    final courseLevels = profile['courseLevels'];
    if (courseLevels is Map && courseLevels.isNotEmpty) return true;

    final scoresByCourse = profile['scoresByCourse'];
    if (scoresByCourse is Map) {
      for (final value in scoresByCourse.values) {
        if (value is Map && value.isNotEmpty) return true;
      }
    }

    final completedLessonIds = profile['completedLessonIds'];
    if (completedLessonIds is List && completedLessonIds.isNotEmpty) {
      return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}

