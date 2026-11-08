import 'dart:convert';
import 'dart:io';

import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/supabase_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const enabled = bool.fromEnvironment('BILIMYOL_RUN_LOCAL_INTEGRATION');
const tutorEnabled = bool.fromEnvironment('BILIMYOL_RUN_LOCAL_AI_INTEGRATION');
const mailbox = String.fromEnvironment('BILIMYOL_LOCAL_MAILBOX');

bool _isLoopback(Uri uri) =>
    uri.scheme == 'http' && ['127.0.0.1', 'localhost'].contains(uri.host);

Future<Uri> _recoveryRedirect(
  HttpClient http,
  Uri mail,
  Uri backend,
  String email,
) async {
  Future<Map<String, dynamic>> jsonAt(Uri uri) async {
    final response = await (await http.getUrl(uri)).close();
    return jsonDecode(await utf8.decoder.bind(response).join())
        as Map<String, dynamic>;
  }

  for (var retry = 0; retry < 24; retry++) {
    final index = await jsonAt(mail.resolve('/api/v1/messages'));
    for (final message in index['messages'] as List) {
      if (!(message['To'] as List).any(
        (recipient) => recipient['Address'] == email,
      )) {
        continue;
      }
      final body = await jsonAt(
        mail.resolve('/api/v1/message/${message['ID']}'),
      );
      final html = (body['HTML'] as String? ?? '').replaceAll('&amp;', '&');
      final link = RegExp(
        r'href="([^"]+/auth/v1/verify[^"]+)"',
      ).firstMatch(html);
      if (link == null) continue;
      final verification = Uri.parse(link.group(1)!);
      if (!_isLoopback(verification) || verification.origin != backend.origin) {
        throw StateError(
          'Recovery verification escaped the disposable backend.',
        );
      }
      final request = await http.getUrl(verification)
        ..followRedirects = false;
      final response = await request.close();
      await response.drain<void>();
      final location = Uri.parse(
        response.headers.value(HttpHeaders.locationHeader)!,
      );
      if (location.queryParameters['code'] == null) {
        throw StateError(
          'PKCE code missing from the verified recovery redirect.',
        );
      }
      return Uri.parse(
        SupabaseConfig.passwordRecoveryUrl,
      ).replace(query: location.query);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('The recovery message did not arrive in the local mailbox.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Flutter tutor uses an authenticated lesson context with the real provider',
    () async {
      if (!_isLoopback(Uri.parse(SupabaseConfig.supabaseUrl))) {
        throw StateError('The tutor test requires disposable loopback Auth.');
      }
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      await SupabaseConfig.initialize();
      addTearDown(() => Supabase.instance.dispose());
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final signup = await Supabase.instance.client.auth.signUp(
        email: 'flutter-ai-qa$stamp@example.test',
        password: 'QA-local-$stamp',
      );
      expect(signup.session, isNotNull);
      final repo = SupabaseLearnerRepository();
      final profile = await repo.getProfile();
      await repo.updateProfile(
        profile.copyWith(selectedCourseId: 'course_eng_01'),
        fields: {LearnerProfileField.selectedCourse},
      );
      await repo.saveCourseLearningPlan(
        courseId: 'course_eng_01',
        goal: OnboardingGoal.mastery,
        dailyMinutes: 15,
        initialLevel: InitialLevel.beginner,
      );
      final answer = await SupabaseAITutorService().askTutor(
        const AskTutorRequest(
          message:
              'Hello va goodbye qachon ishlatiladi? O‘zbek tilida izoh bering.',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          history: [(sender: 'user', text: 'Ingliz tilini noldan boshladim.')],
        ),
      );
      expect(answer.isAiGenerated, isTrue);
      expect(answer.isDeterministicFallback, isFalse);
      expect(
        answer.answer.toLowerCase(),
        allOf(contains('hello'), contains('goodbye')),
      );
    },
    skip: tutorEnabled
        ? false
        : 'Requires local Edge Function with a real AI provider.',
    timeout: const Timeout(Duration(seconds: 70)),
  );

  test(
    'Flutter SDK signs in, starts a course, takes a diagnostic and recovers access',
    () async {
      final backend = Uri.parse(SupabaseConfig.supabaseUrl);
      final mail = Uri.parse(mailbox);
      if (!_isLoopback(backend) || !_isLoopback(mail)) {
        throw StateError(
          'This test requires disposable loopback Auth and SMTP services.',
        );
      }
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      await SupabaseConfig.initialize();
      expect(SupabaseConfig.isConfigured, isTrue);
      addTearDown(() => Supabase.instance.dispose());

      final client = Supabase.instance.client;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final email = 'flutterqa$stamp@example.test';
      final password = 'QA-initial-$stamp';
      final signup = await client.auth.signUp(
        email: email,
        password: password,
        data: {'first_name': 'Flutter', 'last_name': 'Sinov'},
      );
      expect(signup.session, isNotNull);
      final repo = SupabaseLearnerRepository();
      expect((await repo.getProfile()).name, 'Flutter');
      final profile = await client
          .from('profiles')
          .select('first_name,last_name')
          .eq('id', signup.user!.id)
          .single();
      expect(profile, {'first_name': 'Flutter', 'last_name': 'Sinov'});

      const englishId = 'course_eng_01';
      final math = await repo.saveCourseLearningPlan(
        courseId: 'course_math_01',
        goal: OnboardingGoal.mastery,
        dailyMinutes: 15,
        initialLevel: InitialLevel.intermediate,
      );
      await repo.updateProfile(
        math.copyWith(selectedCourseId: englishId),
        fields: {LearnerProfileField.selectedCourse},
      );
      await repo.saveCourseLearningPlan(
        courseId: englishId,
        goal: OnboardingGoal.mastery,
        dailyMinutes: 15,
        initialLevel: InitialLevel.beginner,
      );
      expect((await repo.getProfile()).courseLevels, {
        'course_math_01': InitialLevel.intermediate,
        englishId: InitialLevel.beginner,
      });
      final english = await SupabaseCourseRepository().getCourseById(englishId);
      expect(english?.starterLessonId, 'lesson_eng_starter');
      final starter = await SupabaseLessonRepository().getLessonById(
        english!.starterLessonId!,
      );
      expect(starter?.courseId, englishId);
      expect(starter?.steps.first.type, LessonStepType.concept);
      expect(starter?.steps[1].type, LessonStepType.audioSimulation);

      const course = 'course_logic';
      var placement = await repo.advancePlacement(course);
      final sessionId = placement.id;
      expect(placement.totalQuestions, 4);
      expect(placement.result, isNull);
      expect(placement.question!.correctIndex, -1);
      placement = await repo.advancePlacement(
        course,
        sessionId: sessionId,
        questionId: placement.question!.id,
        selectedIndex: 0,
      );
      expect((await repo.advancePlacement(course)).questionNumber, 2);
      while (placement.result == null) {
        placement = await repo.advancePlacement(
          course,
          sessionId: sessionId,
          questionId: placement.question!.id,
          selectedIndex: 0,
        );
      }
      expect(placement.result!.review, hasLength(4));
      expect((await repo.getProfile()).scoresByCourse[course], hasLength(2));

      await client.auth.signOut(scope: SignOutScope.local);
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.passwordRecoveryUrl,
      );
      final http = HttpClient();
      addTearDown(() => http.close(force: true));
      final redirect = await _recoveryRedirect(http, mail, backend, email);
      final recovery = client.auth.onAuthStateChange.firstWhere(
        (event) => event.event == AuthChangeEvent.passwordRecovery,
      );
      await client.auth.getSessionFromUrl(redirect);
      expect(
        (await recovery.timeout(
          const Duration(seconds: 10),
        )).session?.user.email,
        email,
      );
      final newPassword = 'QA-new-$stamp';
      await client.auth.updateUser(UserAttributes(password: newPassword));
      await client.auth.signOut(scope: SignOutScope.local);
      final signedIn = await client.auth.signInWithPassword(
        email: email,
        password: newPassword,
      );
      expect(signedIn.user?.id, signup.user?.id);
    },
    skip: enabled ? false : 'Requires disposable local Supabase and Mailpit.',
  );
}
