import 'dart:convert';

import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/supabase_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/personalization/learning_start.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _makeJwt({required String role}) {
  String encode(Map<String, Object?> payload) =>
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'role': role, 'iss': 'supabase'})}.sig';
}

void main() {
  late bool previousRemote;
  late bool previousConfigured;
  late bool previousDemoActive;
  late bool? previousProdOverride;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previousRemote = SupabaseConfig.hasRemoteConfiguration;
    previousConfigured = SupabaseConfig.isConfigured;
    previousDemoActive = demoSessionActive.value;
    previousProdOverride = SupabaseConfig.isProductionEnvOverride;

    SupabaseConfig.hasRemoteConfiguration = false;
    SupabaseConfig.isConfigured = false;
    demoSessionActive.value = false;
    SupabaseConfig.isProductionEnvOverride = null;
  });

  tearDown(() {
    SupabaseConfig.hasRemoteConfiguration = previousRemote;
    SupabaseConfig.isConfigured = previousConfigured;
    demoSessionActive.value = previousDemoActive;
    SupabaseConfig.isProductionEnvOverride = previousProdOverride;
  });

  group('FIX-P2-11: usesMathMastery respects demoSessionActive', () {
    test(
      'returns false when hasRemoteConfiguration is true and demoSessionActive is true in non-production',
      () {
        SupabaseConfig.hasRemoteConfiguration = true;
        SupabaseConfig.isProductionEnvOverride = false;
        demoSessionActive.value = true;

        expect(usesMathMastery('course_math_01'), isFalse);
      },
    );

    test(
      'returns true when hasRemoteConfiguration is true and demoSessionActive is false',
      () {
        SupabaseConfig.hasRemoteConfiguration = true;
        SupabaseConfig.isProductionEnvOverride = false;
        demoSessionActive.value = false;

        expect(usesMathMastery('course_math_01'), isTrue);
      },
    );
  });

  group('Coupling #6: non-production demo mode works when remote config is present', () {
    test(
      'active demo session in non-production routes repositories and router to demo content',
      () async {
        SupabaseConfig.hasRemoteConfiguration = true;
        SupabaseConfig.isProductionEnvOverride = false;
        demoSessionActive.value = true;

        expect(SupabaseConfig.isDemoModeAllowed, isTrue);
        expect(SupabaseConfig.isDemoModeActive, isTrue);

        final inMemoryLesson = await InMemoryLessonRepository().getLessonById(
          'lesson_math_starter',
        );
        expect(inMemoryLesson, isNotNull);

        expect(SupabaseLearnerRepository().supportsNodeCompletion, isTrue);

        final demoPlacement = await SupabaseCourseRepository()
            .getPlacementQuestions('course_math_01');
        expect(demoPlacement, isNotEmpty);

        final inMemoryPlacement = await InMemoryCourseRepository()
            .getPlacementQuestions('course_math_01');
        expect(inMemoryPlacement, isNotEmpty);

        final demoLesson = await SupabaseLessonRepository().getLessonById(
          'lesson_math_starter',
        );
        expect(demoLesson, isNotNull);

        final redirect = resolveAppRedirect(
          path: '/dashboard',
          uri: Uri.parse('/dashboard'),
          recoveryActive: false,
          isRemoteConfigured: true,
          isLoggedIn: false,
          isDemoActive: true,
          isTourCompleted: true,
          hasStartedAnyCourse: true,
          isDemoAllowed: true,
        );
        expect(redirect, isNull);
      },
    );
  });

  group('FIX-P0-26: APP_ENV=production fail-closed & service_role rejection', () {
    test('isServiceRoleKey rejects sb_secret_ and service_role JWTs while allowing anon JWTs', () {
      expect(SupabaseConfig.isServiceRoleKey('sb_secret_test_key'), isTrue);
      expect(
        SupabaseConfig.isServiceRoleKey(_makeJwt(role: 'service_role')),
        isTrue,
      );
      expect(SupabaseConfig.isServiceRoleKey(_makeJwt(role: 'anon')), isFalse);
      expect(
        SupabaseConfig.isServiceRoleKey('sb_publishable_test_key'),
        isFalse,
      );
      expect(SupabaseConfig.isServiceRoleKey(''), isFalse);
    });

    test(
      'isValidSupabaseUrl rejects cleartext localhost HTTP in production while allowing it in non-production',
      () {
        SupabaseConfig.isProductionEnvOverride = true;
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://127.0.0.1:54321'),
          isFalse,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://localhost:54321'),
          isFalse,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://[::1]:54321'),
          isFalse,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('https://example.supabase.co'),
          isTrue,
        );

        SupabaseConfig.isProductionEnvOverride = false;
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://127.0.0.1:54321'),
          isTrue,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://localhost:54321'),
          isTrue,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://[::1]:54321'),
          isTrue,
        );
        expect(
          SupabaseConfig.isValidSupabaseUrl('http://example.supabase.co'),
          isFalse,
        );
      },
    );

    test(
      'production environment blocks demo/offline fallback across config, repositories, AI tutor, and router',
      () async {
        SupabaseConfig.isProductionEnvOverride = true;
        SupabaseConfig.hasRemoteConfiguration = false;
        demoSessionActive.value = true;

        expect(SupabaseConfig.isDemoModeAllowed, isFalse);
        expect(SupabaseConfig.isDemoModeActive, isFalse);

        SupabaseConfig.hasRemoteConfiguration = true;
        expect(usesMathMastery('course_math_01'), isTrue);

        SupabaseConfig.hasRemoteConfiguration = false;
        await expectLater(
          SupabaseCourseRepository().getPlacementQuestions('course_math_01'),
          throwsStateError,
        );
        await expectLater(
          SupabaseLessonRepository().getLessonById('lesson_math_starter'),
          throwsStateError,
        );
        await expectLater(
          SupabaseAITutorService().explainMistake(
            const AIExplanationRequest(
              courseId: 'course_math_01',
              skillId: 'skill_math_algebra',
              questionId: 'q_math_alg_01',
              questionText: '2 + 2 = ?',
              selectedOption: '5',
              correctOption: '4',
            ),
          ),
          throwsA(isA<AITutorUnavailableException>()),
        );

        final redirect = resolveAppRedirect(
          path: '/dashboard',
          uri: Uri.parse('/dashboard'),
          recoveryActive: false,
          isRemoteConfigured: true,
          isLoggedIn: false,
          isDemoActive: true,
          isTourCompleted: true,
          hasStartedAnyCourse: true,
          isDemoAllowed: false,
        );
        expect(redirect, anyOf('/login', '/welcome'));
      },
    );

    test(
      'initialize fails closed in production when compile-time defines are missing',
      () async {
        SupabaseConfig.isProductionEnvOverride = true;
        demoSessionActive.value = true;
        SupabaseConfig.configurationError = null;
        addTearDown(() => SupabaseConfig.configurationError = null);

        await SupabaseConfig.initialize();

        expect(SupabaseConfig.hasRemoteConfiguration, isFalse);
        expect(SupabaseConfig.isConfigured, isFalse);
        expect(SupabaseConfig.isDemoModeAllowed, isFalse);
        expect(SupabaseConfig.isDemoModeActive, isFalse);
        expect(demoSessionActive.value, isFalse);
        expect(SupabaseConfig.configurationError, isNotNull);
        expect(
          await InMemoryCourseRepository().getPlacementQuestions('course_math_01'),
          isEmpty,
        );
        expect(
          await InMemoryLessonRepository().getLessonById('lesson_math_starter'),
          isNull,
        );
        await expectLater(
          SupabaseAITutorService().generateLesson(
            const GenerateLessonRequest(
              courseId: 'course_math_01',
              skillId: 'skill_math_algebra',
            ),
          ),
          throwsA(isA<AITutorUnavailableException>()),
        );
      },
    );
  });
}
