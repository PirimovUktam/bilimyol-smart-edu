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
      addTearDown(() {
        demoSessionActive.value = false;
        productTourCompleted.value = false;
        activeSessionHasStartedCourse.value = false;
      });
      final tutor = _UnavailableTutor();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiTutorServiceProvider.overrideWithValue(tutor)],
          child: const BilimYolApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nimadan boşlaşni biling.'), findsOneWidget);
      await tester.tap(find.text('Ötkazib yuboriş'));
      await tester.pumpAndSettle();
      expect(find.text('Xuş kelibsiz!'), findsOneWidget);

      appRouter.go('/onboarding');
      await tester.pumpAndSettle();
      expect(find.text('Xuş kelibsiz!'), findsOneWidget);

      final demo = find.text('Namuna hisobi bilan kiriş');
      await tester.ensureVisible(demo);
      await tester.tap(demo);
      await tester.pumpAndSettle();
      expect(find.text('Matematika'), findsWidgets);
      await tester.tap(find.text('Ingliz tili').first);
      await tester.pumpAndSettle();
      expect(find.text('Birinçi qadamingizni tanlang'), findsOneWidget);
      await tester.tap(find.text('Dars bilan boşlaş'));
      await tester.pumpAndSettle();
      expect(find.text('Tekşiruvni boşlaş'), findsNothing);
      final start = find.text('Birinçi darsni boşlaş');
      await tester.scrollUntilVisible(start, 180);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('Birinçi inglizça sözlar'), findsWidgets);
      expect(find.textContaining('«Hello» — salom'), findsWidgets);
      expect(find.text('Diagnostika natijasi'), findsNothing);
      await tester.tap(find.byTooltip('Yölçidan söraş'));
      await tester.pumpAndSettle();
      expect(find.text('Yölçi AI'), findsWidgets);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('«Hello» — salom'), findsWidgets);
      await tester.tap(find.byTooltip('Söz luğati'));
      await tester.pumpAndSettle();
      expect(find.text('Inglizça söz luğati'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'hello world');
      await tester.tap(find.text('Sözni izlaş'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bitta inglizça söz kiriting. Masalan: hello.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Luğatni yopiş'));
      await tester.pumpAndSettle();
      for (var step = 0; step < 3; step++) {
        final nextBtn = find.text('Keyingi qadam');
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
      }
      final input = find.byKey(const Key('free_text_answer_input'));
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Goodbye');
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();
      expect(find.text('Sizning javobingiz: Goodbye'), findsOneWidget);
      expect(tutor.diagnosisCalls, 0);
      final diagnosis = find.text('Yölçi AI tahlili');
      await tester.ensureVisible(diagnosis);
      await tester.tap(diagnosis);
      await tester.pumpAndSettle();
      expect(tutor.diagnosisCalls, 1);
      expect(find.text('Yölçi izohini yuklab bölmadi.'), findsOneWidget);
      await tester.tap(find.text('Darsga qaytiş'));
      await tester.pumpAndSettle();
      expect(find.text('Sizning javobingiz: Goodbye'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
