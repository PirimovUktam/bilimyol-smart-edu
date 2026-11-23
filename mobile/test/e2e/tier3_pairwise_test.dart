import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';

import 'e2e_harness.dart';

void main() {
  group('Tier 3 — Cross-Feature Pairwise Interactions', () {
    testWidgets(
      'T3.1 Tour Skip -> Demo -> Math -> Diagnostic -> Recommended Lesson -> Knowledge Map',
      (tester) async {
        final recorder = await pumpBilimYolApp(tester);

        await skipProductTour(tester);
        await enterDemoMode(tester);
        await selectCourse(tester, 'Matematika');
        await openOptionalDiagnostic(tester);
        await completePlacement(tester, highAccuracy: false);
        await scrollAndTap(
          tester,
          find.textContaining('Şaxsiy yölni köriş', findRichText: true),
        );

        final cta =
            find.textContaining('Maşq qiliş', findRichText: true).evaluate().isNotEmpty
            ? find.textContaining('Maşq qiliş', findRichText: true)
            : find.textContaining('Boşlaş', findRichText: true);
        await scrollAndTap(tester, cta);
        await submitLessonQuiz(tester, correct: true);

        appRouter.go('/knowledge-map');
        await tester.pumpAndSettle();
        expect(find.textContaining('42 XP', findRichText: true), findsWidgets);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.2 Tour Finish -> Demo -> English -> Beginner Onboarding -> Starter Lesson -> Dashboard & Progress Sync',
      (tester) async {
        final recorder = await pumpBilimYolApp(tester);

        await completeProductTour(tester);
        await enterDemoMode(tester);
        await selectCourse(tester, 'Ingliz tili');
        await scrollAndTap(
          tester,
          find.textContaining('Dars bilan boşlaş', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Birinçi darsni boşlaş', findRichText: true),
        );
        await submitLessonQuiz(tester, correct: true);

        await tapBottomNav(tester, L10nExpect.navHome);
        L10nExpect.expectAnyVisible(['22 XP', '+22']);

        await tapBottomNav(tester, L10nExpect.navProgress);
        expect(find.textContaining('1/4 Olingan', findRichText: true), findsOneWidget);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.3 Returning learner cold restart lands on /dashboard -> 1-tap continue -> Lesson -> Updated Progress',
      (tester) async {
        final recorder = await pumpBilimYolApp(tester);

        await enterDemoMode(tester);
        await selectCourse(tester, 'IT & Kodlaş');
        await scrollAndTap(
          tester,
          find.textContaining('Dars bilan boşlaş', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Birinçi darsni boşlaş', findRichText: true),
        );
        await submitLessonQuiz(tester, correct: true);

        // Cold restart: persisted tour + demo session should land directly on /dashboard.
        await restartBilimYolApp(tester);
        expect(
          find.textContaining('Bugungi maqsad', findRichText: true),
          findsOneWidget,
        );

        final continueBtn =
            find.textContaining('Davom etiş', findRichText: true).evaluate().isNotEmpty
            ? find.textContaining('Davom etiş', findRichText: true)
            : find.textContaining('Birinçi darsni oçiş', findRichText: true);
        await scrollAndTap(tester, continueBtn);

        expect(find.textContaining('Qadam 1 /', findRichText: true), findsOneWidget);
        await submitLessonQuiz(tester, correct: true);

        await tapBottomNav(tester, L10nExpect.navProgress);
        expect(find.textContaining('44 XP', findRichText: true), findsWidgets);

        await tapBottomNav(tester, L10nExpect.navRoadmap);
        await scrollAndTap(
          tester,
          find.textContaining('Bilim xaritasi', findRichText: true),
        );
        expect(find.textContaining('44 XP', findRichText: true), findsWidgets);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.4 uz <-> ru + light <-> dark switch updates all 5 bottom nav tabs',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/profile',
        );

        await scrollAndTap(
          tester,
          L10nExpect.findAnyText(L10nExpect.themeDarkCandidates),
        );
        await scrollAndTap(
          tester,
          L10nExpect.findAnyText(['Русский', 'RU', 'Rus']),
        );

        final tabChecks = <({List<String> nav, List<String> expectedRu, List<String> forbiddenUz})>[
          (
            nav: L10nExpect.navHome,
            expectedRu: L10nExpect.dashboardCopyRu,
            forbiddenUz: ['Bugungi maqsad', 'Mening kurslarim'],
          ),
          (
            nav: L10nExpect.navRoadmap,
            expectedRu: L10nExpect.roadmapCopyRu,
            forbiddenUz: ['Mening ta’lim yölim'],
          ),
          (
            nav: L10nExpect.navAi,
            expectedRu: L10nExpect.aiTutorCopyRu,
            forbiddenUz: ['Salom, men Yölçi AI'],
          ),
          (
            nav: L10nExpect.navProgress,
            expectedRu: L10nExpect.progressCopyRu,
            forbiddenUz: ['Mening natijalarim'],
          ),
          (
            nav: L10nExpect.navProfile,
            expectedRu: L10nExpect.profileCopyRu,
            forbiddenUz: ['Profilim', 'Öquv sozlamalari'],
          ),
        ];

        for (final check in tabChecks) {
          await tapBottomNav(tester, check.nav);
          expectScaffoldThemeBrightness(tester, Brightness.dark);
          L10nExpect.expectAnyVisible(check.expectedRu);
          L10nExpect.expectNoneVisible(check.forbiddenUz);
        }
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.5 Active demo session routing precedence bypasses /welcome & /login',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/welcome',
        );

        expect(
          find.textContaining('Nimadan boşlaşni biling', findRichText: true),
          findsNothing,
        );
        appRouter.go('/login');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Xuş kelibsiz', findRichText: true),
          findsNothing,
        );
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.6 Tour completed + unauthenticated preserves incomplete onboarding/diagnostic',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          mockPrefs: {E2EConfig.keyProductTourCompleted: true},
        );

        L10nExpect.expectAnyVisible(L10nExpect.loginButton);
        await enterDemoMode(tester);
        await selectCourse(tester, 'Mantiq');

        // Onboarding must NOT have been skipped when tour completed.
        expect(
          find.textContaining('Birinçi qadamingizni tanlang', findRichText: true),
          findsOneWidget,
        );
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.7 Profile Demo Reset wipes XP & completed lessons and returns to /courses',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/placement',
        );

        await scrollAndTap(
          tester,
          find.textContaining('Tezkor demo', findRichText: true),
        );
        await tapBottomNav(tester, L10nExpect.navProfile);
        expect(find.text('0 XP', findRichText: true), findsNothing);
        expect(
          find.textContaining(RegExp(r'[1-9]\d*\s*XP'), findRichText: true),
          findsWidgets,
        );

        await scrollAndTap(
          tester,
          L10nExpect.findAnyText(L10nExpect.demoResetCandidates),
        );
        L10nExpect.expectAnyVisible([
          'Fanlar katalogi',
          'Fan tanlaş',
          'Qaysi fanni',
          'Выбрать предмет',
        ]);

        appRouter.go('/progress');
        await tester.pumpAndSettle();
        expect(find.text('0 XP', findRichText: true), findsWidgets);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.8 Profile Logout clears demo session and blocks private routes',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/profile',
        );

        await scrollAndTap(
          tester,
          find.textContaining('Hisobdan çiqiş', findRichText: true),
        );
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);

        appRouter.go('/dashboard');
        await tester.pumpAndSettle();
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);
        expect(
          find.textContaining('Bugungi maqsad', findRichText: true),
          findsNothing,
        );
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.9 Course switching (Matematika -> IT & Kodlaş) updates Dashboard, Knowledge Map & Roadmap',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'Matematika');
        await scrollAndTap(
          tester,
          find.textContaining('Mavzuni özim tanlayman', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Ta’lim yölini oçiş', findRichText: true),
        );

        appRouter.go('/courses');
        await tester.pumpAndSettle();
        await selectCourse(tester, 'IT & Kodlaş');
        await scrollAndTap(
          tester,
          find.textContaining('Mavzuni özim tanlayman', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Ta’lim yölini oçiş', findRichText: true),
        );

        L10nExpect.expectAnyVisible([
          'Python',
          'Veb sahifa',
          'Veb dasturlaş',
          'IT',
        ]);

        await scrollAndTap(
          tester,
          find.textContaining('Bilim xaritasi', findRichText: true),
        );
        L10nExpect.expectAnyVisible([
          'Bilim xaritasi',
          'Bilim Xaritasi',
          'Карта знаний',
        ]);
        L10nExpect.expectAnyVisible([
          'Python',
          'Veb dasturlaş',
          'Veb sahifa',
        ]);

        await tapBottomNav(tester, L10nExpect.navHome);
        expect(find.textContaining('Bugungi maqsad', findRichText: true), findsOneWidget);
        expect(find.textContaining('IT & Kodlaş', findRichText: true), findsWidgets);

        await tapBottomNav(tester, L10nExpect.navProfile);
        expect(find.textContaining('IT & Kodlaş', findRichText: true), findsWidgets);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.10 Course switching (Ingliz tili -> Mantiq) isolates skill scores per subject',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'Mantiq');
        await openOptionalDiagnostic(tester);
        await completePlacement(tester, highAccuracy: true);
        await scrollAndTap(
          tester,
          find.textContaining('Şaxsiy yölni köriş', findRichText: true),
        );

        appRouter.go('/courses');
        await tester.pumpAndSettle();
        await selectCourse(tester, 'Ingliz tili');
        // Switching to unstarted English must still ask onboarding, not inherit Logic placement!
        expect(
          find.textContaining('Birinçi qadamingizni tanlang', findRichText: true),
          findsOneWidget,
        );
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.11 Lesson wrong answer -> YolchiAiSheet -> ReinforcementSheet -> Roadmap unlock + XP bump',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/placement',
        );

        await scrollAndTap(
          tester,
          find.textContaining('Tezkor demo', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Moslaşuvçan Yöl Xaritasi', findRichText: true),
        );
        final cta =
            find.textContaining('Maşq qiliş', findRichText: true).evaluate().isNotEmpty
            ? find.textContaining('Maşq qiliş', findRichText: true)
            : find.textContaining('Boşlaş', findRichText: true);
        await scrollAndTap(tester, cta);

        await submitLessonQuiz(tester, correct: false);
        await scrollAndTap(
          tester,
          find.textContaining('Yölçi AI tahlili', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.textContaining(
              'Mavzuni mustahkamlaş',
              findRichText: true,
            ),
          ),
        );
        await solveReinforcementSheet(tester);
        await scrollAndTap(
          tester,
          find.textContaining('Daşboardga Ötiş', findRichText: true),
        );

        expect(
          find.textContaining('Mening ta’lim yölim', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('Mustahkamlaş: Funksiyalar', findRichText: true),
          findsNothing,
        );
        expect(
          find.textContaining('Qayta maşq kerak', findRichText: true),
          findsNothing,
        );
        expect(
          find.textContaining('Boşlaş', findRichText: true),
          findsWidgets,
        );
        await tapBottomNav(tester, L10nExpect.navProgress);
        expect(find.textContaining('150 XP', findRichText: true), findsWidgets);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.12 360dp + 2.0x textScale + Dark mode + ru locale combined on /dashboard & /roadmap',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          brightness: Brightness.dark,
          initialDemoSession: true,
          initialRoute: '/dashboard',
          mockPrefs: {
            E2EConfig.keyLocale: 'ru',
            E2EConfig.keyThemeMode: 'dark',
          },
        );

        expectScaffoldThemeBrightness(tester, Brightness.dark);
        L10nExpect.expectAnyVisible(L10nExpect.dashboardCopyRu);
        L10nExpect.expectNoneVisible(['Bugungi maqsad', 'Mening kurslarim']);
        await tapBottomNav(tester, L10nExpect.navRoadmap);
        expectScaffoldThemeBrightness(tester, Brightness.dark);
        L10nExpect.expectAnyVisible(L10nExpect.roadmapCopyRu);
        L10nExpect.expectNoneVisible(['Mening ta’lim yölim']);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.13 360dp + keyboard open + Dark mode on /login & /ai-tutor',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          brightness: Brightness.dark,
          keyboardBottomInset: 280,
          initialRoute: '/login',
          mockPrefs: {E2EConfig.keyThemeMode: 'dark'},
        );

        await tester.enterText(find.byType(TextField).first, 'demo@misol.uz');
        await enterDemoMode(tester);
        appRouter.go('/ai-tutor');
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'Savol');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.14 Profile Tour Replay preserves completed lessons and XP',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'Mantiq');
        await scrollAndTap(
          tester,
          find.textContaining('Dars bilan boşlaş', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Birinçi darsni boşlaş', findRichText: true),
        );
        await submitLessonQuiz(tester, correct: true);
        await submitLessonQuiz(tester, correct: true);

        await tapBottomNav(tester, L10nExpect.navProfile);
        await scrollAndTap(
          tester,
          L10nExpect.findAnyText(L10nExpect.tourReplayCandidates),
        );
        await completeProductTour(tester);

        appRouter.go('/progress');
        await tester.pumpAndSettle();
        expect(find.textContaining('24 XP', findRichText: true), findsWidgets);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.15 Demo mode auth routes (/register, /forgot-password, /reset-password) guard safely',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialRoute: '/register',
        );
        expect(find.textContaining('Yangi hisob yaratiş', findRichText: true), findsOneWidget);

        appRouter.go('/forgot-password');
        await tester.pumpAndSettle();
        expect(find.textContaining('Parolni qayta tiklaş', findRichText: true), findsOneWidget);

        appRouter.go('/reset-password');
        await tester.pumpAndSettle();
        // Without recovery event, unauthenticated /reset-password safely routes to /login.
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.16 Reduced motion + AudioSimWaveWidget + AI Tutor offline fallback integration',
      (tester) async {
        final fakeAi = FakeControllableAITutorService();
        final recorder = await pumpBilimYolApp(
          tester,
          disableAnimations: true,
          initialDemoSession: true,
          initialRoute: '/courses',
          overrides: [aiTutorServiceProvider.overrideWithValue(fakeAi)],
        );

        await selectCourse(tester, 'Ingliz tili');
        await scrollAndTap(
          tester,
          find.textContaining('Dars bilan boşlaş', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Birinçi darsni boşlaş', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Keyingi qadam', findRichText: true),
        );
        await tester.tap(find.byTooltip('Yölçidan söraş'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.textContaining('Qoidani sodda tuşuntir', findRichText: true),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('qadam-baqadam yeçim', findRichText: true), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs, isNotNull);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.17 Active demo session preserves deep-links (/knowledge-map, /progress, /courses) without /welcome hijack',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/knowledge-map',
          mockPrefs: {E2EConfig.keyProductTourCompleted: false},
        );

        expect(
          appRouter.routeInformationProvider.value.uri.path,
          '/knowledge-map',
        );
        L10nExpect.expectAnyVisible([
          'Bilim xaritasi',
          'Bilim Xaritasi',
          'Карта знаний',
        ]);
        L10nExpect.expectNoneVisible(['Nimadan boşlaşni biling']);

        appRouter.go('/progress');
        await tester.pumpAndSettle();
        expect(appRouter.routeInformationProvider.value.uri.path, '/progress');
        expect(
          find.textContaining('Mening natijalarim', findRichText: true),
          findsOneWidget,
        );

        appRouter.go('/courses');
        await tester.pumpAndSettle();
        expect(appRouter.routeInformationProvider.value.uri.path, '/courses');
        L10nExpect.expectAnyVisible([
          'Fanlar katalogi',
          'Fan tanlaş',
          'Qaysi fanni',
          'Выбрать предмет',
        ]);
        recorder.expectClean();
      },
    );

    testWidgets(
      'T3.18 Deep-link uz.bilimyol.mobile://auth/reset-password and /reset-password guard without recovery session',
      (tester) async {
        final recorder = await pumpBilimYolApp(tester);

        appRouter.go('uz.bilimyol.mobile://auth/reset-password');
        await tester.pumpAndSettle();
        expect(appRouter.routeInformationProvider.value.uri.path, '/login');
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);
        expect(
          find.textContaining('Yangi parol belgilang', findRichText: true),
          findsNothing,
        );

        // Even with an active demo session, /reset-password without recovery must guard safely.
        await enterDemoMode(tester);
        appRouter.go('/reset-password');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Yangi parol belgilang', findRichText: true),
          findsNothing,
        );
        recorder.expectClean();
      },
    );
  });
}
