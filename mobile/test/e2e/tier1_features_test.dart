import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/widgets/app_card.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';

import 'e2e_harness.dart';

void main() {
  group('Tier 1 — Feature Inventory Coverage', () {
    // -----------------------------------------------------------------------
    // 1. 3-Page Product Tour (F5)
    // -----------------------------------------------------------------------
    group('F5: 3-Page Product Tour', () {
      testWidgets('T1.1 fresh launch shows Page 1 title and tour controls', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester);

        L10nExpect.expectAnyVisible(L10nExpect.tourPage1Titles);
        L10nExpect.expectAnyVisible(L10nExpect.tourNext);
        L10nExpect.expectAnyVisible(L10nExpect.tourSkip);

        recorder.expectClean();
      });

      testWidgets('T1.2 Page 2 shows adaptive lesson preview fragment', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester);

        await tapAnyVisible(tester, L10nExpect.tourNext);
        L10nExpect.expectAnyVisible(L10nExpect.tourPage2Titles);
        L10nExpect.expectAnyVisible(L10nExpect.tourSkip);
        expect(
          find.byType(Image),
          findsOneWidget,
          reason: 'Page 2 should display bundled tour_2_lesson.png asset',
        );
        // Should preview a real starter lesson fragment & support interactive tap
        expect(
          L10nExpect.hasAnyText([
            'Qöşiş va ayirişdan boşlaymiz',
            '4 ta qalamga yana 2 ta qalam',
            'Haqiqiy darsdan kiçik maşq',
          ]),
          isTrue,
          reason: 'Page 2 should embed a real miniature lesson fragment',
        );
        await scrollAndTap(tester, find.text('6').last);
        expect(
          find.textContaining('4 + 2 = 6', findRichText: true),
          findsOneWidget,
        );

        recorder.expectClean();
      });

      testWidgets('T1.3 Page 3 shows growth map and final Boşlaş CTA', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester);

        await tapAnyVisible(tester, L10nExpect.tourNext);
        await tapAnyVisible(tester, L10nExpect.tourNext);

        L10nExpect.expectAnyVisible(L10nExpect.tourPage3Titles);
        L10nExpect.expectAnyVisible(L10nExpect.tourFinish);
        L10nExpect.expectAnyVisible(L10nExpect.tourSkip);

        recorder.expectClean();
      });

      testWidgets('T1.4 swipe advances pages and does not auto-rotate', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester);

        // Idle wait must NOT auto-advance page 1.
        await tester.pump(const Duration(seconds: 5));
        L10nExpect.expectAnyVisible(L10nExpect.tourPage1Titles);

        final pageView = find.byType(PageView);
        expect(pageView, findsOneWidget);
        await tester.fling(pageView, const Offset(-320, 0), 800);
        await tester.pumpAndSettle();
        L10nExpect.expectAnyVisible(L10nExpect.tourPage2Titles);

        await tester.fling(pageView, const Offset(-320, 0), 800);
        await tester.pumpAndSettle();
        L10nExpect.expectAnyVisible(L10nExpect.tourPage3Titles);

        recorder.expectClean();
      });

      testWidgets('T1.5 Skip exits tour to auth/demo choice', (tester) async {
        final recorder = await pumpBilimYolApp(tester);

        await skipProductTour(tester);
        L10nExpect.expectAnyVisible(L10nExpect.demoEntry);
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);

        recorder.expectClean();
      });

      testWidgets('T1.6 Boşlaş on final page exits tour to auth/demo choice', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester);

        await completeProductTour(tester);
        L10nExpect.expectAnyVisible(L10nExpect.demoEntry);
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);

        recorder.expectClean();
      });

      testWidgets(
        'T1.6b 3-step page indicator updates state across pages 1 -> 2 -> 3',
        (tester) async {
          final recorder = await pumpBilimYolApp(tester);

          int? detectActiveStep() {
            // Check explicit step text indicator first (e.g. "1 / 3", "2 / 3", "3 / 3").
            for (var step = 1; step <= 3; step++) {
              final stepRegex = RegExp(
                '(^|\\D)$step\\s*/\\s*3(\\D|\$)|$step-sahifa|$step\\s+из\\s+3',
              );
              if (find
                  .textContaining(stepRegex, findRichText: true)
                  .evaluate()
                  .isNotEmpty) {
                return step - 1;
              }
            }
            // Otherwise inspect 3-dot Row indicator (3 compact BoxDecoration dots
            // where 1 active dot differs in rendered size or color from the other 2).
            for (final rowElem in find.byType(Row).evaluate()) {
              final row = rowElem.widget as Row;
              if (row.children.length < 3) continue;
              final dotElements = <Element>[];
              void collectDots(Element el) {
                final w = el.widget;
                final isDecoratedIndicator =
                    (w is Container && w.decoration is BoxDecoration) ||
                    (w is DecoratedBox && w.decoration is BoxDecoration);
                if (isDecoratedIndicator) {
                  final box = el.renderObject as RenderBox?;
                  if (box != null &&
                      box.hasSize &&
                      box.size.height >= 4 &&
                      box.size.height <= 18 &&
                      box.size.width >= 4 &&
                      box.size.width <= 56) {
                    dotElements.add(el);
                    return;
                  }
                }
                el.visitChildren(collectDots);
              }

              rowElem.visitChildren(collectDots);
              if (dotElements.length != 3) continue;

              final sigs = dotElements.map((el) {
                final box = el.renderObject! as RenderBox;
                final w = el.widget;
                final dec = w is Container
                    ? w.decoration! as BoxDecoration
                    : (w as DecoratedBox).decoration as BoxDecoration;
                return '${box.size.width.round()}x${box.size.height.round()}:${dec.color?.toARGB32()}';
              }).toList();

              if (sigs[0] != sigs[1] && sigs[1] == sigs[2]) return 0;
              if (sigs[1] != sigs[0] && sigs[0] == sigs[2]) return 1;
              if (sigs[2] != sigs[0] && sigs[0] == sigs[1]) return 2;
            }
            return null;
          }

          expect(
            detectActiveStep(),
            0,
            reason: 'Page 1 must display an active 3-step indicator at index 0',
          );

          await tapAnyVisible(tester, L10nExpect.tourNext);
          expect(
            detectActiveStep(),
            1,
            reason: 'Page 2 must advance the 3-step indicator to index 1',
          );

          await tapAnyVisible(tester, L10nExpect.tourNext);
          expect(
            detectActiveStep(),
            2,
            reason: 'Page 3 must advance the 3-step indicator to index 2',
          );

          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 2. Local Persistence & Tour Independence (F3)
    // -----------------------------------------------------------------------
    group('F3: Local Persistence & Tour Independence', () {
      testWidgets('T1.7 finishing tour persists product_tour_completed=true', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester);

        await completeProductTour(tester);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(E2EConfig.keyProductTourCompleted), isTrue);

        recorder.expectClean();
      });

      testWidgets('T1.8 skipping tour persists product_tour_completed=true', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester);

        await skipProductTour(tester);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(E2EConfig.keyProductTourCompleted), isTrue);

        recorder.expectClean();
      });

      testWidgets(
        'T1.9 completing tour does not mark onboarding or diagnostic complete',
        (tester) async {
          final recorder = await pumpBilimYolApp(tester);

          await completeProductTour(tester);
          await enterDemoMode(tester);
          // Demo user entering for the first time without started course lands on /courses
          // and selecting a subject opens /onboarding (not skipped!).
          await selectCourse(tester, 'Matematika');
          expect(
            find.textContaining('Birinçi qadamingizni tanlang', findRichText: true),
            findsOneWidget,
          );

          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.10 returning user with product_tour_completed=true lands on /login with Demo & Tour replay',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            mockPrefs: {E2EConfig.keyProductTourCompleted: true},
          );

          expect(appRouter.routeInformationProvider.value.uri.path, '/login');
          L10nExpect.expectAnyVisible(L10nExpect.loginButton);
          L10nExpect.expectAnyVisible(L10nExpect.demoEntry);
          expect(
            find.textContaining('Nimadan boşlaşni biling', findRichText: true),
            findsNothing,
          );

          final replayBtn = L10nExpect.findAnyText(
            L10nExpect.tourReplayCandidates,
          );
          expect(
            replayBtn,
            findsWidgets,
            reason: '/login must expose a visible Product Tour replay control',
          );
          await scrollAndTap(tester, replayBtn);
          L10nExpect.expectAnyVisible(L10nExpect.tourPage1Titles);

          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.11 demo learner progress persists across cold app restart',
        (tester) async {
          final recorder = await pumpBilimYolApp(tester);

          await enterDemoMode(tester);
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

          await restartBilimYolApp(tester);
          await tapBottomNav(tester, L10nExpect.navProgress);

          expect(
            find.textContaining('22 XP', findRichText: true),
            findsWidgets,
          );
          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 3. Welcome & Auth Flows (F6)
    // -----------------------------------------------------------------------
    group('F6: Welcome & Auth Flows', () {
      testWidgets('T1.12 /login displays fields, auth actions and demo entry', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester, initialRoute: '/login');

        expect(
          find.textContaining('Xuş kelibsiz', findRichText: true),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNWidgets(2));
        L10nExpect.expectAnyVisible(L10nExpect.loginButton);
        L10nExpect.expectAnyVisible(L10nExpect.demoEntry);
        L10nExpect.expectAnyVisible(L10nExpect.registerLink);
        expect(
          find.textContaining('Parolni unutdingizmi', findRichText: true),
          findsOneWidget,
        );

        recorder.expectClean();
      });

      testWidgets('T1.13 /login empty submit shows validation message', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester, initialRoute: '/login');

        await tapAnyVisible(tester, L10nExpect.loginButton);
        expect(
          find.textContaining(
            'Iltimos, email va parolni töliq kiriting',
            findRichText: true,
          ),
          findsOneWidget,
        );

        recorder.expectClean();
      });

      testWidgets('T1.14 /login password visibility icon toggles obscureText', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(tester, initialRoute: '/login');

        final passFieldBefore = tester.widget<TextField>(
          find.byType(TextField).last,
        );
        expect(passFieldBefore.obscureText, isTrue);

        await tester.tap(find.byTooltip('Parolni körsatiş'));
        await tester.pumpAndSettle();

        final passFieldAfter = tester.widget<TextField>(
          find.byType(TextField).last,
        );
        expect(passFieldAfter.obscureText, isFalse);

        recorder.expectClean();
      });

      testWidgets('T1.15 /register validates and guards demo mode safely', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialRoute: '/register',
        );

        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(4));
        await tester.enterText(fields.at(0), 'Aziza');
        await tester.enterText(fields.at(1), 'aziza@misol.uz');
        await tester.enterText(fields.at(2), 'parol123');
        await tester.enterText(fields.at(3), 'parol123');

        await scrollAndTap(
          tester,
          find.textContaining('Hisob Yaratiş', findRichText: true),
        );
        // Must show friendly message and NOT crash when Supabase is unconfigured.
        expect(tester.takeException(), isNull);
        L10nExpect.expectAnyVisible([
          'Namuna rejimida',
          'yaratilmaydi',
          'Демо-режим',
          'ulanib bölmadi',
        ]);

        recorder.expectClean();
      });

      testWidgets(
        'T1.16 /forgot-password validates email and shows demo notice',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialRoute: '/forgot-password',
          );

          await tester.enterText(find.byType(TextField).first, 'user@misol.uz');
          await scrollAndTap(
            tester,
            find.textContaining('Tiklaş havolasini yuboriş', findRichText: true),
          );

          expect(
            find.textContaining(
              'Namuna rejimida tiklaş xati yuborilmaydi',
              findRichText: true,
            ),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.17 unauthenticated access to private routes redirects to /login',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialRoute: '/dashboard',
          );

          // Pre-tour unauthenticated access blocks /dashboard and routes to /welcome.
          expect(
            find.textContaining('Bugungi maqsad', findRichText: true),
            findsNothing,
          );
          L10nExpect.expectAnyVisible(L10nExpect.tourPage1Titles);

          // After tour completion, unauthenticated private route redirects to /login.
          await skipProductTour(tester);
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
    });

    // -----------------------------------------------------------------------
    // 4. Subject Catalog — All 4 Subjects (F9)
    // -----------------------------------------------------------------------
    group('F9: Subject Catalog (All 4 Subjects)', () {
      testWidgets('T1.18 /courses displays all 4 subjects', (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        for (final subject in E2EConfig.allSubjectsUz) {
          final finder = find.textContaining(subject, findRichText: true);
          if (finder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(finder, 180);
          }
          expect(finder, findsWidgets, reason: 'Missing subject: $subject');
        }
        recorder.expectClean();
      });

      testWidgets('T1.19 selecting Matematika opens onboarding', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'Matematika');
        expect(
          find.textContaining('Birinçi qadamingizni tanlang', findRichText: true),
          findsOneWidget,
        );
        recorder.expectClean();
      });

      testWidgets('T1.20 selecting Ingliz tili opens onboarding', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'Ingliz tili');
        expect(
          find.textContaining('Birinçi qadamingizni tanlang', findRichText: true),
          findsOneWidget,
        );
        recorder.expectClean();
      });

      testWidgets('T1.21 selecting IT & Kodlaş opens onboarding', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'IT & Kodlaş');
        expect(
          find.textContaining('Birinçi qadamingizni tanlang', findRichText: true),
          findsOneWidget,
        );
        recorder.expectClean();
      });

      testWidgets('T1.22 selecting Mantiq opens onboarding', (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/courses',
        );

        await selectCourse(tester, 'Mantiq');
        expect(
          find.textContaining('Birinçi qadamingizni tanlang', findRichText: true),
          findsOneWidget,
        );
        recorder.expectClean();
      });
    });

    // -----------------------------------------------------------------------
    // 5. Onboarding Plan & Level Selection (F9)
    // -----------------------------------------------------------------------
    group('F9: Onboarding Plan & Level Selection', () {
      testWidgets('T1.23 /onboarding renders 3 levels and plan selectors', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/onboarding',
        );

        expect(
          find.textContaining('Dars bilan boşlaş', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('Mavzuni özim tanlayman', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('Bilimimni tekşiraman', findRichText: true),
          findsOneWidget,
        );
        final maqsadFinder = find.text('Rejada nimaga urğu beraylik?');
        final kunlikFinder = find.textContaining('Kunlik vaqt', findRichText: true);
        final verticalScrollable = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (kunlikFinder.evaluate().isEmpty &&
            verticalScrollable.evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(
            kunlikFinder,
            180,
            scrollable: verticalScrollable.last,
          );
        }
        expect(maqsadFinder, findsOneWidget);
        expect(kunlikFinder, findsOneWidget);
        recorder.expectClean();
      });

      testWidgets(
        'T1.24 beginner level hides diagnostic button and shows starter lesson CTA',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/onboarding',
          );

          await scrollAndTap(
            tester,
            find.textContaining('Dars bilan boşlaş', findRichText: true),
          );
          final starterCta = find.textContaining(
            'Birinçi darsni boşlaş',
            findRichText: true,
          );
          final verticalScrollable = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          if (starterCta.evaluate().isEmpty &&
              verticalScrollable.evaluate().isNotEmpty) {
            await tester.scrollUntilVisible(
              starterCta,
              180,
              scrollable: verticalScrollable.last,
            );
          }
          expect(
            find.textContaining('Tekşiruvni boşlaş', findRichText: true),
            findsNothing,
          );
          expect(starterCta, findsOneWidget);
          recorder.expectClean();
        },
      );

      testWidgets('T1.25 beginner CTA launches course starter lesson', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
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

        expect(
          find.textContaining('Qöşiş va ayirişdan boşlaymiz', findRichText: true),
          findsWidgets,
        );
        recorder.expectClean();
      });

      testWidgets(
        'T1.26 intermediate/advanced level shows roadmap CTA and optional diagnostic',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/onboarding',
          );

          await scrollAndTap(
            tester,
            find.textContaining('Mavzuni özim tanlayman', findRichText: true),
          );
          final roadmapCta = find.textContaining(
            'Ta’lim yölini oçiş',
            findRichText: true,
          );
          expect(roadmapCta, findsOneWidget);
          await scrollAndTap(tester, find.text('Bilimimni tekşiraman'));
          expect(find.text('Tekşiruvni boşlaş'), findsOneWidget);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.27 selecting plan CTA routes to /roadmap cleanly',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/onboarding',
          );

          await scrollAndTap(
            tester,
            find.textContaining('Mavzuni özim tanlayman', findRichText: true),
          );
          await scrollAndTap(
            tester,
            find.textContaining('Ta’lim yölini oçiş', findRichText: true),
          );

          expect(
            find.textContaining('Mening ta’lim yölim', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 6. Diagnostic / Placement & P0 Fixes (F4, F10)
    // -----------------------------------------------------------------------
    group('F10 & F4: Diagnostic / Placement', () {
      testWidgets('T1.28 /placement loads Savol 1 / 8 and Tezkor demo', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/placement',
        );

        expect(
          find.textContaining('Savol 1 / 8', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tezkor demo', findRichText: true),
          findsOneWidget,
        );
        recorder.expectClean();
      });

      testWidgets(
        'T1.29 selecting an option and submitting advances to Savol 2',
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
          await scrollAndTap(
            tester,
            find.textContaining('Keyingi Savol', findRichText: true),
          );

          expect(
            find.textContaining('Savol 2 / 8', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.30 final placement question opens confirmation dialog and Qaytiş cancels',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
          );

          await selectCourse(tester, 'Mantiq');
          await openOptionalDiagnostic(tester);

          for (var i = 0; i < 3; i++) {
            await scrollAndTap(tester, find.text('A'));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 850)),
            );
            await scrollAndTap(
              tester,
              find.textContaining('Keyingi Savol', findRichText: true),
            );
          }

          await scrollAndTap(tester, find.text('A'));
          await scrollAndTap(
            tester,
            find.textContaining('Natijalarni Köriş', findRichText: true),
          );
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            find.textContaining('Natijalar hisoblansinmi', findRichText: true),
            findsOneWidget,
          );

          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Orqaga'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            find.textContaining('Savol 4 / 4', findRichText: true),
            findsOneWidget,
          );

          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.31 confirming placement submission shows summary and Javoblar tahlili',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
          );

          await selectCourse(tester, 'IT & Kodlaş');
          await openOptionalDiagnostic(tester);
          await completePlacement(tester, highAccuracy: true);

          expect(
            find.textContaining('Diagnostika yakunlandi', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('4 / 4', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('Javoblar tahlili', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.32 Tezkor demo routes to /knowledge-map with weak link highlight',
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

          L10nExpect.expectAnyVisible([
            'Bilim xaritasi',
            'Bilim Xaritasi',
            'Карта знаний',
          ]);
          expect(
            find.textContaining('DIQQAT: Zaif Böğin', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.33 placement result retake button resets diagnostic cleanly',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
          );

          await selectCourse(tester, 'Mantiq');
          await openOptionalDiagnostic(tester);
          await completePlacement(tester, highAccuracy: false);

          await scrollAndTap(
            tester,
            find.textContaining(
              'Diagnostikani qayta topşiriş',
              findRichText: true,
            ),
          );
          expect(
            find.textContaining('Savol 1 / 4', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 7. Roadmap & Knowledge Map (F10, F4)
    // -----------------------------------------------------------------------
    group('F10 & F4: Roadmap & Knowledge Map', () {
      testWidgets(
        'T1.34 /roadmap renders timeline stages without English leftover',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/roadmap',
          );

          expect(
            find.textContaining('Mening ta’lim yölim', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('Şaxsiy öquv xaritangiz', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('1-Bosqiç', findRichText: true),
            findsOneWidget,
          );
          L10nExpect.expectNoEnglishLeftovers();
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.35 /roadmap toggle switches to /knowledge-map cleanly',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/roadmap',
          );

          await scrollAndTap(
            tester,
            find.textContaining('Bilim xaritasi', findRichText: true),
          );
          L10nExpect.expectAnyVisible([
            'Bilim xaritasi',
            'Bilim Xaritasi',
            'Карта знаний',
          ]);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.36 /knowledge-map displays mastery score, XP and Könikmalar Tahlili',
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
          expect(
            find.textContaining('Umumiy Özlaştiriş', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('Könikmalar tahlili', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('XP', findRichText: true),
            findsWidgets,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.37 /knowledge-map bottom CTA navigates to /roadmap',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/knowledge-map',
          );

          await scrollAndTap(
            tester,
            find.textContaining('Moslaşuvçan Yöl Xaritasi', findRichText: true),
          );
          expect(
            find.textContaining('Mening ta’lim yölim', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.38 after Tezkor demo, /roadmap shows actionable Maşq qiliş or Boşlaş button',
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

          final hasCta =
              find.textContaining('Maşq qiliş', findRichText: true).evaluate().isNotEmpty ||
              find.textContaining('Boşlaş', findRichText: true).evaluate().isNotEmpty;
          expect(
            hasCta,
            isTrue,
            reason: 'Contract #3 requires an enabled Maşq qiliş or Boşlaş CTA',
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.39 tapping active CTA on /roadmap opens /lesson',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/roadmap',
          );

          final cta = find.textContaining('Boşlaş', findRichText: true).evaluate().isNotEmpty
              ? find.textContaining('Boşlaş', findRichText: true)
              : find.textContaining('Maşq qiliş', findRichText: true);
          await scrollAndTap(tester, cta);

          expect(
            find.textContaining('Qadam 1 /', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 8. Interactive Lesson, Quiz Feedback & Sheets (F8)
    // -----------------------------------------------------------------------
    group('F8: Interactive Lesson & Sheets', () {
      testWidgets(
        'T1.40 lesson step navigation supports Keyingi qadam and Orqaga',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/roadmap',
          );

          final cta = find.textContaining('Boşlaş', findRichText: true).evaluate().isNotEmpty
              ? find.textContaining('Boşlaş', findRichText: true)
              : find.textContaining('Maşq qiliş', findRichText: true);
          await scrollAndTap(tester, cta);

          expect(find.textContaining('Qadam 1 /', findRichText: true), findsOneWidget);
          expect(find.textContaining('Orqaga', findRichText: true), findsNothing);

          await scrollAndTap(
            tester,
            find.textContaining('Keyingi qadam', findRichText: true),
          );
          expect(find.textContaining('Qadam 2 /', findRichText: true), findsOneWidget);

          await scrollAndTap(
            tester,
            find.textContaining('Orqaga', findRichText: true),
          );
          expect(find.textContaining('Qadam 1 /', findRichText: true), findsOneWidget);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.41 math functions lesson displays formula and interactive graph',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/placement',
          );

          await completePlacement(tester, highAccuracy: true);
          await scrollAndTap(
            tester,
            find.textContaining('Şaxsiy yölni köriş', findRichText: true),
          );
          await openMathFunctionsLessonFromRoadmap(tester);

          expect(find.textContaining('Funksiya', findRichText: true), findsWidgets);
          var sawFormula = find
              .textContaining('f(x) = 2x + 3', findRichText: true)
              .evaluate()
              .isNotEmpty;
          var sawSlider = find.byType(Slider).evaluate().isNotEmpty;

          for (var step = 0; step < 5; step++) {
            final nextStep = find.textContaining(
              'Keyingi qadam',
              findRichText: true,
            );
            if (nextStep.evaluate().isEmpty) break;
            await scrollAndTap(tester, nextStep);
            if (find
                .textContaining('f(x) = 2x + 3', findRichText: true)
                .evaluate()
                .isNotEmpty) {
              sawFormula = true;
            }
            if (find.byType(Slider).evaluate().isNotEmpty) {
              sawSlider = true;
            }
          }

          expect(
            sawFormula,
            isTrue,
            reason: 'Math functions lesson must display f(x) = 2x + 3 formula',
          );
          expect(
            sawSlider,
            isTrue,
            reason:
                'Math functions lesson must render MathFunctionGraphWidget Slider (type: function_graph)',
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.42 English starter lesson renders audio wave and dictionary button',
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

          expect(find.byTooltip('Söz luğati'), findsOneWidget);
          await scrollAndTap(
            tester,
            find.textContaining('Keyingi qadam', findRichText: true),
          );
          expect(
            find.textContaining('Aziza va Ben tanişuv dialogi', findRichText: true),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.43 correct quiz completion awards XP and updates learner profile immediately',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
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

          expect(
            find.textContaining('22 XP', findRichText: true),
            findsWidgets,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.44 wrong quiz answer displays inline feedback and AI/reinforcement CTAs',
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

          await submitLessonQuiz(tester, correct: false);
          final hasMcqReveal = find
              .textContaining('Siz tanladingiz:', findRichText: true)
              .evaluate()
              .isNotEmpty;
          if (hasMcqReveal) {
            expect(
              find.textContaining('Töğri javob:', findRichText: true),
              findsOneWidget,
            );
          } else {
            expect(
              find.textContaining('Sizning javobingiz:', findRichText: true),
              findsOneWidget,
            );
            expect(
              find.textContaining('Faqat ism yoki xayrlaşuv', findRichText: true),
              findsOneWidget,
            );
          }
          expect(
            find.textContaining('Yölçi AI tahlili', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('Mavzuni mustahkamlaş', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.45 YolchiAiSheet transitions into ReinforcementSheet and awards +30 XP',
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

          await submitLessonQuiz(tester, correct: false);
          await scrollAndTap(
            tester,
            find.textContaining('Yölçi AI tahlili', findRichText: true),
          );
          expect(
            find.textContaining('Yölçi', findRichText: true),
            findsWidgets,
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
          expect(
            find.textContaining('+30 XP', findRichText: true),
            findsOneWidget,
          );

          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 9. Dashboard Hero, Tabs & Refresh (F7, F4)
    // -----------------------------------------------------------------------
    group('F7 & F4: Dashboard', () {
      testWidgets(
        'T1.46 /dashboard shows focal continuation hero and single primary CTA',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/dashboard',
          );

          expect(
            find.textContaining('Assalomu alaykum', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('Bugungi maqsad', findRichText: true),
            findsOneWidget,
          );
          final hasPrimaryCta =
              find.textContaining('Davom etiş', findRichText: true).evaluate().isNotEmpty ||
              find.textContaining('Birinçi darsni oçiş', findRichText: true).evaluate().isNotEmpty ||
              find.textContaining('Ta’lim yölini oçiş', findRichText: true).evaluate().isNotEmpty ||
              find.textContaining('Fan tanlaş', findRichText: true).evaluate().isNotEmpty;
          expect(hasPrimaryCta, isTrue);

          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.47 /dashboard displays all 4 subjects without .take(3) clipping',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/dashboard',
          );

          final allTab = find.textContaining('Barçasi', findRichText: true);
          await scrollAndTap(tester, allTab);

          final verticalScrollable = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          for (final subject in E2EConfig.allSubjectsUz) {
            final finder = find.textContaining(subject, findRichText: true);
            if (finder.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                finder,
                180,
                scrollable: verticalScrollable.last,
              );
            }
            expect(
              finder,
              findsWidgets,
              reason: 'Dashboard must show all 4 courses including $subject',
            );
          }
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.48 /dashboard filter tabs change displayed courses',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/dashboard',
          );

          final aktivTab = find.textContaining('Aktiv', findRichText: true);
          final tavsiyaTab = find.textContaining('Tavsiya', findRichText: true);
          final barchasiTab = find.textContaining('Barçasi', findRichText: true);

          await scrollAndTap(tester, barchasiTab);

          expect(aktivTab, findsOneWidget);
          expect(tavsiyaTab, findsOneWidget);
          expect(barchasiTab, findsOneWidget);

          final verticalScrollable = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          final mantiqFinder = find.textContaining('Mantiq', findRichText: true);
          if (mantiqFinder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              mantiqFinder,
              180,
              scrollable: verticalScrollable.last,
            );
          }
          final allCount = E2EConfig.allSubjectsUz
              .where((s) => find.textContaining(s, findRichText: true).evaluate().isNotEmpty)
              .length;

          await scrollAndTap(tester, aktivTab);
          final activeCount = E2EConfig.allSubjectsUz
              .where((s) => find.textContaining(s, findRichText: true).evaluate().isNotEmpty)
              .length;

          expect(
            activeCount < allCount,
            isTrue,
            reason: 'Aktiv tab should filter courses instead of showing all 4 identically',
          );
          recorder.expectClean();
        },
      );

      testWidgets('T1.49 /dashboard search bar filters courses dynamically', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/dashboard',
        );

        final allTab = find.textContaining('Barçasi', findRichText: true);
        await scrollAndTap(tester, allTab);

        final searchField = find.byType(TextField);
        if (searchField.evaluate().isEmpty) {
          final verticalScrollable = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          if (verticalScrollable.evaluate().isNotEmpty) {
            await tester.scrollUntilVisible(
              searchField,
              -200,
              scrollable: verticalScrollable.last,
            );
          }
        }
        expect(searchField, findsWidgets);
        await tester.ensureVisible(searchField.first);
        await tester.pumpAndSettle();
        await tester.enterText(searchField.first, 'Kodlaş');
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppCard),
            matching: find.textContaining('Matematika', findRichText: true),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppCard),
            matching: find.textContaining('Ingliz tili', findRichText: true),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppCard),
            matching: find.textContaining('Mantiq', findRichText: true),
          ),
          findsNothing,
        );
        final itCardText = find.descendant(
          of: find.byType(AppCard),
          matching: find.textContaining('IT & Kodlaş', findRichText: true),
        );
        expect(itCardText, findsWidgets);
        recorder.expectClean();
      });

      testWidgets(
        'T1.50 completing a lesson updates Dashboard XP immediately',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
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
          await tapBottomNav(tester, L10nExpect.navHome);

          L10nExpect.expectAnyVisible(['22 XP', '+22']);
          recorder.expectClean();
        },
      );
    });

    // -----------------------------------------------------------------------
    // 10. Progress, Yölçi AI & Bottom Nav (F11)
    // -----------------------------------------------------------------------
    group('F11: Progress, Yölçi AI & Bottom Nav', () {
      testWidgets('T1.51 bottom navigation switches all 5 tabs cleanly', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/dashboard',
        );

        await tapBottomNav(tester, L10nExpect.navRoadmap);
        expect(find.textContaining('Mening ta’lim yölim', findRichText: true), findsOneWidget);

        await tapBottomNav(tester, L10nExpect.navAi);
        expect(find.textContaining('Salom, men Yölçi AI', findRichText: true), findsOneWidget);

        await tapBottomNav(tester, L10nExpect.navProgress);
        expect(find.textContaining('Mening natijalarim', findRichText: true), findsOneWidget);

        await tapBottomNav(tester, L10nExpect.navProfile);
        expect(find.textContaining('Profilim', findRichText: true), findsOneWidget);

        await tapBottomNav(tester, L10nExpect.navHome);
        expect(find.textContaining('Bugungi maqsad', findRichText: true), findsOneWidget);

        recorder.expectClean();
      });

      testWidgets('T1.52 /lesson hides BilimYolBottomNav for distraction-free study', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/roadmap',
        );

        final cta = find.textContaining('Boşlaş', findRichText: true).evaluate().isNotEmpty
            ? find.textContaining('Boşlaş', findRichText: true)
            : find.textContaining('Maşq qiliş', findRichText: true);
        await scrollAndTap(tester, cta);

        expect(find.text('Natijalar'), findsNothing);
        expect(find.text('Profil'), findsNothing);
        recorder.expectClean();
      });

      testWidgets(
        'T1.53 /progress displays stat tiles, study chart, subject bars and badges',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/progress',
          );

          expect(find.textContaining('Mening natijalarim', findRichText: true), findsOneWidget);
          expect(find.textContaining('Bajarilgan dars', findRichText: true), findsOneWidget);
          expect(find.textContaining('Öqiş vaqti', findRichText: true), findsOneWidget);
          expect(find.textContaining('Mavzular böyiça natija', findRichText: true), findsOneWidget);
          expect(find.textContaining('Yutuqlar va nişonlar', findRichText: true), findsOneWidget);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.54 completing 1 lesson unlocks Ilk Qadam badge on /progress',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/courses',
          );

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
          await tapBottomNav(tester, L10nExpect.navProgress);

          expect(find.textContaining('1/4 Olingan', findRichText: true), findsOneWidget);
          expect(find.textContaining('Ajoyib natija!', findRichText: true), findsOneWidget);
          recorder.expectClean();
        },
      );

      testWidgets('T1.55 /ai-tutor shows welcome bubble and 3 quick prompt chips', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/ai-tutor',
        );

        expect(find.textContaining('Salom, men Yölçi AI', findRichText: true), findsOneWidget);
        expect(find.textContaining('Qoidani sodda tuşuntir', findRichText: true), findsOneWidget);
        expect(find.textContaining('Yana bitta misol ber', findRichText: true), findsOneWidget);
        expect(find.textContaining('Maşq savoli ber', findRichText: true), findsOneWidget);
        recorder.expectClean();
      });

      testWidgets('T1.56 /ai-tutor sends prompt and displays reply', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/ai-tutor',
        );

        await tester.enterText(
          find.byType(TextField).first,
          'Kvadrat tenglama nima?',
        );
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();

        expect(find.textContaining('Kvadrat tenglama nima?', findRichText: true), findsOneWidget);
        expect(find.textContaining('savolingiz juda yaxşi', findRichText: true), findsOneWidget);
        recorder.expectClean();
      });
    });

    // -----------------------------------------------------------------------
    // 11. Profile, uz/ru L10n & Light/Dark Theme (F1, F2, F11)
    // -----------------------------------------------------------------------
    group('F1, F2 & F11: Profile, Theme & Localization', () {
      testWidgets('T1.57 /profile displays identity, demo badge and stats', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/profile',
        );

        expect(find.textContaining('Profilim', findRichText: true), findsOneWidget);
        expect(find.textContaining('Namuna', findRichText: true), findsWidgets);
        expect(find.textContaining('Fanni özgartiriş', findRichText: true), findsOneWidget);
        recorder.expectClean();
      });

      testWidgets('T1.58 /profile allows editing learner name', (tester) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/profile',
        );

        final editBtn = L10nExpect.findAnyText([
          'Ismni tahrirlaş',
          'Tahrirlaş',
          'Özgartiriş',
        ]);
        final editIcon = find.byIcon(Icons.edit_outlined).evaluate().isNotEmpty
            ? find.byIcon(Icons.edit_outlined)
            : find.byIcon(Icons.edit_rounded);
        expect(
          editBtn.evaluate().isNotEmpty || editIcon.evaluate().isNotEmpty,
          isTrue,
          reason: 'Profile must provide name-editing action per M3 spec',
        );

        final target = editIcon.evaluate().isNotEmpty ? editIcon.first : editBtn.first;
        await scrollAndTap(tester, target);

        final nameField = find.byType(TextField).last;
        await tester.enterText(nameField, 'Dilşod');
        await tapAnyVisible(tester, ['Saqlaş', 'Tasdiqlaş']);

        expect(find.textContaining('Dilşod', findRichText: true), findsWidgets);
        recorder.expectClean();
      });

      testWidgets('T1.59 /profile toggles Light and Dark theme mode', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/profile',
        );

        final darkToggle = L10nExpect.findAnyText(
          L10nExpect.themeDarkCandidates,
        );
        expect(
          darkToggle,
          findsWidgets,
          reason: 'Profile must expose theme toggle (Light/Dark)',
        );
        await scrollAndTap(tester, darkToggle);

        expectScaffoldThemeBrightness(tester, Brightness.dark);
        recorder.expectClean();
      });

      testWidgets('T1.60 /profile switches uz <-> ru locale dynamically', (
        tester,
      ) async {
        final recorder = await pumpBilimYolApp(
          tester,
          initialDemoSession: true,
          initialRoute: '/profile',
        );

        final ruToggle = L10nExpect.findAnyText(['Русский', 'RU', 'Rus']);
        expect(
          ruToggle,
          findsWidgets,
          reason: 'Profile must expose uz/ru language switcher',
        );
        await scrollAndTap(tester, ruToggle);

        L10nExpect.expectAnyVisible(L10nExpect.profileCopyRu);
        L10nExpect.expectNoneVisible(['Profilim', 'Öquv sozlamalari']);

        final uzToggle = L10nExpect.findAnyText(['Özbekça', 'UZ', 'Özb']);
        expect(
          uzToggle,
          findsWidgets,
          reason: 'Profile must expose switch back to Uzbek',
        );
        await scrollAndTap(tester, uzToggle);

        L10nExpect.expectAnyVisible(['Profilim', 'Öquv sozlamalari']);
        L10nExpect.expectNoneVisible(['Мой профиль', 'Настройки обучения']);
        recorder.expectClean();
      });

      testWidgets(
        'T1.61 /profile replays Product Tour without wiping learner XP',
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

          final replayBtn = L10nExpect.findAnyText(
            L10nExpect.tourReplayCandidates,
          );
          expect(
            replayBtn,
            findsWidgets,
            reason: 'Profile must provide Product Tour replay action',
          );
          await scrollAndTap(tester, replayBtn);
          L10nExpect.expectAnyVisible(L10nExpect.tourPage1Titles);

          // Skip back and verify XP (>0 from Tezkor demo) is intact.
          await skipProductTour(tester);
          appRouter.go('/profile');
          await tester.pumpAndSettle();
          expect(find.text('0 XP', findRichText: true), findsNothing);
          expect(
            find.textContaining(RegExp(r'[1-9]\d*\s*XP'), findRichText: true),
            findsWidgets,
          );
          recorder.expectClean();
        },
      );

      testWidgets('T1.62 /profile Hisobdan çiqiş logs out to /login', (
        tester,
      ) async {
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
        recorder.expectClean();
      });
    });

    // -----------------------------------------------------------------------
    // 12. Cross-Screen A11y & Reduced Motion (F12)
    // -----------------------------------------------------------------------
    group('F12: Accessibility & Reduced Motion', () {
      testWidgets(
        'T1.63 bottom nav items expose Semantics(selected, button)',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            initialDemoSession: true,
            initialRoute: '/dashboard',
          );

          final homeSemantics = tester.getSemantics(
            find.textContaining('Boş sahifa').last,
          );
          expect(homeSemantics.label, isNotEmpty);
          expect(
            homeSemantics.flagsCollection.isButton,
            isTrue,
            reason: 'Bottom nav item must expose button semantics',
          );
          expect(
            homeSemantics.flagsCollection.isSelected,
            Tristate.isTrue,
            reason: 'Active bottom nav item must expose selected=true semantics',
          );

          final inactiveSemantics = tester.getSemantics(
            find.textContaining('Natijalar').last,
          );
          expect(
            inactiveSemantics.flagsCollection.isSelected,
            isNot(Tristate.isTrue),
            reason: 'Inactive bottom nav item must not be marked selected',
          );

          await tapBottomNav(tester, L10nExpect.navProgress);
          final progressSemantics = tester.getSemantics(
            find.textContaining('Natijalar').last,
          );
          expect(progressSemantics.label, isNotEmpty);
          expect(
            progressSemantics.flagsCollection.isButton,
            isTrue,
          );
          expect(
            progressSemantics.flagsCollection.isSelected,
            Tristate.isTrue,
          );
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.64 primary CTAs on /welcome and /dashboard meet >=44dp touch height',
        (tester) async {
          final recorder = await pumpBilimYolApp(tester);

          final nextTextFinder = L10nExpect.findAnyText(L10nExpect.tourNext);
          expect(
            nextTextFinder,
            findsWidgets,
            reason: 'Tour Next CTA must be visible on /welcome',
          );
          final nextButton = find.ancestor(
            of: nextTextFinder.first,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is ButtonStyleButton ||
                  w is InkWell ||
                  w is GestureDetector,
            ),
          );
          expect(nextButton, findsWidgets);
          final nextSize = tester.getSize(nextButton.first);
          expect(
            nextSize.height >= 44.0,
            isTrue,
            reason: 'Tour CTA touch target height must be >= 44dp (got ${nextSize.height})',
          );

          await skipProductTour(tester);
          await enterDemoMode(tester);
          appRouter.go('/dashboard');
          await tester.pumpAndSettle();

          final navSize = tester.getSize(
            find.ancestor(
              of: find.textContaining('Boş sahifa').last,
              matching: find.byType(InkWell),
            ).first,
          );
          expect(navSize.height >= 44.0, isTrue);
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.65 typing indicator exposes live semantic label during pending AI request',
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

          await tester.enterText(find.byType(TextField).first, 'Salom');
          await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
          await tester.pump(const Duration(milliseconds: 50));

          expect(
            find.bySemanticsLabel('Yölçi AI yozmoqda...'),
            findsOneWidget,
          );

          completer.complete(
            const AskTutorResponse(tutorName: 'Yölçi AI', answer: 'Javob'),
          );
          await tester.pumpAndSettle();
          recorder.expectClean();
        },
      );

      testWidgets(
        'T1.66 reduced motion (disableAnimations=true) settles tour and AI reply cleanly',
        (tester) async {
          final recorder = await pumpBilimYolApp(
            tester,
            disableAnimations: true,
          );

          await completeProductTour(tester);
          await enterDemoMode(tester);
          appRouter.go('/ai-tutor');
          await tester.pumpAndSettle();

          await tester.tap(
            find.textContaining('Qoidani sodda tuşuntir', findRichText: true),
          );
          await tester.pumpAndSettle();

          expect(
            find.textContaining('savolingiz juda yaxşi', findRichText: true),
            findsOneWidget,
          );
          recorder.expectClean();
        },
      );
    });
  });
}
