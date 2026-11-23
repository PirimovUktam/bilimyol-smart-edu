import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';

import 'e2e_harness.dart';

void main() {
  group('Tier 4 — Full Real-World E2E Application Journeys', () {
    testWidgets(
      'T4.1 90-Second Hackathon Judge Demo: Tour -> Demo -> Weak Spot -> Lesson -> AI Mistake -> Reinforcement -> Knowledge Map Growth',
      (tester) async {
        final recorder = await pumpBilimYolApp(tester);

        // 1. 3-page "Mening bilim yölim" Product Tour
        await completeProductTour(tester);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(E2EConfig.keyProductTourCompleted), isTrue);

        // 2. Demo account -> Matematika -> Tezkor demo diagnostic
        await enterDemoMode(tester);
        await selectCourse(tester, 'Matematika');
        await openOptionalDiagnostic(tester);
        await scrollAndTap(
          tester,
          find.textContaining('Tezkor demo', findRichText: true),
        );

        // 3. Knowledge Map reveals weak link -> Roadmap -> Recommended lesson
        expect(
          find.textContaining('DIQQAT: Zaif Böğin', findRichText: true),
          findsOneWidget,
        );
        await scrollAndTap(
          tester,
          find.textContaining('Moslaşuvçan Yöl Xaritasi', findRichText: true),
        );

        final reinfCta = find.textContaining('Maşq qiliş', findRichText: true);
        expect(
          reinfCta,
          findsWidgets,
          reason:
              'Tezkor demo must unlock Funksiyalar remediation (Maşq qiliş) per providers.dart:297',
        );
        await scrollAndTap(tester, reinfCta);

        // 4. Learner answers wrong -> Yölçi AI explains -> Reinforcement awards +30 XP
        await submitLessonQuiz(tester, correct: false);
        expect(
          find.textContaining('Töğri javob:', findRichText: true),
          findsOneWidget,
        );
        await scrollAndTap(
          tester,
          find.textContaining('Yölçi AI tahlili', findRichText: true),
        );
        expect(
          find.textContaining('Ozod son (+3)', findRichText: true),
          findsOneWidget,
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
        expect(find.textContaining('+30 XP', findRichText: true), findsOneWidget);

        // 5. Return to Knowledge Map / Progress & verify growth
        await scrollAndTap(
          tester,
          find.textContaining('Daşboardga Ötiş', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Bilim xaritasi', findRichText: true),
        );
        expect(find.textContaining('150 XP', findRichText: true), findsWidgets);

        recorder.expectClean();
      },
    );

    testWidgets(
      'T4.2 New Beginner Learner E2E: First Launch -> Skip Tour -> Demo -> Ingliz tili -> Beginner -> Starter Lesson -> XP & Badge',
      (tester) async {
        final recorder = await pumpBilimYolApp(tester);

        await skipProductTour(tester);
        await enterDemoMode(tester);
        await selectCourse(tester, 'Ingliz tili');

        await scrollAndTap(
          tester,
          find.textContaining('Noldan boşlayman', findRichText: true),
        );
        expect(
          find.textContaining('Ixtiyoriy diagnostika', findRichText: true),
          findsNothing,
        );
        await scrollAndTap(
          tester,
          find.textContaining('Birinçi darsni boşlaş', findRichText: true),
        );

        expect(
          find.textContaining('Birinçi inglizça sözlar', findRichText: true),
          findsWidgets,
        );
        await submitLessonQuiz(tester, correct: true);

        // Verify immediate XP and badge refresh across Progress & Dashboard
        await tapBottomNav(tester, L10nExpect.navProgress);
        expect(find.textContaining('22 XP', findRichText: true), findsWidgets);
        expect(
          find.textContaining('1/4 Olingan', findRichText: true),
          findsOneWidget,
        );

        await tapBottomNav(tester, L10nExpect.navHome);
        L10nExpect.expectAnyVisible(['22 XP', '+22']);

        recorder.expectClean();
      },
    );

    testWidgets(
      'T4.3 Returning Intermediate Learner Cold Restart: Session 1 -> Restart -> Direct Dashboard -> 1-Tap Continue -> Lesson -> Updated Progress',
      (tester) async {
        final recorder = await pumpBilimYolApp(tester);

        await completeProductTour(tester);
        await enterDemoMode(tester);
        await selectCourse(tester, 'Matematika');
        await scrollAndTap(
          tester,
          find.textContaining('Asoslarini bilaman', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Ta’lim yölini oçiş', findRichText: true),
        );

        // Complete one roadmap lesson in session 1
        final firstCta =
            find.textContaining('Boşlaş', findRichText: true).evaluate().isNotEmpty
            ? find.textContaining('Boşlaş', findRichText: true)
            : find.textContaining('Maşq qiliş', findRichText: true);
        await scrollAndTap(tester, firstCta);
        await submitLessonQuiz(tester, correct: true);

        // Simulate cold restart
        await restartBilimYolApp(tester);

        // Returning active demo learner bypasses Tour & lands on Dashboard
        expect(
          find.textContaining('Bugungi maqsad', findRichText: true),
          findsOneWidget,
        );
        L10nExpect.expectAnyVisible(['22 XP', '+22']);

        // 1-tap continue straight into next learning action
        final continueCta =
            find.textContaining('Davom etiş', findRichText: true).evaluate().isNotEmpty
            ? find.textContaining('Davom etiş', findRichText: true)
            : find.textContaining('Ta’lim yölini oçiş', findRichText: true);
        await scrollAndTap(tester, continueCta);

        expect(
          find.textContaining('Qadam 1 /', findRichText: true).evaluate().isNotEmpty ||
              find.textContaining('Mening ta’lim yölim', findRichText: true).evaluate().isNotEmpty,
          isTrue,
        );

        recorder.expectClean();
      },
    );

    testWidgets(
      'T4.4 Cross-Subject Switching (Matematika <-> Ingliz tili) with Progress Isolation & Mantiq Visibility',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/dashboard',
        );

        // All 4 subjects including Mantiq must be visible in Dashboard 'Barçasi'
        await scrollAndTap(
          tester,
          find.textContaining('Barçasi', findRichText: true),
        );
        final verticalScrollable = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        for (final subject in E2EConfig.allSubjectsUz) {
          final f = find.textContaining(subject, findRichText: true);
          if (f.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              f,
              180,
              scrollable: verticalScrollable.last,
            );
          }
          expect(f, findsWidgets);
        }

        // Complete starter lesson in Matematika via Dashboard's Fanni almaştiriş button
        final switchBtn1 = find.byTooltip('Fanni almaştiriş').evaluate().isNotEmpty
            ? find.byTooltip('Fanni almaştiriş')
            : find.byIcon(Icons.swap_horiz_rounded);
        await scrollAndTap(tester, switchBtn1);
        await selectCourse(tester, 'Matematika');
        await scrollAndTap(
          tester,
          find.textContaining('Noldan boşlayman', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Birinçi darsni boşlaş', findRichText: true),
        );
        await submitLessonQuiz(tester, correct: true);

        // Switch to Ingliz tili via Bottom Nav -> Dashboard -> Fanni almaştiriş
        await tapBottomNav(tester, L10nExpect.navHome);
        final switchBtn2 = find.byTooltip('Fanni almaştiriş').evaluate().isNotEmpty
            ? find.byTooltip('Fanni almaştiriş')
            : find.byIcon(Icons.swap_horiz_rounded);
        await scrollAndTap(tester, switchBtn2);
        await selectCourse(tester, 'Ingliz tili');
        expect(
          find.textContaining('Qayerdan boşlamoqçisiz', findRichText: true),
          findsOneWidget,
        );
        await scrollAndTap(
          tester,
          find.textContaining('Asoslarini bilaman', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Ta’lim yölini oçiş', findRichText: true),
        );
        expect(find.textContaining('Vocabulary', findRichText: true), findsWidgets);

        recorder.expectClean();
      },
    );

    testWidgets(
      'T4.5 Diagnostic <50% -> Roadmap Unlock -> Wrong Answer -> Yölçi AI -> Reinforcement -> Recovery',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'Matematika');
        await openOptionalDiagnostic(tester);
        // Deliberately answer all diagnostic questions wrong (<50%)
        await completePlacement(tester, highAccuracy: false);
        await scrollAndTap(
          tester,
          find.textContaining('Şaxsiy yölni köriş', findRichText: true),
        );

        // Contract #3: Must have actionable enabled CTA (no P0 deadlock!)
        final actionCta =
            find.textContaining('Maşq qiliş', findRichText: true).evaluate().isNotEmpty
            ? find.textContaining('Maşq qiliş', findRichText: true)
            : find.textContaining('Boşlaş', findRichText: true);
        expect(actionCta, findsWidgets);
        await scrollAndTap(tester, actionCta);

        // Answer wrong -> AI explanation -> Reinforcement -> Recover XP & Roadmap
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

        await tapBottomNav(tester, L10nExpect.navProgress);
        expect(find.textContaining('50 XP', findRichText: true), findsWidgets);

        recorder.expectClean();
      },
    );

    testWidgets(
      'T4.6 Offline & Error Recovery Journey: AI Service Failure -> Retry + Dictionary Validation + Auth Demo Guards',
      (tester) async {
        final fakeAi = FakeControllableAITutorService()..failAsk = true;
        final pending = Completer<AskTutorResponse>();

        final recorder = await pumpBilimYolApp(
          tester,
          disableAnimations: false,
          overrides: [aiTutorServiceProvider.overrideWithValue(fakeAi)],
        );

        // Check /register and /forgot-password demo guards first via real UI nav
        await skipProductTour(tester);
        await tapAnyVisible(tester, L10nExpect.registerLink);
        final regFields = find.byType(TextField);
        await tester.enterText(regFields.at(0), 'Ali');
        await tester.enterText(regFields.at(1), 'ali@misol.uz');
        await tester.enterText(regFields.at(2), 'parol123');
        await tester.enterText(regFields.at(3), 'parol123');
        await scrollAndTap(
          tester,
          find.textContaining('Hisob Yaratiş', findRichText: true),
        );
        expect(tester.takeException(), isNull);
        L10nExpect.expectAnyVisible([
          'Namuna rejimida',
          'yaratilmaydi',
          'Демо-режим',
          'ulanib bölmadi',
        ]);

        await scrollAndTap(tester, find.byIcon(Icons.arrow_back_rounded));
        await scrollAndTap(
          tester,
          find.textContaining('Parolni unutdingizmi', findRichText: true),
        );
        await tester.enterText(find.byType(TextField).first, 'ali@misol.uz');
        await scrollAndTap(
          tester,
          find.textContaining('Tiklaş havolasini yuboriş', findRichText: true),
        );
        expect(
          find.textContaining('Namuna rejimida tiklaş xati yuborilmaydi', findRichText: true),
          findsOneWidget,
        );

        // Return to /login -> Enter Demo -> English starter lesson -> Dictionary validation
        await scrollAndTap(tester, find.byIcon(Icons.arrow_back_rounded));
        await enterDemoMode(tester);
        await selectCourse(tester, 'Ingliz tili');
        await scrollAndTap(
          tester,
          find.textContaining('Noldan boşlayman', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Birinçi darsni boşlaş', findRichText: true),
        );

        await tester.tap(find.byTooltip('Söz luğati'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'hello world');
        await scrollAndTap(tester, find.text('Sözni izlaş'));
        expect(
          find.textContaining('Bitta inglizça söz kiriting', findRichText: true),
          findsOneWidget,
        );
        final closeSheet = find.byTooltip('Luğatni yopiş').evaluate().isNotEmpty
            ? find.byTooltip('Luğatni yopiş')
            : find.byIcon(Icons.close);
        await tester.tap(closeSheet.last);
        await tester.pumpAndSettle();

        // Exit lesson to /roadmap -> Bottom Nav Yölçi AI -> offline failure -> retry recovery
        final closeLesson =
            find.byTooltip('Ta’lim yöliga qaytiş').evaluate().isNotEmpty
            ? find.byTooltip('Ta’lim yöliga qaytiş')
            : find.byIcon(Icons.close_rounded);
        await tester.tap(closeLesson.first);
        await tester.pumpAndSettle();
        await tapBottomNav(tester, L10nExpect.navAi);

        await tester.enterText(find.byType(TextField).first, 'Limit nima?');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();
        expect(find.textContaining('Qayta uriniş', findRichText: true), findsOneWidget);

        // Retry with pending loading indicator first, then resolve
        fakeAi.failAsk = false;
        fakeAi.pendingAsk = pending;
        await tester.tap(find.textContaining('Qayta uriniş', findRichText: true));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.bySemanticsLabel('Yölçi AI yozmoqda...'), findsOneWidget);

        pending.complete(
          const AskTutorResponse(
            tutorName: 'Yölçi AI',
            answer: 'Limit — funksiya qiymatining yaqinlaşişi.',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Limit — funksiya qiymatining yaqinlaşişi.', findRichText: true),
          findsOneWidget,
        );

        recorder.expectClean();
      },
    );

    testWidgets(
      'T4.7 Compact 360dp Dark Mode + Russian (ru) Full Navigation & Cold Restart Retention',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          viewport: E2EConfig.compactPhone,
          initialDemoSession: true,
          initialRoute: '/profile',
        );

        // Switch theme to Dark and language to Russian
        await scrollAndTap(
          tester,
          L10nExpect.findAnyText(L10nExpect.themeDarkCandidates),
        );
        await scrollAndTap(
          tester,
          L10nExpect.findAnyText(['Русский', 'RU', 'Rus']),
        );

        // Walk all 5 bottom nav tabs at 360dp
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

        // Cold restart and verify Dark + Russian persisted on landing route (/dashboard or /courses)
        await restartBilimYolApp(tester);
        expectScaffoldThemeBrightness(tester, Brightness.dark);
        L10nExpect.expectAnyVisible([
          ...L10nExpect.dashboardCopyRu,
          ...L10nExpect.coursesCopyRu,
        ]);
        L10nExpect.expectNoneVisible([
          'Bugungi maqsad',
          'Mening kurslarim',
          'Fanlar katalogi',
          'Fan tanlaş',
        ]);

        recorder.expectClean();
      },
    );

    testWidgets(
      'T4.8 Profile Name Edit, Tour Replay, Demo Reset & Logout Session Isolation',
      (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'Mantiq');
        await scrollAndTap(
          tester,
          find.textContaining('Noldan boşlayman', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Birinçi darsni boşlaş', findRichText: true),
        );
        await submitLessonQuiz(tester, correct: true);
        await submitLessonQuiz(tester, correct: true);

        // Edit profile name
        await tapBottomNav(tester, L10nExpect.navProfile);
        final editBtn = L10nExpect.findAnyText(L10nExpect.editNameCandidates);
        final editIcon = find.byIcon(Icons.edit_outlined).evaluate().isNotEmpty
            ? find.byIcon(Icons.edit_outlined)
            : find.byIcon(Icons.edit_rounded);
        expect(
          editBtn.evaluate().isNotEmpty || editIcon.evaluate().isNotEmpty,
          isTrue,
          reason: 'Profile must provide name-editing action per M3 spec',
        );
        final editTarget = editIcon.evaluate().isNotEmpty ? editIcon : editBtn;
        await scrollAndTap(tester, editTarget);
        await tester.enterText(find.byType(TextField).last, 'Madina');
        await tapAnyVisible(tester, L10nExpect.saveCandidates);
        expect(find.textContaining('Madina', findRichText: true), findsWidgets);

        // Replay tour without losing XP; verify tour replay returns inside active session
        await scrollAndTap(
          tester,
          L10nExpect.findAnyText(L10nExpect.tourReplayCandidates),
        );
        await completeProductTour(tester);
        expect(
          appRouter.routeInformationProvider.value.uri.path,
          anyOf('/profile', '/dashboard'),
        );
        if (find.textContaining('Profilim', findRichText: true).evaluate().isEmpty) {
          await tapBottomNav(tester, L10nExpect.navProfile);
        }
        expect(find.textContaining('24 XP', findRichText: true), findsWidgets);

        // Reset demo -> XP goes back to 0 -> return to Profile via UI -> Logout
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

        await selectCourse(tester, 'Matematika');
        await scrollAndTap(
          tester,
          find.textContaining('Asoslarini bilaman', findRichText: true),
        );
        await scrollAndTap(
          tester,
          find.textContaining('Ta’lim yölini oçiş', findRichText: true),
        );
        await tapBottomNav(tester, L10nExpect.navProfile);
        expect(find.text('0 XP', findRichText: true), findsWidgets);

        // Logout -> private routes blocked
        await scrollAndTap(
          tester,
          find.textContaining('Hisobdan çiqiş', findRichText: true),
        );
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);
        appRouter.go('/dashboard');
        await tester.pumpAndSettle();
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);

        recorder.expectClean();
      },
    );
  });
}
