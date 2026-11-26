import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/core/widgets/app_button.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_learner_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/repositories/i_lesson_repository.dart';
import 'package:bilimyol_mobile/features/auth/register_screen.dart';
import 'package:bilimyol_mobile/features/lesson/reading_position.dart';
import 'package:bilimyol_mobile/features/profile/profile_screen.dart';

final RegExp _uuidV4Regex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String _jwtForUser(String userId, {String email = 'learner@example.invalid'}) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({
    'sub': userId,
    'email': email,
    'role': 'authenticated',
    'aal': 'aal1',
    'exp': exp,
  })}.sig';
}

Session _sessionForUser(String userId, {String email = 'learner@example.invalid'}) {
  final token = _jwtForUser(userId, email: email);
  return Session.fromJson({
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh-$userId',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'app_metadata': {'provider': 'email'},
      'user_metadata': {'first_name': 'Sardor'},
      'created_at': '2026-11-26T00:00:00.000Z',
    },
  })!;
}

class _MemoryGotrueStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};
  @override
  Future<String?> getItem({required String key}) async => _map[key];
  @override
  Future<void> removeItem({required String key}) async => _map.remove(key);
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _map[key] = value;
}

Question _sampleQuestion(String id, {int correctIndex = 1}) => Question(
  id: id,
  courseId: 'course_eng_01',
  skillId: 'skill_eng_vocab',
  text: 'Pick greeting',
  options: const ['Bye', 'Hello'],
  correctIndex: correctIndex,
  difficulty: QuestionDifficulty.easy,
  explanation: 'Hello is a greeting.',
);

Lesson _multiCheckpointLesson() => Lesson(
  id: 'lesson_w1b1_mobile_multi',
  courseId: 'course_eng_01',
  skillId: 'skill_eng_vocab',
  title: 'Mobile Multi-Checkpoint',
  estimatedMinutes: 8,
  summary: 'Summary',
  reinforcementExercise: _sampleQuestion('q_w1b1_mobile_reinf'),
  steps: [
    const LessonStep(
      id: 's0',
      stepNumber: 1,
      type: LessonStepType.concept,
      title: 'Concept',
      content: 'Read first',
    ),
    LessonStep(
      id: 's1',
      stepNumber: 2,
      // Deliberately concept type carrying an interactiveQuestion to verify FIX-P1-55 step.interactiveQuestion != null guard!
      type: LessonStepType.concept,
      title: 'Embedded Check 1',
      content: 'Answer Q1',
      interactiveQuestion: _sampleQuestion('q_w1b1_mobile_q1'),
    ),
    const LessonStep(
      id: 's2',
      stepNumber: 3,
      type: LessonStepType.visualExample,
      title: 'Worked Example',
      content: 'Review',
    ),
    LessonStep(
      id: 's3',
      stepNumber: 4,
      type: LessonStepType.interactiveQuestion,
      title: 'Final Check 2',
      content: 'Answer Q2',
      interactiveQuestion: _sampleQuestion('q_w1b1_mobile_q2'),
    ),
  ],
);

class _StaticProfileRepo extends InMemoryLearnerRepository {
  final LearnerProfile staticProfile;
  final bool Function()? shouldFail;
  _StaticProfileRepo(this.staticProfile, {this.shouldFail, super.storage});
  @override
  Future<LearnerProfile> getProfile() async {
    if (shouldFail?.call() == true) {
      throw Exception('Temporary profile read failure');
    }
    return staticProfile;
  }
}

class _SingleLessonRepo implements ILessonRepository {
  final Lesson lesson;
  _SingleLessonRepo(this.lesson);
  @override
  Future<Lesson?> getLessonById(String lessonId) async =>
      lessonId == lesson.id ? lesson : null;
  @override
  Future<Lesson?> getLessonByCourseAndSkill(
    String courseId,
    String skillId,
  ) async =>
      (lesson.courseId == courseId && lesson.skillId == skillId) ? lesson : null;
  @override
  Future<List<LearningPathNode>> getBaseRoadmapNodes(String courseId) async =>
      const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? widgetClient;
  var signUpCalls = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    demoSessionActive.value = false;
    SupabaseConfig.hasRemoteConfiguration = false;
    signUpCalls = 0;
    await SupabaseConfig.bindClientForTesting(null);
    final sessionJson = _sessionForUser(
      'user-half-signup',
      email: 'half@example.invalid',
    ).toJson();
    widgetClient = SupabaseClient(
      'https://example.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.sig',
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/signup')) {
          signUpCalls++;
          if (signUpCalls > 1) {
            return http.Response(
              jsonEncode({'code': 422, 'msg': 'User already registered'}),
              422,
              request: req,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(sessionJson),
            200,
            request: req,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '[]',
          200,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  tearDown(() async {
    demoSessionActive.value = false;
    SupabaseConfig.hasRemoteConfiguration = false;
    await SupabaseConfig.bindClientForTesting(null);
    await widgetClient?.dispose();
    widgetClient = null;
  });

  group('W1-B1 Core Learning Integrity (FIX-P0-24, FIX-P1-55, FIX-P2-23)', () {
    test(
      '1. FIX-P0-24 & FIX-P1-55: SupabaseLearnerRepository sends fresh UUIDv4 per click (Correct -> Wrong -> Correct) and persists pending attempt UUID across timeouts & app restarts',
      () async {
        SupabaseConfig.hasRemoteConfiguration = true;
        final storage = await LocalStorageService.load();
        final capturedKeys = <String>[];
        var failNextSubmit = false;

        final client = SupabaseClient(
          'https://example.supabase.co',
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.sig',
          authOptions: AuthClientOptions(
            autoRefreshToken: false,
            pkceAsyncStorage: _MemoryGotrueStorage(),
          ),
          httpClient: MockClient((req) async {
            if (req.url.path.endsWith('/rpc/submit_answer_attempt')) {
              final body = jsonDecode(req.body) as Map<String, dynamic>;
              capturedKeys.add(body['p_idempotency_key'] as String);
              if (failNextSubmit) {
                failNextSubmit = false;
                throw http.ClientException('Network timeout');
              }
              final idx = body['p_selected_index'] as int;
              return http.Response(
                jsonEncode({
                  'is_correct': idx == 1,
                  'explanation': 'Evaluated',
                  'new_skill_score': idx == 1 ? 100 : 0,
                  'overall_score': idx == 1 ? 100 : 0,
                  'xp_awarded': idx == 1 ? 2 : 0,
                  'already_processed': false,
                }),
                200,
                request: req,
                headers: {'content-type': 'application/json'},
              );
            }
            if (req.url.path.endsWith('/rpc/get_mistake_feedback')) {
              return http.Response(
                'null',
                200,
                request: req,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              '[]',
              200,
              request: req,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await client.auth.setInitialSession(
          jsonEncode(_sessionForUser('user-w1b1-1').toJson()),
        );

        final repo1 = SupabaseLearnerRepository(storage: storage, client: client);

        // Correct -> Wrong -> Correct on non-pilot lesson must use 3 distinct UUIDv4 keys!
        final c1 = await repo1.submitAnswerAttempt(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_starter',
          questionId: 'q_lesson_eng_starter_quiz',
          selectedIndex: 1,
          selectedAnswer: 'Hello',
        );
        final w1 = await repo1.submitAnswerAttempt(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_starter',
          questionId: 'q_lesson_eng_starter_quiz',
          selectedIndex: 0,
          selectedAnswer: 'Goodbye',
        );
        final c2 = await repo1.submitAnswerAttempt(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_starter',
          questionId: 'q_lesson_eng_starter_quiz',
          selectedIndex: 1,
          selectedAnswer: 'Hello',
        );

        expect(c1.isCorrect, isTrue);
        expect(w1.isCorrect, isFalse);
        expect(c2.isCorrect, isTrue);
        expect(capturedKeys.length, 3);
        for (final k in capturedKeys) {
          expect(_uuidV4Regex.hasMatch(k), isTrue, reason: 'Expected UUIDv4 key, got $k');
        }
        expect(capturedKeys.toSet().length, 3);

        // Timeout before server confirmation -> app restart (new repo instance sharing storage) -> retry reuses exact UUID!
        failNextSubmit = true;
        await expectLater(
          repo1.submitAnswerAttempt(
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            lessonId: 'lesson_eng_starter',
            questionId: 'q_timeout_q1',
            selectedIndex: 1,
            selectedAnswer: 'Hello',
          ),
          throwsA(anything),
        );
        final timedOutUuid = capturedKeys.last;
        expect(_uuidV4Regex.hasMatch(timedOutUuid), isTrue);

        // Simulate app restart with fresh SupabaseLearnerRepository reading from persistent storage
        final restartedRepo = SupabaseLearnerRepository(storage: storage, client: client);
        final recovered = await restartedRepo.submitAnswerAttempt(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_starter',
          questionId: 'q_timeout_q1',
          selectedIndex: 1,
          selectedAnswer: 'Hello',
        );
        expect(recovered.isCorrect, isTrue);
        expect(capturedKeys.last, equals(timedOutUuid));
      },
    );

    test(
      '2. FIX-P1-55: LessonReadingPositionStore checks step.interactiveQuestion != null, advances past passedQuestionIds, and LessonSessionNotifier recovers mid-lesson progress across restart',
      () async {
        demoSessionActive.value = true;
        final lesson = _multiCheckpointLesson();

        // Step 1 has type == concept BUT interactiveQuestion != null: must clamp to 1 when Q1 is unanswered!
        expect(LessonReadingPositionStore.maxSafeStepIndex(lesson), equals(1));
        expect(LessonReadingPositionStore.clampStepIndex(lesson, 3), equals(1));

        // Once Q1 is passed, maxSafeStepIndex advances to Step 3 (Q2)!
        expect(
          LessonReadingPositionStore.maxSafeStepIndex(
            lesson,
            passedQuestionIds: const {'q_w1b1_mobile_q1'},
          ),
          equals(3),
        );

        final storage = await LocalStorageService.load();
        final container1 = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            lessonRepositoryProvider.overrideWithValue(_SingleLessonRepo(lesson)),
          ],
        );
        addTearDown(container1.dispose);

        await container1.read(learnerStateNotifierProvider.notifier).loadProfile();
        final notifier1 = container1.read(lessonSessionNotifierProvider.notifier);
        await notifier1.startLesson(lesson.id);
        await notifier1.nextStep(); // Step 0 -> Step 1 (Q1)
        notifier1.selectOption(1);
        await notifier1.submitInteractiveQuiz();
        expect(container1.read(lessonSessionNotifierProvider).answerResult?.isCorrect, isTrue);
        await notifier1.nextStep(); // Step 1 -> Step 2
        await notifier1.nextStep(); // Step 2 -> Step 3 (Q2)
        expect(container1.read(lessonSessionNotifierProvider).currentStepIndex, equals(3));

        // Simulate app restart with fresh ProviderContainer sharing LocalStorageService
        final container2 = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            lessonRepositoryProvider.overrideWithValue(_SingleLessonRepo(lesson)),
          ],
        );
        addTearDown(container2.dispose);

        await container2.read(learnerStateNotifierProvider.notifier).loadProfile();
        final notifier2 = container2.read(lessonSessionNotifierProvider.notifier);
        await notifier2.startLesson(lesson.id);

        // Restored directly at Step 3 (Q2) with Q1 still remembered in _passedQuestionIds!
        expect(container2.read(lessonSessionNotifierProvider).currentStepIndex, equals(3));
        notifier2.selectOption(1);
        await notifier2.submitInteractiveQuiz();
        expect(container2.read(lessonSessionNotifierProvider).isCompleted, isTrue);
      },
    );

    test(
      '3. FIX-P2-23: InMemoryLearnerRepository deduplicates daily question statistics by (date, questionId), honors idempotencyKey, and caps per-question XP to +2 once',
      () async {
        final storage = await LocalStorageService.load();
        final repo = InMemoryLearnerRepository(storage: storage);

        // Q1 wrong
        await repo.recordAnswerAttemptIdempotent(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_starter',
          questionId: 'q_lesson_eng_starter_quiz',
          selectedIndex: 0,
          selectedAnswer: 'Goodbye',
          isCorrect: false,
          idempotencyKey: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
        );

        // Spam Q2 correct 10 times with 10 distinct UUIDs!
        for (var i = 0; i < 10; i++) {
          final attempt = await repo.recordAnswerAttemptIdempotent(
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            lessonId: 'lesson_eng_starter',
            questionId: 'q_lesson_eng_starter_practice',
            selectedIndex: 2,
            selectedAnswer: 'Rahmat',
            isCorrect: true,
            idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-${i.toString().padLeft(12, '0')}',
          );
          expect(attempt.xpAwarded, equals(i == 0 ? 2 : 0));
          expect(attempt.alreadyProcessed, isFalse);
        }

        // Exact replay of an existing idempotencyKey returns alreadyProcessed: true & 0 XP
        final replay = await repo.recordAnswerAttemptIdempotent(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_starter',
          questionId: 'q_lesson_eng_starter_practice',
          selectedIndex: 2,
          selectedAnswer: 'Rahmat',
          isCorrect: true,
          idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000000',
        );
        expect(replay.alreadyProcessed, isTrue);
        expect(replay.xpAwarded, equals(0));

        // Payload mismatch on an existing idempotencyKey must throw ArgumentError
        await expectLater(
          repo.recordAnswerAttemptIdempotent(
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            lessonId: 'lesson_eng_starter',
            questionId: 'q_lesson_eng_starter_practice',
            selectedIndex: 0,
            selectedAnswer: 'Tampered',
            isCorrect: false,
            idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000000',
          ),
          throwsArgumentError,
        );

        // Oversized selectedAnswer (> 4000 chars) must throw ArgumentError
        await expectLater(
          repo.recordAnswerAttemptIdempotent(
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            lessonId: 'lesson_eng_starter',
            questionId: 'q_oversized',
            selectedIndex: 0,
            selectedAnswer: 'x' * 4001,
            isCorrect: false,
            idempotencyKey: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          ),
          throwsArgumentError,
        );

        final profile = await repo.getProfile();
        expect(profile.xp, equals(2));

        final daily = await repo.getDailyActivity(1);
        expect(daily, hasLength(1));
        expect(daily.single.questionsAnswered, equals(2));
        expect(daily.single.correctAnswers, equals(1));
        expect(daily.single.accuracyPercent, equals(50));
        expect(daily.single.xpEarned, equals(2));
      },
    );

    testWidgets(
      '4. FIX-P1-55: ProfileScreen logout succeeds and navigates to /login even when SupabaseConfig.client is null',
      (tester) async {
        SupabaseConfig.hasRemoteConfiguration = true;
        await SupabaseConfig.bindClientForTesting(null);
        final storage = await LocalStorageService.load();

        final router = GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/login',
              builder: (_, _) => const Scaffold(body: Text('LOGIN_SCREEN_REACHED')),
            ),
          ],
        );
        addTearDown(router.dispose);

        final fakeProfile = LearnerProfile(
          id: 'offline-user',
          name: 'Offline User',
          selectedCourseId: 'course_eng_01',
          goal: OnboardingGoal.mastery,
          dailyMinutes: 15,
          initialLevel: InitialLevel.beginner,
          xp: 10,
          streakDays: 1,
          lastActiveDate: '2026-11-26',
          scoresByCourse: const {},
          completedLessonIds: const [],
          completedNodeIds: const [],
          completedReinforcementIds: const [],
          createdAt: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(storage),
              learnerRepositoryProvider.overrideWithValue(
                _StaticProfileRepo(fakeProfile, storage: storage),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        final logoutFinder = find.byIcon(Icons.logout_rounded);
        expect(logoutFinder, findsOneWidget);
        await tester.ensureVisible(logoutFinder);
        await tester.tap(logoutFinder);
        await tester.pumpAndSettle();

        expect(find.text('LOGIN_SCREEN_REACHED'), findsOneWidget);
      },
    );

    testWidgets(
      '5. FIX-P1-55: RegisterScreen recovers active half-signed-up session without calling signUp a second time (avoiding 422)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SupabaseConfig.hasRemoteConfiguration = true;
        var failProfileFetch = true;

        final storage = await LocalStorageService.load();
        final client = widgetClient!;
        await SupabaseConfig.bindClientForTesting(client, storage: storage);

        final fakeProfile = LearnerProfile(
          id: 'user-half-signup',
          name: 'Sardor',
          selectedCourseId: 'course_eng_01',
          goal: OnboardingGoal.mastery,
          dailyMinutes: 15,
          initialLevel: InitialLevel.beginner,
          xp: 0,
          streakDays: 0,
          lastActiveDate: '2026-11-26',
          scoresByCourse: const {},
          completedLessonIds: const [],
          completedNodeIds: const [],
          completedReinforcementIds: const [],
          createdAt: 1,
        );

        final router = GoRouter(
          initialLocation: '/register',
          routes: [
            GoRoute(
              path: '/register',
              builder: (_, _) => const RegisterScreen(),
            ),
            GoRoute(
              path: '/courses',
              builder: (_, _) => const Scaffold(body: Text('COURSES_SCREEN_REACHED')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(storage),
              courseRepositoryProvider.overrideWithValue(
                InMemoryCourseRepository(),
              ),
              lessonRepositoryProvider.overrideWithValue(
                InMemoryLessonRepository(),
              ),
              learnerRepositoryProvider.overrideWithValue(
                _StaticProfileRepo(
                  fakeProfile,
                  shouldFail: () => failProfileFetch,
                  storage: storage,
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Sardor');
        await tester.enterText(fields.at(1), 'half@example.invalid');
        await tester.enterText(fields.at(2), 'ValidPass123');
        await tester.enterText(fields.at(3), 'ValidPass123');
        await tester.pump(const Duration(milliseconds: 100));

        // Tap 1: signUp succeeds (session created), profile fetch fails -> stays on /register
        final submitBtn = find.byType(AppButton).first;
        await tester.tap(submitBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(signUpCalls, equals(1));
        expect(find.text('COURSES_SCREEN_REACHED'), findsNothing);

        // Tap 2: profile fetch now succeeds -> skips signUp (no 422!) and navigates to /courses!
        failProfileFetch = false;
        await tester.tap(submitBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(signUpCalls, equals(1));
        expect(find.text('COURSES_SCREEN_REACHED'), findsOneWidget);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
