import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists client preferences and offline demo snapshots safely.
///
/// Wraps [SharedPreferences.getInstance()] in `try/catch` with an
/// instance-scoped in-memory fallback so unit and widget tests that do not
/// initialize Flutter bindings or mock platform channels never fail or leak
/// state across separate [ProviderScope] instances.
class LocalStorageService {
  static const String productTourCompletedKey =
      'bilimyol.product_tour_completed';
  static const String localeKey = 'bilimyol.locale';
  static const String themeModeKey = 'bilimyol.theme_mode';
  static const String demoSessionActiveKey = 'bilimyol.demo_session_active';
  static const String demoLearnerSnapshotKey =
      'bilimyol.demo_learner_snapshot';
  static const String secureStorageInitializedKey =
      'bilimyol.secure_storage_initialized_v1';
  static const String recoveryUserIdKey = 'bilimyol.recovery_user_id';
  static const String pendingAttemptPrefix = 'bilimyol.pending_attempt.';
  static const String lessonPassedPrefix = 'bilimyol.lesson_passed.';

  static String srsKeyForUser(String userId) => 'bilimyol.srs.$userId';

  static String pendingAttemptKey({
    required String accountScope,
    required String courseId,
    required String lessonId,
    required String questionId,
  }) =>
      '$pendingAttemptPrefix${jsonEncode([accountScope, courseId, lessonId, questionId])}';

  static String lessonPassedKey({
    required String accountScope,
    required String courseId,
    required String lessonId,
  }) => '$lessonPassedPrefix${jsonEncode([accountScope, courseId, lessonId])}';

  SharedPreferences? _prefs;
  Future<SharedPreferences?>? _prefsFuture;
  final Map<String, Object> _memoryFallback = {};

  LocalStorageService({SharedPreferences? prefs})
      : _prefs = prefs,
        _prefsFuture = prefs != null ? Future.value(prefs) : null;

  /// Pre-hydrates [SharedPreferences] for app startup before `runApp`.
  static Future<LocalStorageService> load() async {
    final service = LocalStorageService();
    await service._resolvePrefs();
    return service;
  }

  Future<SharedPreferences?> _resolvePrefs() {
    if (_prefs != null) return Future.value(_prefs);
    return _prefsFuture ??= _initPrefs();
  }

  Future<SharedPreferences?> _initPrefs() async {
    try {
      if (_isAutomatedWidgetTest) {
        _prefs = await Future.any<SharedPreferences?>([
          SharedPreferences.getInstance().then<SharedPreferences?>(
            (p) => p,
            onError: (Object _) => null,
          ),
          _microtaskFallback(),
        ]);
      } else {
        _prefs = await SharedPreferences.getInstance();
      }
    } catch (_) {
      _prefs = null;
    }
    return _prefs;
  }

  static bool get _isAutomatedWidgetTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString() ==
          'AutomatedTestWidgetsFlutterBinding';
    } catch (_) {
      return false;
    }
  }

  static Future<SharedPreferences?> _microtaskFallback() async {
    for (var i = 0; i < 32; i++) {
      await Future<void>.microtask(() {});
    }
    return null;
  }

  bool getBoolSync(String key, {bool defaultValue = false}) {
    final prefs = _prefs;
    if (prefs != null) {
      try {
        final raw = prefs.get(key);
        return raw is bool ? raw : defaultValue;
      } catch (_) {
        return defaultValue;
      }
    }
    final mem = _memoryFallback[key];
    return mem is bool ? mem : defaultValue;
  }

  String? getStringSync(String key) {
    final prefs = _prefs;
    if (prefs != null) {
      try {
        final raw = prefs.get(key);
        return raw is String ? raw : null;
      } catch (_) {
        return null;
      }
    }
    final mem = _memoryFallback[key];
    return mem is String ? mem : null;
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await _resolvePrefs();
    if (prefs != null) {
      try {
        final raw = prefs.get(key);
        return raw is bool ? raw : defaultValue;
      } catch (_) {
        return defaultValue;
      }
    }
    final mem = _memoryFallback[key];
    return mem is bool ? mem : defaultValue;
  }

  Future<void> setBool(String key, bool value) async {
    _memoryFallback[key] = value;
    final prefs = await _resolvePrefs();
    if (prefs != null) {
      await prefs.setBool(key, value);
    }
  }

  Future<String?> getString(String key) async {
    final prefs = await _resolvePrefs();
    if (prefs != null) {
      try {
        final raw = prefs.get(key);
        return raw is String ? raw : null;
      } catch (_) {
        return null;
      }
    }
    final mem = _memoryFallback[key];
    return mem is String ? mem : null;
  }

  Future<void> setString(String key, String value) async {
    _memoryFallback[key] = value;
    final prefs = await _resolvePrefs();
    if (prefs != null) {
      await prefs.setString(key, value);
    }
  }

  Future<void> remove(String key) async {
    _memoryFallback.remove(key);
    final prefs = await _resolvePrefs();
    if (prefs != null) {
      await prefs.remove(key);
    }
  }

  // --- Domain Helpers ---

  bool getProductTourCompletedSync() =>
      getBoolSync(productTourCompletedKey, defaultValue: false);

  Future<bool> getProductTourCompleted() =>
      getBool(productTourCompletedKey, defaultValue: false);

  Future<void> setProductTourCompleted(bool completed) =>
      setBool(productTourCompletedKey, completed);

  String getLocaleCodeSync() => _normalizeLocale(getStringSync(localeKey));

  Future<String> getLocaleCode() async =>
      _normalizeLocale(await getString(localeKey));

  Future<void> setLocaleCode(String code) =>
      setString(localeKey, _normalizeLocale(code));

  ThemeMode getThemeModeSync() => _parseThemeMode(getStringSync(themeModeKey));

  Future<ThemeMode> getThemeMode() async =>
      _parseThemeMode(await getString(themeModeKey));

  Future<void> setThemeMode(ThemeMode mode) =>
      setString(themeModeKey, _serializeThemeMode(mode));

  bool getDemoSessionActiveSync() =>
      getBoolSync(demoSessionActiveKey, defaultValue: false);

  Future<bool> getDemoSessionActive() =>
      getBool(demoSessionActiveKey, defaultValue: false);

  Future<void> setDemoSessionActive(bool active) =>
      setBool(demoSessionActiveKey, active);

  Future<String?> getDemoLearnerSnapshot() =>
      getString(demoLearnerSnapshotKey);

  Future<void> setDemoLearnerSnapshot(String json) =>
      setString(demoLearnerSnapshotKey, json);

  Future<void> clearDemoLearnerSnapshot() async {
    await remove(demoLearnerSnapshotKey);
    await clearDemoAndAnonymousLessonRecovery();
  }

  Future<void> clearDemoAndAnonymousLessonRecovery() async {
    bool isDemoOrAnonKey(String k) =>
        (k.startsWith(pendingAttemptPrefix) ||
            k.startsWith(lessonPassedPrefix)) &&
        (k.contains('["demo",') || k.contains('["anonymous",'));

    _memoryFallback.removeWhere((k, _) => isDemoOrAnonKey(k));
    final prefs = await _resolvePrefs();
    if (prefs != null) {
      try {
        final toRemove = prefs.getKeys().where(isDemoOrAnonKey).toList();
        for (final key in toRemove) {
          await prefs.remove(key);
        }
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> getPendingAttempt({
    required String accountScope,
    required String courseId,
    required String lessonId,
    required String questionId,
  }) async {
    final raw = await getString(
      pendingAttemptKey(
        accountScope: accountScope,
        courseId: courseId,
        lessonId: lessonId,
        questionId: questionId,
      ),
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setPendingAttempt({
    required String accountScope,
    required String courseId,
    required String lessonId,
    required String questionId,
    required Map<String, dynamic> data,
  }) => setString(
    pendingAttemptKey(
      accountScope: accountScope,
      courseId: courseId,
      lessonId: lessonId,
      questionId: questionId,
    ),
    jsonEncode(data),
  );

  Future<void> clearPendingAttempt({
    required String accountScope,
    required String courseId,
    required String lessonId,
    required String questionId,
  }) => remove(
    pendingAttemptKey(
      accountScope: accountScope,
      courseId: courseId,
      lessonId: lessonId,
      questionId: questionId,
    ),
  );

  Future<Set<String>> getPassedLessonQuestionIds({
    required String accountScope,
    required String courseId,
    required String lessonId,
  }) async {
    final raw = await getString(
      lessonPassedKey(
        accountScope: accountScope,
        courseId: courseId,
        lessonId: lessonId,
      ),
    );
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
      }
    } catch (_) {}
    return const {};
  }

  Future<void> setPassedLessonQuestionIds({
    required String accountScope,
    required String courseId,
    required String lessonId,
    required Iterable<String> questionIds,
  }) {
    final clean = questionIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final key = lessonPassedKey(
      accountScope: accountScope,
      courseId: courseId,
      lessonId: lessonId,
    );
    if (clean.isEmpty) return remove(key);
    return setString(key, jsonEncode(clean));
  }

  Future<void> clearPassedLessonQuestionIds({
    required String accountScope,
    required String courseId,
    required String lessonId,
  }) => remove(
    lessonPassedKey(
      accountScope: accountScope,
      courseId: courseId,
      lessonId: lessonId,
    ),
  );

  bool getSecureStorageInitializedSync() =>
      getBoolSync(secureStorageInitializedKey, defaultValue: false);

  Future<bool> getSecureStorageInitialized() =>
      getBool(secureStorageInitializedKey, defaultValue: false);

  Future<void> setSecureStorageInitialized(bool initialized) =>
      setBool(secureStorageInitializedKey, initialized);

  String? getRecoveryUserIdSync() => getStringSync(recoveryUserIdKey);

  Future<String?> getRecoveryUserId() => getString(recoveryUserIdKey);

  Future<void> setRecoveryUserId(String userId) =>
      setString(recoveryUserIdKey, userId);

  Future<void> clearRecoveryUserId() => remove(recoveryUserIdKey);

  Future<String?> getUserFlashcardSrsJson(String userId) =>
      getString(srsKeyForUser(userId));

  Future<void> setUserFlashcardSrsJson(String userId, String json) =>
      setString(srsKeyForUser(userId), json);

  Future<void> clearUserFlashcardSrsJson(String userId) =>
      remove(srsKeyForUser(userId));

  static String _normalizeLocale(String? code) => code == 'ru' ? 'ru' : 'uz';

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
