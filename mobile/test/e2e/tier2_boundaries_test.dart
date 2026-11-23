import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';

import 'e2e_harness.dart';

void main() {
  group('Tier 2 — Boundaries, Responsiveness, Themes & Edge Cases', () {
    // -----------------------------------------------------------------------
    // 1. 360dp @ 1.0x Zero-Overflow Sweep (F12 — 15 tests)
    // -----------------------------------------------------------------------
    group('360dp @ 1.0x Zero-Overflow Sweep', () {
      testWidgets('T2.1 /welcome 3-page tour has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
        );

        L10nExpect.expectAnyVisible(L10nExpect.tourPage1Titles);
        await tapAnyVisible(tester, L10nExpect.tourNext);
        L10nExpect.expectAnyVisible(L10nExpect.tourPage2Titles);
        await tapAnyVisible(tester, L10nExpect.tourNext);
        L10nExpect.expectAnyVisible(L10nExpect.tourPage3Titles);

        recorder.expectClean();
      });

      testWidgets('T2.2 /login has 0 overflow at 360dp @ 1.0x', (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialRoute: '/login',
        );
        recorder.expectClean();
      });

      testWidgets('T2.3 /register has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialRoute: '/register',
        );
        recorder.expectClean();
      });

      testWidgets('T2.4 /forgot-password has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialRoute: '/forgot-password',
        );
        recorder.expectClean();
      });

      testWidgets('T2.5 /courses has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialDemoSession: true,
          initialRoute: '/courses',
        );
        recorder.expectClean();
      });

      testWidgets('T2.6 /onboarding has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialDemoSession: true,
          initialRoute: '/onboarding',
        );
        recorder.expectClean();
      });

      testWidgets('T2.7 /placement has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialDemoSession: true,
          initialRoute: '/placement',
        );
        recorder.expectClean();
      });

      testWidgets('T2.8 /dashboard has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialDemoSession: true,
          initialRoute: '/dashboard',
        );
        recorder.expectClean();
      });

      testWidgets(
        'T2.9 /knowledge-map with demo scores has 0 overflow at 360dp @ 1.0x',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            initialDemoSession: true,
            initialRoute: '/placement',
          );
          await scrollAndTap(
            tester,
            find.textContaining('Tezkor demo', findRichText: true),
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.10 /roadmap with demo scores has 0 overflow at 360dp @ 1.0x',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
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
          recorder.expectClean();
        },
      );

      testWidgets('T2.11 /lesson has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
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
        await scrollAndTap(
          tester,
          find.textContaining('Keyingi qadam', findRichText: true),
        );
        recorder.expectClean();
      });

      testWidgets(
        'T2.12 /ai-tutor with bubbles has 0 overflow at 360dp @ 1.0x',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            initialDemoSession: true,
            initialRoute: '/ai-tutor',
          );
          await scrollAndTap(
            tester,
            find.textContaining('Qoidani sodda tuşuntir', findRichText: true),
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.13 /progress in week AND month mode with non-zero activity has 0 overflow at 360dp @ 1.0x',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            initialDemoSession: true,
            initialRoute: '/courses',
          );
          await selectCourse(tester, 'Matematika');
          await scrollAndTap(
            tester,
            find.textContaining('Dars bilan boşlaş', findRichText: true),
          );
          await scrollAndTap(
            tester,
            find.textContaining('Birinçi darsni boşlaş', findRichText: true),
          );
          await submitLessonQuiz(tester, correct: true);
          await tapBottomNav(tester, L10nExpect.navProgress);

          await scrollAndTap(
            tester,
            find.textContaining('Bu hafta', findRichText: true),
          );
          expect(
            find.textContaining('Bu oy', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets('T2.14 /profile has 0 overflow at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialDemoSession: true,
          initialRoute: '/profile',
        );
        recorder.expectClean();
      });

      testWidgets('T2.15 unknown route fallback renders cleanly at 360dp @ 1.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialDemoSession: true,
          initialRoute: '/does-not-exist-404',
        );
        expect(
          find.textContaining('Sahifa topilmadi', findRichText: true),
          findsOneWidget,
        );
        recorder.expectClean();
      });
    });

    // -----------------------------------------------------------------------
    // 2. 360dp @ 2.0x Text Scale Zero-Overflow Sweep (F12 — 14 tests)
    // -----------------------------------------------------------------------
    group('360dp @ 2.0x Text Scale Zero-Overflow Sweep', () {
      testWidgets('T2.16 /welcome tour pages have 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
        );

        await completeProductTour(tester);
        recorder.expectClean();
      });

      testWidgets('T2.17 /login has 0 overflow at 360dp @ 2.0x', (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialRoute: '/login',
        );
        recorder.expectClean();
      });

      testWidgets('T2.18 /register has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialRoute: '/register',
        );
        recorder.expectClean();
      });

      testWidgets('T2.19 /forgot-password has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialRoute: '/forgot-password',
        );
        recorder.expectClean();
      });

      testWidgets('T2.20 /courses has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialDemoSession: true,
          initialRoute: '/courses',
        );
        recorder.expectClean();
      });

      testWidgets('T2.21 /onboarding has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialDemoSession: true,
          initialRoute: '/onboarding',
        );
        recorder.expectClean();
      });

      testWidgets('T2.22 /placement has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialDemoSession: true,
          initialRoute: '/placement',
        );
        recorder.expectClean();
      });

      testWidgets('T2.23 /dashboard has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialDemoSession: true,
          initialRoute: '/dashboard',
        );
        recorder.expectClean();
      });

      testWidgets('T2.24 /knowledge-map has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialDemoSession: true,
          initialRoute: '/placement',
        );
        await scrollAndTap(
          tester,
          find.textContaining('Tezkor demo', findRichText: true),
        );
        recorder.expectClean();
      });

      testWidgets('T2.25 /roadmap has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
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
        recorder.expectClean();
      });

      testWidgets(
        'T2.26 /lesson and ReinforcementSheet have 0 overflow at 360dp @ 2.0x',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            textScale: 2.0,
            initialDemoSession: true,
            initialRoute: '/courses',
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
          await submitLessonQuiz(tester, correct: false);
          await scrollAndTap(
            tester,
            find.textContaining('Mavzuni mustahkamlaş', findRichText: true),
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.27 /ai-tutor and YolchiAiSheet have 0 overflow at 360dp @ 2.0x',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            textScale: 2.0,
            initialDemoSession: true,
            initialRoute: '/ai-tutor',
          );
          await scrollAndTap(
            tester,
            find.textContaining('Qoidani sodda tuşuntir', findRichText: true),
          );

          // Also open YolchiAiSheet at 360dp @ 2.0x via a wrong lesson answer.
          appRouter.go('/courses');
          await tester.pumpAndSettle();
          await selectCourse(tester, 'Ingliz tili');
          await scrollAndTap(
            tester,
            find.textContaining('Dars bilan boşlaş', findRichText: true),
          );
          await scrollAndTap(
            tester,
            find.textContaining('Birinçi darsni boşlaş', findRichText: true),
          );
          await submitLessonQuiz(tester, correct: false);
          await scrollAndTap(
            tester,
            find.textContaining('Yölçi AI tahlili', findRichText: true),
          );
          expect(
            find.textContaining('Yölçi', findRichText: true),
            findsWidgets,
          );
          recorder.expectClean();
        },
      );

      testWidgets('T2.28 /progress has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialDemoSession: true,
          initialRoute: '/progress',
        );
        recorder.expectClean();
      });

      testWidgets('T2.29 /profile has 0 overflow at 360dp @ 2.0x', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          textScale: 2.0,
          initialDemoSession: true,
          initialRoute: '/profile',
        );
        recorder.expectClean();
      });
    });

    // -----------------------------------------------------------------------
    // 3. Keyboard Open (viewInsets.bottom = 280 at 360dp) (F12, F6, F8 — 5 tests)
    // -----------------------------------------------------------------------
    group('Keyboard Open (viewInsets.bottom = 280) at 360dp', () {
      testWidgets('T2.30 /login handles keyboard open without overflow', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          keyboardBottomInset: 280,
          initialRoute: '/login',
        );
        await tester.enterText(find.byType(TextField).first, 'test@misol.uz');
        await tester.pumpAndSettle();
        recorder.expectClean();
      });

      testWidgets('T2.31 /register handles keyboard open without overflow', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          keyboardBottomInset: 280,
          initialRoute: '/register',
        );
        await tester.enterText(find.byType(TextField).first, 'Aziza');
        await tester.pumpAndSettle();
        recorder.expectClean();
      });

      testWidgets(
        'T2.32 /forgot-password handles keyboard open without overflow',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            keyboardBottomInset: 280,
            initialRoute: '/forgot-password',
          );
          await tester.enterText(find.byType(TextField).first, 'user@misol.uz');
          await tester.pumpAndSettle();
          recorder.expectClean();
        },
      );

      testWidgets('T2.33 /ai-tutor handles keyboard open without overflow', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          keyboardBottomInset: 280,
          initialDemoSession: true,
          initialRoute: '/ai-tutor',
        );
        await tester.enterText(find.byType(TextField).first, 'Misol bering');
        await tester.pumpAndSettle();
        recorder.expectClean();
      });

      testWidgets(
        'T2.34 DictionarySheet handles keyboard open without overflow',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            keyboardBottomInset: 280,
            initialDemoSession: true,
            initialRoute: '/courses',
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
          await tester.tap(find.byTooltip('Söz luğati'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'two words');
          await scrollAndTap(tester, find.text('Sözni izlaş'));
          expect(
            find.textContaining('Bitta inglizça söz kiriting', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 4. Light & Dark Theme Boundary Checks (F1 — 6 tests)
    // -----------------------------------------------------------------------
    group('F1: Light & Dark Theme Boundaries', () {
      testWidgets(
        'T2.35 system Brightness.dark applies dark theme on /welcome',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            brightness: Brightness.dark,
          );
          expectScaffoldThemeBrightness(tester, Brightness.dark);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.36 persisted theme_mode=dark applies dark theme on /dashboard',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/dashboard',
            mockPrefs: {E2EConfig.keyThemeMode: 'dark'},
          );
          expectScaffoldThemeBrightness(tester, Brightness.dark);
          recorder.expectClean();
        },
      );

      testWidgets('T2.37 dark theme on /ai-tutor renders cleanly', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          brightness: Brightness.dark,
          initialDemoSession: true,
          initialRoute: '/ai-tutor',
          mockPrefs: {E2EConfig.keyThemeMode: 'dark'},
        );
        await scrollAndTap(
          tester,
          find.textContaining('Qoidani sodda tuşuntir', findRichText: true),
        );
        expectScaffoldThemeBrightness(tester, Brightness.dark);
        recorder.expectClean();
      });

      testWidgets('T2.38 dark theme on /progress and /profile renders cleanly', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          brightness: Brightness.dark,
          initialDemoSession: true,
          initialRoute: '/progress',
          mockPrefs: {E2EConfig.keyThemeMode: 'dark'},
        );
        expectScaffoldThemeBrightness(tester, Brightness.dark);

        await tapBottomNav(tester, L10nExpect.navProfile);
        expectScaffoldThemeBrightness(tester, Brightness.dark);
        recorder.expectClean();
      });

      testWidgets('T2.39 dark theme on /lesson renders cleanly', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          brightness: Brightness.dark,
          initialDemoSession: true,
          initialRoute: '/roadmap',
          mockPrefs: {E2EConfig.keyThemeMode: 'dark'},
        );
        final cta =
            find.textContaining('Boşlaş', findRichText: true).evaluate().isNotEmpty
            ? find.textContaining('Boşlaş', findRichText: true)
            : find.textContaining('Maşq qiliş', findRichText: true);
        await scrollAndTap(tester, cta);
        expectScaffoldThemeBrightness(tester, Brightness.dark);
        recorder.expectClean();
      });

      testWidgets(
        'T2.40 explicit theme_mode=light overrides system Brightness.dark',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            brightness: Brightness.dark,
            initialDemoSession: true,
            initialRoute: '/dashboard',
            mockPrefs: {E2EConfig.keyThemeMode: 'light'},
          );
          expectScaffoldThemeBrightness(tester, Brightness.light);
          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 5. uz & ru Localization & Long-Label Boundaries (F2 — 6 tests)
    // -----------------------------------------------------------------------
    group('F2: uz / ru Localization Boundaries', () {
      testWidgets('T2.41 locale=ru renders 3-page Product Tour in Russian', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          mockPrefs: {E2EConfig.keyLocale: 'ru'},
        );
        L10nExpect.expectAnyVisible(L10nExpect.tourPage1TitlesRu);
        L10nExpect.expectAnyVisible(L10nExpect.tourNextRu);
        L10nExpect.expectAnyVisible(L10nExpect.tourSkipRu);
        L10nExpect.expectNoneVisible([
          'Nimadan boşlaşni biling',
          'Keyingi',
          'Ötkazib yuboriş',
        ]);

        await tapAnyVisible(tester, L10nExpect.tourNextRu);
        L10nExpect.expectAnyVisible(L10nExpect.tourPage2TitlesRu);
        L10nExpect.expectNoneVisible(['Sizga mos darsni sinab köring']);

        await tapAnyVisible(tester, L10nExpect.tourNextRu);
        L10nExpect.expectAnyVisible(L10nExpect.tourPage3TitlesRu);
        L10nExpect.expectAnyVisible(L10nExpect.tourFinishRu);
        L10nExpect.expectNoneVisible(['Ösişingizni körib boring']);
        recorder.expectClean();
      });

      testWidgets('T2.42 locale=ru renders /login and /register in Russian', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialRoute: '/login',
          mockPrefs: {E2EConfig.keyLocale: 'ru'},
        );
        L10nExpect.expectAnyVisible(L10nExpect.loginTitleRu);
        L10nExpect.expectAnyVisible(L10nExpect.loginButtonRu);
        L10nExpect.expectAnyVisible(L10nExpect.demoEntryRu);
        L10nExpect.expectNoneVisible([
          'Xuş kelibsiz',
          'Namuna hisobi bilan kiriş',
        ]);

        appRouter.go('/register');
        await tester.pumpAndSettle();
        L10nExpect.expectAnyVisible(L10nExpect.registerHeadingRu);
        L10nExpect.expectNoneVisible([
          'Yangi hisob yaratiş',
          'Hisob Yaratiş',
        ]);
        recorder.expectClean();
      });

      testWidgets(
        'T2.43 locale=ru renders bottom navigation in Russian at 360dp @ 2.0x with 0 overflow',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            textScale: 2.0,
            initialDemoSession: true,
            initialRoute: '/dashboard',
            mockPrefs: {E2EConfig.keyLocale: 'ru'},
          );
          expect(find.text('Главная'), findsOneWidget);
          expect(find.text('Путь обучения'), findsOneWidget);
          expect(find.text('Результаты'), findsOneWidget);
          expect(find.text('Профиль'), findsOneWidget);
          L10nExpect.expectAnyVisible(L10nExpect.dashboardCopyRu);
          L10nExpect.expectNoneVisible(['Boş sahifa', 'Bugungi maqsad']);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.44 locale=ru renders /dashboard and /courses at 360dp with 0 overflow',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            initialDemoSession: true,
            initialRoute: '/dashboard',
            mockPrefs: {E2EConfig.keyLocale: 'ru'},
          );
          L10nExpect.expectAnyVisible(L10nExpect.dashboardCopyRu);
          L10nExpect.expectNoneVisible([
            'Bugungi maqsad',
            'Mening kurslarim',
          ]);

          appRouter.go('/courses');
          await tester.pumpAndSettle();
          L10nExpect.expectAnyVisible(L10nExpect.coursesCopyRu);
          L10nExpect.expectNoneVisible([
            'Fanlar katalogi',
            'Qaysi fanni örganişni istaysiz',
          ]);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.45 locale=ru renders /progress and /profile at 360dp with 0 overflow',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            initialDemoSession: true,
            initialRoute: '/progress',
            mockPrefs: {E2EConfig.keyLocale: 'ru'},
          );
          L10nExpect.expectAnyVisible(L10nExpect.progressCopyRu);
          L10nExpect.expectNoneVisible([
            'Mening natijalarim',
            'Ta’lim körsatkiçlari',
          ]);

          appRouter.go('/profile');
          await tester.pumpAndSettle();
          L10nExpect.expectAnyVisible(L10nExpect.profileCopyRu);
          L10nExpect.expectNoneVisible([
            'Profilim',
            'Öquv sozlamalari',
            'Hisobdan çiqiş',
          ]);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.46 zero English leftovers (Roadmap, Reset, Speaker) across core screens',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/dashboard',
          );
          L10nExpect.expectNoEnglishLeftovers();

          appRouter.go('/roadmap');
          await tester.pumpAndSettle();
          L10nExpect.expectNoEnglishLeftovers();

          appRouter.go('/knowledge-map');
          await tester.pumpAndSettle();
          L10nExpect.expectNoEnglishLeftovers();

          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 6. Diagnostic <50% & >=80% & P0 Boundary Conditions (F4, F10 — 6 tests)
    // -----------------------------------------------------------------------
    group('F4 & F10: Diagnostic Scoring & Roadmap Unlock Boundaries', () {
      testWidgets(
        'T2.47 Math diagnostic <50% MUST produce enabled Boşlaş or Maşq qiliş on /roadmap',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
          );

          await selectCourse(tester, 'Matematika');
          await openOptionalDiagnostic(tester);
          await completePlacement(tester, highAccuracy: false);
          await scrollAndTap(
            tester,
            find.textContaining('Şaxsiy yölni köriş', findRichText: true),
          );

          final ctaFinder =
              find.textContaining('Maşq qiliş', findRichText: true).evaluate().isNotEmpty
              ? find.textContaining('Maşq qiliş', findRichText: true)
              : find.textContaining('Boşlaş', findRichText: true);
          expect(
            ctaFinder,
            findsWidgets,
            reason: 'Contract #3: <50% diagnostic must NOT deadlock /roadmap',
          );
          await scrollAndTap(tester, ctaFinder);
          expect(
            find.textContaining('Qadam 1 /', findRichText: true),
            findsOneWidget,
            reason: 'Contract #3: /roadmap CTA must be enabled and open /lesson',
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.48 English diagnostic <50% MUST produce enabled Boşlaş or Maşq qiliş on /roadmap',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
          );

          await selectCourse(tester, 'Ingliz tili');
          await openOptionalDiagnostic(tester);
          await completePlacement(tester, highAccuracy: false);
          await scrollAndTap(
            tester,
            find.textContaining('Şaxsiy yölni köriş', findRichText: true),
          );

          final ctaFinder =
              find.textContaining('Maşq qiliş', findRichText: true).evaluate().isNotEmpty
              ? find.textContaining('Maşq qiliş', findRichText: true)
              : find.textContaining('Boşlaş', findRichText: true);
          expect(ctaFinder, findsWidgets);
          await scrollAndTap(tester, ctaFinder);
          expect(
            find.textContaining('Qadam 1 /', findRichText: true),
            findsOneWidget,
            reason: 'Contract #3: English /roadmap CTA must be enabled and open /lesson',
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.49 Math diagnostic 100% (>=80%) advances starting step on /roadmap',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
          );

          await selectCourse(tester, 'Matematika');
          await openOptionalDiagnostic(tester);
          await completePlacement(tester, highAccuracy: true);
          expect(find.textContaining('8 / 8', findRichText: true), findsOneWidget);

          await scrollAndTap(
            tester,
            find.textContaining('Şaxsiy yölni köriş', findRichText: true),
          );
          // Contract #3: High scores (>=80%) advance/master early skills rather than
          // marking everything weak (<50%).
          expect(
            find.textContaining('Özlaştirilgan', findRichText: true).evaluate().isNotEmpty ||
                find.textContaining('Bajarildi', findRichText: true).evaluate().isNotEmpty,
            isTrue,
            reason: '100% Math diagnostic must advance/unlock early roadmap nodes',
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.50 IT diagnostic 100% unlocks roadmap cleanly',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
          );

          await selectCourse(tester, 'IT & Kodlaş');
          await openOptionalDiagnostic(tester);
          await completePlacement(tester, highAccuracy: true);
          await scrollAndTap(
            tester,
            find.textContaining('Şaxsiy yölni köriş', findRichText: true),
          );

          expect(
            find.textContaining('Özlaştirilgan', findRichText: true).evaluate().isNotEmpty ||
                find.textContaining('Bajarildi', findRichText: true).evaluate().isNotEmpty ||
                find.textContaining('Takrorlaş', findRichText: true).evaluate().isNotEmpty,
            isTrue,
            reason: '100% IT diagnostic must advance/unlock early roadmap nodes',
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.51 double-tapping lesson TEKŞIRIŞ does not double-award XP',
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
          await scrollAndTap(tester, find.text('C'));
          final checkBtn = find.textContaining('TEKŞIRIŞ', findRichText: true);
          await tester.tap(checkBtn);
          await tester.pump(const Duration(milliseconds: 20));
          if (checkBtn.evaluate().isNotEmpty) {
            await tester.tap(checkBtn, warnIfMissed: false);
          }
          await tester.pumpAndSettle();

          await tapBottomNav(tester, L10nExpect.navProgress);
          expect(find.textContaining('24 XP', findRichText: true), findsWidgets);
          expect(
            find.textContaining(
              RegExp(r'\b(26|44|46)\s*XP'),
              findRichText: true,
            ),
            findsNothing,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.52 rapid double-tap on placement Keyingi Savol does not skip questions',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/placement',
          );

          await scrollAndTap(tester, find.text('A'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 850)),
          );
          final nextBtn = find.textContaining('Keyingi Savol', findRichText: true);
          await tester.tap(nextBtn);
          await tester.pump(const Duration(milliseconds: 20));
          if (nextBtn.evaluate().isNotEmpty) {
            await tester.tap(nextBtn, warnIfMissed: false);
          }
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Savol 2 / 8', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 7. Empty, Loading, Error, Offline & Persistence Corner Cases (12 tests)
    // -----------------------------------------------------------------------
    group('Empty, Loading, Error, Offline & Persistence Corner Cases', () {
      testWidgets('T2.53 /ai-tutor ignores empty and whitespace input', (
        tester,
      ) async {
        final fakeAi = FakeControllableAITutorService();
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/ai-tutor',
          overrides: [aiTutorServiceProvider.overrideWithValue(fakeAi)],
        );

        await tester.enterText(find.byType(TextField).first, '   ');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();

        expect(fakeAi.askCalls, 0);
        recorder.expectClean();
      });

      testWidgets(
        'T2.54 /ai-tutor disables prompt chips and shows typing indicator while loading',
        (tester) async {
          final fakeAi = FakeControllableAITutorService();
          final completer = Completer<AskTutorResponse>();
          fakeAi.pendingAsk = completer;

          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/ai-tutor',
            disableAnimations: false,
            overrides: [aiTutorServiceProvider.overrideWithValue(fakeAi)],
          );

          await tester.tap(
            find.textContaining('Qoidani sodda tuşuntir', findRichText: true),
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            find.bySemanticsLabel('Yölçi AI yozmoqda...'),
            findsOneWidget,
          );

          // Chip is disabled while sending -> tapping again must not increment askCalls.
          await tester.tap(
            find.textContaining('Qoidani sodda tuşuntir', findRichText: true).last,
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(fakeAi.askCalls, 1);

          completer.complete(
            const AskTutorResponse(tutorName: 'Yölçi AI', answer: 'Tayyor'),
          );
          await tester.pumpAndSettle();
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.55 /ai-tutor shows error bubble and recovers via Qayta uriniş',
        (tester) async {
          final fakeAi = FakeControllableAITutorService()..failAsk = true;
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/ai-tutor',
            overrides: [aiTutorServiceProvider.overrideWithValue(fakeAi)],
          );

          await tester.enterText(find.byType(TextField).first, 'Funksiya?');
          await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
          await tester.pumpAndSettle();

          expect(find.textContaining('Qayta uriniş', findRichText: true), findsOneWidget);

          fakeAi.failAsk = false;
          await scrollAndTap(
            tester,
            find.textContaining('Qayta uriniş', findRichText: true),
          );

          expect(find.textContaining('qadam-baqadam yeçim', findRichText: true), findsOneWidget);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.56 YolchiAiSheet shows error state and recovers on Qayta uriniş',
        (tester) async {
          final fakeAi = FakeControllableAITutorService()..failExplain = true;
          final recorder = await pumpBilimYolApp(
            tester,
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
          await submitLessonQuiz(tester, correct: false);
          await scrollAndTap(
            tester,
            find.textContaining('Yölçi AI tahlili', findRichText: true),
          );

          expect(
            find.textContaining('Yölçi izohini yuklab bölmadi', findRichText: true),
            findsOneWidget,
          );
          fakeAi.failExplain = false;
          await scrollAndTap(
            tester,
            find.textContaining('Qayta uriniş', findRichText: true),
          );
          expect(
            find.textContaining('Xatoni tahlil qiliş', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.57 DictionarySheet validates empty and multi-word input locally',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
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
          await tester.tap(find.byTooltip('Söz luğati'));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField).last, 'two words');
          await tester.tap(find.text('Sözni izlaş'));
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Bitta inglizça söz kiriting', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.58 /progress empty state shows zero activity message and 0/4 badges',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/progress',
          );

          expect(
            find.textContaining('Hali öquv faoliyati qayd etilmagan', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('0/4 Olingan', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.59 /register rejects mismatched passwords with validation error',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialRoute: '/register',
          );

          final fields = find.byType(TextField);
          await tester.enterText(fields.at(0), 'Aziza');
          await tester.enterText(fields.at(1), 'aziza@misol.uz');
          await tester.enterText(fields.at(2), 'parol123');
          await tester.enterText(fields.at(3), 'boşqa999');

          await scrollAndTap(
            tester,
            find.textContaining('Hisob Yaratiş', findRichText: true),
          );
          expect(
            find.textContaining('mos', findRichText: true),
            findsWidgets,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.60 /forgot-password rejects invalid email format',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialRoute: '/forgot-password',
          );

          await tester.enterText(find.byType(TextField).first, 'not-an-email');
          await scrollAndTap(
            tester,
            find.textContaining('Tiklaş havolasini yuboriş', findRichText: true),
          );
          expect(
            find.textContaining('email', findRichText: true),
            findsWidgets,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.61 active demo session in SharedPreferences bypasses /welcome to /dashboard or /courses',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            mockPrefs: {
              E2EConfig.keyProductTourCompleted: true,
              E2EConfig.keyDemoSessionActive: true,
            },
          );

          expect(
            find.textContaining('Nimadan boşlaşni biling', findRichText: true),
            findsNothing,
          );
          L10nExpect.expectAnyVisible([
            'Bugungi maqsad',
            'Fanlar katalogi',
            'Fan tanlaş',
            'Qaysi fanni',
            'Выбрать предмет',
          ]);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.62 cold restart preserves locale, theme_mode and tour flag together',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            mockPrefs: {
              E2EConfig.keyProductTourCompleted: true,
              E2EConfig.keyLocale: 'ru',
              E2EConfig.keyThemeMode: 'dark',
            },
          );

          await restartBilimYolApp(tester);
          expect(appRouter.routeInformationProvider.value.uri.path, '/login');
          expectScaffoldThemeBrightness(tester, Brightness.dark);
          L10nExpect.expectAnyVisible(L10nExpect.loginButtonRu);
          L10nExpect.expectNoneVisible([
            'Nimadan boşlaşni biling',
            'Знайте, с чего начать',
            'Xuş kelibsiz',
          ]);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.63 MathFunctionGraphWidget slider updates cleanly at 360dp @ 2.0x',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            viewport: E2EConfig.compactPhone,
            textScale: 2.0,
            initialDemoSession: true,
            initialRoute: '/placement',
          );

          await completePlacement(tester, highAccuracy: true);
          await scrollAndTap(
            tester,
            find.textContaining('Şaxsiy yölni köriş', findRichText: true),
          );
          await openMathFunctionsLessonFromRoadmap(tester);

          var slider = find.byType(Slider);
          for (var step = 0; step < 5 && slider.evaluate().isEmpty; step++) {
            final nextStep = find.textContaining(
              'Keyingi qadam',
              findRichText: true,
            );
            if (nextStep.evaluate().isEmpty) break;
            await scrollAndTap(tester, nextStep);
            slider = find.byType(Slider);
          }

          expect(
            slider,
            findsOneWidget,
            reason:
                'Math functions lesson must render MathFunctionGraphWidget Slider (type: function_graph)',
          );
          await tester.ensureVisible(slider);
          await tester.pumpAndSettle();
          await tester.drag(slider, const Offset(40, 0));
          await tester.pumpAndSettle();
          recorder.expectClean();
        },
      );

      testWidgets(
        'T2.64 AudioSimWaveWidget play/pause toggles without errors',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
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

          final playBtn = find.byIcon(Icons.play_arrow_rounded);
          expect(playBtn, findsOneWidget);
          await tester.ensureVisible(playBtn);
          await tester.pumpAndSettle();
          await tester.tap(playBtn);
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

          final pauseBtn = find.byIcon(Icons.pause_rounded);
          await tester.ensureVisible(pauseBtn);
          await tester.pumpAndSettle();
          await tester.tap(pauseBtn);
          await tester.pumpAndSettle();
          recorder.expectClean();
        },
      );
    });
  });
}
