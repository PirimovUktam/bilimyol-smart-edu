import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilimyol_mobile/app/app.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';

class _UnavailableTutor extends DemoAITutorService {
  int diagnosisCalls = 0;

  @override
  Future<AIExplanationResponse> explainMistake(
    AIExplanationRequest request,
  ) async {
    diagnosisCalls++;
    throw StateError('Tutor unavailable');
  }
}

void main() {
  testWidgets(
    'welcome leads to a beginner lesson and contextual help preserves it',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => demoSessionActive.value = false);
      final tutor = _UnavailableTutor();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiTutorServiceProvider.overrideWithValue(tutor)],
          child: const BilimYolApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('O‘zingizga mos yo‘ldan o‘rganing.'), findsOneWidget);
      expect(find.text('Tanlash va davom etish'), findsNothing);
      appRouter.go('/onboarding');
      await tester.pumpAndSettle();
      expect(find.text('Xush kelibsiz!'), findsOneWidget);

      final demo = find.text('Namuna hisobi bilan kirish');
      await tester.ensureVisible(demo);
      await tester.tap(demo);
      await tester.pumpAndSettle();
      expect(find.text('Matematika'), findsWidgets);
      await tester.tap(find.text('Ingliz tili').first);
      await tester.pumpAndSettle();
      expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);
      await tester.tap(find.text('Noldan boshlayman'));
      await tester.pumpAndSettle();
      expect(find.text('Ixtiyoriy diagnostika'), findsNothing);
      final start = find.text('Birinchi darsni boshlash');
      await tester.scrollUntilVisible(start, 180);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
      expect(find.textContaining('«Hello» — salom'), findsWidgets);
      expect(find.text('Diagnostika natijasi'), findsNothing);
      await tester.tap(find.byTooltip('Yo‘lchidan so‘rash'));
      await tester.pumpAndSettle();
      expect(find.text('Yo‘lchi AI'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('«Hello» — salom'), findsWidgets);
      await tester.tap(find.byTooltip('So‘z lug‘ati'));
      await tester.pumpAndSettle();
      expect(find.text('Inglizcha so‘z lug‘ati'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'hello world');
      await tester.tap(find.text('So‘zni izlash'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bitta inglizcha so‘z kiriting. Masalan: hello.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Lug‘atni yopish'));
      await tester.pumpAndSettle();
      for (var step = 0; step < 2; step++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Goodbye'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      expect(find.text('To‘g‘ri javob: Hello'), findsOneWidget);
      expect(tutor.diagnosisCalls, 0);
      final diagnosis = find.text('Yo‘lchi AI tahlili');
      await tester.ensureVisible(diagnosis);
      await tester.tap(diagnosis);
      await tester.pumpAndSettle();
      expect(tutor.diagnosisCalls, 1);
      expect(find.text('Yo‘lchi izohini yuklab bo‘lmadi.'), findsOneWidget);
      await tester.tap(find.text('Darsga qaytish'));
      await tester.pumpAndSettle();
      expect(find.text('To‘g‘ri javob: Hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
