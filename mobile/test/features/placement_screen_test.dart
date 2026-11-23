import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/features/lesson/lesson_media_widget.dart';
import 'package:bilimyol_mobile/features/placement/placement_test_screen.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

class _FiveOptionCourseRepository extends InMemoryCourseRepository {
  @override
  Future<List<Question>> getPlacementQuestions(String courseId) async {
    return const [
      Question(
        id: 'q_five_opts',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        cefrLevel: 'A1',
        isPlacement: true,
        text: 'Pick option E:',
        options: ['Opt 1', 'Opt 2', 'Opt 3', 'Opt 4', 'Opt 5'],
        correctIndex: 4,
        difficulty: QuestionDifficulty.easy,
        explanation: 'Option 5 is correct.',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/placement',
    routes: [
      GoRoute(
        path: '/placement',
        builder: (_, _) => const PlacementTestScreen(),
      ),
      GoRoute(
        path: '/roadmap',
        builder: (_, _) => const RoadmapScreen(),
      ),
    ],
  );

  testWidgets(
    'PlacementTestScreen renders LessonMediaWidget on listening question with collapsed transcript, isolates mastery, and routes to RoadmapScreen recommendation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      );
      await tester.pumpAndSettle();

      var sawListeningMedia = false;
      for (var step = 1; step <= 8; step++) {
        final state = container.read(placementStateNotifierProvider);
        final q = state.currentQuestion;
        expect(q, isNotNull);
        expect(q!.text, isNot(contains('Audio context:')));

        if (q.skillId == 'skill_eng_listening') {
          sawListeningMedia = true;
          expect(find.byType(LessonMediaWidget), findsOneWidget);
          expect(find.text('English'), findsOneWidget);
          // Transcript collapsed until tapped
          expect(find.textContaining('Lola:'), findsNothing);
          expect(find.textContaining('Receptionist:'), findsNothing);
          expect(find.textContaining('Malika:'), findsNothing);
        }

        // Deliberately pick wrong answer on every step to verify Pre-A1 placement
        final wrongIdx = (q.correctIndex + 1) % q.options.length;
        final wrongFinder = find.text(q.options[wrongIdx]);
        await tester.ensureVisible(wrongFinder);
        await tester.tap(wrongFinder);
        await tester.pumpAndSettle();

        final nextBtn = find.text(
          step == 8 ? 'Natijalarni Köriş' : 'Keyingi Savol',
        );
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        if (step == 8) {
          await tester.tap(find.text('Topşiriş'));
          await tester.pumpAndSettle();
        } else {
          // Wait past 800ms wall-clock placement rate-limiter
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 850)),
          );
          await tester.pumpAndSettle();
        }
      }

      expect(sawListeningMedia, isTrue);
      expect(find.text('Diagnostika yakunlandi'), findsOneWidget);
      expect(find.text('0 / 8 javob töğri.'), findsOneWidget);
      expect(find.text('Pre-A1'), findsWidgets);
      expect(find.textContaining('B2–C2'), findsWidgets);

      final profile = container.read(learnerStateNotifierProvider).value!;
      expect(profile.placementCefrByCourse['course_eng_01'], equals('Pre-A1'));
      expect(profile.placementScoreByCourse['course_eng_01'], equals(0));
      expect(profile.scoresByCourse['course_eng_01'], isNull);
      expect(profile.completedLessonIds, isEmpty);

      await tester.tap(find.text('Şaxsiy yölni köriş'));
      await tester.pumpAndSettle();

      expect(find.text('Birinçi inglizça sözlar'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PlacementTestScreen handles >4 options without RangeError',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          courseRepositoryProvider.overrideWithValue(
            _FiveOptionCourseRepository(),
          ),
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Opt 5'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
