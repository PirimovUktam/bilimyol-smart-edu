import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/secure_auth_storage.dart';

class SupabaseConfig {
  /// Values are supplied at compile time with `--dart-define` or
  /// `--dart-define-from-file`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const passwordRecoveryUrl =
      'uz.bilimyol.mobile://auth/reset-password';

  static bool isConfigured = false;

  /// True when real backend credentials were supplied, even if client
  /// initialization failed. This prevents an online outage from being treated
  /// as demo mode and exposing bundled answer keys or accepting local scores.
  static bool hasRemoteConfiguration = false;

  static bool isValidSupabaseUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') return true;
    if (scheme == 'http') {
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

  static Future<void> initialize() async {
    hasRemoteConfiguration =
        isValidSupabaseUrl(supabaseUrl) &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseUrl.contains('bilimyol-demo') &&
        !supabaseAnonKey.contains('demo-anon-key');

    if (!hasRemoteConfiguration) {
      isConfigured = false;
      return;
    }

    try {
      final persistSessionKey = persistSessionKeyForUrl(supabaseUrl);
      final coordinator = SecureAuthStorageCoordinator(
        persistSessionKey: persistSessionKey,
      );
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
    } catch (_) {
      isConfigured = false;
    }
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
    if (!isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
