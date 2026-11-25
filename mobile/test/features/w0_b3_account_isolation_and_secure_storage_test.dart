import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bilimyol_mobile/core/auth/secure_auth_storage.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _FakeSecureChannel {
  final Map<String, String> store;
  final List<String> calls = [];
  final List<Map<String, String>> capturedOptions = [];
  bool throwPlatformExceptionOnRead = false;
  bool throwPlatformExceptionOnContainsKey = false;
  bool throwMissingPluginOnAll = false;

  _FakeSecureChannel([Map<String, String>? initial])
    : store = Map<String, String>.from(initial ?? {});

  void attach() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, _handle);
  }

  void detach() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  }

  Future<dynamic> _handle(MethodCall call) async {
    calls.add(call.method);
    if (throwMissingPluginOnAll) {
      throw MissingPluginException('No implementation for ${call.method}');
    }
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    final options = (args['options'] as Map?)?.cast<String, String>() ?? {};
    capturedOptions.add(options);
    final key = args['key'] as String?;

    switch (call.method) {
      case 'read':
        if (throwPlatformExceptionOnRead) {
          throw PlatformException(
            code: 'BadPaddingException',
            message: 'Simulated Keystore corruption',
          );
        }
        return store[key];
      case 'write':
        final value = args['value'] as String;
        store[key!] = value;
        return null;
      case 'delete':
        store.remove(key);
        return null;
      case 'deleteAll':
        store.clear();
        return null;
      case 'containsKey':
        if (throwPlatformExceptionOnContainsKey) {
          throw PlatformException(
            code: 'BadPaddingException',
            message: 'Simulated Keystore corruption',
          );
        }
        return store.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(store);
      default:
        throw MissingPluginException('Unknown method ${call.method}');
    }
  }
}

String _encodeJwt({required String sub, required int exp}) {
  String b64(Map<String, Object?> jsonMap) => base64Url
      .encode(utf8.encode(jsonEncode(jsonMap)))
      .replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': sub, 'exp': exp})}.sig';
}

Session _buildTestSession({required String userId, required bool expired}) {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = expired ? nowSec - 3600 : nowSec + 3600;
  return Session(
    accessToken: _encodeJwt(sub: userId, exp: exp),
    refreshToken: 'refresh-$userId',
    expiresIn: 3600,
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: '$userId@example.test',
    ),
  );
}

Directory _resolveMobileDir() {
  final cwd = Directory.current;
  if (File('${cwd.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
    return cwd;
  }
  return Directory('${cwd.path}${Platform.pathSeparator}mobile');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('W0-B3 Task 3 Part A — Secure Auth Storage & Canonical Configs', () {
    late _FakeSecureChannel fakeChannel;

    setUp(() {
      fakeChannel = _FakeSecureChannel();
      fakeChannel.attach();
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = null;
    });

    tearDown(() {
      fakeChannel.detach();
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      '1. SecureAuthStorageCoordinator migrates session + both PKCE keys atomically without race and deletes cleartext SharedPreferences copies',
      () async {
        const sessionKey = 'sb-testproj-auth-token';
        const derivedVerifierKey = 'sb-testproj-auth-token-code-verifier';
        const defaultVerifierKey = 'supabase.auth.token-code-verifier';

        SharedPreferences.setMockInitialValues({
          sessionKey: '{"access_token":"legacy-tok","refresh_token":"legacy-ref"}',
          derivedVerifierKey: 'pkce-derived-verifier/PASSWORD_RECOVERY',
          defaultVerifierKey: 'pkce-default-verifier/SIGNED_IN',
        });

        final coordinator = SecureAuthStorageCoordinator(
          persistSessionKey: sessionKey,
        );
        final localStorage = SecureAuthLocalStorage(coordinator: coordinator);
        final gotrueStorage = SecureGotrueAsyncStorage(
          coordinator: coordinator,
        );

        // Concurrent init + getItem across both adapters must serialize via one memoized Future.
        final results = await Future.wait<Object?>([
          localStorage.initialize(),
          gotrueStorage.getItem(key: defaultVerifierKey),
          gotrueStorage.getItem(key: derivedVerifierKey),
          localStorage.accessToken(),
        ]);

        expect(results[1], 'pkce-default-verifier/SIGNED_IN');
        expect(results[2], 'pkce-derived-verifier/PASSWORD_RECOVERY');
        expect(
          results[3],
          '{"access_token":"legacy-tok","refresh_token":"legacy-ref"}',
        );
        expect(await localStorage.hasAccessToken(), isTrue);

        // Secure store holds all three keys.
        expect(
          fakeChannel.store[sessionKey],
          '{"access_token":"legacy-tok","refresh_token":"legacy-ref"}',
        );
        expect(
          fakeChannel.store[derivedVerifierKey],
          'pkce-derived-verifier/PASSWORD_RECOVERY',
        );
        expect(
          fakeChannel.store[defaultVerifierKey],
          'pkce-default-verifier/SIGNED_IN',
        );

        // Cleartext SharedPreferences keys are deleted; init marker is set.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(sessionKey), isNull);
        expect(prefs.getString(derivedVerifierKey), isNull);
        expect(prefs.getString(defaultVerifierKey), isNull);
        expect(
          prefs.getBool(LocalStorageService.secureStorageInitializedKey),
          isTrue,
        );

        // Verify AndroidOptions uses storageNamespace and iOSOptions uses expected attributes.
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await localStorage.persistSession('{"access_token":"new-tok"}');
        expect(
          fakeChannel.capturedOptions.last['storageNamespace'],
          'uz.bilimyol.mobile.secure_auth',
        );
        expect(prefs.getString(sessionKey), isNull);

        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await gotrueStorage.setItem(key: defaultVerifierKey, value: 'v2');
        expect(
          fakeChannel.capturedOptions.last['accountName'],
          'uz.bilimyol.mobile.auth',
        );
        expect(
          fakeChannel.capturedOptions.last['accessibility'],
          'first_unlock_this_device',
        );
        expect(fakeChannel.capturedOptions.last['synchronizable'], 'false');

        await localStorage.removePersistedSession();
        expect(await localStorage.hasAccessToken(), isFalse);
        await gotrueStorage.removeItem(key: defaultVerifierKey);
        expect(await gotrueStorage.getItem(key: defaultVerifierKey), isNull);
      },
    );

    test(
      '2. Fresh iOS install purges stale Keychain entries via deleteAll() when initialized flag is false and no legacy SharedPreferences exist',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        fakeChannel.store['sb-testproj-auth-token'] = 'stale-keychain-session';
        fakeChannel.store['supabase.auth.token-code-verifier'] = 'stale-pkce';
        SharedPreferences.setMockInitialValues({});

        final coordinator = SecureAuthStorageCoordinator(
          persistSessionKey: 'sb-testproj-auth-token',
        );
        final localStorage = SecureAuthLocalStorage(coordinator: coordinator);
        await localStorage.initialize();

        expect(fakeChannel.calls, contains('deleteAll'));
        expect(fakeChannel.store, isEmpty);
        expect(await localStorage.hasAccessToken(), isFalse);
        expect(await localStorage.accessToken(), isNull);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(LocalStorageService.secureStorageInitializedKey),
          isTrue,
        );

        // Once initialized=true, subsequent app launches preserve valid secure sessions.
        await localStorage.persistSession('{"access_token":"valid"}');
        final nextLaunchCoordinator = SecureAuthStorageCoordinator(
          persistSessionKey: 'sb-testproj-auth-token',
        );
        final nextLocalStorage = SecureAuthLocalStorage(
          coordinator: nextLaunchCoordinator,
        );
        await nextLocalStorage.initialize();
        expect(await nextLocalStorage.accessToken(), '{"access_token":"valid"}');
      },
    );

    test(
      '3a. PlatformException deletes corrupted secure key and returns null without falling back to cleartext SharedPreferences',
      () async {
        const sessionKey = 'sb-testproj-auth-token';
        const verifierKey = 'supabase.auth.token-code-verifier';
        fakeChannel.store[sessionKey] = 'corrupted-ciphertext';
        fakeChannel.store[verifierKey] = 'corrupted-verifier';
        SharedPreferences.setMockInitialValues({
          LocalStorageService.secureStorageInitializedKey: true,
        });

        final coordinator = SecureAuthStorageCoordinator(
          persistSessionKey: sessionKey,
        );
        final localStorage = SecureAuthLocalStorage(coordinator: coordinator);
        final gotrueStorage = SecureGotrueAsyncStorage(
          coordinator: coordinator,
        );
        await localStorage.initialize();

        fakeChannel.throwPlatformExceptionOnRead = true;
        fakeChannel.throwPlatformExceptionOnContainsKey = true;

        expect(await localStorage.accessToken(), isNull);
        expect(await localStorage.hasAccessToken(), isFalse);
        expect(await gotrueStorage.getItem(key: verifierKey), isNull);
        expect(fakeChannel.calls.where((c) => c == 'delete').length, greaterThanOrEqualTo(2));
        expect(fakeChannel.store[sessionKey], isNull);
        expect(fakeChannel.store[verifierKey], isNull);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(sessionKey), isNull);
        expect(prefs.getString(verifierKey), isNull);
      },
    );

    test(
      '3b. MissingPluginException falls back to instance-scoped RAM storage in Flutter test environment without writing cleartext disk keys',
      () async {
        expect(Platform.environment['FLUTTER_TEST'], 'true');
        fakeChannel.throwMissingPluginOnAll = true;
        SharedPreferences.setMockInitialValues({});

        final coordinatorA = SecureAuthStorageCoordinator(
          persistSessionKey: 'sb-testproj-auth-token',
        );
        final storageA = SecureAuthLocalStorage(coordinator: coordinatorA);
        final gotrueA = SecureGotrueAsyncStorage(coordinator: coordinatorA);
        await storageA.initialize();
        await storageA.persistSession('ram-session-a');
        await gotrueA.setItem(
          key: 'supabase.auth.token-code-verifier',
          value: 'ram-pkce-a',
        );

        expect(await storageA.hasAccessToken(), isTrue);
        expect(await storageA.accessToken(), 'ram-session-a');
        expect(
          await gotrueA.getItem(key: 'supabase.auth.token-code-verifier'),
          'ram-pkce-a',
        );

        // Must never write cleartext to SharedPreferences.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('sb-testproj-auth-token'), isNull);
        expect(prefs.getString('supabase.auth.token-code-verifier'), isNull);

        // Instance-scoped: a separate coordinator does not see coordinatorA's RAM entries.
        final coordinatorB = SecureAuthStorageCoordinator(
          persistSessionKey: 'sb-testproj-auth-token',
        );
        final storageB = SecureAuthLocalStorage(coordinator: coordinatorB);
        await storageB.initialize();
        expect(await storageB.hasAccessToken(), isFalse);
        expect(await storageB.accessToken(), isNull);
      },
    );

    test(
      '3c. MissingPluginException in non-test production mode NEVER falls back to RAM or cleartext SharedPreferences',
      () async {
        fakeChannel.throwMissingPluginOnAll = true;
        SharedPreferences.setMockInitialValues({
          'sb-testproj-auth-token': 'legacy-cleartext-should-not-vanish',
        });

        final prodCoordinator = SecureAuthStorageCoordinator(
          persistSessionKey: 'sb-testproj-auth-token',
          allowInMemoryTestFallback: false,
        );
        final prodLocalStorage = SecureAuthLocalStorage(
          coordinator: prodCoordinator,
        );
        final prodGotrueStorage = SecureGotrueAsyncStorage(
          coordinator: prodCoordinator,
        );

        await expectLater(
          prodLocalStorage.initialize(),
          throwsA(isA<MissingPluginException>()),
        );
        await expectLater(
          prodLocalStorage.persistSession('should-fail'),
          throwsA(isA<MissingPluginException>()),
        );
        await expectLater(
          prodLocalStorage.accessToken(),
          throwsA(isA<MissingPluginException>()),
        );
        await expectLater(
          prodGotrueStorage.getItem(key: 'supabase.auth.token-code-verifier'),
          throwsA(isA<MissingPluginException>()),
        );

        // Legacy key was not deleted before secure migration succeeded.
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('sb-testproj-auth-token'),
          'legacy-cleartext-should-not-vanish',
        );
      },
    );

    test(
      '4. Supabase URL/deep-link validation and canonical uz.bilimyol.mobile + allowBackup=false configs',
      () {
        expect(
          SupabaseConfig.isValidSupabaseUrl('https://abcxyz.supabase.co'),
          isTrue,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://127.0.0.1:54321'),
          isTrue,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://localhost:54321'),
          isTrue,
        );
        expect(SupabaseConfig.isValidSupabaseUrl(''), isFalse);
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://abcxyz.supabase.co'),
          isFalse,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://192.168.1.25:54321'),
          isFalse,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('ftp://abcxyz.supabase.co'),
          isFalse,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('javascript:alert(1)'),
          isFalse,
        );

        // Allowed callback-parameterized URIs
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('uz.bilimyol.mobile://auth/reset-password?code=pkce_123'),
          ),
          isTrue,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse(
              'uz.bilimyol.mobile://auth/reset-password#access_token=jwt_123',
            ),
          ),
          isTrue,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse(
              'uz.bilimyol.mobile://auth/reset-password?token_hash=th_123',
            ),
          ),
          isTrue,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse(
              'uz.bilimyol.mobile://auth/reset-password?error=access_denied',
            ),
          ),
          isTrue,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('https://bilimyol.uz/reset-password?code=pkce_123'),
          ),
          isTrue,
        );

        // Rejected bare URIs, empty params, wrong paths, wrong hosts, non-HTTPS
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('uz.bilimyol.mobile://auth/reset-password'),
          ),
          isFalse,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('https://bilimyol.uz/reset-password'),
          ),
          isFalse,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('uz.bilimyol.mobile://auth/reset-password?code='),
          ),
          isFalse,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('uz.bilimyol.mobile://auth/reset-password?foo=bar'),
          ),
          isFalse,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('uz.bilimyol.mobile://auth/callback?code=123'),
          ),
          isFalse,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('uz.bilimyol.mobile://evil/reset-password?code=123'),
          ),
          isFalse,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('https://evil.example/reset-password?code=123'),
          ),
          isFalse,
        );
        expect(
          SupabaseConfig.isAllowedAuthRedirectUri(
            Uri.parse('http://bilimyol.uz/reset-password?code=123'),
          ),
          isFalse,
        );

        // Platform canonical IDs and allowBackup="false"
        final mobileDir = _resolveMobileDir();
        final gradle = File(
          '${mobileDir.path}/android/app/build.gradle.kts',
        ).readAsStringSync();
        expect(gradle, contains('applicationId = "uz.bilimyol.mobile"'));
        expect(gradle, contains('namespace = "uz.bilimyol.bilimyol_mobile"'));

        final manifest = File(
          '${mobileDir.path}/android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        expect(manifest, contains('android:allowBackup="false"'));

        final iosPbxproj = File(
          '${mobileDir.path}/ios/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync();
        expect(
          RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = uz\.bilimyol\.mobile;')
              .allMatches(iosPbxproj)
              .length,
          3,
        );
        expect(
          RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = uz\.bilimyol\.mobile\.RunnerTests;')
              .allMatches(iosPbxproj)
              .length,
          3,
        );
        expect(iosPbxproj, isNot(contains('bilimyolMobile')));

        final macosXcconfig = File(
          '${mobileDir.path}/macos/Runner/Configs/AppInfo.xcconfig',
        ).readAsStringSync();
        expect(
          macosXcconfig,
          contains('PRODUCT_BUNDLE_IDENTIFIER = uz.bilimyol.mobile'),
        );

        final macosPbxproj = File(
          '${mobileDir.path}/macos/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync();
        expect(
          RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = uz\.bilimyol\.mobile\.RunnerTests;')
              .allMatches(macosPbxproj)
              .length,
          3,
        );
        expect(macosPbxproj, isNot(contains('bilimyolMobile')));
      },
    );

    test(
      '5. verifyActiveSessionOrSignOut() refreshes expired >1h sessions, signs out locally on 401/403, and ignores offline TimeoutException/SocketException',
      () async {
        // 5a: Expired (>1h) session calls refreshSession() (NOT getUser()) and stays signed in.
        final requestedPathsA = <String>[];
        final expiredSession = _buildTestSession(userId: 'user-a', expired: true);
        final refreshedSession = _buildTestSession(
          userId: 'user-a',
          expired: false,
        );
        final clientA = GoTrueClient(
          url: 'https://testproj.supabase.co/auth/v1',
          autoRefreshToken: false,
          httpClient: MockClient((request) async {
            requestedPathsA.add('${request.url.path}?${request.url.query}');
            if (request.url.path.endsWith('/token') &&
                request.url.queryParameters['grant_type'] == 'refresh_token') {
              return http.Response(jsonEncode(refreshedSession.toJson()), 200);
            }
            return http.Response('{"error":"unexpected"}', 500);
          }),
        );
        addTearDown(clientA.dispose);
        await clientA.setInitialSession(jsonEncode(expiredSession.toJson()));

        await SupabaseConfig.verifyActiveSessionOrSignOut(authClient: clientA);
        expect(
          requestedPathsA,
          anyElement(contains('/token?grant_type=refresh_token')),
        );
        expect(requestedPathsA, isNot(anyElement(contains('/user'))));
        expect(clientA.currentSession?.user.id, 'user-a');

        // 5b: Non-expired session calls getUser(); 401/403 signs out locally.
        final requestedPathsB = <String>[];
        final activeSession = _buildTestSession(userId: 'user-b', expired: false);
        final clientB = GoTrueClient(
          url: 'https://testproj.supabase.co/auth/v1',
          autoRefreshToken: false,
          httpClient: MockClient((request) async {
            requestedPathsB.add(request.url.path);
            if (request.url.path.endsWith('/user')) {
              return http.Response(
                jsonEncode({'message': 'Session revoked', 'code': 'session_not_found'}),
                401,
              );
            }
            return http.Response('{}', 200);
          }),
        );
        addTearDown(clientB.dispose);
        await clientB.setInitialSession(jsonEncode(activeSession.toJson()));

        await SupabaseConfig.verifyActiveSessionOrSignOut(authClient: clientB);
        expect(requestedPathsB, anyElement(endsWith('/user')));
        expect(clientB.currentSession, isNull);

        // 5c: Offline SocketException keeps session intact.
        final offlineSession = _buildTestSession(
          userId: 'user-c',
          expired: false,
        );
        final clientC = GoTrueClient(
          url: 'https://testproj.supabase.co/auth/v1',
          autoRefreshToken: false,
          httpClient: MockClient((request) async {
            throw const SocketException('Network unreachable');
          }),
        );
        addTearDown(clientC.dispose);
        await clientC.setInitialSession(jsonEncode(offlineSession.toJson()));

        await SupabaseConfig.verifyActiveSessionOrSignOut(authClient: clientC);
        expect(clientC.currentSession?.user.id, 'user-c');

        // 5d: Bounded timeout ignores TimeoutException and keeps session intact.
        final slowSession = _buildTestSession(userId: 'user-d', expired: false);
        final neverCompletes = Completer<http.Response>();
        final clientD = GoTrueClient(
          url: 'https://testproj.supabase.co/auth/v1',
          autoRefreshToken: false,
          httpClient: MockClient((request) => neverCompletes.future),
        );
        addTearDown(clientD.dispose);
        await clientD.setInitialSession(jsonEncode(slowSession.toJson()));

        await SupabaseConfig.verifyActiveSessionOrSignOut(
          authClient: clientD,
          timeout: const Duration(milliseconds: 50),
        );
        expect(clientD.currentSession?.user.id, 'user-d');
      },
    );
  });
}
