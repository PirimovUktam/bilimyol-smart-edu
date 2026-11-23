import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/auth/auth_error_message.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/core/theme/app_semantic_colors.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/core/widgets/app_button.dart';
import 'package:bilimyol_mobile/core/widgets/app_card.dart';
import 'package:bilimyol_mobile/core/widgets/bilimyol_bottom_nav.dart';
import 'package:bilimyol_mobile/core/widgets/yolchi_ai_mascot.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/features/ai_tutor/yolchi_ai_sheet.dart';
import 'package:bilimyol_mobile/features/auth/forgot_password_screen.dart';
import 'package:bilimyol_mobile/features/auth/login_screen.dart';
import 'package:bilimyol_mobile/features/auth/register_screen.dart';
import 'package:bilimyol_mobile/features/auth/reset_password_screen.dart';
import 'package:bilimyol_mobile/features/auth/welcome_screen.dart';
import 'package:bilimyol_mobile/features/dashboard/dashboard_screen.dart';
import 'package:bilimyol_mobile/features/lesson/audio_sim_wave_widget.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/lesson/math_function_graph_widget.dart';
import 'package:bilimyol_mobile/features/reinforcement/reinforcement_sheet.dart';

bool _fontsLoaded = false;

Future<void> _ensureReadableFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final segoe = File(r'C:\Windows\Fonts\segoeui.ttf');
  if (segoe.existsSync()) {
    final bytes = await segoe.readAsBytes();
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  final consola = File(r'C:\Windows\Fonts\consola.ttf');
  if (consola.existsSync()) {
    final bytes = await consola.readAsBytes();
    final loader = FontLoader('JetBrains Mono')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  final materialIcons = File(
    r'C:\Users\user\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  );
  if (materialIcons.existsSync()) {
    final bytes = await materialIcons.readAsBytes();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> _maybeCapturePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String fileName,
) async {
  final renderDir = Platform.environment['BILIMYOL_RENDER_DIR'];
  if (renderDir == null || renderDir.trim().isEmpty) return;
  await tester.runAsync(() async {
    await _ensureReadableFonts();
    final dir = Directory(renderDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final outFile = File('${dir.path}${Platform.pathSeparator}$fileName');
    await outFile.writeAsBytes(byteData.buffer.asUint8List());
  });
}

void main() {
  group('M2 Core Visual Trio, Auth, Routing & Escalated Fixes', () {
    setUp(() {
      productTourCompleted.value = false;
      demoSessionActive.value = false;
      activeSessionHasStartedCourse.value = false;
    });

    test('resolveAppRedirect enforces Recovery > Replay > Active Session > Tour precedence', () {
      // 1. Only active recovery session routes to /reset-password
      expect(
        resolveAppRedirect(
          path: '/welcome',
          uri: Uri.parse('/welcome'),
          recoveryActive: true,
          isRemoteConfigured: true,
          isLoggedIn: true,
          isDemoActive: false,
          isTourCompleted: false,
          hasStartedAnyCourse: true,
        ),
        '/reset-password',
      );
      // Bare reset-password deep link WITHOUT recoveryActive must never open /reset-password
      expect(
        resolveAppRedirect(
          path: '/reset-password',
          uri: Uri.parse('uz.bilimyol.mobile://auth/reset-password'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: false,
          isTourCompleted: true,
          hasStartedAnyCourse: false,
        ),
        '/login',
      );
      expect(
        resolveAppRedirect(
          path: '/reset-password',
          uri: Uri.parse('uz.bilimyol.mobile://auth/reset-password'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: false,
          isTourCompleted: false,
          hasStartedAnyCourse: false,
        ),
        '/login',
      );
      expect(
        resolveAppRedirect(
          path: '/reset-password',
          uri: Uri.parse('/reset-password'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: false,
          isTourCompleted: false,
          hasStartedAnyCourse: false,
        ),
        '/login',
      );
      expect(
        resolveAppRedirect(
          path: '/reset-password',
          uri: Uri.parse('uz.bilimyol.mobile://auth/reset-password'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: true,
          isTourCompleted: true,
          hasStartedAnyCourse: true,
        ),
        '/dashboard',
      );
      expect(
        resolveAppRedirect(
          path: '/login',
          uri: Uri.parse('uz.bilimyol.mobile://auth/reset-password'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: true,
          isTourCompleted: false,
          hasStartedAnyCourse: false,
        ),
        '/courses',
      );
      // Active session receiving raw custom-scheme reset-password URI with empty/'/' path
      expect(
        resolveAppRedirect(
          path: '',
          uri: Uri.parse('uz.bilimyol.mobile://auth/reset-password'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: true,
          isTourCompleted: true,
          hasStartedAnyCourse: true,
        ),
        '/dashboard',
      );
      expect(
        resolveAppRedirect(
          path: '/',
          uri: Uri.parse('uz.bilimyol.mobile://auth/reset-password'),
          recoveryActive: false,
          isRemoteConfigured: true,
          isLoggedIn: true,
          isDemoActive: false,
          isTourCompleted: false,
          hasStartedAnyCourse: false,
        ),
        '/courses',
      );
      expect(
        resolveAppRedirect(
          path: '',
          uri: Uri.parse('uz.bilimyol.mobile://auth/reset-password'),
          recoveryActive: true,
          isRemoteConfigured: true,
          isLoggedIn: true,
          isDemoActive: false,
          isTourCompleted: true,
          hasStartedAnyCourse: true,
        ),
        '/reset-password',
      );

      // 2. Explicit tour replay always allowed
      expect(
        resolveAppRedirect(
          path: '/welcome',
          uri: Uri.parse('/welcome?replay=1'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: true,
          isTourCompleted: true,
          hasStartedAnyCourse: true,
        ),
        isNull,
      );

      // 3. Active session goes to /dashboard if started course exists, else /courses
      expect(
        resolveAppRedirect(
          path: '/welcome',
          uri: Uri.parse('/welcome'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: true,
          isTourCompleted: true,
          hasStartedAnyCourse: true,
        ),
        '/dashboard',
      );
      expect(
        resolveAppRedirect(
          path: '/login',
          uri: Uri.parse('/login'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: true,
          isTourCompleted: true,
          hasStartedAnyCourse: false,
        ),
        '/courses',
      );

      // 4. Unauthenticated before tour completion -> /welcome for / or protected routes
      expect(
        resolveAppRedirect(
          path: '/',
          uri: Uri.parse('/'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: false,
          isTourCompleted: false,
          hasStartedAnyCourse: false,
        ),
        '/welcome',
      );
      expect(
        resolveAppRedirect(
          path: '/dashboard',
          uri: Uri.parse('/dashboard'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: false,
          isTourCompleted: false,
          hasStartedAnyCourse: false,
        ),
        '/welcome',
      );

      // 5. Unauthenticated after tour completion -> /login for /, /welcome, or protected routes
      expect(
        resolveAppRedirect(
          path: '/welcome',
          uri: Uri.parse('/welcome'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: false,
          isTourCompleted: true,
          hasStartedAnyCourse: false,
        ),
        '/login',
      );
      expect(
        resolveAppRedirect(
          path: '/courses',
          uri: Uri.parse('/courses'),
          recoveryActive: false,
          isRemoteConfigured: false,
          isLoggedIn: false,
          isDemoActive: false,
          isTourCompleted: true,
          hasStartedAnyCourse: false,
        ),
        '/login',
      );
      expect(
        resolveAppRedirect(
          path: '/reset-password',
          uri: Uri.parse('/reset-password'),
          recoveryActive: false,
          isRemoteConfigured: true,
          isLoggedIn: false,
          isDemoActive: false,
          isTourCompleted: true,
          hasStartedAnyCourse: false,
        ),
        '/login',
      );
    });

    testWidgets('3-page Product Tour swipe, interactive starter quiz, Skip/Finish & persistence without altering course/diagnostic state', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.load();
      final repo = InMemoryLearnerRepository(storage: storage);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            home: const WelcomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1
      expect(find.text('Nimadan boşlaşni biling.'), findsOneWidget);
      expect(find.text('Ötkazib yuboriş'), findsOneWidget);
      expect(find.text('Keyingi'), findsOneWidget);

      // Swipe to Page 2
      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(find.text('Sizga mos darsni sinab köring.'), findsOneWidget);
      expect(
        find.text('4 ta qalamga yana 2 ta qalam qöşilsa, jami neçta böladi?'),
        findsOneWidget,
      );

      // Tap wrong option '4' then right option '6'
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Yana bir bor urinib köring — javobni bosing.'),
        findsOneWidget,
      );
      await tester.tap(find.text('6').last);
      await tester.pumpAndSettle();
      expect(
        find.text('4 ta va 2 ta qalamni birlaştiramiz. 4 + 2 = 6.'),
        findsOneWidget,
      );

      // Tap Keyingi -> Page 3
      await tester.tap(find.text('Keyingi'));
      await tester.pumpAndSettle();
      expect(find.text('Ösişingizni körib boring.'), findsOneWidget);
      expect(find.text('Boşlaş'), findsOneWidget);
      expect(find.text('+25 XP'), findsOneWidget);

      // Finish tour via appSettingsProvider check (WelcomeScreen navigates via GoRouter when mounted in router)
      await container.read(appSettingsProvider.notifier).completeProductTour();
      expect(await storage.getProductTourCompleted(), isTrue);

      final profile = await repo.getProfile();
      expect(profile.courseLevels, isEmpty);
      expect(profile.scoresByCourse, isEmpty);
      expect(profile.completedLessonIds, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Auth 4 screens render cleanly at 360dp @ 2.0x in Light/Dark, uz/ru, and keyboard open', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final isDark in [false, true]) {
        for (final code in ['uz', 'ru']) {
          for (final screen in [
            const LoginScreen(),
            const RegisterScreen(),
            const ForgotPasswordScreen(),
            const ResetPasswordScreen(),
          ]) {
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                  locale: Locale(code),
                  supportedLocales: AppStrings.supportedLocales,
                  localizationsDelegates: AppStrings.localizationsDelegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(2.0),
                      viewInsets: const EdgeInsets.only(bottom: 280),
                    ),
                    child: child!,
                  ),
                  home: screen,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType} overflow in dark=$isDark locale=$code',
            );
          }
        }
      }
    });

    testWidgets('MathFunctionGraphWidget & 5-option InteractiveLessonScreen & Sheets render cleanly with zero overflow or RangeError', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Verify lesson_math_functions_01 contains function_graph step
      final mathFuncLesson = seedLessons['lesson_math_functions_01']!;
      expect(
        mathFuncLesson.steps.any(
          (s) => s.visualModelData?.type == 'function_graph',
        ),
        isTrue,
      );

      // 1) MathFunctionGraphWidget slider interaction & 2.0x scale
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('ru'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: MathFunctionGraphWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('f(2.0) = 7.0'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2) AudioSimWaveWidget with disableAnimations = true
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('uz'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: AudioSimWaveWidget(
                transcript: 'Hello! I am Aziza.',
                speakerName: 'Aziza',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 3) 5-option question in InteractiveLessonScreen (no RangeError)
      const fiveOptionLesson = Lesson(
        id: 'lesson_5opt',
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        title: 'Beş variantli savol',
        estimatedMinutes: 5,
        summary: 'Test',
        steps: [
          LessonStep(
            id: 'step_5opt',
            stepNumber: 1,
            type: LessonStepType.interactiveQuestion,
            title: 'Savol',
            content: 'Töğri variantni tanlang.',
            interactiveQuestion: Question(
              id: 'q_5opt',
              courseId: 'course_math_01',
              skillId: 'skill_math_functions',
              text: '2 + 3 neçaga teng?',
              options: ['1', '3', '5', '7', '9'],
              correctIndex: 2,
              difficulty: QuestionDifficulty.easy,
              explanation: '2 + 3 = 5.',
            ),
          ),
        ],
        reinforcementExercise: Question(
          id: 'q_5opt_reinf',
          courseId: 'course_math_01',
          skillId: 'skill_math_functions',
          text: '1 + 4 = ?',
          options: ['2', '3', '4', '5', '6'],
          correctIndex: 3,
          difficulty: QuestionDifficulty.easy,
          explanation: '1 + 4 = 5.',
        ),
      );

      final repo = InMemoryLearnerRepository();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_math_01');
      container.read(lessonSessionNotifierProvider.notifier).state =
          const LessonSessionState(lesson: fiveOptionLesson);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            home: const InteractiveLessonScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('E'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 4) YolchiAiSheet & ReinforcementSheet at 360dp @ 2.0x in Dark mode
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('ru'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  YolchiAiSheet(
                    loadExplanation: () => DemoAITutorService().explainMistake(
                      const AIExplanationRequest(
                        courseId: 'course_math_01',
                        skillId: 'skill_math_functions',
                        questionId: 'q_math_func_01_step',
                        questionText: 'f(4)?',
                        selectedOption: '8',
                        correctOption: '11',
                      ),
                    ),
                    onStartReinforcement: () {},
                  ),
                  ReinforcementSheet(
                    question: fiveOptionLesson.reinforcementExercise,
                    onSubmit: (_) async => null,
                    onGoToDashboard: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('E'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Real Render Verification: Core Trio PNG captures (Light & Dark, 360dp)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final renderDir = Platform.environment['BILIMYOL_RENDER_DIR'];
      if (renderDir != null && renderDir.trim().isNotEmpty) {
        await tester.runAsync(_ensureReadableFonts);
      }

      for (final isDark in [false, true]) {
        SharedPreferences.setMockInitialValues({});
        final modeTag = isDark ? 'dark' : 'light';
        final boundaryKey = GlobalKey();

        // A. Product Tour Pages 1, 2, 3
        await tester.pumpWidget(
          ProviderScope(
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: const Locale('uz'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                home: const WelcomeScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _maybeCapturePng(tester, boundaryKey, 'tour_page1_$modeTag.png');

        await tester.tap(find.text('Keyingi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('6').last);
        await tester.pumpAndSettle();
        await _maybeCapturePng(tester, boundaryKey, 'tour_page2_$modeTag.png');

        await tester.tap(find.text('Keyingi'));
        await tester.pumpAndSettle();
        await _maybeCapturePng(tester, boundaryKey, 'tour_page3_$modeTag.png');

        // B. Login Screen
        await tester.pumpWidget(
          ProviderScope(
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: const Locale('uz'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                home: const LoginScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _maybeCapturePng(tester, boundaryKey, 'login_${modeTag}_360.png');

        // C. Dashboard Screen (with Tezkor demo preset seeded)
        final repo = InMemoryLearnerRepository();
        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(repo),
            courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(courseStateNotifierProvider.notifier).init();
        await container
            .read(courseStateNotifierProvider.notifier)
            .selectCourse('course_math_01');
        await container.read(learnerStateNotifierProvider.notifier).seedQuickDemo();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: const Locale('uz'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                home: const DashboardScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bugun nimani davom ettiraman?'), findsOneWidget);
        expect(find.text('Davom etiş'), findsOneWidget);
        expect(find.text('0/7 dars'), findsNothing);
        expect(find.text('Ta’lim yölini oçiş'), findsNothing);
        expect(find.text('Obuna böliş'), findsNothing);
        await _maybeCapturePng(
          tester,
          boundaryKey,
          'dashboard_${modeTag}_360.png',
        );

        // D. Interactive Lesson: lesson_math_functions_01 Graph Step + Quiz Reveal
        await container
            .read(lessonSessionNotifierProvider.notifier)
            .startLesson('lesson_math_functions_01');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: const Locale('uz'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                home: const InteractiveLessonScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Step 3 (math_step_graph)
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
        expect(find.byType(MathFunctionGraphWidget), findsOneWidget);
        await _maybeCapturePng(
          tester,
          boundaryKey,
          'lesson_graph_${modeTag}_360.png',
        );

        // Advance to Step 4 (Quiz) and submit wrong answer '8' to verify reveal + guidance
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('8').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('TEKŞIRIŞ'));
        await tester.pumpAndSettle();
        expect(find.text('Töğri javob: 11'), findsOneWidget);
        expect(find.text('Endi nima qiliş kerak?'), findsOneWidget);
        await _maybeCapturePng(
          tester,
          boundaryKey,
          'lesson_quiz_reveal_${modeTag}_360.png',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('WelcomeScreen all 3 pages fit 360dp @ 2.0x in uz & ru, Light & Dark with zero overflow or clipping', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final isDark in [false, true]) {
        for (final code in ['uz', 'ru']) {
          SharedPreferences.setMockInitialValues({});
          final s = AppStrings.forCode(code);
          SharedPreferences.setMockInitialValues({'bilimyol.locale': code});
          final storage = await LocalStorageService.load();
          final container = ProviderContainer(
            overrides: [
              localStorageServiceProvider.overrideWithValue(storage),
              initialAppSettingsProvider.overrideWithValue(
                AppSettingsState(
                  localeCode: code,
                  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                  productTourCompleted: false,
                ),
              ),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: Locale(code),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2.0),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: WelcomeScreen(key: ValueKey('$isDark-$code')),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Page 1: visualTitle & pill stay inside stage and never overlap YolchiAIMascot
          final titleRect = tester.getRect(find.text(s.tourSlide1VisualTitle));
          final pillRect = tester.getRect(
            find
                .ancestor(
                  of: find.text(s.tourSlide1VisualTitle),
                  matching: find.byType(Container),
                )
                .first,
          );
          final stageRect = tester.getRect(find.byType(AppCard).first);
          final mascotRect = tester.getRect(find.byType(YolchiAIMascot).first);
          expect(
            titleRect.right,
            lessThanOrEqualTo(360.0),
            reason: 'Slide 1 visualTitle clipped in $code dark=$isDark: $titleRect',
          );
          expect(
            pillRect.bottom,
            lessThanOrEqualTo(stageRect.bottom),
            reason:
                'Slide 1 pill overflows stage in $code dark=$isDark: $pillRect vs $stageRect',
          );
          expect(
            pillRect.overlaps(mascotRect),
            isFalse,
            reason:
                'Slide 1 pill overlaps mascot in $code dark=$isDark: $pillRect vs $mascotRect',
          );
          expect(tester.takeException(), isNull);

          // Page 2: Russian localization on mini-quiz + untruncated title + interaction
          await tester.tap(find.text(s.tourNext));
          await tester.pumpAndSettle();
          final expectedLessonTitle = code == 'ru'
              ? 'Начинаем со сложения и вычитания'
              : s.tourSlide2MiniLessonTitle('Qöşiş va ayirişdan boşlaymiz');
          final lessonTitleWidget = tester.widget<Text>(
            find.text(expectedLessonTitle),
          );
          expect(lessonTitleWidget.maxLines, isNull);
          expect(lessonTitleWidget.overflow, isNull);
          if (code == 'ru') {
            expect(
              find.text('Начинаем со сложения и вычитания'),
              findsOneWidget,
            );
            expect(
              find.text(
                'Если к 4 карандашам добавить ещё 2 карандаша, сколько станет всего?',
              ),
              findsOneWidget,
            );
          }
          final sixthOption = find.text('6').last;
          await tester.ensureVisible(sixthOption);
          await tester.tap(sixthOption);
          await tester.pumpAndSettle();
          expect(
            find.text(
              code == 'ru'
                  ? s.tourSlide2CorrectFeedback
                  : '4 ta va 2 ta qalamni birlaştiramiz. 4 + 2 = 6.',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          // Page 3
          await tester.tap(find.text(s.tourNext));
          await tester.pumpAndSettle();
          expect(find.text(s.tourFinish), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('DashboardScreen & InteractiveLessonScreen at 360dp @ 2.0x in uz & ru, needsPlan focus, and non-mastery wrong-reveal CTA disable', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final isDark in [false, true]) {
        for (final code in ['uz', 'ru']) {
          SharedPreferences.setMockInitialValues({});
          final s = AppStrings.forCode(code);
          final repo = InMemoryLearnerRepository();
          final current = await repo.getProfile();
          await repo.updateProfile(current.copyWith(name: ''));

          final container = ProviderContainer(
            overrides: [
              learnerRepositoryProvider.overrideWithValue(repo),
              courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
              lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
            ],
          );
          addTearDown(container.dispose);

          await container.read(courseStateNotifierProvider.notifier).init();
          await container
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_math_01');

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: Locale(code),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2.0),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: const DashboardScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(s.heroGreeting(s.defaultLearnerName)), findsOneWidget);
          expect(find.text(s.heroFocusNeedsPlan), findsOneWidget);
          expect(find.text(s.chooseSubject), findsOneWidget);
          expect(tester.takeException(), isNull);

          // InteractiveLessonScreen non-mastery lesson at 360dp @ 2.0x
          await container
              .read(lessonSessionNotifierProvider.notifier)
              .startLesson('lesson_math_functions_01');
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: Locale(code),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2.0),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: const InteractiveLessonScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Advance to Step 4 (Quiz)
          await tester.tap(find.text(s.nextStep));
          await tester.pumpAndSettle();
          await tester.tap(find.text(s.nextStep));
          await tester.pumpAndSettle();
          await tester.tap(find.text(s.nextStep));
          await tester.pumpAndSettle();

          // Submit wrong option '8' -> TEKŞIRIŞ/ПРОВЕРИТЬ becomes disabled until a different option is picked
          final wrongOpt = find.text('8').first;
          await tester.ensureVisible(wrongOpt);
          await tester.tap(wrongOpt);
          await tester.pumpAndSettle();
          await tester.tap(find.text(s.checkAnswer));
          await tester.pumpAndSettle();

          final checkButton = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, s.checkAnswer),
          );
          expect(checkButton.onPressed, isNull);

          // Tapping the same wrong option keeps it disabled
          await tester.ensureVisible(wrongOpt);
          await tester.tap(wrongOpt);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, s.checkAnswer),
                )
                .onPressed,
            isNull,
          );

          // Picking a different option re-enables TEKŞIRIŞ/ПРОВЕРИТЬ
          final rightOpt = find.text('11').first;
          await tester.ensureVisible(rightOpt);
          await tester.tap(rightOpt);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, s.checkAnswer),
                )
                .onPressed,
            isNotNull,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('seedQuickDemo() reloads roadmap immediately with non-zero progress & Davom etiş CTA', (tester) async {
      final repo = InMemoryLearnerRepository();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_math_01');
      await container.read(learnerStateNotifierProvider.notifier).seedQuickDemo();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Davom etiş'), findsOneWidget);
      expect(find.text('0/7 dars'), findsNothing);
      expect(find.text('Ta’lim yölini oçiş'), findsNothing);
      expect(find.textContaining('2/7 dars'), findsOneWidget);
    });

    testWidgets('Bare reset-password deep link without recovery session redirects to /login via GoRouter', (tester) async {
      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      SupabaseConfig.hasRemoteConfiguration = false;
      productTourCompleted.value = true;
      demoSessionActive.value = false;
      activeSessionHasStartedCourse.value = false;
      addTearDown(() => SupabaseConfig.hasRemoteConfiguration = previousRemote);

      final router = GoRouter(
        initialLocation: '/login',
        redirect: (context, state) => resolveAppRedirect(
          path: state.matchedLocation,
          uri: state.uri,
          recoveryActive: false,
          isRemoteConfigured: SupabaseConfig.hasRemoteConfiguration,
          isLoggedIn: false,
          isDemoActive: demoSessionActive.value,
          isTourCompleted: productTourCompleted.value,
          hasStartedAnyCourse: activeSessionHasStartedCourse.value,
        ),
        routes: [
          GoRoute(path: '/welcome', builder: (_, _) => const Text('WELCOME')),
          GoRoute(path: '/login', builder: (_, _) => const Text('LOGIN_PAGE')),
          GoRoute(
            path: '/reset-password',
            builder: (_, _) => const Text('RESET_PAGE'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('uz.bilimyol.mobile://auth/reset-password');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.text('LOGIN_PAGE'), findsOneWidget);
      expect(find.text('RESET_PAGE'), findsNothing);
    });

    testWidgets('Bare reset-password deep link redirects to /login via GoRouter even when !productTourCompleted', (tester) async {
      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      SupabaseConfig.hasRemoteConfiguration = false;
      productTourCompleted.value = false;
      demoSessionActive.value = false;
      activeSessionHasStartedCourse.value = false;
      addTearDown(() => SupabaseConfig.hasRemoteConfiguration = previousRemote);

      final router = GoRouter(
        initialLocation: '/welcome',
        redirect: (context, state) => resolveAppRedirect(
          path: state.matchedLocation,
          uri: state.uri,
          recoveryActive: false,
          isRemoteConfigured: SupabaseConfig.hasRemoteConfiguration,
          isLoggedIn: false,
          isDemoActive: demoSessionActive.value,
          isTourCompleted: productTourCompleted.value,
          hasStartedAnyCourse: activeSessionHasStartedCourse.value,
        ),
        routes: [
          GoRoute(path: '/welcome', builder: (_, _) => const Text('WELCOME')),
          GoRoute(path: '/login', builder: (_, _) => const Text('LOGIN_PAGE')),
          GoRoute(
            path: '/reset-password',
            builder: (_, _) => const Text('RESET_PAGE'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('uz.bilimyol.mobile://auth/reset-password');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.text('LOGIN_PAGE'), findsOneWidget);
      expect(find.text('RESET_PAGE'), findsNothing);
    });

    testWidgets('Demo logout -> Re-enter Demo with persisted started course routes to /dashboard', (tester) async {
      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      SupabaseConfig.hasRemoteConfiguration = false;
      productTourCompleted.value = true;
      demoSessionActive.value = false;
      activeSessionHasStartedCourse.value = false;
      addTearDown(() => SupabaseConfig.hasRemoteConfiguration = previousRemote);

      final snapshotJson = jsonEncode({
        'version': 1,
        'profile': {
          'id': 'demo_learner',
          'name': 'Aziza',
          'selectedCourseId': 'course_math_01',
          'goal': 'mastery',
          'dailyMinutes': 15,
          'initialLevel': 'beginner',
          'courseLevels': {'course_math_01': 'beginner'},
          'xp': 120,
          'streakDays': 3,
          'lastActiveDate': '2026-11-21',
          'scoresByCourse': <String, dynamic>{},
          'completedLessonIds': ['lesson_math_starter'],
          'completedNodeIds': <String>[],
          'completedReinforcementIds': <String>[],
          'createdAt': 1,
        },
        'history': const [],
      });
      SharedPreferences.setMockInitialValues({
        LocalStorageService.productTourCompletedKey: true,
        LocalStorageService.demoLearnerSnapshotKey: snapshotJson,
      });
      final storage = await LocalStorageService.load();

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          learnerRepositoryProvider.overrideWithValue(
            InMemoryLearnerRepository(storage: storage),
          ),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
          GoRoute(path: '/courses', builder: (_, _) => const Text('COURSES')),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Text('DASHBOARD'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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

      final demoBtn = find.text(AppStrings.uz.demoEnterAction);
      await tester.ensureVisible(demoBtn);
      await tester.tap(demoBtn);
      await tester.pumpAndSettle();

      expect(demoSessionActive.value, isTrue);
      expect(activeSessionHasStartedCourse.value, isTrue);
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('LoginScreen empty submit in demo/offline mode shows emptyLoginFieldsError', (tester) async {
      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      SupabaseConfig.hasRemoteConfiguration = false;
      addTearDown(() => SupabaseConfig.hasRemoteConfiguration = previousRemote);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.uz.loginAction));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.uz.emptyLoginFieldsError), findsOneWidget);
      expect(find.text(AppStrings.uz.authServiceOfflineShort), findsNothing);
    });

    testWidgets('YolchiAiSheet Retry recovers cleanly after initial failure without Future setState error', (tester) async {
      var attempt = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('uz'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          home: Scaffold(
            body: YolchiAiSheet(
              loadExplanation: () async {
                attempt++;
                if (attempt == 1) {
                  throw StateError('transient failure');
                }
                return const AIExplanationResponse(
                  tutorName: 'Yölçi',
                  title: 'Çiziqli funksiya',
                  explanation: 'f(4) = 2*4 + 3 = 11.',
                  remediationStep: 'Qayta hisoblang.',
                  suggestedAction: 'Mavzuni mustahkamlang',
                  isDeterministicFallback: true,
                );
              },
              onStartReinforcement: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.uz.yolchiExplanationLoadFailed), findsOneWidget);
      await tester.tap(find.text(AppStrings.uz.retry));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(attempt, 2);
      expect(find.text('f(4) = 2*4 + 3 = 11.'), findsOneWidget);
    });

    testWidgets('YolchiAiSheet Retry handles <1 frame pre-await async throw on calls #1 & #2 and recovers on #3', (tester) async {
      var attempt = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('uz'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          home: Scaffold(
            body: YolchiAiSheet(
              loadExplanation: () async {
                attempt++;
                if (attempt <= 2) {
                  throw StateError('fast offline failure #$attempt');
                }
                return const AIExplanationResponse(
                  tutorName: 'Yölçi',
                  title: 'Çiziqli funksiya',
                  explanation: 'f(4) = 2*4 + 3 = 11.',
                  remediationStep: 'Qayta hisoblang.',
                  suggestedAction: 'Mavzuni mustahkamlang',
                  isDeterministicFallback: true,
                );
              },
              onStartReinforcement: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(attempt, 1);
      expect(find.text(AppStrings.uz.yolchiExplanationLoadFailed), findsOneWidget);

      await tester.tap(find.text(AppStrings.uz.retry));
      await tester.pumpAndSettle();

      expect(attempt, 2);
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.uz.yolchiExplanationLoadFailed), findsOneWidget);

      await tester.tap(find.text(AppStrings.uz.retry));
      await tester.pumpAndSettle();

      expect(attempt, 3);
      expect(tester.takeException(), isNull);
      expect(find.text('f(4) = 2*4 + 3 = 11.'), findsOneWidget);
    });

    testWidgets('authErrorMessage localizes uz/ru and shared widgets honor disableAnimations', (tester) async {
      const err = AuthException('bad', code: 'invalid_credentials');
      expect(authErrorMessage(err), 'Email yoki parol xato.');
      expect(
        authErrorMessage(err, strings: AppStrings.ru),
        'Неверный email или пароль.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('uz'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: const BilimYolBottomNav(currentIndex: 0),
            body: AppCard(
              child: AppButton(text: 'OK', onPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final animatedContainers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      expect(animatedContainers, isNotEmpty);
      for (final container in animatedContainers) {
        expect(container.duration, Duration.zero);
      }
    });

    testWidgets('Tour Page 3 next-lesson pill uses WCAG AA brandStrong in Dark and brand in Light', (tester) async {
      double contrastRatio(Color fg, Color bg) {
        final l1 = fg.computeLuminance();
        final l2 = bg.computeLuminance();
        final bright = math.max(l1, l2);
        final dark = math.min(l1, l2);
        return (bright + 0.05) / (dark + 0.05);
      }

      for (final isDark in [false, true]) {
        final expectedColors = isDark
            ? AppSemanticColors.dark
            : AppSemanticColors.light;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              locale: const Locale('uz'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              home: WelcomeScreen(key: ValueKey('pill-contrast-$isDark')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.uz.tourNext));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.uz.tourNext));
        await tester.pumpAndSettle();

        final nextPillText = tester.widget<Text>(
          find.text(AppStrings.uz.tourSlide3NextBadge),
        );
        final expectedFg = isDark
            ? expectedColors.brandStrong
            : expectedColors.brand;
        expect(nextPillText.style?.color, expectedFg);

        final compositedBg = Color.alphaBlend(
          expectedColors.brandSoft,
          expectedColors.subtle,
        );
        expect(
          contrastRatio(expectedFg, compositedBg),
          greaterThanOrEqualTo(4.5),
          reason:
              'Tour Page 3 _StageNodePill contrast in dark=$isDark must be >= 4.5:1',
        );
      }
    });
  });
}
