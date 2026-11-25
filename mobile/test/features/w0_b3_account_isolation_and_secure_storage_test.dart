import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/auth/secure_auth_storage.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_lessons_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_learner_repository.dart';
import 'package:bilimyol_mobile/domain/entities/course.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/skill.dart';
import 'package:bilimyol_mobile/domain/repositories/i_course_repository.dart';
import 'package:bilimyol_mobile/features/auth/login_screen.dart';
import 'package:bilimyol_mobile/features/auth/reset_password_screen.dart';
import 'package:bilimyol_mobile/features/lesson/reading_position.dart';
import 'package:bilimyol_mobile/features/profile/profile_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

String _encodeJwt({
  required String sub,
  required int exp,
  List<Map<String, Object?>>? amr,
  int? iat,
}) {
  String b64(Map<String, Object?> jsonMap) => base64Url
      .encode(utf8.encode(jsonEncode(jsonMap)))
      .replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({
    'sub': sub,
    'exp': exp,
    'iat': ?iat,
    'amr': ?amr,
  })}.sig';
}

Session _buildTestSession({
  required String userId,
  required bool expired,
  List<Map<String, Object?>>? amr,
  int? iat,
}) {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = expired ? nowSec - 3600 : nowSec + 3600;
  return Session(
    accessToken: _encodeJwt(sub: userId, exp: exp, amr: amr, iat: iat),
    refreshToken: 'refresh-$userId',
    expiresIn: 3600,
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {'first_name': 'Learner'},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: '$userId@example.test',
    ),
  );
}

String? _subFromAuthHeader(String? authHeader) {
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
  final token = authHeader.substring('Bearer '.length).trim();
  final parts = token.split('.');
  if (parts.length < 2) return null;
  final normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
  final padded = normalized.padRight(
    normalized.length + ((4 - (normalized.length % 4)) % 4),
    '=',
  );
  final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
  return decoded is Map<String, dynamic> ? decoded['sub'] as String? : null;
}

SupabaseClient _buildMockSupabaseClient({
  Map<String, Map<String, dynamic>>? learnerProfilesByUserId,
  Map<String, Map<String, dynamic>>? Function()? learnerProfilesByUserIdResolver,
  bool delayProfileFetch = false,
  Completer<void>? profileFetchGate,
  Completer<void>? Function()? profileFetchGateResolver,
  void Function(String path)? onRequest,
}) {
  return SupabaseClient(
    'https://testproj.supabase.co',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      onRequest?.call(request.url.path);
      final path = request.url.path;
      final uid =
          _subFromAuthHeader(request.headers['Authorization']) ?? 'user-a';

      http.Response jsonResp(
        Object body,
        int status, {
        Map<String, String> headers = const {'content-type': 'application/json'},
      }) {
        final encoded = body is String ? body : jsonEncode(body);
        return http.Response(
          encoded,
          status,
          request: request,
          headers: headers,
        );
      }

      if (path.endsWith('/auth/v1/token') &&
          request.url.queryParameters['grant_type'] == 'password') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final email = (body['email'] as String? ?? 'user-a@example.test');
        final derivedId = email.split('@').first;
        final session = _buildTestSession(userId: derivedId, expired: false);
        return jsonResp(session.toJson(), 200);
      }

      if (path.endsWith('/auth/v1/logout')) {
        return http.Response('', 204, request: request);
      }

      if (path.endsWith('/auth/v1/user') && request.method == 'PUT') {
        final session = _buildTestSession(
          userId: uid,
          expired: false,
          amr: [
            {'method': 'recovery', 'timestamp': 1000},
          ],
        );
        return jsonResp(session.user.toJson(), 200);
      }

      if (path.endsWith('/auth/v1/user')) {
        final session = _buildTestSession(userId: uid, expired: false);
        return jsonResp(session.user.toJson(), 200);
      }

      if (path.endsWith('/rest/v1/profiles')) {
        final gate = profileFetchGateResolver?.call() ?? profileFetchGate;
        if ((delayProfileFetch || gate != null) && gate != null) {
          await gate.future;
        }
        return jsonResp({
          'id': uid,
          'first_name': 'User $uid',
          'last_name': '',
          'display_name': 'User $uid',
          'email': '$uid@example.test',
          'avatar_url': null,
        }, 200);
      }

      if (path.endsWith('/rest/v1/learner_profiles')) {
        final profilesMap =
            learnerProfilesByUserIdResolver?.call() ?? learnerProfilesByUserId;
        final row = profilesMap?[uid] ??
            {
              'user_id': uid,
              'selected_course_id': 'course_eng_01',
              'goal': 'mastery',
              'daily_minutes': 15,
              'initial_level': 'beginner',
              'course_levels': const <String, dynamic>{},
              'placement_score_by_course': const <String, dynamic>{},
              'placement_cefr_by_course': const <String, dynamic>{},
            };
        return jsonResp(row, 200);
      }

      if (path.endsWith('/rest/v1/gamification_profiles')) {
        return jsonResp({
          'user_id': uid,
          'xp': 120,
          'streak_days': 3,
          'last_activity_date': '2026-11-25',
        }, 200);
      }

      if (path.endsWith('/rest/v1/learner_skill_scores') ||
          path.endsWith('/rest/v1/lesson_progress') ||
          path.endsWith('/rest/v1/reinforcement_attempts') ||
          path.endsWith('/rest/v1/roadmap_nodes')) {
        return jsonResp('[]', 200);
      }

      return jsonResp('[]', 200);
    }),
  );
}

class _SpyCourseRepository extends InMemoryCourseRepository {
  int getAllCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<Course>> getAllCourses() async {
    getAllCalls++;
    if (gate != null) await gate!.future;
    return super.getAllCourses();
  }
}

class _ThrowingCourseRepository implements ICourseRepository {
  @override
  Future<List<Course>> getAllCourses() =>
      throw StateError('Should not query courses while logged out');

  @override
  Future<Course?> getCourseById(String id) =>
      throw StateError('Should not query courses while logged out');

  @override
  Future<List<Question>> getPlacementQuestions(String courseId) =>
      throw StateError('Should not query placement while logged out');

  @override
  Future<List<Skill>> getSkillsByCourseId(String courseId) =>
      throw StateError('Should not query skills while logged out');
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

  group('W0-B3 Task 4 Part B — Multi-Account Isolation, Scoped SRS/Reading & Recovery/Hydration Guards', () {
    late bool prevRemote;
    late bool prevTour;
    late bool prevDemo;
    late bool prevStarted;
    SupabaseClient? widgetScopedClient;
    Map<String, Map<String, dynamic>>? mockProfilesOverride;
    Completer<void>? mockProfileGate;

    setUp(() {
      prevRemote = SupabaseConfig.hasRemoteConfiguration;
      prevTour = productTourCompleted.value;
      prevDemo = demoSessionActive.value;
      prevStarted = activeSessionHasStartedCourse.value;
      SharedPreferences.setMockInitialValues({});
      SupabaseConfig.hasRemoteConfiguration = false;
      productTourCompleted.value = true;
      demoSessionActive.value = false;
      activeSessionHasStartedCourse.value = false;
      postLoginHydrating.value = false;
      mockProfilesOverride = null;
      mockProfileGate = null;
      widgetScopedClient = _buildMockSupabaseClient(
        learnerProfilesByUserIdResolver: () => mockProfilesOverride,
        profileFetchGateResolver: () => mockProfileGate,
      );
    });

    tearDown(() async {
      await SupabaseConfig.bindClientForTesting(null);
      await widgetScopedClient?.dispose();
      widgetScopedClient = null;
      SupabaseConfig.hasRemoteConfiguration = prevRemote;
      productTourCompleted.value = prevTour;
      demoSessionActive.value = prevDemo;
      activeSessionHasStartedCourse.value = prevStarted;
      postLoginHydrating.value = false;
    });

    test(
      '1. LessonReadingPositionStore enforces tupleKey isolation across accounts and retains Account A progress on re-login',
      () async {
        final lesson = a1LessonsData['lesson_eng_starter']!;
        SharedPreferences.setMockInitialValues({});

        // Account A saves step = 3.
        await LessonReadingPositionStore.saveStepIndex(
          lesson,
          3,
          accountId: 'user-a',
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.get(LessonReadingPositionStore.primaryKey(lesson.id)),
          isNull,
        );
        expect(
          await LessonReadingPositionStore.readStepIndex(
            lesson,
            accountId: 'user-a',
          ),
          3,
        );

        // Account B sees 0 (no leakage from Account A), saves step = 1, logs out.
        expect(
          await LessonReadingPositionStore.readStepIndex(
            lesson,
            accountId: 'user-b',
          ),
          0,
        );
        await LessonReadingPositionStore.saveStepIndex(
          lesson,
          1,
          accountId: 'user-b',
        );
        expect(
          await LessonReadingPositionStore.readStepIndex(
            lesson,
            accountId: 'user-b',
          ),
          1,
        );

        // Account A logs back in and retains step = 3 without Account B contamination.
        expect(
          await LessonReadingPositionStore.readStepIndex(
            lesson,
            accountId: 'user-a',
          ),
          3,
        );

        // Clearing Account B leaves Account A intact.
        await LessonReadingPositionStore.clearStepIndex(
          lesson,
          accountId: 'user-b',
        );
        expect(
          await LessonReadingPositionStore.readStepIndex(
            lesson,
            accountId: 'user-b',
          ),
          0,
        );
        expect(
          await LessonReadingPositionStore.readStepIndex(
            lesson,
            accountId: 'user-a',
          ),
          3,
        );

        // Standalone accountId == null calls still read/write/clear primaryKey.
        await LessonReadingPositionStore.saveStepIndex(lesson, 2);
        expect(
          prefs.getString(LessonReadingPositionStore.primaryKey(lesson.id)),
          '2',
        );
        expect(await LessonReadingPositionStore.readStepIndex(lesson), 2);
        await LessonReadingPositionStore.clearStepIndex(lesson);
        expect(await LessonReadingPositionStore.readStepIndex(lesson), 0);
        expect(
          await LessonReadingPositionStore.readStepIndex(
            lesson,
            accountId: 'user-a',
          ),
          3,
        );
      },
    );

    test(
      '2. Multi-account SRS isolation scopes bilimyol.srs.<uid>, leaves bilimyol.demo_learner_snapshot untouched, and retains Account A SRS on re-login',
      () async {
        SupabaseConfig.hasRemoteConfiguration = true;
        SharedPreferences.setMockInitialValues({});
        final storage = await LocalStorageService.load();

        final client = _buildMockSupabaseClient();
        addTearDown(client.dispose);
        await SupabaseConfig.bindClientForTesting(client, storage: storage);

        // Account A logs in and reviews 2 flashcards.
        await client.auth.setInitialSession(
          jsonEncode(_buildTestSession(userId: 'user-a', expired: false).toJson()),
        );
        final repoA = SupabaseLearnerRepository(storage: storage);
        final afterA1 = await repoA.recordFlashcardReview(
          courseId: 'course_eng_01',
          cardId: 'fc_a_1',
          remembered: true,
        );
        expect(
          afterA1.flashcardSrsByCourse['course_eng_01']?.keys,
          contains('fc_a_1'),
        );
        expect(await storage.getDemoLearnerSnapshot(), isNull);
        expect(
          await storage.getUserFlashcardSrsJson('user-a'),
          isNotNull,
        );

        // Logout Account A -> Login Account B.
        await repoA.clearLocalState();
        await client.auth.signOut(scope: SignOutScope.local);
        await client.auth.setInitialSession(
          jsonEncode(_buildTestSession(userId: 'user-b', expired: false).toJson()),
        );
        final repoB = SupabaseLearnerRepository(storage: storage);
        final profileB = await repoB.getProfile();
        expect(profileB.flashcardSrsByCourse, isEmpty);

        // Account B reviews 1 card -> sees 0 cards from Account A.
        final afterB1 = await repoB.recordFlashcardReview(
          courseId: 'course_eng_01',
          cardId: 'fc_b_1',
          remembered: false,
        );
        expect(
          afterB1.flashcardSrsByCourse['course_eng_01']?.keys.toList(),
          equals(['fc_b_1']),
        );
        expect(await storage.getDemoLearnerSnapshot(), isNull);

        // Logout Account B -> logged-out SRS write is blocked.
        await repoB.clearLocalState();
        await client.auth.signOut(scope: SignOutScope.local);
        await expectLater(
          repoB.recordFlashcardReview(
            courseId: 'course_eng_01',
            cardId: 'fc_logged_out',
            remembered: true,
          ),
          throwsStateError,
        );

        // Account A logs back in -> retains Account A's SRS without Account B contamination.
        await client.auth.setInitialSession(
          jsonEncode(_buildTestSession(userId: 'user-a', expired: false).toJson()),
        );
        final repoA2 = SupabaseLearnerRepository(storage: storage);
        final reloadedA = await repoA2.getProfile();
        expect(
          reloadedA.flashcardSrsByCourse['course_eng_01']?.keys.toList(),
          equals(['fc_a_1']),
        );
        expect(
          reloadedA.flashcardSrsByCourse['course_eng_01']?['fc_a_1']?.status,
          'remembered',
        );
        expect(await storage.getDemoLearnerSnapshot(), isNull);

        // Mid-flight account change during post-write getProfile() throws StateError.
        final srsProfileGate = Completer<void>();
        final midFlightClient = _buildMockSupabaseClient(
          delayProfileFetch: true,
          profileFetchGate: srsProfileGate,
        );
        addTearDown(midFlightClient.dispose);
        await midFlightClient.auth.setInitialSession(
          jsonEncode(_buildTestSession(userId: 'user-a', expired: false).toJson()),
        );
        final midFlightRepo = SupabaseLearnerRepository(
          storage: storage,
          client: midFlightClient,
        );
        final inFlightReview = expectLater(
          midFlightRepo.recordFlashcardReview(
            courseId: 'course_eng_01',
            cardId: 'fc_a_2',
            remembered: true,
          ),
          throwsStateError,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await midFlightClient.auth.signOut(scope: SignOutScope.local);
        srsProfileGate.complete();
        await inFlightReview;
      },
    );

    testWidgets(
      '3. All 4 logout paths reset activeSessionHasStartedCourse, clear _fallbackRepo, recreate all 5 StateNotifiers, block logged-out writes, and preserve quick-demo entry',
      (tester) async {
        // 3a: Background AuthChangeEvent.signedOut + logged-out write blocking + null -> 'demo' preservation.
        SupabaseConfig.hasRemoteConfiguration = true;
        SharedPreferences.setMockInitialValues({
          LocalStorageService.demoLearnerSnapshotKey: '{"stale":true}',
        });
        final storage = await LocalStorageService.load();
        final client = widgetScopedClient!;
        await SupabaseConfig.bindClientForTesting(client, storage: storage);
        await client.auth.setInitialSession(
          jsonEncode(_buildTestSession(userId: 'user-a', expired: false).toJson()),
        );

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            courseRepositoryProvider.overrideWithValue(_SpyCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(authSessionUserIdProvider), 'user-a');
        final learnerBefore = container.read(learnerStateNotifierProvider.notifier);
        final courseBefore = container.read(courseStateNotifierProvider.notifier);
        final roadmapBefore = container.read(roadmapStateNotifierProvider.notifier);
        final placementBefore = container.read(placementStateNotifierProvider.notifier);
        final lessonBefore = container.read(lessonSessionNotifierProvider.notifier);
        activeSessionHasStartedCourse.value = true;

        // Path 4: Background AuthChangeEvent.signedOut.
        await client.auth.signOut(scope: SignOutScope.local);
        await tester.pump();

        expect(container.read(authSessionUserIdProvider), isNull);
        expect(activeSessionHasStartedCourse.value, isFalse);
        expect(await storage.getDemoLearnerSnapshot(), isNull);
        expect(
          identical(container.read(learnerStateNotifierProvider.notifier), learnerBefore),
          isFalse,
        );
        expect(
          identical(container.read(courseStateNotifierProvider.notifier), courseBefore),
          isFalse,
        );
        expect(
          identical(container.read(roadmapStateNotifierProvider.notifier), roadmapBefore),
          isFalse,
        );
        expect(
          identical(container.read(placementStateNotifierProvider.notifier), placementBefore),
          isFalse,
        );
        expect(
          identical(container.read(lessonSessionNotifierProvider.notifier), lessonBefore),
          isFalse,
        );

        // Logged-out background learner/course writes are blocked when scope == null.
        await container.read(learnerStateNotifierProvider.notifier).loadProfile();
        await container.read(learnerStateNotifierProvider.notifier).recordFlashcardReview(
          courseId: 'course_eng_01',
          cardId: 'fc_blocked',
          remembered: true,
        );
        expect(container.read(learnerStateNotifierProvider).valueOrNull, isNull);
        expect(await storage.getUserFlashcardSrsJson('user-a'), isNull);

        // Quick-demo entry (null -> 'demo') must NOT wipe activeSessionHasStartedCourse.
        SupabaseConfig.hasRemoteConfiguration = false;
        activeSessionHasStartedCourse.value = true;
        demoSessionActive.value = true;
        await tester.pump();
        expect(container.read(authSessionUserIdProvider), 'demo');
        expect(activeSessionHasStartedCourse.value, isTrue);

        // Path 2: Demo logout via ProfileScreen clears _fallbackRepo, resets flag, recreates all 5 notifiers.
        await storage.setDemoLearnerSnapshot('{"version":1,"profile":{"id":"demo"}}');
        final demoLearner = container.read(learnerStateNotifierProvider.notifier);
        final demoCourse = container.read(courseStateNotifierProvider.notifier);
        final demoRoadmap = container.read(roadmapStateNotifierProvider.notifier);
        final demoPlacement = container.read(placementStateNotifierProvider.notifier);
        final demoLesson = container.read(lessonSessionNotifierProvider.notifier);

        final demoRouter = GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            GoRoute(path: '/login', builder: (_, _) => const Text('LOGIN_DEST')),
          ],
        );
        addTearDown(demoRouter.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              locale: const Locale('uz'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              routerConfig: demoRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final logoutBtn = find.text(AppStrings.uz.logout);
        await tester.ensureVisible(logoutBtn);
        await tester.tap(logoutBtn);
        await tester.pumpAndSettle();

        expect(demoSessionActive.value, isFalse);
        expect(activeSessionHasStartedCourse.value, isFalse);
        expect(await storage.getDemoLearnerSnapshot(), isNull);
        expect(container.read(authSessionUserIdProvider), isNull);
        expect(
          identical(container.read(learnerStateNotifierProvider.notifier), demoLearner),
          isFalse,
        );
        expect(
          identical(container.read(courseStateNotifierProvider.notifier), demoCourse),
          isFalse,
        );
        expect(
          identical(container.read(roadmapStateNotifierProvider.notifier), demoRoadmap),
          isFalse,
        );
        expect(
          identical(container.read(placementStateNotifierProvider.notifier), demoPlacement),
          isFalse,
        );
        expect(
          identical(container.read(lessonSessionNotifierProvider.notifier), demoLesson),
          isFalse,
        );
        expect(find.text('LOGIN_DEST'), findsOneWidget);

        // Path 1: Live logout via ProfileScreen.
        SupabaseConfig.hasRemoteConfiguration = true;
        await client.auth.setInitialSession(
          jsonEncode(_buildTestSession(userId: 'user-a', expired: false).toJson()),
        );
        await tester.pump();
        await storage.setDemoLearnerSnapshot('{"stale_live":true}');
        activeSessionHasStartedCourse.value = true;

        final liveContainer = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            courseRepositoryProvider.overrideWithValue(_SpyCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(liveContainer.dispose);
        final liveLearner = liveContainer.read(learnerStateNotifierProvider.notifier);
        final liveCourse = liveContainer.read(courseStateNotifierProvider.notifier);
        final liveRoadmap = liveContainer.read(roadmapStateNotifierProvider.notifier);
        final livePlacement = liveContainer.read(placementStateNotifierProvider.notifier);
        final liveLesson = liveContainer.read(lessonSessionNotifierProvider.notifier);

        final liveRouter = GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            GoRoute(path: '/login', builder: (_, _) => const Text('LOGIN_DEST_LIVE')),
          ],
        );
        addTearDown(liveRouter.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: liveContainer,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              locale: const Locale('uz'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              routerConfig: liveRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final liveLogoutBtn = find.text(AppStrings.uz.logout);
        await tester.ensureVisible(liveLogoutBtn);
        await tester.tap(liveLogoutBtn);
        await tester.pumpAndSettle();

        expect(client.auth.currentSession, isNull);
        expect(activeSessionHasStartedCourse.value, isFalse);
        expect(await storage.getDemoLearnerSnapshot(), isNull);
        expect(
          identical(liveContainer.read(learnerStateNotifierProvider.notifier), liveLearner),
          isFalse,
        );
        expect(
          identical(liveContainer.read(courseStateNotifierProvider.notifier), liveCourse),
          isFalse,
        );
        expect(
          identical(liveContainer.read(roadmapStateNotifierProvider.notifier), liveRoadmap),
          isFalse,
        );
        expect(
          identical(liveContainer.read(placementStateNotifierProvider.notifier), livePlacement),
          isFalse,
        );
        expect(
          identical(liveContainer.read(lessonSessionNotifierProvider.notifier), liveLesson),
          isFalse,
        );
        expect(find.text('LOGIN_DEST_LIVE'), findsOneWidget);

        // Path 3: Recovery _leave() via ResetPasswordScreen.
        await client.auth.setInitialSession(
          jsonEncode(
            _buildTestSession(
              userId: 'user-rec',
              expired: false,
              amr: [
                {'method': 'recovery', 'timestamp': 1000},
              ],
            ).toJson(),
          ),
        );
        await tester.pump();
        expect(SupabaseConfig.isRecoveryActive, isTrue);
        activeSessionHasStartedCourse.value = true;
        await storage.setDemoLearnerSnapshot('{"stale_rec":true}');

        final recContainer = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            courseRepositoryProvider.overrideWithValue(_SpyCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(recContainer.dispose);
        final recLearner = recContainer.read(learnerStateNotifierProvider.notifier);
        final recCourse = recContainer.read(courseStateNotifierProvider.notifier);
        final recRoadmap = recContainer.read(roadmapStateNotifierProvider.notifier);
        final recPlacement = recContainer.read(placementStateNotifierProvider.notifier);
        final recLesson = recContainer.read(lessonSessionNotifierProvider.notifier);

        final recRouter = GoRouter(
          initialLocation: '/reset-password',
          routes: [
            GoRoute(
              path: '/reset-password',
              builder: (_, _) => const ResetPasswordScreen(),
            ),
            GoRoute(path: '/login', builder: (_, _) => const Text('LOGIN_DEST_REC')),
          ],
        );
        addTearDown(recRouter.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: recContainer,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              locale: const Locale('uz'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              routerConfig: recRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cancelBtn = find.text(AppStrings.uz.cancel);
        await tester.ensureVisible(cancelBtn);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(client.auth.currentSession, isNull);
        expect(SupabaseConfig.isRecoveryActive, isFalse);
        expect(await storage.getRecoveryUserId(), isNull);
        expect(activeSessionHasStartedCourse.value, isFalse);
        expect(await storage.getDemoLearnerSnapshot(), isNull);
        expect(
          identical(recContainer.read(learnerStateNotifierProvider.notifier), recLearner),
          isFalse,
        );
        expect(
          identical(recContainer.read(courseStateNotifierProvider.notifier), recCourse),
          isFalse,
        );
        expect(
          identical(recContainer.read(roadmapStateNotifierProvider.notifier), recRoadmap),
          isFalse,
        );
        expect(
          identical(recContainer.read(placementStateNotifierProvider.notifier), recPlacement),
          isFalse,
        );
        expect(
          identical(recContainer.read(lessonSessionNotifierProvider.notifier), recLesson),
          isFalse,
        );
        expect(find.text('LOGIN_DEST_REC'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Logged-out /welcome and /login redirects never read learner/course providers, and postLoginHydrating holds /login until loadProfile() + init() settle',
      (tester) async {
        // 4a: Logged-out and recovery redirects must NOT touch learner/course providers.
        final throwingContainer = ProviderContainer(
          overrides: [
            courseRepositoryProvider.overrideWithValue(_ThrowingCourseRepository()),
          ],
        );
        addTearDown(throwingContainer.dispose);

        late bool loggedOutResult;
        late bool recoveryResult;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: throwingContainer,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  loggedOutResult = resolveAppHasStartedCourse(
                    context,
                    isSessionActive: false,
                    recoveryActive: false,
                  );
                  recoveryResult = resolveAppHasStartedCourse(
                    context,
                    isSessionActive: true,
                    recoveryActive: true,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        expect(loggedOutResult, isFalse);
        expect(recoveryResult, isFalse);

        // Also test resolveAppRedirect directly with isHydratingProfile.
        expect(
          resolveAppRedirect(
            path: '/login',
            uri: Uri.parse('/login'),
            recoveryActive: false,
            isRemoteConfigured: true,
            isLoggedIn: true,
            isDemoActive: false,
            isTourCompleted: true,
            hasStartedAnyCourse: false,
            isHydratingProfile: true,
          ),
          isNull,
        );
        expect(
          resolveAppRedirect(
            path: '/login',
            uri: Uri.parse('/login'),
            recoveryActive: false,
            isRemoteConfigured: true,
            isLoggedIn: true,
            isDemoActive: false,
            isTourCompleted: true,
            hasStartedAnyCourse: true,
            isHydratingProfile: false,
          ),
          '/dashboard',
        );

        // 4b: LoginScreen holds /login via postLoginHydrating while profile+courses load, then routes returning learner to /dashboard.
        SupabaseConfig.hasRemoteConfiguration = true;
        final storage = await LocalStorageService.load();
        final profileGate = Completer<void>();
        final coursesGate = Completer<void>();
        final spyCourseRepo = _SpyCourseRepository()..gate = coursesGate;

        mockProfilesOverride = {
          'user-returning': {
            'user_id': 'user-returning',
            'selected_course_id': 'course_math_01',
            'goal': 'mastery',
            'daily_minutes': 20,
            'initial_level': 'intermediate',
            'course_levels': {'course_math_01': 'intermediate'},
            'placement_score_by_course': const <String, dynamic>{},
            'placement_cefr_by_course': const <String, dynamic>{},
          },
        };
        mockProfileGate = profileGate;
        final client = widgetScopedClient!;
        await SupabaseConfig.bindClientForTesting(client, storage: storage);

        final loginContainer = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            courseRepositoryProvider.overrideWithValue(spyCourseRepo),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(loginContainer.dispose);

        final router = GoRouter(
          initialLocation: '/login',
          refreshListenable: Listenable.merge([
            SupabaseConfig.authUserIdListenable,
            SupabaseConfig.recoveryActiveListenable,
            SupabaseConfig.authStateRevisionListenable,
            postLoginHydrating,
            activeSessionHasStartedCourse,
          ]),
          redirect: (context, state) {
            final isLoggedIn =
                (SupabaseConfig.authUserIdListenable.value ??
                    SupabaseConfig.client?.auth.currentUser?.id) !=
                null;
            return resolveAppRedirect(
              path: state.matchedLocation,
              uri: state.uri,
              recoveryActive: SupabaseConfig.isRecoveryActive,
              isRemoteConfigured: SupabaseConfig.hasRemoteConfiguration,
              isLoggedIn: isLoggedIn,
              isDemoActive: demoSessionActive.value,
              isTourCompleted: productTourCompleted.value,
              hasStartedAnyCourse: resolveAppHasStartedCourse(
                context,
                isSessionActive: isLoggedIn,
                recoveryActive: SupabaseConfig.isRecoveryActive,
              ),
              isHydratingProfile: postLoginHydrating.value,
            );
          },
          routes: [
            GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
            GoRoute(path: '/courses', builder: (_, _) => const Text('COURSES_DEST')),
            GoRoute(path: '/dashboard', builder: (_, _) => const Text('DASHBOARD_DEST')),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: loginContainer,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              locale: const Locale('uz'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'user-returning@example.test');
        await tester.enterText(textFields.at(1), 'StrongPass123');
        final loginBtn = find.text(AppStrings.uz.loginAction);
        await tester.ensureVisible(loginBtn);
        await tester.tap(loginBtn);
        await tester.pump();
        await tester.pump();

        // signInWithPassword succeeded, but profile/courses are still hydrating: must hold /login!
        expect(postLoginHydrating.value, isTrue);
        expect(router.routeInformationProvider.value.uri.path, '/login');
        expect(find.text('COURSES_DEST'), findsNothing);

        // Complete hydration gates -> returning learner must land on /dashboard.
        profileGate.complete();
        coursesGate.complete();
        await tester.pumpAndSettle();

        expect(postLoginHydrating.value, isFalse);
        expect(activeSessionHasStartedCourse.value, isTrue);
        expect(router.routeInformationProvider.value.uri.path, '/dashboard');
        expect(find.text('DASHBOARD_DEST'), findsOneWidget);
      },
    );

    test(
      '5. Cold-start & restart recovery lock persists bilimyol.recovery_user_id before appRouter is read and clears on updateUser or signOut',
      () async {
        SupabaseConfig.hasRemoteConfiguration = true;
        SharedPreferences.setMockInitialValues({});
        final storage = await LocalStorageService.load();

        // Cold-start listener captures recovery before appRouter exists.
        final client1 = _buildMockSupabaseClient();
        addTearDown(client1.dispose);
        await SupabaseConfig.bindClientForTesting(client1, storage: storage);

        final recoverySession = _buildTestSession(
          userId: 'user-rec',
          expired: false,
          amr: [
            {'method': 'recovery', 'timestamp': 1000},
          ],
        );
        await client1.auth.setInitialSession(jsonEncode(recoverySession.toJson()));

        expect(SupabaseConfig.isRecoveryActive, isTrue);
        expect(await storage.getRecoveryUserId(), 'user-rec');
        expect(
          resolveAppRedirect(
            path: '/dashboard',
            uri: Uri.parse('/dashboard'),
            recoveryActive: SupabaseConfig.isRecoveryActive,
            isRemoteConfigured: true,
            isLoggedIn: true,
            isDemoActive: false,
            isTourCompleted: true,
            hasStartedAnyCourse: true,
          ),
          '/reset-password',
        );

        // App restart: new GoTrueClient + new LocalStorageService reading persisted bilimyol.recovery_user_id,
        // even with a refreshed session JWT lacking amr.
        await SupabaseConfig.bindClientForTesting(null);
        final restartedStorage = await LocalStorageService.load();
        final client2 = _buildMockSupabaseClient();
        addTearDown(client2.dispose);
        await client2.auth.setInitialSession(
          jsonEncode(_buildTestSession(userId: 'user-rec', expired: false).toJson()),
        );
        await SupabaseConfig.bindClientForTesting(client2, storage: restartedStorage);

        expect(SupabaseConfig.isRecoveryActive, isTrue);
        expect(await restartedStorage.getRecoveryUserId(), 'user-rec');

        // updateUser(password) clears recovery marker and prevents amr re-lock.
        await client2.auth.updateUser(UserAttributes(password: 'NewPass123!'));
        await Future<void>.delayed(Duration.zero);
        expect(SupabaseConfig.isRecoveryActive, isFalse);
        expect(await restartedStorage.getRecoveryUserId(), isNull);

        // signOut also clears recovery lock when active.
        await client2.auth.setInitialSession(jsonEncode(recoverySession.toJson()));
        await Future<void>.delayed(Duration.zero);
        expect(SupabaseConfig.isRecoveryActive, isTrue);
        await client2.auth.signOut(scope: SignOutScope.local);
        await Future<void>.delayed(Duration.zero);
        expect(SupabaseConfig.isRecoveryActive, isFalse);
        expect(await restartedStorage.getRecoveryUserId(), isNull);
      },
    );

    testWidgets(
      '6. Same-ProviderContainer logout -> re-login syncs auth state immediately without ReplaySubject race and routes returning learner to /dashboard',
      (tester) async {
        SupabaseConfig.hasRemoteConfiguration = true;
        final storage = await LocalStorageService.load();
        mockProfilesOverride = {
          'user-returning': {
            'user_id': 'user-returning',
            'selected_course_id': 'course_math_01',
            'goal': 'mastery',
            'daily_minutes': 20,
            'initial_level': 'intermediate',
            'course_levels': {'course_math_01': 'intermediate'},
            'placement_score_by_course': const <String, dynamic>{},
            'placement_cefr_by_course': const <String, dynamic>{},
          },
        };
        final client = widgetScopedClient!;
        await SupabaseConfig.bindClientForTesting(client, storage: storage);
        await client.auth.setInitialSession(
          jsonEncode(
            _buildTestSession(userId: 'user-returning', expired: false).toJson(),
          ),
        );

        final sameContainer = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            courseRepositoryProvider.overrideWithValue(_SpyCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(sameContainer.dispose);

        final router = GoRouter(
          initialLocation: '/profile',
          refreshListenable: Listenable.merge([
            SupabaseConfig.authUserIdListenable,
            SupabaseConfig.recoveryActiveListenable,
            SupabaseConfig.authStateRevisionListenable,
            postLoginHydrating,
            activeSessionHasStartedCourse,
          ]),
          redirect: (context, state) {
            final activeClient = SupabaseConfig.client;
            final isLoggedIn =
                (activeClient != null
                    ? activeClient.auth.currentUser?.id
                    : SupabaseConfig.authUserIdListenable.value) !=
                null;
            return resolveAppRedirect(
              path: state.matchedLocation,
              uri: state.uri,
              recoveryActive: SupabaseConfig.isRecoveryActive,
              isRemoteConfigured: SupabaseConfig.hasRemoteConfiguration,
              isLoggedIn: isLoggedIn,
              isDemoActive: demoSessionActive.value,
              isTourCompleted: productTourCompleted.value,
              hasStartedAnyCourse: resolveAppHasStartedCourse(
                context,
                isSessionActive: isLoggedIn,
                recoveryActive: SupabaseConfig.isRecoveryActive,
              ),
              isHydratingProfile: postLoginHydrating.value,
            );
          },
          routes: [
            GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            GoRoute(path: '/courses', builder: (_, _) => const Text('COURSES_DEST')),
            GoRoute(path: '/dashboard', builder: (_, _) => const Text('DASHBOARD_DEST')),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: sameContainer,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              locale: const Locale('uz'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: Logout from ProfileScreen in the existing ProviderContainer.
        final logoutBtn = find.text(AppStrings.uz.logout);
        await tester.ensureVisible(logoutBtn);
        await tester.tap(logoutBtn);
        await tester.pumpAndSettle();

        expect(client.auth.currentUser, isNull);
        expect(sameContainer.read(authSessionUserIdProvider), isNull);
        expect(router.routeInformationProvider.value.uri.path, '/login');
        // Ensure logged-out providers are initialized with sessionScope == null.
        expect(sameContainer.read(learnerStateNotifierProvider).valueOrNull, isNull);
        expect(sameContainer.read(courseStateNotifierProvider).courses, isEmpty);

        // Step 2: Re-login as returning learner in the SAME ProviderContainer.
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'user-returning@example.test');
        await tester.enterText(textFields.at(1), 'StrongPass123');
        final loginBtn = find.text(AppStrings.uz.loginAction);
        await tester.ensureVisible(loginBtn);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();

        expect(sameContainer.read(authSessionUserIdProvider), 'user-returning');
        expect(activeSessionHasStartedCourse.value, isTrue);
        expect(router.routeInformationProvider.value.uri.path, '/dashboard');
        expect(find.text('DASHBOARD_DEST'), findsOneWidget);
        expect(find.text('COURSES_DEST'), findsNothing);

        // Verify synchronous currentUser takes precedence over any lagging listenable
        // and syncCurrentAuthState() updates authUserIdListenable synchronously.
        await client.auth.signOut(scope: SignOutScope.local);
        sameContainer.invalidate(authSessionUserIdProvider);
        expect(sameContainer.read(authSessionUserIdProvider), isNull);
        SupabaseConfig.syncCurrentAuthState();
        expect(SupabaseConfig.authUserIdListenable.value, isNull);
      },
    );
  });
}
