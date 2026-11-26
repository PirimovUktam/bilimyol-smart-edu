import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/demo_session.dart';
import '../auth/secure_auth_storage.dart';
import '../storage/local_storage_service.dart';

class SupabaseConfig {
  /// Values are supplied at compile time with `--dart-define` or
  /// `--dart-define-from-file`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const passwordRecoveryUrl =
      'uz.bilimyol.mobile://auth/reset-password';

  @visibleForTesting
  static bool? isProductionEnvOverride;

  static bool get isProductionEnv =>
      isProductionEnvOverride ??
      (appEnv.trim().toLowerCase() == 'production');

  static bool get isDemoModeAllowed => !isProductionEnv;

  static bool get isDemoModeActive =>
      isDemoModeAllowed &&
      (!hasRemoteConfiguration || demoSessionActive.value);

  static String? configurationError;

  static bool isConfigured = false;

  /// True when real backend credentials were supplied, even if client
  /// initialization failed. This prevents an online outage from being treated
  /// as demo mode and exposing bundled answer keys or accepting local scores.
  static bool hasRemoteConfiguration = false;

  static final ValueNotifier<String?> _authUserIdNotifier =
      ValueNotifier<String?>(null);
  static final ValueNotifier<bool> _recoveryActiveNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<int> _authStateRevisionNotifier =
      ValueNotifier<int>(0);

  static ValueListenable<String?> get authUserIdListenable =>
      _authUserIdNotifier;
  static ValueListenable<bool> get recoveryActiveListenable =>
      _recoveryActiveNotifier;
  static ValueListenable<int> get authStateRevisionListenable =>
      _authStateRevisionNotifier;
  static bool get isRecoveryActive => _recoveryActiveNotifier.value;

  static StreamSubscription<AuthState>? _authSubscription;
  static SupabaseClient? _clientOverride;
  static SecureAuthStorageCoordinator? _activeStorageCoordinator;
  static LocalStorageService? _recoveryStorage;
  static String? _recoveryUserId;
  static ({
    String userId,
    String accessToken,
    int recoveryTimestamp,
    int clearedAt,
  })?
  _clearedRecoveryClaim;
  static bool _completingRecoverySignOut = false;

  static void setCompletingRecoverySignOut(bool value) {
    _completingRecoverySignOut = value;
  }

  static bool isValidSupabaseUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') return true;
    if (scheme == 'http' && !isProductionEnv) {
      final host = uri.host.toLowerCase();
      return host == '127.0.0.1' || host == 'localhost' || host == '::1';
    }
    return false;
  }

  static bool isAllowedAuthRedirectUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final isAllowedTarget =
        (scheme == 'uz.bilimyol.mobile' &&
            host == 'auth' &&
            uri.path == '/reset-password') ||
        (scheme == 'https' &&
            host == 'bilimyol.uz' &&
            uri.path == '/reset-password');
    if (!isAllowedTarget) return false;

    Map<String, String> fragmentParams = const <String, String>{};
    if (uri.fragment.isNotEmpty) {
      try {
        fragmentParams = Uri.splitQueryString(uri.fragment);
      } catch (_) {
        fragmentParams = const <String, String>{};
      }
    }

    const allowedCallbackParams = <String>[
      'code',
      'access_token',
      'token_hash',
      'error',
    ];
    for (final param in allowedCallbackParams) {
      final queryValue = uri.queryParameters[param];
      if (queryValue != null && queryValue.trim().isNotEmpty) {
        return true;
      }
      final fragmentValue = fragmentParams[param];
      if (fragmentValue != null && fragmentValue.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  static String persistSessionKeyForUrl(String url) {
    final uri = Uri.parse(url.trim());
    return 'sb-${uri.host.split('.').first}-auth-token';
  }

  static bool isServiceRoleKey(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('sb_secret_')) return true;
    final payload = _decodeJwtPayload(trimmed);
    final role = payload?['role'];
    if (role is String && role.trim().toLowerCase() == 'service_role') {
      return true;
    }
    return lower.contains('service_role');
  }

  static Future<void> initialize({LocalStorageService? storage}) async {
    configurationError = null;
    if (isProductionEnv) {
      demoSessionActive.value = false;
      activeSessionHasStartedCourse.value = false;
    }

    final hasValidCredentials =
        isValidSupabaseUrl(supabaseUrl) &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseUrl.contains('bilimyol-demo') &&
        !supabaseAnonKey.contains('demo-anon-key') &&
        !isServiceRoleKey(supabaseAnonKey);
    hasRemoteConfiguration = hasValidCredentials;

    if (!hasRemoteConfiguration) {
      isConfigured = false;
      if (isServiceRoleKey(supabaseAnonKey)) {
        configurationError =
            'Privileged service_role key must never be bundled in the client.';
      } else if (isProductionEnv) {
        configurationError =
            'Production build requires valid SUPABASE_URL and SUPABASE_ANON_KEY.';
      }
      return;
    }

    try {
      final resolvedStorage = storage ?? await LocalStorageService.load();
      final persistSessionKey = persistSessionKeyForUrl(supabaseUrl);
      final coordinator = SecureAuthStorageCoordinator(
        persistSessionKey: persistSessionKey,
      );
      _activeStorageCoordinator = coordinator;
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          localStorage: SecureAuthLocalStorage(coordinator: coordinator),
          pkceAsyncStorage: SecureGotrueAsyncStorage(coordinator: coordinator),
          detectSessionInUriPredicate: isAllowedAuthRedirectUri,
        ),
      );
      isConfigured = true;
      await _attachAuthListener(
        Supabase.instance.client.auth,
        storage: resolvedStorage,
      );
    } catch (error) {
      isConfigured = false;
      configurationError = error.toString();
    }
  }

  @visibleForTesting
  static Future<void> bindClientForTesting(
    SupabaseClient? testClient, {
    LocalStorageService? storage,
  }) async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    _clientOverride = testClient;
    _activeStorageCoordinator = null;
    _recoveryUserId = null;
    _clearedRecoveryClaim = null;
    _completingRecoverySignOut = false;

    if (testClient == null) {
      _recoveryStorage = null;
      _recoveryActiveNotifier.value = false;
      _authUserIdNotifier.value = null;
      _authStateRevisionNotifier.value++;
      return;
    }

    final resolvedStorage = storage ?? await LocalStorageService.load();
    await _attachAuthListener(testClient.auth, storage: resolvedStorage);
  }

  static Future<void> _attachAuthListener(
    GoTrueClient authClient, {
    required LocalStorageService storage,
  }) async {
    await _authSubscription?.cancel();
    _recoveryStorage = storage;
    _recoveryUserId =
        storage.getRecoveryUserIdSync() ?? await storage.getRecoveryUserId();
    _applyAuthState(
      event: null,
      session: authClient.currentSession,
      storage: storage,
    );
    _authSubscription = authClient.onAuthStateChange.listen(
      (state) {
        _applyAuthState(
          event: state.event,
          session: state.session ?? authClient.currentSession,
          storage: storage,
        );
      },
      onError: (Object _) {
        _authStateRevisionNotifier.value++;
      },
    );
  }

  static Map<String, dynamic>? _decodeJwtPayload(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final padded = normalized.padRight(
        normalized.length + ((4 - (normalized.length % 4)) % 4),
        '=',
      );
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static List<({String method, int timestamp})> _extractAmrEntries(
    Map<String, dynamic>? payload,
  ) {
    final rawAmr = payload?['amr'];
    if (rawAmr is! List) return const [];
    final entries = <({String method, int timestamp})>[];
    for (final item in rawAmr) {
      if (item is String && item.isNotEmpty) {
        entries.add((method: item, timestamp: 0));
      } else if (item is Map) {
        final method = item['method'];
        if (method is String && method.isNotEmpty) {
          final ts = item['timestamp'];
          entries.add((
            method: method,
            timestamp: ts is num ? ts.toInt() : 0,
          ));
        }
      }
    }
    return entries;
  }

  static bool hasUnresolvedRecoveryAmrClaim(Session? session) {
    if (session == null) return false;
    final payload = _decodeJwtPayload(session.accessToken);
    final entries = _extractAmrEntries(payload);
    final recoveryEntries = entries.where((e) => e.method == 'recovery').toList();
    if (recoveryEntries.isEmpty) return false;

    final latestRecoveryTs = recoveryEntries
        .map((e) => e.timestamp)
        .reduce((a, b) => a > b ? a : b);
    final hasNewerPassword = entries.any(
      (e) => e.method == 'password' && e.timestamp > latestRecoveryTs,
    );
    if (hasNewerPassword) return false;

    final cleared = _clearedRecoveryClaim;
    if (cleared != null && cleared.userId == session.user.id) {
      if (cleared.accessToken == session.accessToken) {
        return false;
      }
      if (latestRecoveryTs > 0 && latestRecoveryTs <= cleared.recoveryTimestamp) {
        return false;
      }
      final iat = payload?['iat'];
      final iatSec = iat is num ? iat.toInt() : null;
      if (latestRecoveryTs == 0 &&
          (iatSec == null || iatSec <= cleared.clearedAt)) {
        return false;
      }
    }
    return true;
  }

  static void _recordClearedRecoveryClaim(Session session) {
    final payload = _decodeJwtPayload(session.accessToken);
    final entries = _extractAmrEntries(payload);
    final recoveryEntries = entries.where((e) => e.method == 'recovery');
    var latestRecoveryTs = 0;
    for (final entry in recoveryEntries) {
      if (entry.timestamp > latestRecoveryTs) {
        latestRecoveryTs = entry.timestamp;
      }
    }
    _clearedRecoveryClaim = (
      userId: session.user.id,
      accessToken: session.accessToken,
      recoveryTimestamp: latestRecoveryTs,
      clearedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  static void _applyAuthState({
    required AuthChangeEvent? event,
    required Session? session,
    required LocalStorageService storage,
  }) {
    if (event == AuthChangeEvent.signedOut || session == null) {
      _recoveryUserId = null;
      _clearedRecoveryClaim = null;
      _completingRecoverySignOut = false;
      unawaited(storage.clearRecoveryUserId());
      activeSessionHasStartedCourse.value = false;
      _recoveryActiveNotifier.value = false;
      _authUserIdNotifier.value = null;
      _authStateRevisionNotifier.value++;
      return;
    }

    demoSessionActive.value = false;
    final userId = session.user.id;
    if (event == AuthChangeEvent.passwordRecovery) {
      _recoveryUserId = userId;
      _clearedRecoveryClaim = null;
      unawaited(storage.setRecoveryUserId(userId));
      _recoveryActiveNotifier.value = true;
    } else if (event == AuthChangeEvent.userUpdated &&
        (_recoveryUserId == userId ||
            _recoveryActiveNotifier.value ||
            hasUnresolvedRecoveryAmrClaim(session))) {
      if (!_completingRecoverySignOut) {
        _recordClearedRecoveryClaim(session);
        _recoveryUserId = null;
        unawaited(storage.clearRecoveryUserId());
        _recoveryActiveNotifier.value = false;
      }
    } else {
      if (_recoveryUserId != null && _recoveryUserId != userId) {
        _recoveryUserId = null;
        unawaited(storage.clearRecoveryUserId());
      }
      final unresolvedAmr = hasUnresolvedRecoveryAmrClaim(session);
      if (unresolvedAmr && _recoveryUserId != userId) {
        _recoveryUserId = userId;
        unawaited(storage.setRecoveryUserId(userId));
      }
      _recoveryActiveNotifier.value =
          (_recoveryUserId == userId) || unresolvedAmr;
    }

    _authUserIdNotifier.value = userId;
    _authStateRevisionNotifier.value++;
  }

  @visibleForTesting
  static void setAuthUserIdForTesting(
    String? userId, {
    SecureAuthStorageCoordinator? coordinator,
  }) {
    _authUserIdNotifier.value = userId;
    if (coordinator != null) {
      _activeStorageCoordinator = coordinator;
    }
    _authStateRevisionNotifier.value++;
  }

  static Future<void> clearPasswordRecovery({
    Session? session,
    LocalStorageService? storage,
  }) async {
    final resolvedStorage = storage ?? _recoveryStorage;
    final activeSession = session ?? client?.auth.currentSession;
    if (activeSession != null) {
      _recordClearedRecoveryClaim(activeSession);
    }
    _recoveryUserId = null;
    await resolvedStorage?.clearRecoveryUserId();
    _recoveryActiveNotifier.value = false;
    _authStateRevisionNotifier.value++;
  }

  /// Synchronizes [authUserIdListenable] and [recoveryActiveListenable] with the
  /// synchronous `currentSession`/`currentUser` on [client] immediately after
  /// `signInWithPassword` or `signOut`, without waiting for GoTrue's async
  /// `onAuthStateChange` stream delivery.
  static void syncCurrentAuthState({LocalStorageService? storage}) {
    final authClient = client?.auth;
    if (authClient == null) return;
    final resolvedStorage = storage ?? _recoveryStorage;
    if (resolvedStorage != null) {
      _applyAuthState(
        event: null,
        session: authClient.currentSession,
        storage: resolvedStorage,
      );
      return;
    }
    final userId = authClient.currentUser?.id;
    if (userId == null) {
      _recoveryUserId = null;
      _clearedRecoveryClaim = null;
      _completingRecoverySignOut = false;
      activeSessionHasStartedCourse.value = false;
      _recoveryActiveNotifier.value = false;
    } else {
      demoSessionActive.value = false;
      final unresolvedAmr = hasUnresolvedRecoveryAmrClaim(
        authClient.currentSession,
      );
      _recoveryActiveNotifier.value =
          (_recoveryUserId == userId) || unresolvedAmr;
    }
    _authUserIdNotifier.value = userId;
    _authStateRevisionNotifier.value++;
  }

  /// Guarantees local auth state and encrypted session storage are purged on
  /// explicit user logout even when [client] is null (offline cold-boot) or
  /// [GoTrueClient.signOut] throws.
  static Future<void> forceLocalSignOutCleanup({
    LocalStorageService? storage,
  }) async {
    final authClient = client?.auth;
    if (authClient != null) {
      try {
        await authClient.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Proceed with unconditional local purge below.
      }
    }

    final coordinator =
        _activeStorageCoordinator ??
        (isValidSupabaseUrl(supabaseUrl)
            ? SecureAuthStorageCoordinator(
                persistSessionKey: persistSessionKeyForUrl(supabaseUrl),
              )
            : null);
    if (coordinator != null) {
      try {
        await coordinator.purgePersistedAuthArtifacts();
      } catch (_) {
        // Best-effort secure token purge.
      }
    }

    final resolvedStorage = storage ?? _recoveryStorage;
    _recoveryUserId = null;
    _clearedRecoveryClaim = null;
    _completingRecoverySignOut = false;
    activeSessionHasStartedCourse.value = false;
    _recoveryActiveNotifier.value = false;
    try {
      await resolvedStorage?.clearRecoveryUserId();
    } catch (_) {}
    _authUserIdNotifier.value = authClient?.currentUser?.id;
    if (authClient == null || authClient.currentSession == null) {
      _authUserIdNotifier.value = null;
    }
    _authStateRevisionNotifier.value++;
  }

  /// Non-blocking startup session verification bounded to [timeout].
  ///
  /// Uses `refreshSession()` when the local access token is already expired
  /// (`>1h`) so valid returning learners keep their refresh token, and
  /// `getUser()` otherwise. Signs out locally only on explicit auth rejection
  /// (`400`/`401`/`403`) for the same user; offline/timeout errors are ignored.
  static Future<void> verifyActiveSessionOrSignOut({
    @visibleForTesting GoTrueClient? authClient,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final auth = authClient ?? client?.auth;
    if (auth == null) return;
    final session = auth.currentSession;
    if (session == null) return;
    final initialUserId = session.user.id;

    try {
      if (session.isExpired) {
        await auth.refreshSession().timeout(timeout);
      } else {
        await auth.getUser().timeout(timeout);
      }
    } on TimeoutException {
      return;
    } on SocketException {
      return;
    } on AuthRetryableFetchException {
      return;
    } on AuthException catch (error) {
      final status = error.statusCode?.trim();
      if (status == '400' || status == '401' || status == '403') {
        if (auth.currentSession?.user.id == initialUserId) {
          try {
            await auth.signOut(scope: SignOutScope.local);
            syncCurrentAuthState();
          } catch (_) {
            // Best-effort local signOut.
          }
        }
      }
    } catch (_) {
      // Ignore unexpected transient/network errors on startup verification.
    }
  }

  static SupabaseClient? get client {
    if (_clientOverride != null) return _clientOverride;
    if (!isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
