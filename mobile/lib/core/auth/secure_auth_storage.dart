import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/local_storage_service.dart';

/// Coordinates one-time migration from legacy cleartext [SharedPreferences]
/// auth keys to encrypted [FlutterSecureStorage] for both [LocalStorage] and
/// [GotrueAsyncStorage] without initialization races.
class SecureAuthStorageCoordinator {
  static const String androidStorageNamespace = 'uz.bilimyol.mobile.secure_auth';
  static const String appleAccountName = 'uz.bilimyol.mobile.auth';
  static const String defaultGotrueCodeVerifierKey =
      'supabase.auth.token-code-verifier';

  static const AndroidOptions defaultAndroidOptions = AndroidOptions(
    storageNamespace: androidStorageNamespace,
  );

  static const IOSOptions defaultIosOptions = IOSOptions(
    accountName: appleAccountName,
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  static const MacOsOptions defaultMacOsOptions = MacOsOptions(
    accountName: appleAccountName,
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  static FlutterSecureStorage createDefaultSecureStorage() =>
      const FlutterSecureStorage(
        aOptions: defaultAndroidOptions,
        iOptions: defaultIosOptions,
        mOptions: defaultMacOsOptions,
      );

  static bool get _defaultIsTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment['FLUTTER_TEST'] == 'true';
    } catch (_) {
      return false;
    }
  }

  SecureAuthStorageCoordinator({
    required this.persistSessionKey,
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences> Function()? prefsProvider,
    @visibleForTesting bool? allowInMemoryTestFallback,
  }) : _secureStorage = secureStorage ?? createDefaultSecureStorage(),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _allowInMemoryTestFallback =
           allowInMemoryTestFallback ?? _defaultIsTestEnvironment;

  final String persistSessionKey;
  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> Function() _prefsProvider;
  final bool _allowInMemoryTestFallback;

  Future<void>? _initFuture;
  bool _useMemoryFallback = false;
  final Map<String, String> _memoryFallback = <String, String>{};

  Set<String> get _migrationKeys => <String>{
    persistSessionKey,
    '$persistSessionKey-code-verifier',
    defaultGotrueCodeVerifierKey,
  };

  /// Ensures one-time migration and iOS fresh-install Keychain purge complete
  /// once before any read/write on either [LocalStorage] or [GotrueAsyncStorage].
  Future<void> ensureInitialized() {
    final existing = _initFuture;
    if (existing != null) return existing;

    final future = _initialize();
    _initFuture = future;
    return future.catchError((Object error, StackTrace stackTrace) {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    SharedPreferences? prefs;
    try {
      prefs = await _prefsProvider();
    } on MissingPluginException {
      if (!_allowInMemoryTestFallback) rethrow;
      _useMemoryFallback = true;
      return;
    }

    final isInitialized =
        prefs.getBool(LocalStorageService.secureStorageInitializedKey) ?? false;

    final legacyEntries = <String, String>{};
    for (final key in _migrationKeys) {
      final raw = prefs.get(key);
      if (raw is String && raw.isNotEmpty) {
        legacyEntries[key] = raw;
      }
    }

    if (!isInitialized && legacyEntries.isEmpty && !kIsWeb) {
      await _deleteAllRaw();
    }

    for (final entry in legacyEntries.entries) {
      final existingSecure = await _readRaw(entry.key);
      if (existingSecure == null) {
        await _writeRaw(entry.key, entry.value);
      }
    }

    // Delete all cleartext keys only after every legacy entry is persisted in
    // secure storage (or verified already present there).
    for (final key in _migrationKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }

    if (!isInitialized) {
      await prefs.setBool(LocalStorageService.secureStorageInitializedKey, true);
    }
  }

  Future<bool> containsKey(String key) async {
    await ensureInitialized();
    if (_useMemoryFallback) {
      return _memoryFallback.containsKey(key);
    }
    try {
      return await _secureStorage.containsKey(key: key);
    } on PlatformException {
      await _safeDeleteCorruptedKey(key);
      return false;
    } on MissingPluginException {
      if (!_allowInMemoryTestFallback) rethrow;
      _useMemoryFallback = true;
      return _memoryFallback.containsKey(key);
    }
  }

  Future<String?> read(String key) async {
    await ensureInitialized();
    return _readRaw(key);
  }

  Future<void> write(String key, String value) async {
    await ensureInitialized();
    await _writeRaw(key, value);
  }

  Future<void> delete(String key) async {
    await ensureInitialized();
    await _deleteRaw(key);
  }

  /// Purges all persisted auth session and PKCE verifier keys from both
  /// encrypted secure storage and legacy SharedPreferences, even when
  /// [SupabaseConfig.client] failed to initialize offline.
  Future<void> purgePersistedAuthArtifacts() async {
    for (final key in _migrationKeys) {
      await _deleteRaw(key);
    }
    try {
      final prefs = await _prefsProvider();
      for (final key in _migrationKeys) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {
      // Best-effort cleanup in headless/unmocked environments.
    }
  }

  Future<String?> _readRaw(String key) async {
    if (_useMemoryFallback) {
      return _memoryFallback[key];
    }
    try {
      return await _secureStorage.read(key: key);
    } on PlatformException {
      await _safeDeleteCorruptedKey(key);
      return null;
    } on MissingPluginException {
      if (!_allowInMemoryTestFallback) rethrow;
      _useMemoryFallback = true;
      return _memoryFallback[key];
    }
  }

  Future<void> _writeRaw(String key, String value) async {
    if (_useMemoryFallback) {
      _memoryFallback[key] = value;
      return;
    }
    try {
      await _secureStorage.write(key: key, value: value);
    } on PlatformException {
      await _safeDeleteCorruptedKey(key);
      try {
        await _secureStorage.write(key: key, value: value);
      } on PlatformException {
        // Never fall back to cleartext SharedPreferences on Keystore failure.
      }
    } on MissingPluginException {
      if (!_allowInMemoryTestFallback) rethrow;
      _useMemoryFallback = true;
      _memoryFallback[key] = value;
    }
  }

  Future<void> _deleteRaw(String key) async {
    if (_useMemoryFallback) {
      _memoryFallback.remove(key);
      return;
    }
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException {
      // Best-effort secure key deletion without cleartext fallback.
    } on MissingPluginException {
      if (!_allowInMemoryTestFallback) rethrow;
      _useMemoryFallback = true;
      _memoryFallback.remove(key);
    }
  }

  Future<void> _deleteAllRaw() async {
    if (_useMemoryFallback) {
      _memoryFallback.clear();
      return;
    }
    try {
      await _secureStorage.deleteAll();
    } on PlatformException {
      // Do not crash startup if Keychain/Keystore deleteAll fails; never
      // fall back to cleartext storage.
    } on MissingPluginException {
      if (!_allowInMemoryTestFallback) rethrow;
      _useMemoryFallback = true;
      _memoryFallback.clear();
    }
  }

  Future<void> _safeDeleteCorruptedKey(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException {
      // Ignore secondary errors while clearing a corrupted key.
    } on MissingPluginException {
      if (!_allowInMemoryTestFallback) rethrow;
      _useMemoryFallback = true;
      _memoryFallback.remove(key);
    }
  }
}

/// Encrypted [LocalStorage] adapter backed by [SecureAuthStorageCoordinator].
class SecureAuthLocalStorage extends LocalStorage {
  const SecureAuthLocalStorage({required this.coordinator});

  final SecureAuthStorageCoordinator coordinator;

  @override
  Future<void> initialize() => coordinator.ensureInitialized();

  @override
  Future<bool> hasAccessToken() =>
      coordinator.containsKey(coordinator.persistSessionKey);

  @override
  Future<String?> accessToken() =>
      coordinator.read(coordinator.persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      coordinator.delete(coordinator.persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      coordinator.write(coordinator.persistSessionKey, persistSessionString);
}

/// Encrypted [GotrueAsyncStorage] adapter for PKCE `code_verifier` keys.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  SecureGotrueAsyncStorage({required this.coordinator});

  final SecureAuthStorageCoordinator coordinator;

  @override
  Future<String?> getItem({required String key}) => coordinator.read(key);

  @override
  Future<void> removeItem({required String key}) => coordinator.delete(key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      coordinator.write(key, value);
}
