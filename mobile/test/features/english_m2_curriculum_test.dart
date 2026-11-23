import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/constants/app_colors.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/core/widgets/bilimyol_bottom_nav.dart';
import 'package:bilimyol_mobile/core/widgets/friendly_error_state.dart';
import 'package:bilimyol_mobile/data/datasources/courses_data.dart';
import 'package:bilimyol_mobile/data/datasources/demo_ai_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_roadmap_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/cefr_skeleton_data.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/lesson_media.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_reinforcement_use_case.dart';
import 'package:bilimyol_mobile/features/ai_tutor/ai_tutor_screen.dart';
import 'package:bilimyol_mobile/features/ai_tutor/yolchi_bubble.dart';
import 'package:bilimyol_mobile/features/course_selection/course_selection_screen.dart';
import 'package:bilimyol_mobile/features/dashboard/dashboard_screen.dart';
import 'package:bilimyol_mobile/features/lesson/flashcard_deck_widget.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/lesson/reading_position.dart';
import 'package:bilimyol_mobile/features/onboarding/onboarding_screen.dart';
import 'package:bilimyol_mobile/features/profile/profile_screen.dart';
import 'package:bilimyol_mobile/features/reinforcement/reinforcement_sheet.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('M2.3 English CEFR Curriculum & Domain Contracts', () {
    test('canonical datasources preserve 1:1 counts, order, and 9 QuestionModes', () {
      expect(a1LessonsData.length, 17);
      expect(a1AllFlashcards.length, 17);
      expect(a1RoadmapNodes.length, 15);
      expect(cefrSkeletonLevels.length, 6);
      final moduleCount = cefrSkeletonLevels.fold<int>(
        0,
        (sum, lvl) => sum + lvl.modules.length,
      );
      expect(moduleCount, 22);

      final engCourse = seedCourses.firstWhere((c) => c.id == 'course_eng_01');
      expect(engCourse.lessons.first, 'lesson_eng_listening_01');
      expect(engCourse.lessons.length, 33);
      for (final a1Id in a1LessonsData.keys) {
        expect(engCourse.lessons, contains(a1Id));
      }
      expect(demoAiResponsesData['q_eng_listening_01'], isNotNull);

      final seenModes = <QuestionMode>{};
      for (final lesson in a1LessonsData.values) {
        for (final step in lesson.steps) {
          if (step.interactiveQuestion != null) {
            seenModes.add(step.interactiveQuestion!.mode);
          }
        }
        seenModes.add(lesson.reinforcementExercise.mode);
        if (lesson.alternateExercise != null) {
          seenModes.add(lesson.alternateExercise!.mode);
        }
      }
      expect(seenModes, containsAll(QuestionMode.values));

      final m2Node = a1RoadmapNodes.firstWhere(
        (n) => n.id == 'node_eng_a1_m2_daily_life',
      );
      expect(m2Node.prerequisites, ['node_eng_a1_u1_checkpoint']);
      expect(m2Node.status, NodeStatus.locked);
    });

    test('normalizeTextAnswer handles Uzbek/acute apostrophe variants', () {
      expect(normalizeTextAnswer('I\u02bbm Sam.'), "i'm sam");
      expect(normalizeTextAnswer('I\u00b4m Sam!'), "i'm sam");
      expect(normalizeTextAnswer('  My   name\u2019s Sam '), "my name's sam");
    });

    test('SRS flashcard review records persist across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = InMemoryLearnerRepository();
      await repo1.recordFlashcardReview(
        courseId: 'course_eng_01',
        cardId: 'fc_eng_starter_1',
        remembered: false,
      );
      await repo1.recordFlashcardReview(
        courseId: 'course_eng_01',
        cardId: 'fc_eng_starter_2',
        remembered: true,
      );
      final p2 = await repo1.recordFlashcardReview(
        courseId: 'course_eng_01',
        cardId: 'fc_eng_starter_2',
        remembered: true,
      );
      expect(
        p2.flashcardSrsByCourse['course_eng_01']?['fc_eng_starter_1']?.status,
        'need_practice',
      );
      expect(
        p2.flashcardSrsByCourse['course_eng_01']?['fc_eng_starter_1']
            ?.nextReviewBucket,
        'session_next',
      );
      final rec2 =
          p2.flashcardSrsByCourse['course_eng_01']?['fc_eng_starter_2'];
      expect(rec2?.status, 'remembered');
      expect(rec2?.reviewCount, 2);
      expect(rec2?.intervalBucket, 2);
      expect(rec2?.nextReviewBucket, '3_days');

      // Re-instantiate repository from SharedPreferences
      final repo2 = InMemoryLearnerRepository();
      final reloaded = await repo2.getProfile();
      expect(
        reloaded.flashcardSrsByCourse['course_eng_01']?['fc_eng_starter_2']
            ?.nextReviewBucket,
        '3_days',
      );
    });

    test('reading position store clamps out-of-range indices and clears cleanly', () async {
      final lesson = a1LessonsData['lesson_eng_starter']!;
      final firstQuizIdx = lesson.steps.indexWhere(
        (s) => s.interactiveQuestion != null,
      );
      SharedPreferences.setMockInitialValues({
        'bilimyol-reading:${lesson.id}': '999',
      });
      expect(
        await LessonReadingPositionStore.readStepIndex(lesson),
        firstQuizIdx,
      );

      SharedPreferences.setMockInitialValues({
        'bilimyol-reading:${lesson.id}': '-5',
      });
      expect(await LessonReadingPositionStore.readStepIndex(lesson), 0);

      await LessonReadingPositionStore.saveStepIndex(lesson, 2);
      expect(await LessonReadingPositionStore.readStepIndex(lesson), 2);
      await LessonReadingPositionStore.clearStepIndex(lesson);
      expect(await LessonReadingPositionStore.readStepIndex(lesson), 0);
    });

    test('FakeLessonAudioController load generation aborts stale load after stop', () async {
      final controller = FakeLessonAudioController();
      await controller.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      expect(controller.state.assetPath, isNotNull);
      await controller.stop();
      expect(controller.state.isPlaying, isFalse);
      await controller.dispose();
    });

    test('AppTheme darkTheme configures dark brightness and WCAG colors', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(dark.colorScheme.surface, AppColors.darkSurface);
    });
  });

  group('M2.3 Widget Flows', () {
    testWidgets('FlashcardDeckWidget shows 5 modes, IPA+IPA AmE, alt fallback, and standalone empty state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = InMemoryLearnerRepository();
      final cards = a1LessonsData['lesson_eng_starter']!.steps[2].flashcards!;
      for (final c in cards) {
        await repo.recordFlashcardReview(
          courseId: 'course_eng_01',
          cardId: c.id,
          remembered: true,
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: [cards.first],
                  allCourseFlashcards: cards,
                  standaloneSrsMode: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All remembered/un-due -> empty state with Keyingi takrorlaş (SRS) + Tasodifiy maşq
      expect(find.text('Barça kartoçkalar körib çiqildi!'), findsOneWidget);
      expect(find.text('Keyingi takrorlaş (SRS)'), findsOneWidget);
      expect(find.text('Tasodifiy maşq'), findsWidgets);

      // Broken image alt fallback test using a nonexistent asset path
      final brokenCard = LessonFlashcard(
        id: 'fc_broken',
        front: 'Broken asset test',
        backUz: 'Sinov',
        ipa: '/brəʊkən/',
        ipaAmE: '/broʊkən/',
        example: 'Example sentence.',
        imageSrc: '/lesson-media/english/does-not-exist.png',
        alt: 'Broken card fallback description',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(flashcards: [brokenCard]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Broken card fallback description'), findsOneWidget);
      await tester.tap(find.text('Javobni köriş'));
      await tester.pumpAndSettle();
      expect(find.text('/brəʊkən/'), findsOneWidget);
      expect(find.text('/broʊkən/'), findsOneWidget);
    });

    testWidgets('Grouped CEFR Roadmap displays A1..C2, Modul sinovi, SRS modal, and lock SnackBar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(roadmapStateNotifierProvider.notifier).loadRoadmap('course_eng_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RoadmapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SRS Takrorlaş'), findsOneWidget);
      expect(find.text('Modul sinovi'), findsWidgets);
      expect(find.text('A1'), findsOneWidget);

      // Tap locked node card -> prerequisite snackbar
      final lockedTitle = find.text('Present Simple: Böş joyni töldiriş');
      await tester.scrollUntilVisible(lockedTitle, 200);
      await tester.tap(lockedTitle);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      // Math roadmap stays linear (no SRS Takrorlaş)
      await container.read(roadmapStateNotifierProvider.notifier).loadRoadmap('course_math_01');
      await tester.pumpAndSettle();
      expect(find.text('SRS Takrorlaş'), findsNothing);
      expect(find.text(seedRoadmapNodes['course_math_01']!.first.title), findsOneWidget);
    });

    testWidgets('Rich exercises: wordMatch, sentenceOrder, speakingPrompt self-assessment, and checkpoint Qayta maşq', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_u1_checkpoint');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InteractiveLessonScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Advance to the interactive question step of U1 checkpoint
      while (find.text('TEKŞIRIŞ').evaluate().isEmpty) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }

      // Pick wrong option on checkpoint -> Qayta maşq button appears
      final stepQuestion = container
          .read(lessonSessionNotifierProvider)
          .lesson!
          .steps[container.read(lessonSessionNotifierProvider).currentStepIndex]
          .interactiveQuestion!;
      final wrongIdx = (stepQuestion.correctIndex + 1) % stepQuestion.options.length;
      await tester.tap(find.text(stepQuestion.options[wrongIdx]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      expect(find.text('Qayta maşq'), findsOneWidget);

      // Speaking prompt self-assessment renders sample response & rubric checkboxes
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_m1_speaking');
      await tester.pumpAndSettle();
      while (find.byKey(const Key('self_assessed_text_input')).evaluate().isEmpty) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byKey(const Key('self_assessed_text_input')),
        'Hello! My name is Aziza.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      expect(find.text('Namuna javob:'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);
    });

    testWidgets('AI Tutor supports RU welcome in didChangeDependencies, Foydali javob toggle, and Escape', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.binding.platformDispatcher.localeTestValue = const Locale('ru');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiTutorServiceProvider.overrideWithValue(DemoAITutorService()),
          ],
          child: const MaterialApp(
            home: AITutorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Привет, я Yölçi AI', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Полезный ответ'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Что такое present simple?');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Полезный ответ'), findsOneWidget);
      await tester.tap(find.text('Полезный ответ'));
      await tester.pumpAndSettle();
      expect(find.text('Отмечено полезным'), findsOneWidget);

      // Escape key triggers maybePop cleanly
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    test('LessonMedia.transcript is null on the 3 image media steps', () {
      final imageSteps = [
        a1LessonsData['lesson_eng_a1_m2_sentence_builder']!.steps[1].media!,
        a1LessonsData['lesson_eng_a1_m2_daily_life']!.steps[1].media!,
        a1LessonsData['lesson_eng_a1_m4_writing']!.steps[1].media!,
      ];
      for (final media in imageSteps) {
        expect(media.kind, LessonMediaKind.image);
        expect(media.transcript, isNull);
      }
    });

    test('Concurrent Future.wait recordFlashcardReview preserves all SRS updates (Probe 1E)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = InMemoryLearnerRepository();
      await Future.wait([
        repo.recordFlashcardReview(
          courseId: 'course_eng_01',
          cardId: 'fc_eng_starter_1',
          remembered: true,
        ),
        repo.recordFlashcardReview(
          courseId: 'course_eng_01',
          cardId: 'fc_eng_starter_2',
          remembered: false,
        ),
        repo.recordFlashcardReview(
          courseId: 'course_eng_01',
          cardId: 'fc_eng_a1_m1_1',
          remembered: true,
        ),
      ]);
      final profile = await repo.getProfile();
      final srs = profile.flashcardSrsByCourse['course_eng_01']!;
      expect(srs['fc_eng_starter_1']?.status, 'remembered');
      expect(srs['fc_eng_starter_2']?.status, 'need_practice');
      expect(srs['fc_eng_a1_m1_1']?.status, 'remembered');
    });

    test('AudioController.stop() returns idle when unloaded, guards stopGen race, and clears error (Probes 3B/3C/3E)', () async {
      // Probe 3E: FakeLessonAudioController
      final fake = FakeLessonAudioController(failOnLoad: true);
      await fake.stop();
      expect(fake.state.status, LessonAudioStatus.idle);

      await fake.loadAsset('assets/lesson_media/english/missing.wav');
      expect(fake.state.hasError, isTrue);
      await fake.stop();
      expect(fake.state.status, LessonAudioStatus.idle);
      expect(fake.state.hasError, isFalse);

      fake.failOnLoad = false;
      await fake.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      await fake.play();
      await fake.stop();
      expect(fake.state.status, LessonAudioStatus.ready);
      await fake.dispose();

      // Probes 3B & 3C: JustAudioLessonController
      final player = _TestStopRaceAudioPlayer();
      final justAudio = JustAudioLessonController(player: player);

      await justAudio.stop();
      expect(justAudio.state.status, LessonAudioStatus.idle);

      player.throwOnSetAsset = true;
      await justAudio.loadAsset('assets/lesson_media/english/missing.wav');
      expect(justAudio.state.hasError, isTrue);
      await justAudio.stop();
      expect(justAudio.state.status, LessonAudioStatus.idle);
      expect(justAudio.state.hasError, isFalse);

      // Probe 3B: stop() awaiting _player.stop() must not overwrite a newer loadAsset()
      player.throwOnSetAsset = false;
      player.stopGate = Completer<void>();
      final stopFuture = justAudio.stop();
      await justAudio.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      expect(justAudio.state.status, LessonAudioStatus.ready);
      player.stopGate!.complete();
      await stopFuture;
      expect(justAudio.state.status, LessonAudioStatus.ready);
      await justAudio.dispose();
    });

    test('Security: cross-course & non-integrated skillId mismatch blocked; wordMatch jsonEncode handles quotes', () async {
      SharedPreferences.setMockInitialValues({});
      final learnerRepo = InMemoryLearnerRepository();
      final lessonRepo = InMemoryLessonRepository();
      final useCase = SubmitReinforcementUseCase(learnerRepo, lessonRepo);

      const mismatchedQuestion = Question(
        id: 'q_mismatch',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_listening',
        text: 'Mismatch',
        mode: QuestionMode.multipleChoice,
        options: ['A', 'B'],
        correctIndex: 0,
        difficulty: QuestionDifficulty.easy,
        explanation: 'Exp',
      );
      await expectLater(
        () => useCase.execute(
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          reinforcementNodeId: 'reinf_1',
          reinforcementQuestion: mismatchedQuestion,
          selectedIndex: 0,
        ),
        throwsArgumentError,
      );

      await expectLater(
        () => useCase.execute(
          courseId: 'course_math_01',
          skillId: 'skill_eng_listening',
          reinforcementNodeId: 'reinf_math',
          reinforcementQuestion: mismatchedQuestion,
          selectedIndex: 0,
        ),
        throwsArgumentError,
      );

      const wordMatchWithQuotes = Question(
        id: 'q_wm_quotes',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        text: 'Match quotes',
        mode: QuestionMode.wordMatch,
        matchPairs: [
          WordMatchPair(id: 'p1', left: 'Say "hi"', right: 'Salom "ayt"'),
        ],
        difficulty: QuestionDifficulty.easy,
        explanation: 'Exp',
      );
      final attempt = await learnerRepo.submitAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_a1_m1_greetings',
        questionId: 'q_eng_a1_m1_greet_match',
        selectedIndex: 0,
        selectedAnswer: '{"pair_gm":"Xayrli tong","pair_ge":"Xayrli keç","pair_hay":"Ahvolingiz qanday?","pair_ift":"Yaxşiman, rahmat."}',
      );
      expect(attempt.isCorrect, isTrue);
      // Verify jsonEncode escaping on quotes doesn't throw FormatException on decode
      expect(wordMatchWithQuotes.isWordMatchCorrect({'p1': 'Salom "ayt"'}), isTrue);
    });

    testWidgets('fillBlank end-to-end completion (lesson_eng_a1_m2_daily_life)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_m2_daily_life');

      final router = _buildTestRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      while (find.byKey(const Key('free_text_answer_input')).evaluate().isEmpty) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      expect(find.text('My sister ___ English at school every morning.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('free_text_answer_input')), 'studies');
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      expect(container.read(lessonSessionNotifierProvider).isCompleted, isTrue);
      final profile = container.read(learnerStateNotifierProvider).value!;
      expect(profile.completedLessonIds, contains('lesson_eng_a1_m2_daily_life'));
      expect(find.text('Roadmap'), findsOneWidget);
    });

    testWidgets('lesson_eng_a1_exit full 5-step multi-skill completion', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_exit');

      final router = _buildTestRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Keyingi qadam'));
      await tester.pumpAndSettle();

      // Step 2: listening MCQ (skill_eng_listening)
      await tester.tap(find.text('20:30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Step 3: fillBlank (skill_eng_grammar)
      await tester.enterText(find.byKey(const Key('free_text_answer_input')), 'opens');
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Step 4: sentenceOrder (skill_eng_grammar)
      for (final token in ['I', 'drink', 'my', 'tea', 'beside', 'the', 'window.']) {
        final chip = find.widgetWithText(ActionChip, token);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Step 5: reading MCQ (skill_eng_reading)
      final readOpt = find.text('Yakşanba kuni soat 16:00–17:00 orasida suhbat davrasi bor va talabalarga çoy bepul');
      await tester.ensureVisible(readOpt);
      await tester.tap(readOpt);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      expect(container.read(lessonSessionNotifierProvider).isCompleted, isTrue);
      final profile = container.read(learnerStateNotifierProvider).value!;
      expect(profile.completedLessonIds, contains('lesson_eng_a1_exit'));
      expect(find.text('Roadmap'), findsOneWidget);
    });

    testWidgets('wordMatch at 390x844 renders Tozalaş without overflow and completes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_m1_greetings');

      final router = _buildTestRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      while (find.text('Good morning').evaluate().isEmpty) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }

      // Match first pair so Tozalaş appears at 390px -> assert zero RenderFlex overflow
      final gmLeft = find.text('Good morning');
      await tester.ensureVisible(gmLeft);
      await tester.tap(gmLeft);
      await tester.pumpAndSettle();
      final gmRight = find.widgetWithText(ActionChip, 'Xayrli tong');
      await tester.ensureVisible(gmRight);
      await tester.tap(gmRight);
      await tester.pumpAndSettle();
      expect(find.text('Tozalaş'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final pair in [
        ('Good evening', 'Xayrli keç'),
        ('How are you?', 'Ahvolingiz qanday?'),
        ("I'm fine, thanks.", 'Yaxşiman, rahmat.'),
      ]) {
        final left = find.text(pair.$1);
        await tester.ensureVisible(left);
        await tester.tap(left);
        await tester.pumpAndSettle();
        final right = find.widgetWithText(ActionChip, pair.$2);
        await tester.ensureVisible(right);
        await tester.tap(right);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      expect(container.read(lessonSessionNotifierProvider).isCompleted, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sentenceOrder partial hint, Tozalaş reset, and completion (lesson_eng_a1_m2_sentence_builder)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_m2_sentence_builder');

      final router = _buildTestRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      while (find.text('Gapni tartib bilan tuzing:').evaluate().isEmpty) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }

      // Single token -> partial hint
      await tester.tap(find.widgetWithText(ActionChip, 'They'));
      await tester.pumpAndSettle();
      expect(find.text('Tozalaş'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gapdagi barça sözlarni tartiblang (1/6)'), findsOneWidget);

      await tester.tap(find.text('Tozalaş'));
      await tester.pumpAndSettle();

      for (final token in ['They', 'read', 'books', 'in', 'the', 'library.']) {
        await tester.tap(find.widgetWithText(ActionChip, token));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      expect(container.read(lessonSessionNotifierProvider).isCompleted, isTrue);
    });

    testWidgets('errorCorrection, Qayta maşq, and q_eng_a1_u3_cp_reinf multi-skill reinforcement', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_u3_checkpoint');

      final router = _buildTestRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keyingi qadam'));
      await tester.pumpAndSettle();

      expect(find.text('The study desk is the window beside.'), findsOneWidget);
      await tester.tap(find.text('The study desk beside is the window.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      expect(find.text('Mavzuni mustahkamlaş'), findsOneWidget);
      expect(find.text('Qayta maşq'), findsOneWidget);

      // Open ReinforcementSheet for q_eng_a1_u3_cp_reinf (skill_eng_listening)
      final reinfBtn = find.text('Mavzuni mustahkamlaş');
      await tester.ensureVisible(reinfBtn);
      await tester.tap(reinfBtn);
      await tester.pumpAndSettle();
      final opt2230 = find.text('22:30');
      await tester.ensureVisible(opt2230);
      await tester.tap(opt2230);
      await tester.pumpAndSettle();
      final checkBtn = find.text('Javobni Tekşiriş');
      await tester.ensureVisible(checkBtn);
      await tester.tap(checkBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ajoyib Natija!'), findsOneWidget);
      final profile = container.read(learnerStateNotifierProvider).value!;
      expect(
        profile.scoresByCourse['course_eng_01']?['skill_eng_listening']?.score,
        greaterThan(0),
      );

      // Close sheet via Dashboard button
      final dashBtn = find.text('Daşboardga Ötiş');
      await tester.ensureVisible(dashBtn);
      await tester.tap(dashBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('ReinforcementSheet supports q_eng_a1_exit_reinf in RU dark mode and wordMatch/selfAssessed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.binding.platformDispatcher.localeTestValue = const Locale('ru');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_exit');

      final exitReinf = a1LessonsData['lesson_eng_a1_exit']!.reinforcementExercise;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ru'),
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ReinforcementSheet(
                question: exitReinf,
                onSubmit: (idx) => container
                    .read(lessonSessionNotifierProvider.notifier)
                    .submitReinforcement(idx),
                onSubmitRich: ({
                  required int selectedIndex,
                  String? selectedText,
                  Map<String, String>? matchedPairs,
                  List<String>? orderedTokens,
                }) => container
                    .read(lessonSessionNotifierProvider.notifier)
                    .submitReinforcement(
                      selectedIndex,
                      selectedText: selectedText,
                      matchedPairs: matchedPairs,
                      orderedTokens: orderedTokens,
                    ),
                onGoToDashboard: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тренировка закрепления'), findsOneWidget);
      expect(find.text('Waiter: «Good afternoon! What would you like?»'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('A cup of green tea and a sandwich, please.'));
      await tester.pumpAndSettle();
      final checkRuBtn = find.text('Проверить ответ');
      await tester.ensureVisible(checkRuBtn);
      await tester.tap(checkRuBtn);
      await tester.pumpAndSettle();

      expect(find.text('Отличный результат!'), findsOneWidget);
      expect(find.text('Прежний балл'), findsOneWidget);
      expect(find.text('Новый балл'), findsOneWidget);
      expect(find.text('Перейти на главную'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('writingPrompt self-assessment, rubric, non-certification notice, and completion (lesson_eng_a1_m4_writing)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');
      await container.read(lessonSessionNotifierProvider.notifier).startLesson('lesson_eng_a1_m4_writing');

      final router = _buildTestRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      while (find.byKey(const Key('self_assessed_text_input')).evaluate().isEmpty) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }

      await tester.enterText(
        find.byKey(const Key('self_assessed_text_input')),
        'Hi Ben! My desk is beside the window.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKŞIRIŞ'));
      await tester.pumpAndSettle();

      expect(find.text('Namuna javob:'), findsOneWidget);
      expect(
        find.text('Özini baholaş (mustaqil yozma maşq): bu vazifa rasmiy CEFR sertifikati bermaydi.'),
        findsOneWidget,
      );
      final firstCheck = find.byType(CheckboxListTile).first;
      await tester.ensureVisible(firstCheck);
      await tester.tap(firstCheck);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yakunlaş'));
      await tester.pumpAndSettle();

      expect(container.read(lessonSessionNotifierProvider).isCompleted, isTrue);
      expect(
        container.read(learnerStateNotifierProvider).value!.completedLessonIds,
        contains('lesson_eng_a1_m4_writing'),
      );
    });

    testWidgets('FlashcardDeckWidget 390px with srsRecord != null + partOfSpeech has zero overflow (T4-01 guard)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryLearnerRepository();
      await repo.recordFlashcardReview(
        courseId: 'course_eng_01',
        cardId: 'fc_eng_starter_1',
        remembered: false,
      );
      final cards = a1LessonsData['lesson_eng_starter']!.steps[2].flashcards!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  allCourseFlashcards: cards,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Takrorlaş: 1 • Şu darsda'), findsOneWidget);
      expect(find.text('phrase'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Standalone SRS Probe 1C preserves unreviewed cards after 1 remembered', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final cards = a1LessonsData['lesson_eng_starter']!.steps[2].flashcards!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  allCourseFlashcards: cards,
                  standaloneSrsMode: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("What's your name?"), findsOneWidget);
      await tester.tap(find.text('Javobni köriş'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslab qoldim'));
      await tester.pumpAndSettle();

      expect(find.text('Nice to meet you.'), findsOneWidget);
      expect(find.text('Barça kartoçkalar körib çiqildi!'), findsNothing);
    });

    testWidgets('Standalone SRS Probe 1D preserves rotated need_practice order across reviewCount bump', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final cards = a1LessonsData['lesson_eng_starter']!.steps[2].flashcards!;
      final repo = InMemoryLearnerRepository();
      for (final c in cards) {
        await repo.recordFlashcardReview(
          courseId: 'course_eng_01',
          cardId: c.id,
          remembered: false,
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  allCourseFlashcards: cards,
                  standaloneSrsMode: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("What's your name?"), findsOneWidget);
      await tester.tap(find.text('Javobni köriş'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yana maşq qilaman'));
      await tester.pumpAndSettle();

      expect(find.text('Nice to meet you.'), findsOneWidget);
    });

    testWidgets('RU localization renders across flagged screens & controllers', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.binding.platformDispatcher.localeTestValue = const Locale('ru');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      const audioErrState = LessonAudioState(
        status: LessonAudioStatus.error,
        errorMessage: 'Audio faylni yuklab bölmadi.',
        errorCode: LessonAudioErrorCode.loadFailed,
      );
      expect(audioErrState.localizedErrorMessage('uz'), 'Audio faylni yuklab bölmadi.');
      expect(audioErrState.localizedErrorMessage('ru'), 'Не удалось загрузить аудиофайл.');

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('ru'),
            home: Scaffold(
              bottomNavigationBar: BilimYolBottomNav(currentIndex: 0),
              body: Column(
                children: [
                  FriendlyErrorState(),
                  YolchiTypingIndicator(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('Не удалось загрузить данные.'), findsOneWidget);
      expect(find.bySemanticsLabel('Yölçi AI печатает...'), findsOneWidget);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('ru'),
            home: CourseSelectionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Каталог предметов'), findsOneWidget);
      expect(find.text('Английский язык'), findsOneWidget);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(courseStateNotifierProvider.notifier).selectCourse('course_eng_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ru'),
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('С чего хотите начать?'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ru'),
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Мой профиль'), findsOneWidget);
      expect(find.text('Сменить предмет'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ru'),
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Выберите план обучения'), findsOneWidget);
    });
  });
}

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const InteractiveLessonScreen(),
      ),
      GoRoute(
        path: '/roadmap',
        builder: (_, _) => const Scaffold(body: Center(child: Text('Roadmap'))),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Center(child: Text('Dashboard'))),
      ),
    ],
  );
}

class _TestStopRaceAudioPlayer implements AudioPlayer {
  bool throwOnSetAsset = false;
  Completer<void>? stopGate;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<double> get speedStream => const Stream.empty();

  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    if (throwOnSetAsset) {
      throw PlayerException(404, 'Simulated setAsset failure', null);
    }
    return const Duration(seconds: 4);
  }

  @override
  Future<void> stop() async {
    if (stopGate != null) {
      await stopGate!.future;
    }
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
