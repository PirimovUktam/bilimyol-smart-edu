import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/personalization/learning_start.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_lesson_answer_use_case.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    demoSessionActive.value = false;
  });

  group('M6.1.2 Regression: course_eng_01 roadmap refresh', () {
    test(
      'completing lesson_eng_grammar_01 refreshes roadmapStateNotifierProvider while usesMathMastery remains false',
      () async {
        expect(usesMathMastery('course_eng_01'), isFalse);
        SupabaseConfig.hasRemoteConfiguration = true;
        try {
          expect(usesMathMastery('course_eng_01'), isFalse);
        } finally {
          SupabaseConfig.hasRemoteConfiguration = false;
        }

        final learnerRepo = InMemoryLearnerRepository();
        await learnerRepo.markNodeCompleted(
          'node_eng_a1_m2_sentence_builder',
          courseId: 'course_eng_01',
        );
        final profile = await learnerRepo.getProfile();
        await learnerRepo.updateProfile(
          profile.copyWith(selectedCourseId: 'course_eng_01'),
        );

        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(learnerRepo),
            lessonRepositoryProvider.overrideWithValue(
              InMemoryLessonRepository(),
            ),
            courseRepositoryProvider.overrideWithValue(
              InMemoryCourseRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(roadmapStateNotifierProvider.notifier)
            .loadRoadmap('course_eng_01');
        final beforeNodes =
            container.read(roadmapStateNotifierProvider).value?.nodes ??
            const <LearningPathNode>[];
        expect(
          beforeNodes
              .firstWhere((n) => n.id == 'node_eng_a1_m2_daily_life')
              .status,
          NodeStatus.locked,
        );

        final lessonNotifier = container.read(
          lessonSessionNotifierProvider.notifier,
        );
        await lessonNotifier.startLesson('lesson_eng_grammar_01');
        await lessonNotifier.nextStep();
        await lessonNotifier.nextStep();
        lessonNotifier.selectOption(0);
        await lessonNotifier.submitInteractiveQuiz();

        expect(
          container.read(lessonSessionNotifierProvider).isCompleted,
          isTrue,
        );
        final afterNodes =
            container.read(roadmapStateNotifierProvider).value?.nodes ??
            const <LearningPathNode>[];
        expect(
          afterNodes
              .firstWhere((n) => n.id == 'node_eng_gram')
              .status,
          NodeStatus.completed,
        );
        expect(
          afterNodes
              .firstWhere((n) => n.id == 'node_eng_a1_m2_daily_life')
              .status,
          isNot(NodeStatus.locked),
        );
      },
    );

    testWidgets(
      'RoadmapScreen unlocks downstream A1 node after context.push(/lesson) -> complete -> context.go(/roadmap)',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          demoSessionActive.value = false;
          appRouter.go('/welcome');
        });

        final learnerRepo = InMemoryLearnerRepository();
        await learnerRepo.saveSkillScores('course_eng_01', {
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
            score: 70,
            lastUpdated: 1,
            masteryLevel: MasteryLevel.proficient,
          ),
          'skill_eng_listening': const SkillScore(
            skillId: 'skill_eng_listening',
            courseId: 'course_eng_01',
            score: 70,
            lastUpdated: 1,
            masteryLevel: MasteryLevel.proficient,
          ),
        });
        await learnerRepo.markNodeCompleted(
          'node_eng_a1_m2_sentence_builder',
          courseId: 'course_eng_01',
        );
        final profile = await learnerRepo.getProfile();
        await learnerRepo.updateProfile(
          profile.copyWith(selectedCourseId: 'course_eng_01'),
        );

        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(learnerRepo),
            lessonAudioControllerFactoryProvider.overrideWithValue(
              () => FakeLessonAudioController(),
            ),
          ],
        );
        addTearDown(container.dispose);

        demoSessionActive.value = true;
        await container.read(courseStateNotifierProvider.notifier).init();
        await container
            .read(roadmapStateNotifierProvider.notifier)
            .loadRoadmap('course_eng_01');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        appRouter.go('/roadmap');
        await tester.pumpAndSettle();

        expect(find.byType(RoadmapScreen), findsOneWidget);

        final downstreamTitle = find.text('Present Simple: Bo‘sh joyni to‘ldirish');
        await tester.scrollUntilVisible(downstreamTitle, 200);
        expect(downstreamTitle, findsOneWidget);
        final downstreamColumnBefore = find
            .ancestor(of: downstreamTitle, matching: find.byType(Column))
            .first;
        expect(
          find.descendant(
            of: downstreamColumnBefore,
            matching: find.text('Boshlash'),
          ),
          findsNothing,
        );

        final grammarTitle = find.text('Grammar');
        await tester.scrollUntilVisible(grammarTitle, -200);
        expect(grammarTitle, findsOneWidget);
        final grammarColumn = find
            .ancestor(of: grammarTitle, matching: find.byType(Column))
            .first;
        final grammarStart = find.descendant(
          of: grammarColumn,
          matching: find.text('Boshlash'),
        );
        await tester.ensureVisible(grammarStart);
        await tester.tap(grammarStart);
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveLessonScreen), findsOneWidget);

        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keyingi qadam'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('does'));
        await tester.pump();
        await tester.tap(find.text('TEKSHIRISH'));
        await tester.pumpAndSettle();

        expect(find.byType(RoadmapScreen), findsOneWidget);

        await tester.scrollUntilVisible(downstreamTitle, 200);
        final downstreamColumnAfter = find
            .ancestor(of: downstreamTitle, matching: find.byType(Column))
            .first;
        expect(
          find.descendant(
            of: downstreamColumnAfter,
            matching: find.text('Boshlash'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('M6.1.2 Regression: Starter free-text input-specific feedback', () {
    final starterQuestion = seedLessons['lesson_eng_starter']!
        .steps
        .firstWhere((s) => s.interactiveQuestion?.id == 'q_lesson_eng_starter_quiz')
        .interactiveQuestion!;

    test(
      'SubmitLessonAnswerUseCase returns input-specific feedback for Goodbye/Hello in uz & ru and preserves fallback for Sam',
      () async {
        final useCase = SubmitLessonAnswerUseCase(InMemoryLearnerRepository());

        final goodbyeUz = await useCase.execute(
          question: starterQuestion,
          lessonId: 'lesson_eng_starter',
          selectedText: 'Goodbye',
          uiLocale: 'uz',
        );
        expect(goodbyeUz.isCorrect, isFalse);
        expect(goodbyeUz.optionFeedback, contains('«Goodbye» xayrlashuv so‘zi'));

        final byeRu = await useCase.execute(
          question: starterQuestion,
          lessonId: 'lesson_eng_starter',
          selectedText: '  BYE! ',
          uiLocale: 'ru',
        );
        expect(byeRu.isCorrect, isFalse);
        expect(byeRu.optionFeedback, contains('«Goodbye» означает прощание'));

        final helloUz = await useCase.execute(
          question: starterQuestion,
          lessonId: 'lesson_eng_starter',
          selectedText: 'Hello',
          uiLocale: 'uz',
        );
        expect(helloUz.isCorrect, isFalse);
        expect(helloUz.optionFeedback, contains('Salomlashish to‘g‘ri'));

        final helloRu = await useCase.execute(
          question: starterQuestion,
          lessonId: 'lesson_eng_starter',
          selectedText: 'Hi!',
          uiLocale: 'ru',
        );
        expect(helloRu.isCorrect, isFalse);
        expect(helloRu.optionFeedback, contains('Приветствие верное'));

        final samUz = await useCase.execute(
          question: starterQuestion,
          lessonId: 'lesson_eng_starter',
          selectedText: 'Sam',
          uiLocale: 'uz',
        );
        expect(samUz.isCorrect, isFalse);
        expect(samUz.optionFeedback, isNull);
        expect(
          starterQuestion.localizedWrongFeedback('uz'),
          contains('Faqat ism yoki xayrlashuv so‘zini yozmang'),
        );
      },
    );

    test(
      'DemoAITutorService.explainMistake surfaces Goodbye/Hello input-specific explanation in uz & ru',
      () async {
        final tutor = DemoAITutorService();

        final goodbyeUz = await tutor.explainMistake(
          const AIExplanationRequest(
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            questionId: 'q_lesson_eng_starter_quiz',
            questionText: "What's your name?",
            selectedOption: 'Goodbye',
            correctOption: "I'm Sam",
            language: 'uz',
            lessonId: 'lesson_eng_starter',
          ),
        );
        expect(goodbyeUz.explanation, contains('«Goodbye» xayrlashuv so‘zi'));

        final goodbyeRu = await tutor.explainMistake(
          const AIExplanationRequest(
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            questionId: 'q_lesson_eng_starter_quiz',
            questionText: "What's your name?",
            selectedOption: 'Good bye',
            correctOption: "I'm Sam",
            language: 'ru',
            lessonId: 'lesson_eng_starter',
          ),
        );
        expect(goodbyeRu.explanation, contains('«Goodbye» означает прощание'));

        final helloUz = await tutor.explainMistake(
          const AIExplanationRequest(
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            questionId: 'q_lesson_eng_starter_quiz',
            questionText: "What's your name?",
            selectedOption: 'Hello',
            correctOption: "I'm Sam",
            language: 'uz',
            lessonId: 'lesson_eng_starter',
          ),
        );
        expect(helloUz.explanation, contains('Salomlashish to‘g‘ri'));

        final samUz = await tutor.explainMistake(
          const AIExplanationRequest(
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            questionId: 'q_lesson_eng_starter_quiz',
            questionText: "What's your name?",
            selectedOption: 'Sam',
            correctOption: "I'm Sam",
            language: 'uz',
            lessonId: 'lesson_eng_starter',
          ),
        );
        expect(
          samUz.explanation,
          contains('Faqat ism yoki xayrlashuv so‘zini yozmang'),
        );
      },
    );
  });
}
