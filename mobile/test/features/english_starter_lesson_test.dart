import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/app.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';
import 'package:bilimyol_mobile/data/datasources/starter_lessons_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/lesson_media.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/personalization/learning_start.dart';
import 'package:bilimyol_mobile/features/lesson/flashcard_deck_widget.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/lesson/lesson_media_widget.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    demoSessionActive.value = false;
  });

  group('LessonMedia, AudioController & TextInput Unit Contracts', () {
    test('LessonMedia.tryParse enforces approved status, language, and safe asset paths', () {
      expect(
        LessonMedia.tryParse({
          'id': 'm1',
          'kind': 'audio',
          'language': 'en',
          'title': 'Dialogue',
          'source': '/lesson-media/english/a1-starter-dialogue.wav',
          'transcript': 'Aziza: Hi!',
          'durationSeconds': 5.9,
          'reviewStatus': 'draft',
        }),
        isNull,
      );

      expect(
        LessonMedia.tryParse({
          'id': 'm2',
          'kind': 'audio',
          'language': 'en',
          'title': 'Traversal',
          'source': '/lesson-media/../secret.wav',
          'transcript': 'Hi',
          'durationSeconds': 2.0,
          'reviewStatus': 'approved',
        }),
        isNull,
      );

      expect(
        LessonMedia.tryParse({
          'id': 'm3',
          'kind': 'audio',
          'language': 'en',
          'title': 'Remote URL',
          'source': 'https://example.com/a.wav',
          'transcript': 'Hi',
          'durationSeconds': 2.0,
          'reviewStatus': 'approved',
        }),
        isNull,
      );

      final valid = LessonMedia.tryParse({
        'id': 'media_eng_starter_dialogue',
        'kind': 'audio',
        'language': 'en',
        'titleUz': 'Aziza va Ben tanishuv dialogi',
        'titleRu': 'Диалог знакомства Азизы и Бена',
        'source': '/lesson-media/english/a1-starter-dialogue.wav',
        'posterImage': '/lesson-media/english/a1-starter-greeting.png',
        'posterAlt': 'Greeting',
        'transcript': "Aziza: Hi, I'm Aziza.\nBen: I'm Ben.",
        'durationSeconds': 5.907,
        'reviewStatus': 'approved',
      });
      expect(valid, isNotNull);
      expect(valid!.language, LessonMediaLanguage.en);
      expect(
        valid.resolvedSourceAssetPath,
        'assets/lesson_media/english/a1-starter-dialogue.wav',
      );
      expect(
        valid.resolvedPosterAssetPath,
        'assets/lesson_media/english/a1-starter-greeting.png',
      );
    });

    test('normalizeTextAnswer & Question.isTextAnswerCorrect handle variants cleanly', () {
      const q = Question(
        id: 'q_test',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        mode: QuestionMode.textInput,
        text: "What's your name?",
        acceptedAnswers: ["I'm Sam", "My name is Sam", "I am Sam", "Hi, I'm Sam"],
        difficulty: QuestionDifficulty.easy,
        explanation: 'Use I\'m or My name is.',
      );

      expect(q.isTextAnswerCorrect("I'm Sam"), isTrue);
      expect(q.isTextAnswerCorrect("  i’m   sam! "), isTrue);
      expect(q.isTextAnswerCorrect("My name is Sam."), isTrue);
      expect(q.isTextAnswerCorrect("I am Sam"), isTrue);
      expect(q.isTextAnswerCorrect("Hi I'm Sam"), isTrue);
      expect(q.isTextAnswerCorrect("Sam"), isFalse);
      expect(q.isTextAnswerCorrect("Goodbye"), isFalse);
      expect(q.isTextAnswerCorrect("   "), isFalse);

      final starterQuiz = starterLessons['lesson_eng_starter']!
          .steps[3]
          .interactiveQuestion!;
      expect(starterQuiz.isTextAnswerCorrect("My name's Sam"), isTrue);
      expect(starterQuiz.isTextAnswerCorrect("Hi, my name's Sam"), isTrue);
      expect(starterQuiz.isTextAnswerCorrect("Hello, my name's Sam"), isTrue);
    });

    test('SupabaseLessonRepository.parseLearnerLesson parses flashcard, media & textInput', () {
      final parsed = SupabaseLessonRepository.parseLearnerLesson({
        'id': 'lesson_eng_starter',
        'course_id': 'course_eng_01',
        'skill_id': 'skill_eng_vocab',
        'title': 'Birinchi inglizcha so‘zlar',
        'steps': [
          {
            'id': 's1',
            'type': 'audio_simulation',
            'title': 'Dialog',
            'content': 'Listen',
            'media': {
              'id': 'm1',
              'kind': 'audio',
              'language': 'en',
              'title': 'Dialogue',
              'source': '/lesson-media/english/a1-starter-dialogue.wav',
              'transcript': 'Aziza: Hi!',
              'durationSeconds': 5.9,
              'reviewStatus': 'approved',
            },
          },
          {
            'id': 's2',
            'type': 'flashcard',
            'title': 'Cards',
            'content': 'Review',
            'flashcards': [
              {
                'id': 'fc1',
                'front': "What's your name?",
                'backUz': 'Ismingiz nima?',
                'example': "Hi, what's your name?",
              },
            ],
          },
          {
            'id': 's3',
            'type': 'interactive_question',
            'title': 'Try',
            'content': 'Write',
            'interactiveQuestion': {
              'id': 'q1',
              'mode': 'text_input',
              'text': 'Introduce yourself.',
              'options': <String>[],
            },
          },
          {
            'id': 's4',
            'type': 'interactive_question',
            'title': 'Try camel',
            'content': 'Write',
            'interactiveQuestion': {
              'id': 'q2',
              'questionType': 'text_input',
              'text': 'Say hello.',
              'options': <String>[],
            },
          },
        ],
        'reinforcement_exercise': {
          'id': 'q_reinf',
          'question_type': 'text_input',
          'text': 'Say your name.',
          'options': <String>[],
        },
      });

      expect(parsed.steps[0].media, isNotNull);
      expect(parsed.steps[1].type, LessonStepType.flashcard);
      expect(parsed.steps[1].flashcards!.single.front, "What's your name?");
      expect(parsed.steps[2].interactiveQuestion!.mode, QuestionMode.textInput);
      expect(parsed.steps[3].interactiveQuestion!.mode, QuestionMode.textInput);
      expect(parsed.reinforcementExercise.mode, QuestionMode.textInput);
    });

    test('SupabaseLessonRepository.parseLearnerLesson ignores empty mode string and falls back to questionType', () {
      final parsed = SupabaseLessonRepository.parseLearnerLesson({
        'id': 'lesson_empty_mode',
        'course_id': 'course_eng_01',
        'skill_id': 'skill_eng_vocab',
        'title': 'Empty mode fallback',
        'steps': [
          {
            'id': 's1',
            'type': 'interactive_question',
            'title': 'Try',
            'content': 'Write',
            'interactiveQuestion': {
              'id': 'q1',
              'mode': '',
              'questionType': 'text_input',
              'text': 'Introduce yourself.',
              'options': <String>[],
            },
          },
        ],
        'reinforcement_exercise': {
          'id': 'q_reinf',
          'mode': '   ',
          'question_type': 'text_input',
          'text': 'Say your name.',
          'options': <String>[],
        },
      });

      expect(parsed.steps.single.interactiveQuestion!.mode, QuestionMode.textInput);
      expect(parsed.reinforcementExercise.mode, QuestionMode.textInput);
    });

    test('FakeLessonAudioController tracks actions and auto-advances on replay before dispose', () async {
      final controller = FakeLessonAudioController(
        autoAdvanceOnPlay: true,
        simulatedDuration: const Duration(milliseconds: 1200),
        tickStep: const Duration(milliseconds: 400),
      );
      await controller.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      expect(controller.state.status, LessonAudioStatus.ready);
      await controller.play();
      expect(controller.state.status, LessonAudioStatus.playing);
      await controller.pause();
      expect(controller.state.status, LessonAudioStatus.paused);
      await controller.replay();
      expect(controller.replayCalls, 1);
      expect(controller.state.status, LessonAudioStatus.playing);
      expect(controller.state.position, Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(controller.state.position, greaterThan(Duration.zero));
      await controller.dispose();
      expect(controller.disposeCalls, 1);
    });

    test('FakeLessonAudioController preserves load error on replay and supports retry after play error', () async {
      final controller = FakeLessonAudioController(
        failOnLoad: true,
        failOnPlay: false,
      );
      await controller.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      expect(controller.state.hasError, isTrue);
      expect(controller.state.errorMessage, 'Audio faylni yuklab bo‘lmadi.');

      await controller.replay();
      expect(controller.state.hasError, isTrue);
      expect(controller.state.status, LessonAudioStatus.error);
      expect(controller.state.errorMessage, 'Audio faylni yuklab bo‘lmadi.');

      controller.failOnLoad = false;
      await controller.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      expect(controller.state.hasError, isFalse);
      expect(controller.state.status, LessonAudioStatus.ready);

      controller.failOnPlay = true;
      await controller.play();
      expect(controller.state.hasError, isTrue);
      expect(controller.state.errorMessage, 'Audio ijro etilmadi.');

      controller.failOnPlay = false;
      await controller.replay();
      expect(controller.state.hasError, isFalse);
      expect(controller.state.status, LessonAudioStatus.playing);
      await controller.dispose();
    });

    test('JustAudioLessonController does not call seek or play on replay after setAsset fails', () async {
      final player = _FailingLoadAudioPlayer();
      final controller = JustAudioLessonController(player: player);

      await controller.loadAsset('assets/lesson_media/english/missing.wav');
      expect(controller.state.hasError, isTrue);
      expect(controller.state.errorMessage, 'Missing asset');

      await controller.replay();
      expect(player.seekCalls, 0);
      expect(player.playCalls, 0);
      expect(controller.state.hasError, isTrue);
      expect(controller.state.errorMessage, 'Missing asset');

      await controller.dispose();
    });

    test('JustAudioLessonController recovers from transient play failure on replay and play while setAsset failure blocks seek/play', () async {
      final player = _StatefulAudioPlayer()..throwOnSetAsset = true;
      final controller = JustAudioLessonController(player: player);

      await controller.loadAsset('assets/lesson_media/english/missing.wav');
      expect(controller.state.hasError, isTrue);
      expect(controller.state.status, LessonAudioStatus.error);

      await controller.play();
      await controller.replay();
      expect(player.seekCalls, 0);
      expect(player.playCalls, 0);

      player.throwOnSetAsset = false;
      await controller.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      expect(controller.state.hasError, isFalse);
      expect(controller.state.status, LessonAudioStatus.ready);

      player.throwOnPlay = true;
      await controller.play();
      expect(controller.state.hasError, isTrue);
      expect(controller.state.status, LessonAudioStatus.error);
      expect(controller.state.errorMessage, 'Simulated play failure');

      player.throwOnPlay = false;
      await controller.replay();
      expect(player.seekCalls, 1);
      expect(player.playCalls, 2);
      expect(controller.state.hasError, isFalse);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.status, LessonAudioStatus.playing);

      player.throwOnPlay = true;
      await controller.play();
      expect(controller.state.hasError, isTrue);
      expect(controller.state.status, LessonAudioStatus.error);

      player.throwOnPlay = false;
      await controller.play();
      expect(player.playCalls, 4);
      expect(controller.state.hasError, isFalse);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.status, LessonAudioStatus.playing);

      await controller.dispose();
    });

    test('FakeLessonAudioController blocks play and replay until loadAsset succeeds even if failOnLoad is toggled', () async {
      final controller = FakeLessonAudioController(failOnLoad: true);
      await controller.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      expect(controller.state.hasError, isTrue);

      controller.failOnLoad = false;
      await controller.play();
      await controller.replay();
      expect(controller.state.hasError, isTrue);
      expect(controller.state.status, LessonAudioStatus.error);

      await controller.loadAsset('assets/lesson_media/english/a1-starter-dialogue.wav');
      expect(controller.state.hasError, isFalse);
      expect(controller.state.status, LessonAudioStatus.ready);

      await controller.replay();
      expect(controller.state.hasError, isFalse);
      expect(controller.state.status, LessonAudioStatus.playing);
      await controller.dispose();
    });

    test('InMemoryLearnerRepository persists progress to SharedPreferences and isolates math', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = InMemoryLearnerRepository();
      await repo1.recordAnswerAttempt(
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        selectedIndex: 0,
        selectedAnswer: "I'm Sam",
        isCorrect: true,
      );
      await repo1.markLessonCompleted('lesson_eng_starter', courseId: 'course_eng_01');

      final repo2 = InMemoryLearnerRepository();
      final restored = await repo2.getProfile();
      expect(restored.completedLessonIds, contains('lesson_eng_starter'));
      expect(restored.xp, greaterThan(0));
      expect(restored.scoresByCourse['course_eng_01'], isNotNull);
      expect(restored.scoresByCourse['course_math_01'], isNull);

      await repo2.resetAll();
      final repo3 = InMemoryLearnerRepository();
      final afterReset = await repo3.getProfile();
      expect(afterReset.completedLessonIds, isEmpty);
      expect(afterReset.xp, 0);
    });

    test('AskTutorRequest defaults language to uz and DemoAITutorService supports ru', () async {
      const reqDefault = AskTutorRequest(message: 'Salom');
      expect(reqDefault.language, 'uz');
      final resRu = await DemoAITutorService().askTutor(
        const AskTutorRequest(message: 'Привет', topic: 'Greetings', language: 'ru'),
      );
      expect(resRu.answer, contains('Greetings'));
      expect(resRu.answer, contains('шаг за шагом'));
    });
  });

  group('LessonMediaWidget & FlashcardDeckWidget Component Tests', () {
    testWidgets('LessonMediaWidget plays, pauses, replays, toggles transcript, and retries on error', (tester) async {
      final fakeController = FakeLessonAudioController(failOnLoad: true);
      final media = starterLessons['lesson_eng_starter']!.steps[1].media!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => fakeController,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LessonMediaWidget(media: media),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error & retry banner shown when failOnLoad is true
      final retryFinder = find.text('Qayta urinish');
      expect(retryFinder, findsOneWidget);
      fakeController.failOnLoad = false;
      await tester.ensureVisible(retryFinder);
      await tester.tap(retryFinder);
      await tester.pumpAndSettle();
      expect(find.text('Qayta urinish'), findsNothing);
      expect(find.text('English'), findsOneWidget);

      // Play -> Pause -> Replay -> Position emit
      final playBtn = find.byIcon(Icons.play_arrow_rounded);
      await tester.ensureVisible(playBtn);
      await tester.tap(playBtn);
      await tester.pump();
      expect(fakeController.playCalls, 1);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      fakeController.emitPosition(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('0:03 / 0:05'), findsOneWidget);

      final pauseBtn = find.byIcon(Icons.pause_rounded);
      await tester.ensureVisible(pauseBtn);
      await tester.tap(pauseBtn);
      await tester.pump();
      expect(fakeController.pauseCalls, 1);

      final replayBtn = find.byIcon(Icons.replay_rounded);
      await tester.ensureVisible(replayBtn);
      await tester.tap(replayBtn);
      await tester.pump();
      expect(fakeController.replayCalls, 1);

      // Transcript collapsed initially, expands on tap
      expect(find.textContaining("Hi, I'm Aziza", findRichText: true), findsNothing);
      final transcriptToggle = find.text('Matnli bayon');
      await tester.ensureVisible(transcriptToggle);
      await tester.tap(transcriptToggle);
      await tester.pumpAndSettle();
      expect(find.textContaining('Aziza:', findRichText: true), findsOneWidget);
      expect(find.textContaining('Ben:', findRichText: true), findsOneWidget);
    });

    testWidgets('LessonMediaWidget displays Текст under Russian locale', (tester) async {
      final fakeController = FakeLessonAudioController();
      final media = starterLessons['lesson_eng_starter']!.steps[1].media!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => fakeController,
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Localizations.override(
                context: context,
                locale: const Locale('ru'),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: LessonMediaWidget(media: media),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Текст'), findsOneWidget);
      expect(find.text('Диалог знакомства Азизы и Бена'), findsOneWidget);
    });

    testWidgets('FlashcardDeckWidget reveals back, plays audio, re-queues need practice, and completes', (tester) async {
      final fakeController = FakeLessonAudioController();
      final cards = starterLessons['lesson_eng_starter']!.steps[2].flashcards!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => fakeController,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  audioController: fakeController,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("What's your name?"), findsOneWidget);
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();
      expect(
        fakeController.loadedAssets,
        contains('assets/lesson_media/english/a1-starter-whats-your-name.wav'),
      );

      // Reveal first card -> re-queue with "Yana mashq qilaman"
      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      expect(find.text('/wɒts jɔːr neɪm/'), findsOneWidget);
      expect(
        find.text('Ismingiz nima?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Yana mashq qilaman'));
      await tester.pumpAndSettle();
      expect(find.text('Nice to meet you.'), findsOneWidget);

      // Remember second card -> first card returns in queue!
      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslab qoldim'));
      await tester.pumpAndSettle();
      expect(find.text("What's your name?"), findsOneWidget);

      // Remember re-queued first card -> summary shown
      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslab qoldim'));
      await tester.pumpAndSettle();
      expect(find.text('Barcha kartochkalar ko‘rib chiqildi!'), findsOneWidget);
    });

    testWidgets('LessonMediaWidget disposes audio controller when updated to non-audio media', (tester) async {
      final fakeController = FakeLessonAudioController();
      final audioMedia = starterLessons['lesson_eng_starter']!.steps[1].media!;
      const imageMedia = LessonMedia(
        id: 'media_img_only',
        kind: LessonMediaKind.image,
        language: LessonMediaLanguage.en,
        title: 'Greeting illustration',
        source: '/lesson-media/english/a1-starter-greeting.png',
        alt: 'Two students greeting',
        reviewStatus: LessonMediaReviewStatus.approved,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => fakeController,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LessonMediaWidget(media: audioMedia),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fakeController.disposeCalls, 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => fakeController,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LessonMediaWidget(media: imageMedia),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fakeController.disposeCalls, 1);
    });

    testWidgets('FlashcardDeckWidget clears stale audio error when advancing to next card', (tester) async {
      final fakeController = FakeLessonAudioController(failOnPlay: true);
      final cards = starterLessons['lesson_eng_starter']!.steps[2].flashcards!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => fakeController,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  audioController: fakeController,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Audio qayta ijro etilmadi.'), findsOneWidget);

      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslab qoldim'));
      await tester.pumpAndSettle();

      expect(find.text('Nice to meet you.'), findsOneWidget);
      expect(find.text('Audio qayta ijro etilmadi.'), findsNothing);
    });

    testWidgets('FlashcardDeckWidget displays load error, retains hasError, and clears on advancing card', (tester) async {
      final fakeController = FakeLessonAudioController(
        failOnLoad: true,
        failOnPlay: false,
      );
      final cards = starterLessons['lesson_eng_starter']!.steps[2].flashcards!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => fakeController,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  audioController: fakeController,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();

      expect(fakeController.state.hasError, isTrue);
      expect(fakeController.state.status, LessonAudioStatus.error);
      expect(fakeController.replayCalls, 0);
      expect(find.text('Audio faylni yuklab bo‘lmadi.'), findsOneWidget);

      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslab qoldim'));
      await tester.pumpAndSettle();

      expect(find.text('Nice to meet you.'), findsOneWidget);
      expect(find.text('Audio faylni yuklab bo‘lmadi.'), findsNothing);
    });

    testWidgets('FlashcardDeckWidget re-subscribes cleanly when audioController prop is swapped', (tester) async {
      final controllerA = FakeLessonAudioController();
      final controllerB = FakeLessonAudioController(
        failOnLoad: true,
        failOnPlay: false,
      );
      final cards = starterLessons['lesson_eng_starter']!.steps[2].flashcards!;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  audioController: controllerA,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  audioController: controllerB,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();

      expect(controllerA.loadCalls, 0);
      expect(controllerA.disposeCalls, 0);
      expect(controllerB.loadCalls, 1);
      expect(controllerB.disposeCalls, 0);
      expect(controllerB.state.hasError, isTrue);
      expect(find.text('Audio faylni yuklab bo‘lmadi.'), findsOneWidget);
    });

    testWidgets('FlashcardDeckWidget skips replay when card advances or controller swaps mid-load', (tester) async {
      final loadGate = Completer<void>();
      final controllerA = _GatedLoadAudioController(loadGate);
      final controllerB = FakeLessonAudioController();
      final cards = starterLessons['lesson_eng_starter']!.steps[2].flashcards!;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  audioController: controllerA,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();
      expect(controllerA.loadStarted, isTrue);

      // Advance card while controllerA.loadAsset is still awaiting loadGate
      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslab qoldim'));
      await tester.pumpAndSettle();
      expect(find.text('Nice to meet you.'), findsOneWidget);

      // Swap controller as well before load completes
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FlashcardDeckWidget(
                  flashcards: cards,
                  audioController: controllerB,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      loadGate.complete();
      await tester.pumpAndSettle();

      expect(controllerA.loadCalls, 1);
      expect(controllerA.state.hasError, isFalse);
      expect(controllerA.replayCalls, 0);
      expect(controllerA.disposeCalls, 0);
      expect(controllerB.disposeCalls, 0);
    });
  });

  group('Starter Lesson E2E Journey, Restart Persistence & Broken Node Fixes', () {
    testWidgets('full English starter flow with audio, flashcard, free-text feedback, and SharedPreferences restore', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => demoSessionActive.value = false);

      final audioControllers = <FakeLessonAudioController>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(() {
              final c = FakeLessonAudioController();
              audioControllers.add(c);
              return c;
            }),
          ],
          child: const BilimYolApp(),
        ),
      );
      await tester.pumpAndSettle();

      appRouter.go('/onboarding');
      await tester.pumpAndSettle();

      final skipTour = find.text('O‘tkazib yuborish');
      if (skipTour.evaluate().isNotEmpty) {
        await tester.tap(skipTour);
        await tester.pumpAndSettle();
      }

      final demo = find.text('Namuna hisobi bilan kirish');
      await tester.ensureVisible(demo);
      await tester.tap(demo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ingliz tili').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Noldan boshlayman'));
      await tester.pumpAndSettle();
      final startBtn = find.text('Birinchi darsni boshlash');
      await tester.scrollUntilVisible(startBtn, 180);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // Step 1: concept
      expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
      expect(find.textContaining('«Hello» — salom'), findsWidgets);
      await tester.tap(find.text('Keyingi qadam'));
      await tester.pumpAndSettle();

      // Step 2: real media widget with illustration & audio
      expect(find.text('Aziza va Ben tanishuv dialogi'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(audioControllers.first.loadedAssets, contains('assets/lesson_media/english/a1-starter-dialogue.wav'));
      final playIcon = find.byIcon(Icons.play_arrow_rounded);
      await tester.ensureVisible(playIcon);
      await tester.pumpAndSettle();
      await tester.tap(playIcon);
      await tester.pump();
      final pauseIcon = find.byIcon(Icons.pause_rounded);
      await tester.ensureVisible(pauseIcon);
      await tester.tap(pauseIcon);
      await tester.pump();
      final replayIcon = find.byIcon(Icons.replay_rounded);
      await tester.ensureVisible(replayIcon);
      await tester.tap(replayIcon);
      await tester.pump();
      expect(audioControllers.first.replayCalls, 1);

      final transcriptToggle = find.text('Matnli bayon');
      await tester.ensureVisible(transcriptToggle);
      await tester.tap(transcriptToggle);
      await tester.pumpAndSettle();
      expect(find.textContaining('Aziza:', findRichText: true), findsOneWidget);
      expect(find.textContaining('Ben:', findRichText: true), findsOneWidget);

      await tester.tap(find.text('Keyingi qadam'));
      await tester.pumpAndSettle();

      // Step 3: flashcard deck (flipping does NOT complete lesson)
      expect(find.text("What's your name?"), findsOneWidget);
      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      expect(find.text('/wɒts jɔːr neɪm/'), findsOneWidget);

      final container1 = ProviderScope.containerOf(
        tester.element(find.byType(InteractiveLessonScreen)),
      );
      expect(
        container1.read(learnerStateNotifierProvider).value?.completedLessonIds,
        isNot(contains('lesson_eng_starter')),
      );

      await tester.tap(find.text('Keyingi qadam'));
      await tester.pumpAndSettle();

      // Step 4: free-text question (no spoiler, wrong feedback, accepted answer)
      final input = find.byKey(const Key('free_text_answer_input'));
      expect(input, findsOneWidget);
      expect(find.textContaining("My name is Sam"), findsNothing);

      await tester.enterText(input, 'Sam');
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      expect(find.text('Sizning javobingiz: Sam'), findsOneWidget);
      expect(
        find.textContaining('Faqat ism yoki xayrlashuv so‘zini yozmang'),
        findsOneWidget,
      );

      await tester.enterText(input, "I'm Sam");
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();

      // Completed & navigated to roadmap
      expect(
        container1.read(learnerStateNotifierProvider).value?.completedLessonIds,
        contains('lesson_eng_starter'),
      );

      // Simulate app restart without clearing SharedPreferences
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      demoSessionActive.value = false;
      appRouter.go('/welcome');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
          child: const BilimYolApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container2 = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container2.read(learnerStateNotifierProvider.notifier).loadProfile();
      await tester.pumpAndSettle();
      final restored = container2.read(learnerStateNotifierProvider).value!;
      expect(restored.completedLessonIds, contains('lesson_eng_starter'));
      expect(restored.xp, greaterThan(0));
      expect(restored.scoresByCourse['course_eng_01'], isNotNull);
      expect(restored.scoresByCourse['course_math_01'], isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts "My name is Sam" free-text variant in InteractiveLessonScreen', (tester) async {
      addTearDown(() {
        demoSessionActive.value = false;
        appRouter.go('/welcome');
      });
      demoSessionActive.value = true;
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
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_starter');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      appRouter.go('/lesson');
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        final nextBtn = find.text('Keyingi qadam');
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
      }
      final freeInput = find.byKey(const Key('free_text_answer_input'));
      await tester.ensureVisible(freeInput);
      await tester.enterText(
        freeInput,
        'My name is Sam',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();

      expect(container.read(lessonSessionNotifierProvider).isCompleted, isTrue);
    });

    testWidgets('accepts "My name\'s Sam" and localizes step badge under Russian locale', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('ru');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(() {
        demoSessionActive.value = false;
        appRouter.go('/welcome');
      });
      demoSessionActive.value = true;
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
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_starter');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      appRouter.go('/lesson');
      await tester.pumpAndSettle();

      expect(find.text('Шаг 1 / 4'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        final nextBtn = find.text('Следующий шаг');
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
      }
      expect(find.text('Шаг 4 / 4'), findsOneWidget);
      final freeInput = find.byKey(const Key('free_text_answer_input'));
      await tester.ensureVisible(freeInput);
      await tester.enterText(
        freeInput,
        "My name's Sam",
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить'));
      await tester.pumpAndSettle();

      expect(container.read(lessonSessionNotifierProvider).isCompleted, isTrue);
    });

    test('broken node & isolation invariants: node_eng_read, lesson_eng_foundation_02, lesson_eng_listening_01, math isolation', () {
      final engNodes = seedRoadmapNodes['course_eng_01']!;
      final readNode = engNodes.firstWhere((n) => n.id == 'node_eng_read');
      expect(readNode.targetLessonId, 'lesson_eng_reading_01');
      final readLesson = seedLessons['lesson_eng_reading_01'];
      expect(readLesson, isNotNull);
      expect(readLesson!.title, 'Asosiy g‘oya va dalil');

      final found02 = seedLessons['lesson_eng_foundation_02']!;
      final found02Quiz = found02.steps[2].interactiveQuestion!;
      expect(found02.reinforcementExercise.id, isNot(equals(found02Quiz.id)));
      expect(found02.reinforcementExercise.text, isNot(equals(found02Quiz.text)));
      expect(found02.reinforcementExercise.text, contains('She ___ a teacher.'));

      final listening01 = seedLessons['lesson_eng_listening_01']!;
      final listMedia = listening01.steps[1].media;
      expect(listMedia, isNotNull);
      expect(listMedia!.isApproved, isTrue);
      expect(listMedia.language, LessonMediaLanguage.en);
      expect(listMedia.source, '/lesson-media/english/a1-listening-lecture-time.wav');
      expect(listMedia.durationSeconds, closeTo(5.546, 0.01));
      expect(listMedia.transcript, contains('in the afternoon'));

      expect(usesMathMastery('course_eng_01'), isFalse);
      SupabaseConfig.hasRemoteConfiguration = true;
      try {
        expect(usesMathMastery('course_eng_01'), isFalse);
        expect(usesMathMastery('course_math_01'), isTrue);
      } finally {
        SupabaseConfig.hasRemoteConfiguration = false;
      }
    });

    testWidgets('node_eng_read opens lesson_eng_reading_01 from RoadmapScreen when prerequisite is completed', (tester) async {
      addTearDown(() {
        demoSessionActive.value = false;
        appRouter.go('/welcome');
      });
      final repo = InMemoryLearnerRepository();
      await repo.saveSkillScores('course_eng_01', {
        'skill_eng_vocab': const SkillScore(
          skillId: 'skill_eng_vocab',
          courseId: 'course_eng_01',
          score: 85,
          lastUpdated: 1,
          masteryLevel: MasteryLevel.mastered,
        ),
        'skill_eng_grammar': const SkillScore(
          skillId: 'skill_eng_grammar',
          courseId: 'course_eng_01',
          score: 80,
          lastUpdated: 1,
          masteryLevel: MasteryLevel.mastered,
        ),
        'skill_eng_listening': const SkillScore(
          skillId: 'skill_eng_listening',
          courseId: 'course_eng_01',
          score: 80,
          lastUpdated: 1,
          masteryLevel: MasteryLevel.mastered,
        ),
        'skill_eng_reading': const SkillScore(
          skillId: 'skill_eng_reading',
          courseId: 'course_eng_01',
          score: 75,
          lastUpdated: 1,
          masteryLevel: MasteryLevel.proficient,
        ),
      });
      await repo.markNodeCompleted('node_eng_vocab', courseId: 'course_eng_01');
      await repo.markNodeCompleted('node_eng_gram', courseId: 'course_eng_01');
      await repo.markNodeCompleted('node_eng_list', courseId: 'course_eng_01');
      final profile = await repo.getProfile();
      await repo.updateProfile(profile.copyWith(selectedCourseId: 'course_eng_01'));

      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(repo),
          lessonAudioControllerFactoryProvider.overrideWithValue(
            () => FakeLessonAudioController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      demoSessionActive.value = true;
      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(roadmapStateNotifierProvider.notifier).loadRoadmap('course_eng_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      appRouter.go('/roadmap');
      await tester.pumpAndSettle();

      expect(find.byType(RoadmapScreen), findsOneWidget);
      final readingTitle = find.text('Reading');
      await tester.scrollUntilVisible(readingTitle, 180);
      expect(readingTitle, findsOneWidget);

      final readingColumn = find
          .ancestor(of: readingTitle, matching: find.byType(Column))
          .first;
      final startBtn = find.descendant(
        of: readingColumn,
        matching: find.text('Boshlash'),
      );
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      expect(find.text('Asosiy g‘oya va dalil'), findsWidgets);
      expect(find.text('Qoida'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

class _GatedLoadAudioController extends FakeLessonAudioController {
  final Completer<void> _gate;
  bool loadStarted = false;

  _GatedLoadAudioController(this._gate);

  @override
  Future<void> loadAsset(String assetPath, {Duration? fallbackDuration}) async {
    loadStarted = true;
    await _gate.future;
    await super.loadAsset(assetPath, fallbackDuration: fallbackDuration);
  }
}

class _StatefulAudioPlayer implements AudioPlayer {
  bool throwOnSetAsset = false;
  bool throwOnPlay = false;
  int setAssetCalls = 0;
  int seekCalls = 0;
  int playCalls = 0;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();
  final StreamController<PlayerState> _playerStateController =
      StreamController<PlayerState>.broadcast();

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<double> get speedStream => _speedController.stream;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    setAssetCalls++;
    if (throwOnSetAsset) {
      throw PlayerException(404, 'Simulated setAsset failure', null);
    }
    const duration = Duration(seconds: 6);
    _durationController.add(duration);
    _playerStateController.add(PlayerState(false, ProcessingState.ready));
    return duration;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seekCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
    if (throwOnPlay) {
      throw PlayerException(500, 'Simulated play failure', null);
    }
    _playerStateController.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _speedController.close();
    await _playerStateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingLoadAudioPlayer implements AudioPlayer {
  int seekCalls = 0;
  int playCalls = 0;

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
    throw PlayerException(404, 'Missing asset', null);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seekCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
