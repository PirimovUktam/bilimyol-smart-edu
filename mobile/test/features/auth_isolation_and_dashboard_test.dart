import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/core/widgets/demo_control_bar.dart';
import 'package:bilimyol_mobile/core/widgets/friendly_error_state.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/features/auth/register_screen.dart';
import 'package:bilimyol_mobile/features/dashboard/dashboard_screen.dart';
import 'package:bilimyol_mobile/features/profile/profile_screen.dart';

void main() {
  group('Auth Guard, Provider Isolation & Dashboard Course Filter', () {
    testWidgets('RegisterScreen guards null SupabaseConfig.client in demo mode without throwing', (tester) async {
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
            home: const RegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ali');
      await tester.enterText(fields.at(1), 'ali@example.com');
      await tester.enterText(fields.at(2), 'secret123');
      await tester.enterText(fields.at(3), 'secret123');
      await tester.pump();

      final submitBtn = find.text('Hisob Yaratish');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Namuna rejimida yangi hisob yaratilmaydi.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    test('LearnerStateNotifier.resetAll invalidates placement & lesson session providers', () async {
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
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
      await container.read(placementStateNotifierProvider.notifier).loadQuestions('course_math_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_math_functions_01');

      expect(container.read(placementStateNotifierProvider).courseId, 'course_math_01');
      expect(container.read(lessonSessionNotifierProvider).lesson?.id, 'lesson_math_functions_01');

      await container.read(learnerStateNotifierProvider.notifier).resetAll();

      expect(container.read(placementStateNotifierProvider).courseId, isEmpty);
      expect(container.read(lessonSessionNotifierProvider).lesson, isNull);
    });

    testWidgets('DashboardScreen filters Aktiv, Tavsiya, Barchasi tabs and shows Mantiq', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');

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

      // Default tab 0 (Aktiv): Hero pill + Matematika course card, Mantiq not shown
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      final barchasiTab = find.text('Barchasi');
      expect(find.text('Matematika'), findsNWidgets(2));
      expect(find.text('Mantiq'), findsNothing);

      // Tap tab 1 (Tavsiya): unstarted courses including Mantiq appear, active Matematika excluded from list (only Hero pill remains)
      await tester.tap(find.text('Tavsiya'));
      await tester.pumpAndSettle();
      expect(find.text('Ingliz tili'), findsOneWidget);
      expect(find.text('IT & Kodlash'), findsOneWidget);
      expect(find.text('Mantiq'), findsOneWidget);
      expect(find.text('Matematika'), findsOneWidget);

      // Tap tab 2 (Barchasi): all 4 courses including Mantiq appear without .take(3) truncation
      await tester.tap(barchasiTab);
      await tester.pumpAndSettle();
      expect(find.text('Matematika'), findsNWidgets(2));
      expect(find.text('Ingliz tili'), findsOneWidget);
      expect(find.text('IT & Kodlash'), findsOneWidget);
      expect(find.text('Mantiq'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DashboardScreen renders at 360x800 with 2.0x text scale in uz and ru without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      SupabaseConfig.hasRemoteConfiguration = false;
      addTearDown(() => SupabaseConfig.hasRemoteConfiguration = previousRemote);

      for (final code in ['uz', 'ru']) {
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
        await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
        await container.read(appSettingsProvider.notifier).setLocale(code);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              locale: Locale(code),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: child!,
              ),
              home: const DashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Initial overflow in $code');

        final bottomAiBtn = find.text(AppStrings.forCode(code).openChat);
        await tester.scrollUntilVisible(
          bottomAiBtn,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Scrolled overflow in $code');
      }
    });

    testWidgets('DemoControlBar in DashboardScreen at 412x800 @ 1.14x gives banner > 180dp width with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(412, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      SupabaseConfig.hasRemoteConfiguration = false;
      addTearDown(() => SupabaseConfig.hasRemoteConfiguration = previousRemote);

      for (final code in ['uz', 'ru']) {
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
        await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
        await container.read(appSettingsProvider.notifier).setLocale(code);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              locale: Locale(code),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.14),
                ),
                child: child!,
              ),
              home: const DashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow at 412x800 @ 1.14x in $code');

        final strings = AppStrings.forCode(code);
        final bannerSize = tester.getSize(find.text(strings.demoBanner));
        expect(
          bannerSize.width,
          greaterThan(180),
          reason: 'Banner text squeezed at 412dp @ 1.14x in $code: $bannerSize',
        );
      }
    });

    test('PROBE_NOTIFIER_STALE_LOAD: pre-reset loadProfile completing after resetAll does not resurrect XP', () async {
      final repo = _ControllableLearnerRepo();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await repo.addXp(80, 'pre_reset_xp');
      final notifier = container.read(learnerStateNotifierProvider.notifier);
      await notifier.loadProfile();
      expect(container.read(learnerStateNotifierProvider).value?.xp, 80);

      repo.armGetProfileGate();
      final staleLoadFuture = notifier.loadProfile();
      await repo.getProfileEntered.future;

      await notifier.resetAll();
      expect(container.read(learnerStateNotifierProvider).value?.xp, 0);

      repo.releaseGetProfile();
      await staleLoadFuture;

      expect(container.read(learnerStateNotifierProvider).value?.xp, 0);
      expect((await repo.getProfile()).xp, 0);
    });

    test('PROBE_INTERLEAVE_NOTIFIERS_2: resetAll slow clear does not overwrite concurrent post-reset loadProfile', () async {
      final storage = _BlockingClearStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await repo.addXp(80, 'pre_reset_xp');
      final notifier = container.read(learnerStateNotifierProvider.notifier);
      await notifier.loadProfile();

      storage.armClearGate();
      final resetFuture = notifier.resetAll();
      await storage.clearEntered.future;

      final addXpFuture = repo.addXp(50, 'post_reset_xp');
      await notifier.loadProfile();
      expect(container.read(learnerStateNotifierProvider).value?.xp, 50);

      storage.releaseClear();
      await Future.wait([resetFuture, addXpFuture]);

      expect(container.read(learnerStateNotifierProvider).value?.xp, 50);
      expect((await repo.getProfile()).xp, 50);
    });

    test('LearnerStateNotifier.resetAll completes cleanly if disposed mid-clear', () async {
      final storage = _BlockingClearStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );

      final notifier = container.read(learnerStateNotifierProvider.notifier);
      await notifier.loadProfile();

      storage.armClearGate();
      final resetFuture = notifier.resetAll();
      await storage.clearEntered.future;

      container.dispose();
      storage.releaseClear();
      await resetFuture;
    });

    test('PROBE_MID_CLEAR_POST_RESET_SESSION_WIPE: slow clear in resetAll preserves post-reset loadProfile, placement, and lesson session', () async {
      final storage = _BlockingClearStorage();
      final repo = InMemoryLearnerRepository(storage: storage);
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');
      await repo.addXp(80, 'pre_reset_xp');
      final notifier = container.read(learnerStateNotifierProvider.notifier);
      await notifier.loadProfile();
      expect(container.read(learnerStateNotifierProvider).value?.xp, 80);

      storage.armClearGate();
      final resetFuture = notifier.resetAll();
      await storage.clearEntered.future;

      final addXpFuture = repo.addXp(50, 'post_reset_xp');
      await notifier.loadProfile();
      await container.read(placementStateNotifierProvider.notifier).loadQuestions('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_vocab_01');

      expect(container.read(placementStateNotifierProvider).courseId, 'course_eng_01');
      expect(container.read(lessonSessionNotifierProvider).lesson?.id, 'lesson_eng_vocab_01');

      storage.releaseClear();
      await Future.wait([resetFuture, addXpFuture]);

      expect(container.read(learnerStateNotifierProvider).value?.xp, 50);
      expect(container.read(placementStateNotifierProvider).courseId, 'course_eng_01');
      expect(container.read(lessonSessionNotifierProvider).lesson?.id, 'lesson_eng_vocab_01');
    });

    test('PROBE_OVERLAPPING_RESETS_OUT_OF_ORDER_REPO: out-of-order reset1 finishing after reset2 does not wipe post-reset2 session', () async {
      final repo = _OutOfOrderResetRepo();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await repo.addXp(60, 'pre_reset_xp');
      final notifier = container.read(learnerStateNotifierProvider.notifier);
      await notifier.loadProfile();

      repo.armFirstResetGate();
      final reset1Future = notifier.resetAll();
      await repo.firstResetEntered.future;

      await notifier.resetAll();
      expect(container.read(learnerStateNotifierProvider).hasValue, isTrue);
      expect(container.read(learnerStateNotifierProvider).isLoading, isFalse);
      expect(container.read(learnerStateNotifierProvider).value?.xp, 0);

      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      expect(container.read(courseStateNotifierProvider).activeCourse?.id, 'course_eng_01');
      await container.read(placementStateNotifierProvider.notifier).loadQuestions('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_vocab_01');

      repo.releaseFirstReset();
      await reset1Future;

      expect(container.read(learnerStateNotifierProvider).hasValue, isTrue);
      expect(container.read(learnerStateNotifierProvider).isLoading, isFalse);
      expect(container.read(courseStateNotifierProvider).activeCourse?.id, 'course_eng_01');
      expect(container.read(placementStateNotifierProvider).courseId, 'course_eng_01');
      expect(container.read(lessonSessionNotifierProvider).lesson?.id, 'lesson_eng_vocab_01');
    });

    test('PROBE_9_SELECT_COURSE_RIGHT_AFTER_RESET_DOES_NOT_DROP: selectCourse immediately after resetAll awaits invalidated init', () async {
      final repo = InMemoryLearnerRepository();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.listen(courseStateNotifierProvider, (_, _) {});
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(learnerStateNotifierProvider.notifier).loadProfile();

      await container.read(learnerStateNotifierProvider.notifier).resetAll();
      expect(container.read(courseStateNotifierProvider).isLoading, isTrue);

      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');

      expect(container.read(courseStateNotifierProvider).isLoading, isFalse);
      expect(container.read(courseStateNotifierProvider).activeCourse?.id, 'course_eng_01');
      expect((await repo.getProfile()).selectedCourseId, 'course_eng_01');
    });

    testWidgets('PROBE_5B: DemoControlBar and ProfileScreen catch resetAll failures cleanly with localized feedback', (tester) async {
      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      final previousDemoSession = demoSessionActive.value;
      SupabaseConfig.hasRemoteConfiguration = false;
      demoSessionActive.value = true;
      addTearDown(() {
        SupabaseConfig.hasRemoteConfiguration = previousRemote;
        demoSessionActive.value = previousDemoSession;
      });

      // 1) Standalone DemoControlBar
      final repo1 = _AlwaysThrowResetRepo();
      final container1 = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo1),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container1.dispose);
      await container1.read(learnerStateNotifierProvider.notifier).loadProfile();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container1,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            home: const Scaffold(body: DemoControlBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.uz.demoReset));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.uz.demoResetFailed), findsOneWidget);
      expect(container1.read(learnerStateNotifierProvider).hasError, isFalse);

      // 2) DemoControlBar hosted inside DashboardScreen (immediate throw -> recovers in place)
      final repo2 = _AlwaysThrowResetRepo();
      final container2 = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo2),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container2.dispose);
      await container2.read(courseStateNotifierProvider.notifier).init();
      await container2.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container2,
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

      await tester.tap(find.text(AppStrings.uz.demoReset));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.uz.demoResetFailed), findsOneWidget);
      expect(container2.read(learnerStateNotifierProvider).hasError, isFalse);
      expect(find.byType(DemoControlBar), findsOneWidget);

      // 3) DemoControlBar hosted inside DashboardScreen (async throw after loading unmounts bar)
      final repo2Async = _DelayedThrowResetRepo();
      final container2Async = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo2Async),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container2Async.dispose);
      await container2Async.read(courseStateNotifierProvider.notifier).init();
      await container2Async.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container2Async,
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

      await tester.tap(find.text(AppStrings.uz.demoReset));
      await tester.pump();
      repo2Async.failReset();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.uz.demoResetFailed), findsOneWidget);
      expect(find.byType(FriendlyErrorState), findsOneWidget);

      await tester.tap(find.text(AppStrings.uz.retry));
      await tester.pumpAndSettle();
      expect(container2Async.read(learnerStateNotifierProvider).hasError, isFalse);
      expect(find.byType(DemoControlBar), findsOneWidget);

      // 4) ProfileScreen reset button
      final repo3 = _AlwaysThrowResetRepo();
      final container3 = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo3),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container3.dispose);
      await container3.read(courseStateNotifierProvider.notifier).init();
      await container3.read(learnerStateNotifierProvider.notifier).loadProfile();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container3,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final profileResetBtn = find.text('Namuna natijalarini tiklash');
      await tester.ensureVisible(profileResetBtn);
      await tester.tap(profileResetBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.uz.demoResetFailed), findsOneWidget);
      expect(container3.read(learnerStateNotifierProvider).hasError, isFalse);
    });

    testWidgets('PROBE_5B_2: DemoControlBar inside DashboardScreen navigates to /courses when async resetAll spans >= 1 frame', (tester) async {
      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      final previousDemoSession = demoSessionActive.value;
      SupabaseConfig.hasRemoteConfiguration = false;
      demoSessionActive.value = true;
      addTearDown(() {
        SupabaseConfig.hasRemoteConfiguration = previousRemote;
        demoSessionActive.value = previousDemoSession;
      });

      final repo = _DelayedSuccessResetRepo();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/courses',
            builder: (_, _) => const Scaffold(body: Center(child: Text('COURSES_DEST'))),
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

      await tester.tap(find.text(AppStrings.uz.demoReset));
      await repo.resetEntered.future;
      // Pump 1 frame while resetAll is in-flight so DashboardScreen renders loading & unmounts DemoControlBar
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(DemoControlBar), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.completeReset();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(router.routeInformationProvider.value.uri.path, '/courses');
      expect(find.text('COURSES_DEST'), findsOneWidget);
    });

    testWidgets('PROBE_5B_2B_PUSH: manual router.push(/lesson) while resetAll in-flight does NOT hijack navigation', (tester) async {
      final previousRemote = SupabaseConfig.hasRemoteConfiguration;
      final previousDemoSession = demoSessionActive.value;
      SupabaseConfig.hasRemoteConfiguration = false;
      demoSessionActive.value = true;
      addTearDown(() {
        SupabaseConfig.hasRemoteConfiguration = previousRemote;
        demoSessionActive.value = previousDemoSession;
      });

      final repo = _DelayedSuccessResetRepo();
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_math_01');

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/lesson',
            builder: (_, _) => const Scaffold(body: Center(child: Text('LESSON_DEST'))),
          ),
          GoRoute(
            path: '/courses',
            builder: (_, _) => const Scaffold(body: Center(child: Text('COURSES_DEST'))),
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

      await tester.tap(find.text(AppStrings.uz.demoReset));
      await repo.resetEntered.future;
      await tester.pump(const Duration(milliseconds: 16));

      unawaited(router.push('/lesson'));
      await tester.pumpAndSettle();
      expect(find.text('LESSON_DEST'), findsOneWidget);

      repo.completeReset();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('LESSON_DEST'), findsOneWidget);
      expect(find.text('COURSES_DEST'), findsNothing);
      expect(router.routerDelegate.currentConfiguration.matches.last.matchedLocation, '/lesson');
    });
  });
}

class _ControllableLearnerRepo extends InMemoryLearnerRepository {
  Completer<void>? _getProfileGate;
  Completer<void> getProfileEntered = Completer<void>();

  void armGetProfileGate() {
    getProfileEntered = Completer<void>();
    _getProfileGate = Completer<void>();
  }

  void releaseGetProfile() {
    final gate = _getProfileGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<LearnerProfile> getProfile() async {
    final gate = _getProfileGate;
    if (gate != null && !gate.isCompleted) {
      if (!getProfileEntered.isCompleted) getProfileEntered.complete();
      await gate.future;
    }
    return super.getProfile();
  }
}

class _BlockingClearStorage extends LocalStorageService {
  Completer<void> clearEntered = Completer<void>();
  Completer<void>? _clearGate;
  String? _snapshot;

  void armClearGate() {
    clearEntered = Completer<void>();
    _clearGate = Completer<void>();
  }

  void releaseClear() {
    final gate = _clearGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<String?> getDemoLearnerSnapshot() async => _snapshot;

  @override
  Future<void> setDemoLearnerSnapshot(String json) async {
    _snapshot = json;
  }

  @override
  Future<void> clearDemoLearnerSnapshot() async {
    if (!clearEntered.isCompleted) clearEntered.complete();
    final gate = _clearGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    _snapshot = null;
  }
}

class _OutOfOrderResetRepo extends InMemoryLearnerRepository {
  Completer<void> firstResetEntered = Completer<void>();
  Completer<void>? _firstResetGate;
  bool _blockNextReset = false;

  void armFirstResetGate() {
    firstResetEntered = Completer<void>();
    _firstResetGate = Completer<void>();
    _blockNextReset = true;
  }

  void releaseFirstReset() {
    final gate = _firstResetGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<LearnerProfile> resetAll() async {
    final shouldBlock = _blockNextReset;
    _blockNextReset = false;
    final profile = await super.resetAll();
    if (shouldBlock) {
      if (!firstResetEntered.isCompleted) firstResetEntered.complete();
      final gate = _firstResetGate;
      if (gate != null && !gate.isCompleted) {
        await gate.future;
      }
    }
    return profile;
  }
}

class _AlwaysThrowResetRepo extends InMemoryLearnerRepository {
  @override
  Future<LearnerProfile> resetAll() async {
    throw StateError('storage wipe failed');
  }
}

class _DelayedThrowResetRepo extends InMemoryLearnerRepository {
  final Completer<void> _gate = Completer<void>();

  void failReset() {
    if (!_gate.isCompleted) {
      _gate.completeError(StateError('delayed storage wipe failed'));
    }
  }

  @override
  Future<LearnerProfile> resetAll() async {
    await _gate.future;
    return super.resetAll();
  }
}

class _DelayedSuccessResetRepo extends InMemoryLearnerRepository {
  final Completer<void> resetEntered = Completer<void>();
  final Completer<void> _gate = Completer<void>();

  void completeReset() {
    if (!_gate.isCompleted) {
      _gate.complete();
    }
  }

  @override
  Future<LearnerProfile> resetAll() async {
    if (!resetEntered.isCompleted) resetEntered.complete();
    await _gate.future;
    return super.resetAll();
  }
}
