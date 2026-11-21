import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/features/ai_tutor/ai_tutor_screen.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';

class _CapturingTutorService extends DemoAITutorService {
  final List<AskTutorRequest> capturedRequests = [];

  @override
  Future<AskTutorResponse> askTutor(AskTutorRequest request) {
    capturedRequests.add(request);
    return super.askTutor(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'InteractiveLessonScreen passes active question context to AITutorScreen, blocks answer spoilers, and preserves lesson input on pop',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final capturingTutor = _CapturingTutorService();

      final container = ProviderContainer(
        overrides: [
          aiTutorServiceProvider.overrideWithValue(capturingTutor),
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_starter');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InteractiveLessonScreen()),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Qadam 4 / 4'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('free_text_answer_input')),
        "I'm Sam",
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Yo‘lchidan so‘rash'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'To‘g‘ri javobni ayt');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
      await tester.pumpAndSettle();

      expect(capturingTutor.capturedRequests, hasLength(1));
      final req = capturingTutor.capturedRequests.single;
      expect(req.courseId, equals('course_eng_01'));
      expect(req.lessonId, equals('lesson_eng_starter'));
      expect(req.questionId, equals('q_lesson_eng_starter_quiz'));
      expect(req.language, equals('uz'));

      expect(
        find.textContaining('qadam-baqadam', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining("I'm Sam", findRichText: true), findsNothing);
      expect(
        find.textContaining('My name is Sam', findRichText: true),
        findsNothing,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Qadam 4 / 4'), findsOneWidget);
      final inputWidget = tester.widget<TextField>(
        find.byKey(const Key('free_text_answer_input')),
      );
      expect(inputWidget.controller?.text, equals("I'm Sam"));
    },
  );

  testWidgets(
    'AITutorScreen localizes lesson topic in Russian locale and emits single шаг за шагом',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('ru');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      SharedPreferences.setMockInitialValues({});
      final capturingTutor = _CapturingTutorService();

      final container = ProviderContainer(
        overrides: [
          aiTutorServiceProvider.overrideWithValue(capturingTutor),
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_starter', uiLocale: 'ru');
      final starterLesson = container.read(lessonSessionNotifierProvider).lesson!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: AITutorScreen(lesson: starterLesson)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Когда использовать Hello?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      final req = capturingTutor.capturedRequests.single;
      expect(req.language, equals('ru'));
      expect(req.topic, equals('Первые английские слова'));
      expect(
        find.textContaining('шаг за шагом', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Первые английские слова', findRichText: true),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'Opening AITutorScreen and tapping Send immediately after correct Step 4 in lesson_eng_b1_m1_travel dispatches askTutor without 5s delay',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final capturingTutor = _CapturingTutorService();

      final container = ProviderContainer(
        overrides: [
          aiTutorServiceProvider.overrideWithValue(capturingTutor),
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_b1_m1_travel');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InteractiveLessonScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Advance Steps 1..3 -> Step 4 (listening MCQ)
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Qadam 4 / 6'), findsOneWidget);

      const step4Correct =
          '11:15 da 19-darvozadan; turar joy tasdiq xati hali kelmagan edi';
      await tester.ensureVisible(find.text(step4Correct));
      await tester.tap(find.text(step4Correct));
      await tester.pump();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Qadam 5 / 6'), findsOneWidget);

      // Immediately open AITutorScreen (NO 5s delay) and tap Send
      await tester.tap(find.byTooltip('Yo‘lchidan so‘rash'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Salom');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(capturingTutor.capturedRequests, hasLength(1));
      final req = capturingTutor.capturedRequests.single;
      expect(req.message, equals('Salom'));
      expect(req.lessonId, equals('lesson_eng_b1_m1_travel'));
      expect(req.questionId, equals('q_eng_b1_m1_fill'));
      expect(tester.takeException(), isNull);
    },
  );
}
