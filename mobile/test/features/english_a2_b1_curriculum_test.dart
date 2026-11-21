import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/core/utils/question_option_order.dart';
import 'package:bilimyol_mobile/core/widgets/app_card.dart';
import 'package:bilimyol_mobile/data/datasources/courses_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_roadmap_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a2_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/a2_roadmap_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/b1_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/b1_roadmap_data.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/lesson_media.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/personalization/learning_start.dart';
import 'package:bilimyol_mobile/domain/personalization/route_engine.dart';
import 'package:bilimyol_mobile/features/lesson/flashcard_deck_widget.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

String _mobileRootPath() {
  final cwd = Directory.current.path;
  if (Directory('$cwd${Platform.pathSeparator}assets').existsSync()) {
    return cwd;
  }
  return '$cwd${Platform.pathSeparator}mobile';
}

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/lesson',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/lesson',
        builder: (_, _) => const InteractiveLessonScreen(),
      ),
      GoRoute(
        path: '/roadmap',
        builder: (_, _) => const Scaffold(body: Text('Roadmap')),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
    ],
  );
}

List<Question> _collectQuestions(Iterable<Lesson> lessons) {
  final seen = <String>{};
  final result = <Question>[];
  void addIfNew(Question q) {
    if (seen.add(q.id)) result.add(q);
  }

  for (final lesson in lessons) {
    for (final step in lesson.steps) {
      if (step.interactiveQuestion != null) {
        addIfNew(step.interactiveQuestion!);
      }
    }
    addIfNew(lesson.reinforcementExercise);
    if (lesson.alternateExercise != null) {
      addIfNew(lesson.alternateExercise!);
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('M3.4 English A2 & B1 Curriculum Wiring & Verification', () {
    test('combined A1+A2+B1 counts, order, entry point, and 9 QuestionModes', () {
      expect(a1LessonsData.length, 17);
      expect(a2LessonsData.length, 8);
      expect(b1LessonsData.length, 8);
      expect(a1AllFlashcards.length, 17);
      expect(a2AllFlashcards.length, 16);
      expect(b1AllFlashcards.length, 16);

      final engCourse = seedCourses.firstWhere((c) => c.id == 'course_eng_01');
      expect(engCourse.lessons.first, 'lesson_eng_listening_01');
      expect(engCourse.lessons.length, 33);
      expect(engCourse.lessons.toSet().length, 33);
      for (final id in [
        ...a1LessonsData.keys,
        ...a2LessonsData.keys,
        ...b1LessonsData.keys,
      ]) {
        expect(engCourse.lessons, contains(id));
        expect(seedLessons[id], isNotNull, reason: 'Missing $id in seedLessons');
      }

      final engNodes = seedRoadmapNodes['course_eng_01']!;
      expect(engNodes.length, 31);
      expect(a1RoadmapNodes.length, 15);
      expect(a2RoadmapNodes.length, 8);
      expect(b1RoadmapNodes.length, 8);
      for (var i = 0; i < engNodes.length; i++) {
        expect(engNodes[i].order, (i + 1).toDouble());
      }
      expect(a2RoadmapNodes.map((n) => n.order).toList(), [
        16.0,
        17.0,
        18.0,
        19.0,
        20.0,
        21.0,
        22.0,
        23.0,
      ]);
      expect(b1RoadmapNodes.map((n) => n.order).toList(), [
        24.0,
        25.0,
        26.0,
        27.0,
        28.0,
        29.0,
        30.0,
        31.0,
      ]);

      final a1Qs = _collectQuestions(a1LessonsData.values);
      final a2Qs = _collectQuestions(a2LessonsData.values);
      final b1Qs = _collectQuestions(b1LessonsData.values);
      final allEngQs = [...a1Qs, ...a2Qs, ...b1Qs];
      expect(a1Qs.length, 42);
      expect(a2Qs.length, 27);
      expect(b1Qs.length, 29);
      expect(allEngQs.map((q) => q.id).toSet().length, 98);

      final a2Modes = a2Qs.map((q) => q.mode).toSet();
      final b1Modes = b1Qs.map((q) => q.mode).toSet();
      expect(a2Modes, containsAll(QuestionMode.values));
      expect(b1Modes, containsAll(QuestionMode.values));

      final allFlashcards = [
        ...a1AllFlashcards,
        ...a2AllFlashcards,
        ...b1AllFlashcards,
      ];
      expect(allFlashcards.length, 49);
      expect(allFlashcards.map((f) => f.id).toSet().length, 49);
    });

    test('all A2 and B1 media assets resolve cleanly to non-empty files on disk', () {
      final mobileRoot = _mobileRootPath();
      final a2AssetPaths = <String>{};
      final b1AssetPaths = <String>{};

      void inspectLevel(
        Map<String, Lesson> lessons,
        List<LessonFlashcard> flashcards,
        Set<String> bucket,
        String expectedPrefix,
      ) {
        for (final lesson in lessons.values) {
          for (final step in lesson.steps) {
            final media = step.media;
            if (media != null) {
              expect(media.language, LessonMediaLanguage.en);
              expect(media.reviewStatus, LessonMediaReviewStatus.approved);
              final resolved = LessonMedia.resolveAssetPath(media.source);
              expect(resolved, isNotNull);
              expect(resolved!, startsWith(expectedPrefix));
              bucket.add(resolved);

              if (media.kind == LessonMediaKind.audio) {
                expect(media.durationSeconds ?? 0, greaterThan(0));
                expect(media.transcript?.trim().isNotEmpty, isTrue);
              }
              if (media.posterImage != null) {
                final resolvedPoster = LessonMedia.resolveAssetPath(
                  media.posterImage,
                );
                expect(resolvedPoster, isNotNull);
                expect(resolvedPoster!, startsWith(expectedPrefix));
                bucket.add(resolvedPoster);
              }
            }
          }
        }
        for (final card in flashcards) {
          if (card.audioSrc != null) {
            final resolvedAudio = LessonMedia.resolveAssetPath(card.audioSrc);
            expect(resolvedAudio, isNotNull);
            expect(resolvedAudio!, startsWith(expectedPrefix));
            bucket.add(resolvedAudio);
          }
          if (card.imageSrc != null) {
            final resolvedImage = LessonMedia.resolveAssetPath(card.imageSrc);
            expect(resolvedImage, isNotNull);
            expect(resolvedImage!, startsWith(expectedPrefix));
            bucket.add(resolvedImage);
          }
        }
      }

      inspectLevel(
        a2LessonsData,
        a2AllFlashcards,
        a2AssetPaths,
        'assets/lesson_media/english/a2/',
      );
      inspectLevel(
        b1LessonsData,
        b1AllFlashcards,
        b1AssetPaths,
        'assets/lesson_media/english/b1/',
      );

      expect(a2AssetPaths.length, 25);
      expect(b1AssetPaths.length, 26);

      for (final assetRel in [...a2AssetPaths, ...b1AssetPaths]) {
        final file = File(
          '$mobileRoot${Platform.pathSeparator}${assetRel.replaceAll('/', Platform.pathSeparator)}',
        );
        expect(file.existsSync(), isTrue, reason: 'Missing asset: $assetRel');
        expect(file.lengthSync(), greaterThan(0), reason: 'Empty asset: $assetRel');
      }
    });

    test('seedLessons permutes A2 & B1 MCQ options deterministically while raw data stays canonical', () async {
      SharedPreferences.setMockInitialValues({});
      final rawQuestions = _collectQuestions([
        ...a2LessonsData.values,
        ...b1LessonsData.values,
      ]).where((q) => q.usesOptionSelection).toList();
      expect(rawQuestions.length, 29); // 15 A2 + 14 B1

      // Raw datasources remain unpermuted (correctIndex == 0)
      for (final raw in rawQuestions) {
        expect(raw.correctIndex, 0, reason: '${raw.id} raw correctIndex');
      }

      final seedQuestions = _collectQuestions([
        for (final id in [...a2LessonsData.keys, ...b1LessonsData.keys])
          seedLessons[id]!,
      ]).where((q) => q.usesOptionSelection).toList();
      expect(seedQuestions.length, 29);

      final positions = seedQuestions.map((q) => q.correctIndex).toSet();
      expect(positions.length, greaterThanOrEqualTo(3));
      expect(
        seedQuestions.where((q) => q.correctIndex == 0).length,
        lessThan(seedQuestions.length),
      );

      final repo = InMemoryLearnerRepository();
      for (var i = 0; i < rawQuestions.length; i++) {
        final raw = rawQuestions[i];
        final permuted = seedQuestions.firstWhere((q) => q.id == raw.id);
        final rePermuted = permuteQuestionOptions(raw);

        expect(permuted.options, rePermuted.options);
        expect(permuted.correctIndex, rePermuted.correctIndex);
        expect(permuted.options[permuted.correctIndex], raw.options[0]);
        expect(permuted.options.length, 4);

        final distractors = permuted.options
            .where((opt) => opt != permuted.options[permuted.correctIndex])
            .toSet();
        expect(permuted.mistakeFeedbackByOption.keys.toSet(), distractors);

        // Verify scoring repository agrees with permuted correctIndex
        final attempt = await repo.submitAnswerAttempt(
          courseId: permuted.courseId,
          skillId: permuted.skillId,
          lessonId: 'lesson_check',
          questionId: permuted.id,
          selectedIndex: permuted.correctIndex,
          selectedAnswer: permuted.options[permuted.correctIndex],
        );
        expect(attempt.isCorrect, isTrue, reason: '${permuted.id} correct check');
      }
    });

    test('RouteEngine prerequisite locking & sequential progression across A1 -> A2 -> B1', () {
      final baseNodes = seedRoadmapNodes['course_eng_01']!;
      const highScores = <String, SkillScore>{
        'skill_eng_vocab': SkillScore(
          skillId: 'skill_eng_vocab',
          courseId: 'course_eng_01',
          score: 80,
          lastUpdated: 1,
          masteryLevel: MasteryLevel.mastered,
        ),
        'skill_eng_grammar': SkillScore(
          skillId: 'skill_eng_grammar',
          courseId: 'course_eng_01',
          score: 80,
          lastUpdated: 1,
          masteryLevel: MasteryLevel.mastered,
        ),
        'skill_eng_listening': SkillScore(
          skillId: 'skill_eng_listening',
          courseId: 'course_eng_01',
          score: 80,
          lastUpdated: 1,
          masteryLevel: MasteryLevel.mastered,
        ),
        'skill_eng_reading': SkillScore(
          skillId: 'skill_eng_reading',
          courseId: 'course_eng_01',
          score: 80,
          lastUpdated: 1,
          masteryLevel: MasteryLevel.mastered,
        ),
      };

      final initial = RouteEngine.adaptRoadmap(
        courseId: 'course_eng_01',
        baseNodes: baseNodes,
        skillScores: highScores,
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );
      expect(
        initial.nodes
            .firstWhere((n) => n.id == 'node_eng_a2_m1_directions')
            .status,
        NodeStatus.locked,
      );
      expect(
        initial.nodes
            .firstWhere((n) => n.id == 'node_eng_b1_m1_travel')
            .status,
        NodeStatus.locked,
      );

      final completed = <String>['node_eng_a1_exit'];
      for (final a2Node in a2RoadmapNodes) {
        final adapted = RouteEngine.adaptRoadmap(
          courseId: 'course_eng_01',
          baseNodes: baseNodes,
          skillScores: highScores,
          completedNodeIds: completed,
          completedReinforcementIds: const [],
        );
        expect(
          adapted.nodes.firstWhere((n) => n.id == a2Node.id).status,
          NodeStatus.available,
          reason: '${a2Node.id} should unlock after prerequisite completion',
        );
        completed.add(a2Node.id);
      }

      for (final b1Node in b1RoadmapNodes) {
        final adapted = RouteEngine.adaptRoadmap(
          courseId: 'course_eng_01',
          baseNodes: baseNodes,
          skillScores: highScores,
          completedNodeIds: completed,
          completedReinforcementIds: const [],
        );
        expect(
          adapted.nodes.firstWhere((n) => n.id == b1Node.id).status,
          NodeStatus.available,
          reason: '${b1Node.id} should unlock after prerequisite completion',
        );
        completed.add(b1Node.id);
      }
    });

    test('Multi-skill B1 lessons complete & reinforce without ArgumentError and stay isolated from Math', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      expect(usesMathMastery('course_eng_01'), isFalse);
      expect(
        usesMathMastery('course_math_01'),
        SupabaseConfig.hasRemoteConfiguration,
      );

      Future<void> passLessonAndReinforce(String lessonId) async {
        final notifier = container.read(lessonSessionNotifierProvider.notifier);
        await notifier.startLesson(lessonId);
        final lesson = container.read(lessonSessionNotifierProvider).lesson!;

        for (var i = 0; i < lesson.steps.length; i++) {
          final step = lesson.steps[i];
          final q = step.interactiveQuestion;
          if (q != null) {
            if (q.usesOptionSelection) {
              notifier.selectOption(q.correctIndex);
            } else if (q.usesTextEvaluation) {
              notifier.setTextAnswer(q.acceptedAnswers.first);
            } else if (q.mode == QuestionMode.wordMatch) {
              for (final p in q.matchPairs) {
                notifier.selectMatchLeft(p.id);
                notifier.selectMatchRight(p.right);
              }
            } else if (q.mode == QuestionMode.sentenceOrder) {
              for (final t in q.orderedTokens) {
                notifier.addOrderToken(t);
              }
            } else if (q.isSelfAssessed) {
              notifier.setTextAnswer(q.sampleResponse ?? 'Sample speaking response.');
            }
            await notifier.submitInteractiveQuiz();
          }
          if (i < lesson.steps.length - 1) {
            await notifier.nextStep();
          } else if (q?.isSelfAssessed == true) {
            await notifier.nextStep();
          }
        }

        expect(
          container.read(lessonSessionNotifierProvider).isCompleted,
          isTrue,
          reason: '$lessonId should complete cleanly',
        );

        // Also test reinforcement execution on a fresh session before completion
        await notifier.startLesson(lessonId);
        final reinf = lesson.reinforcementExercise;
        final reinfResult = await notifier.submitReinforcement(
          reinf.usesOptionSelection ? reinf.correctIndex : 0,
          selectedText: reinf.usesTextEvaluation
              ? reinf.acceptedAnswers.first
              : null,
          matchedPairs: reinf.mode == QuestionMode.wordMatch
              ? {for (final p in reinf.matchPairs) p.id: p.right}
              : null,
          orderedTokens: reinf.mode == QuestionMode.sentenceOrder
              ? reinf.orderedTokens
              : null,
        );
        expect(reinfResult, isNotNull, reason: '$lessonId reinforcement');
        expect(reinfResult!.isCorrect, isTrue, reason: '$lessonId reinf pass');
      }

      await passLessonAndReinforce('lesson_eng_b1_m1_travel');
      await passLessonAndReinforce('lesson_eng_b1_m2_work_study');
      await passLessonAndReinforce('lesson_eng_b1_m3_narrative');

      final profile = container.read(learnerStateNotifierProvider).value!;
      expect(
        profile.completedLessonIds,
        containsAll([
          'lesson_eng_b1_m1_travel',
          'lesson_eng_b1_m2_work_study',
          'lesson_eng_b1_m3_narrative',
        ]),
      );
      expect(
        profile.completedLessonIds.any((id) => id.startsWith('lesson_math_')),
        isFalse,
      );
      expect(profile.scoresByCourse['course_math_01'], isNull);
    });

    testWidgets('RoadmapScreen renders A1, A2, B1 grouped modules + B2..C2 locked tiles at 390x844 and unlocks A2 after A1 exit', (tester) async {
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
      await container
          .read(roadmapStateNotifierProvider.notifier)
          .loadRoadmap('course_eng_01');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RoadmapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify A1, A2, B1 grouped sections and B2..C2 locked tiles render cleanly
      expect(find.text('A1 — Elementar daraja'), findsOneWidget);
      expect(find.text('0 / 15'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('A2 — Boshlang‘ichdan yuqori daraja'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('A2 — Boshlang‘ichdan yuqori daraja'), findsOneWidget);
      expect(find.text('0 / 8'), findsWidgets);

      // Tapping locked A2 node displays prerequisite SnackBar
      final a2FirstNode = find.text(
        'Metro xaritasi, buyruq fe’llari, harakat predloglari va yo‘l ko‘rsatish nutq mashqi.',
      );
      await tester.scrollUntilVisible(a2FirstNode, 300, scrollable: scrollable);
      await tester.tap(a2FirstNode);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Avval oldingi bosqichni yakunlang'),
        findsOneWidget,
      );

      // Scroll to B1 & B2..C2 locked levels
      final b1FirstNode = find.text(
        'Sayohat logistikasi: Present Perfect vs Past Simple',
      );
      await tester.scrollUntilVisible(b1FirstNode, 300, scrollable: scrollable);
      expect(find.text('B1 — O‘rta daraja'), findsOneWidget);
      await tester.tap(b1FirstNode);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('C2 — Mukammal egallash darajasi'),
        300,
        scrollable: scrollable,
        maxScrolls: 80,
      );
      expect(find.text('Keyingi darajalar (B2–C2)'), findsOneWidget);
      expect(find.text('B2 — O‘rtadan yuqori daraja'), findsOneWidget);
      expect(find.text('C1 — Yuqori professional daraja'), findsOneWidget);
      expect(find.text('C2 — Mukammal egallash darajasi'), findsOneWidget);

      // Complete A1 exit node -> verify A2 unlocks on roadmap
      await container
          .read(learnerRepositoryProvider)
          .markNodeCompleted('node_eng_a1_exit', courseId: 'course_eng_01');
      await container
          .read(roadmapStateNotifierProvider.notifier)
          .loadRoadmap('course_eng_01');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('A2 — Boshlang‘ichdan yuqori daraja'),
        -300,
        scrollable: scrollable,
      );
      await tester.scrollUntilVisible(a2FirstNode, 300, scrollable: scrollable);
      final a2Card = find.ancestor(
        of: a2FirstNode,
        matching: find.byType(AppCard),
      );
      expect(a2Card, findsWidgets);
      expect(
        find.descendant(
          of: a2Card.first,
          matching: find.textContaining(RegExp(r'(Boshlash|Mashq qilish)')),
        ),
        findsOneWidget,
      );

      // Open SRS Flashcards modal and confirm all 49 cards copy
      await tester.scrollUntilVisible(
        find.text('SRS Takrorlash'),
        -500,
        scrollable: scrollable,
      );
      expect(
        find.textContaining('49 ta so‘z va iborani SRS asosida takrorlang'),
        findsOneWidget,
      );
      await tester.tap(find.text('SRS Takrorlash'));
      await tester.pumpAndSettle();
      expect(find.byType(FlashcardDeckWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('InteractiveLessonScreen evaluates A2 word_match, fill_blank, text_input & self_assessed speaking_prompt with zero overflow at 390x844', (tester) async {
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

      // 1) A2 M1 Directions: listening MCQ with distractor feedback + speaking_prompt self_assessed
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_a2_m1_directions');

      final router = _buildTestRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 (audio) -> Step 3 (flashcards) -> Step 4 (listening MCQ)
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      final qMcq = seedLessons['lesson_eng_a2_m1_directions']!
          .steps[3]
          .interactiveQuestion!;
      final wrongIdx = qMcq.correctIndex == 0 ? 1 : 0;
      final wrongText = qMcq.options[wrongIdx];
      await tester.scrollUntilVisible(find.text(wrongText), 200);
      await tester.tap(find.text(wrongText));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      expect(
        find.text(qMcq.mistakeFeedbackByOption[wrongText]!.uz),
        findsOneWidget,
      );

      // Now select correct answer and advance
      final correctText = qMcq.options[qMcq.correctIndex];
      await tester.scrollUntilVisible(find.text(correctText), 200);
      await tester.tap(find.text(correctText));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Step 5: speaking_prompt (self_assessed)
      expect(find.byKey(const Key('self_assessed_text_input')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('self_assessed_text_input')),
        'Go straight along Navoi Street and turn right at the pharmacy.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();

      final speakQ = seedLessons['lesson_eng_a2_m1_directions']!
          .steps[4]
          .interactiveQuestion!;
      expect(find.text(speakQ.sampleResponse!), findsOneWidget);
      expect(find.text(speakQ.selfAssessmentNoticeUz!), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));

      await tester.ensureVisible(find.byType(CheckboxListTile).first);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Yakunlash'));
      await tester.tap(find.text('Yakunlash'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        container.read(lessonSessionNotifierProvider).isCompleted,
        isTrue,
      );

      // 2) A2 M2 Shopping: word_match + fill_blank
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_a2_m2_shopping');
      router.go('/lesson');
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      final wmQ = seedLessons['lesson_eng_a2_m2_shopping']!
          .steps[4]
          .interactiveQuestion!;
      for (final p in wmQ.matchPairs) {
        await tester.scrollUntilVisible(find.text(p.left), 150);
        await tester.tap(find.text(p.left));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(p.right), 150);
        await tester.tap(find.text(p.right));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Step 6: fill_blank ("much")
      await tester.enterText(
        find.byKey(const Key('free_text_answer_input')),
        'much',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        container.read(lessonSessionNotifierProvider).isCompleted,
        isTrue,
      );

      // 3) B1 M3 Narrative: steps 1-3 -> step 4 MCQ -> step 5 word_match -> step 6 writing_prompt (self_assessed) + 3 rubric criteria
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_b1_m3_narrative');
      router.go('/lesson');
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      final b1M3 = seedLessons['lesson_eng_b1_m3_narrative']!;
      final b1M3Mcq = b1M3.steps[3].interactiveQuestion!;
      await tester.scrollUntilVisible(
        find.text(b1M3Mcq.options[b1M3Mcq.correctIndex]),
        150,
      );
      await tester.tap(find.text(b1M3Mcq.options[b1M3Mcq.correctIndex]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final b1M3Match = b1M3.steps[4].interactiveQuestion!;
      for (final p in b1M3Match.matchPairs) {
        await tester.scrollUntilVisible(find.text(p.left), 150);
        await tester.tap(find.text(p.left));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(p.right), 150);
        await tester.tap(find.text(p.right));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('self_assessed_text_input')),
        'While I was preparing the presentation, the electricity went out. Eventually, we saved everything.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();

      final writeQ = b1M3.steps[5].interactiveQuestion!;
      expect(find.text(writeQ.sampleResponse!), findsOneWidget);
      expect(find.text(writeQ.selfAssessmentNoticeUz!), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('InteractiveLessonScreen evaluates A2 sentence_order & text_input and B1 error_correction & conversation_completion', (tester) async {
      SharedPreferences.setMockInitialValues({});
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

      final router = _buildTestRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // A2 M3 Plans: step 5 conversation_completion + step 6 text_input
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_a2_m3_plans');
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      final convQ = seedLessons['lesson_eng_a2_m3_plans']!
          .steps[4]
          .interactiveQuestion!;
      final convCorrect = convQ.options[convQ.correctIndex];
      await tester.scrollUntilVisible(find.text(convCorrect), 150);
      await tester.tap(find.text(convCorrect));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('free_text_answer_input')),
        "I'm going to visit my grandmother on Sunday.",
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        container.read(lessonSessionNotifierProvider).isCompleted,
        isTrue,
      );

      // A2 Exit: step 1 audio -> step 2 listen MCQ -> step 3 read MCQ -> step 4 fill_blank -> step 5 sentence_order
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_a2_exit');
      router.go('/lesson');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keyingi qadam'));
      await tester.pumpAndSettle();

      final a2ExitLesson = seedLessons['lesson_eng_a2_exit']!;
      // Step 2: listen MCQ
      final exitQ2 = a2ExitLesson.steps[1].interactiveQuestion!;
      await tester.scrollUntilVisible(
        find.text(exitQ2.options[exitQ2.correctIndex]),
        150,
      );
      await tester.tap(find.text(exitQ2.options[exitQ2.correctIndex]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Step 3: read MCQ
      final exitQ3 = a2ExitLesson.steps[2].interactiveQuestion!;
      await tester.scrollUntilVisible(
        find.text(exitQ3.options[exitQ3.correctIndex]),
        150,
      );
      await tester.tap(find.text(exitQ3.options[exitQ3.correctIndex]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Step 4: fill_blank ("visited")
      await tester.enterText(
        find.byKey(const Key('free_text_answer_input')),
        'visited',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Step 5: sentence_order ("Can we meet before the train leaves?")
      final orderQ = a2ExitLesson.steps[4].interactiveQuestion!;
      for (final tok in orderQ.orderedTokens) {
        final chip = find.widgetWithText(ActionChip, tok);
        await tester.scrollUntilVisible(chip.first, 150);
        await tester.tap(chip.first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        container.read(lessonSessionNotifierProvider).isCompleted,
        isTrue,
      );

      // B1 M2 Work & Study: steps 1-3 -> step 4 MCQ -> step 5 fill_blank ("do not have" / "don't have")
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_b1_m2_work_study');
      router.go('/lesson');
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      final b1M2 = seedLessons['lesson_eng_b1_m2_work_study']!;
      final b1M2Mcq = b1M2.steps[3].interactiveQuestion!;
      await tester.scrollUntilVisible(
        find.text(b1M2Mcq.options[b1M2Mcq.correctIndex]),
        150,
      );
      await tester.tap(find.text(b1M2Mcq.options[b1M2Mcq.correctIndex]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final b1M2Fill = b1M2.steps[4].interactiveQuestion!;
      await tester.enterText(
        find.byKey(const Key('free_text_answer_input')),
        b1M2Fill.acceptedAnswers.first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        container.read(lessonSessionNotifierProvider).isCompleted,
        isTrue,
      );

      // B1 M2 error_correction reinforcement via ReinforcementSheet
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_b1_m2_work_study');
      router.go('/lesson');
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      final wrongB1McqIdx = b1M2Mcq.correctIndex == 0 ? 1 : 0;
      await tester.scrollUntilVisible(
        find.text(b1M2Mcq.options[wrongB1McqIdx]),
        150,
      );
      await tester.tap(find.text(b1M2Mcq.options[wrongB1McqIdx]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();

      final errQ = b1M2.reinforcementExercise;
      expect(errQ.mode, QuestionMode.errorCorrection);
      await tester.ensureVisible(find.text('Mavzuni mustahkamlash'));
      await tester.tap(find.text('Mavzuni mustahkamlash'));
      await tester.pumpAndSettle();
      final errCorrect = errQ.options[errQ.correctIndex];
      await tester.ensureVisible(find.text(errCorrect));
      await tester.tap(find.text(errCorrect));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Javobni Tekshirish'));
      await tester.tap(find.text('Javobni Tekshirish'));
      await tester.pumpAndSettle();
      expect(find.text('Ajoyib Natija!'), findsOneWidget);
      await tester.ensureVisible(find.text('Dashboardga O‘tish'));
      await tester.tap(find.text('Dashboardga O‘tish'));
      await tester.pumpAndSettle();

      // B1 M4 Decisions: step 4 conversation_completion
      await container
          .read(lessonSessionNotifierProvider.notifier)
          .startLesson('lesson_eng_b1_m4_decisions');
      router.go('/lesson');
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
      }
      final b1M4Conv = seedLessons['lesson_eng_b1_m4_decisions']!
          .steps[3]
          .interactiveQuestion!;
      expect(b1M4Conv.mode, QuestionMode.conversationCompletion);
      final b1M4Correct = b1M4Conv.options[b1M4Conv.correctIndex];
      await tester.scrollUntilVisible(find.text(b1M4Correct), 150);
      await tester.tap(find.text(b1M4Correct));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEKSHIRISH'));
      await tester.pumpAndSettle();
      expect(find.text('To‘g‘ri javob!'), findsOneWidget);
      expect(
        container.read(lessonSessionNotifierProvider).currentStepIndex,
        4,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('FlashcardDeckWidget standalone SRS with 49 A1-B1 cards displays A2/B1 IPA, re-queues, and persists', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final all49 = [
        ...a1AllFlashcards,
        ...a2AllFlashcards,
        ...b1AllFlashcards,
      ];
      final a2B1Pool = [...a2AllFlashcards, ...b1AllFlashcards];
      final fakeAudio = FakeLessonAudioController();

      final container = ProviderContainer(
        overrides: [
          lessonAudioControllerFactoryProvider.overrideWithValue(() => fakeAudio),
        ],
      );
      addTearDown(container.dispose);
      await container.read(learnerStateNotifierProvider.notifier).loadProfile();

      // First verify full 49-card standalone SRS deck counter
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FlashcardDeckWidget(
                  key: const ValueKey('full_49_srs_deck'),
                  flashcards: all49,
                  allCourseFlashcards: all49,
                  courseId: 'course_eng_01',
                  standaloneSrsMode: true,
                  audioController: fakeAudio,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Flashcard • 0/49'), findsOneWidget);

      // Now verify A2/B1 cards directly (BrE + AmE IPA, re-queue, and persistence)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FlashcardDeckWidget(
                  key: const ValueKey('a2_b1_srs_deck'),
                  flashcards: a2B1Pool,
                  allCourseFlashcards: a2B1Pool,
                  courseId: 'course_eng_01',
                  standaloneSrsMode: true,
                  audioController: fakeAudio,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First card in A2 is 'turn left' with BrE /tɜːn left/ and AmE /tɜːrn left/
      expect(find.text('turn left'), findsOneWidget);
      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      expect(find.text('chapga burilmoq'), findsOneWidget);
      expect(find.textContaining('/tɜːn left/'), findsOneWidget);
      expect(find.textContaining('/tɜːrn left/'), findsOneWidget);

      // Tap "Yana mashq qilaman" -> re-queues 'turn left' and advances to 'go past'
      await tester.tap(find.text('Yana mashq qilaman'));
      await tester.pumpAndSettle();
      expect(find.text('go past'), findsOneWidget);

      // Reveal 'go past' and tap "Eslab qoldim" -> persists in profile
      await tester.tap(find.text('Javobni ko‘rish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslab qoldim'));
      await tester.pumpAndSettle();

      final profile = container.read(learnerStateNotifierProvider).value!;
      final srs = profile.flashcardSrsByCourse['course_eng_01']!;
      expect(srs['fc_eng_a2_m1_1']?.status, 'need_practice');
      expect(srs['fc_eng_a2_m1_2']?.status, 'remembered');
      expect(profile.flashcardSrsByCourse['course_math_01'], isNull);

      // Verify jsonDecode / persistence round-trip
      final prefs = await SharedPreferences.getInstance();
      final savedRaw =
          prefs.getString(LocalStorageService.demoLearnerSnapshotKey) ??
          prefs.getString('bilimyol_demo_progress_v1');
      expect(savedRaw, isNotNull);
      final decoded = jsonDecode(savedRaw!) as Map<String, dynamic>;
      expect(decoded['profile'], isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
