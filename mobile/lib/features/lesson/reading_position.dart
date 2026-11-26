import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/lesson.dart';

class LessonReadingPositionStore {
  static String primaryKey(String lessonId) => 'bilimyol-reading:$lessonId';

  static String tupleKey(String accountId, String courseId, String lessonId) =>
      'bilimyol-reading:${jsonEncode([accountId, courseId, lessonId])}';

  static int maxSafeStepIndex(
    Lesson lesson, {
    Set<String> passedQuestionIds = const {},
  }) {
    if (lesson.steps.isEmpty) return 0;
    final firstUnansweredExercise = lesson.steps.indexWhere((step) {
      final hasExercise =
          step.type == LessonStepType.interactiveQuestion ||
          step.interactiveQuestion != null;
      if (!hasExercise) return false;
      final qId = step.interactiveQuestion?.id;
      if (qId != null && passedQuestionIds.contains(qId)) {
        return false;
      }
      return true;
    });
    if (firstUnansweredExercise >= 0) return firstUnansweredExercise;
    return lesson.steps.length - 1;
  }

  static int clampStepIndex(
    Lesson lesson,
    int? rawIndex, {
    Set<String> passedQuestionIds = const {},
  }) {
    if (rawIndex == null || lesson.steps.isEmpty) return 0;
    final maxSafe = maxSafeStepIndex(
      lesson,
      passedQuestionIds: passedQuestionIds,
    );
    if (rawIndex < 0) return 0;
    if (rawIndex > maxSafe) return maxSafe;
    return rawIndex;
  }

  static bool _isWidgetTestBinding() {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains(
        'TestWidgetsFlutterBinding',
      );
    } catch (_) {
      return false;
    }
  }

  static Future<SharedPreferences?> getPrefsSafe([
    Future<SharedPreferences> Function()? provider,
  ]) async {
    try {
      final getInstance = provider ?? SharedPreferences.getInstance;
      final future = getInstance();
      if (provider == null && _isWidgetTestBinding()) {
        SharedPreferences? resolved;
        var done = false;
        unawaited(
          future.then(
            (prefs) {
              resolved = prefs;
              done = true;
            },
            onError: (_, _) {
              done = true;
            },
          ),
        );
        for (var i = 0; i < 32 && !done; i++) {
          await Future<void>.microtask(() {});
        }
        return done ? resolved : null;
      }
      return await future;
    } catch (_) {
      return null;
    }
  }

  static int? _readInt(SharedPreferences prefs, String key) {
    final raw = prefs.get(key);
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString().trim());
  }

  static String _storageKey(Lesson lesson, {String? accountId}) {
    if (accountId != null && accountId.isNotEmpty) {
      return tupleKey(accountId, lesson.courseId, lesson.id);
    }
    return primaryKey(lesson.id);
  }

  static Future<int> readStepIndex(
    Lesson lesson, {
    String? accountId,
    Set<String> passedQuestionIds = const {},
    Future<SharedPreferences> Function()? preferencesProvider,
  }) async {
    final prefs = await getPrefsSafe(preferencesProvider);
    if (prefs == null) return 0;
    final stored = _readInt(prefs, _storageKey(lesson, accountId: accountId));
    if (stored != null) {
      return clampStepIndex(
        lesson,
        stored,
        passedQuestionIds: passedQuestionIds,
      );
    }
    return 0;
  }

  static Future<void> saveStepIndex(
    Lesson lesson,
    int stepIndex, {
    String? accountId,
    Set<String> passedQuestionIds = const {},
    Future<SharedPreferences> Function()? preferencesProvider,
  }) async {
    final prefs = await getPrefsSafe(preferencesProvider);
    if (prefs == null) return;
    final clamped = clampStepIndex(
      lesson,
      stepIndex,
      passedQuestionIds: passedQuestionIds,
    );
    try {
      await prefs.setString(
        _storageKey(lesson, accountId: accountId),
        clamped.toString(),
      );
    } catch (_) {
      // Best-effort reading checkpoint persistence.
    }
  }

  static Future<void> clearStepIndex(
    Lesson lesson, {
    String? accountId,
    Future<SharedPreferences> Function()? preferencesProvider,
  }) async {
    final prefs = await getPrefsSafe(preferencesProvider);
    if (prefs == null) return;
    try {
      await prefs.remove(_storageKey(lesson, accountId: accountId));
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
