import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/core/theme/app_semantic_colors.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/core/widgets/bilimyol_bottom_nav.dart';
import 'package:bilimyol_mobile/core/widgets/friendly_error_state.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/supabase_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/course.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/placement_session.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_placement_test_use_case.dart';
import 'package:bilimyol_mobile/features/ai_tutor/ai_tutor_screen.dart';
import 'package:bilimyol_mobile/features/ai_tutor/yolchi_bubble.dart';
import 'package:bilimyol_mobile/features/auth/welcome_screen.dart';
import 'package:bilimyol_mobile/features/course_selection/course_selection_screen.dart';
import 'package:bilimyol_mobile/features/knowledge_map/knowledge_map_screen.dart';
import 'package:bilimyol_mobile/features/lesson/audio_sim_wave_widget.dart';
import 'package:bilimyol_mobile/features/onboarding/onboarding_screen.dart';
import 'package:bilimyol_mobile/features/placement/placement_test_screen.dart';
import 'package:bilimyol_mobile/features/profile/profile_screen.dart';
import 'package:bilimyol_mobile/features/progress/progress_screen.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

bool _fontsLoaded = false;

Future<void> _ensureReadableFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final segoe = File(r'C:\Windows\Fonts\segoeui.ttf');
  if (segoe.existsSync()) {
    final bytes = await segoe.readAsBytes();
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  final consola = File(r'C:\Windows\Fonts\consola.ttf');
  if (consola.existsSync()) {
    final bytes = await consola.readAsBytes();
    final loader = FontLoader('JetBrains Mono')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  final materialIcons = File(
    r'C:\Users\user\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  );
  if (materialIcons.existsSync()) {
    final bytes = await materialIcons.readAsBytes();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> _maybeCapturePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String fileName,
) async {
  final renderDir = Platform.environment['BILIMYOL_RENDER_DIR'];
  if (renderDir == null || renderDir.trim().isEmpty) return;
  await tester.runAsync(() async {
    await _ensureReadableFonts();
    final dir = Directory(renderDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final outFile = File('${dir.path}${Platform.pathSeparator}$fileName');
    await outFile.writeAsBytes(byteData.buffer.asUint8List());
  });
}

double _relativeLuminance(Color color) {
  double linearize(double channel) => channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linearize(color.r) +
      0.7152 * linearize(color.g) +
      0.0722 * linearize(color.b);
}

double _contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

class _ActivityRepo extends InMemoryLearnerRepository {
  final List<DailyActivitySummary> entries;
  bool failActivity;
  final bool forceEmpty;

  _ActivityRepo({
    this.entries = const [],
    this.failActivity = false,
    this.forceEmpty = false,
  });

  @override
  Future<List<DailyActivitySummary>> getDailyActivity([int days = 7]) async {
    if (failActivity) {
      throw StateError('Activity fetch failed');
    }
    if (forceEmpty) {
      return const [];
    }
    if (entries.isNotEmpty) {
      return entries.take(days).toList();
    }
    return super.getDailyActivity(days);
  }
}

class _FailingPlacementRepo extends InMemoryLearnerRepository {
  bool failSavePlacement;

  _FailingPlacementRepo({this.failSavePlacement = true});

  @override
  Future<String> savePlacementAttempt(PlacementAttemptData data) async {
    if (failSavePlacement) {
      throw StateError('Placement save failed');
    }
    return super.savePlacementAttempt(data);
  }
}

class _FailingProfileRepo extends InMemoryLearnerRepository {
  bool failGetProfile;

  _FailingProfileRepo({this.failGetProfile = true});

  @override
  Future<LearnerProfile> getProfile() async {
    if (failGetProfile) {
      throw StateError('Profile load failed');
    }
    return super.getProfile();
  }
}

class _FailingRoadmapLessonRepo extends InMemoryLessonRepository {
  bool failRoadmap;

  _FailingRoadmapLessonRepo({this.failRoadmap = true});

  @override
  Future<List<LearningPathNode>> getBaseRoadmapNodes(String courseId) async {
    if (failRoadmap) {
      throw StateError('Roadmap load failed');
    }
    if (SupabaseConfig.hasRemoteConfiguration) {
      return List.of(seedRoadmapNodes[courseId] ?? const []);
    }
    return super.getBaseRoadmapNodes(courseId);
  }
}

class _SlowCourseRepo extends InMemoryCourseRepository {
  final Completer<List<Course>> completer = Completer<List<Course>>();

  @override
  Future<List<Course>> getAllCourses() => completer.future;
}

class _ErrorCourseRepo extends InMemoryCourseRepository {
  final bool emptyMode;

  _ErrorCourseRepo({this.emptyMode = false});

  @override
  Future<List<Course>> getAllCourses() async {
    if (emptyMode) return const [];
    throw StateError('Course load error');
  }
}

class _ControllableTutorService implements IAITutorService {
  int calls = 0;
  bool failNext = false;
  Completer<void>? gate;

  @override
  Future<AIExplanationResponse> explainMistake(
    AIExplanationRequest request,
  ) => DemoAITutorService().explainMistake(request);

  @override
  Future<GeneratedLessonResponse> generateLesson(
    GenerateLessonRequest request,
  ) => DemoAITutorService().generateLesson(request);

  @override
  Future<AskTutorResponse> askTutor(AskTutorRequest request) async {
    calls++;
    if (gate != null) {
      await gate!.future;
    }
    if (failNext) {
      failNext = false;
      throw const AITutorUnavailableException('Offline sinov xatosi');
    }
    return DemoAITutorService().askTutor(request);
  }
}

Widget _wrapScreen({
  required ProviderContainer container,
  required Widget child,
  required bool isDark,
  required String localeCode,
  double textScale = 1.0,
  double viewInsetsBottom = 0,
  bool disableAnimations = false,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(localeCode),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: AppStrings.localizationsDelegates,
      builder: (context, widgetChild) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
            viewInsets: mq.viewInsets.copyWith(bottom: viewInsetsBottom),
          ),
          child: widgetChild!,
        );
      },
      home: child,
    ),
  );
}

void main() {
  group('Milestone M3: Tour Assets, Core Hooks, Remaining 8 Routes & Renders', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      productTourCompleted.value = false;
      demoSessionActive.value = false;
      activeSessionHasStartedCourse.value = false;
    });

    test('LearnerStateNotifier.updateDisplayName trims, rejects empty, and persists across reload', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.load();
      final repo1 = InMemoryLearnerRepository(storage: storage);
      final container1 = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          learnerRepositoryProvider.overrideWithValue(repo1),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container1.dispose);

      await container1.read(learnerStateNotifierProvider.notifier).loadProfile();
      await expectLater(
        () => container1
            .read(learnerStateNotifierProvider.notifier)
            .updateDisplayName('   '),
        throwsArgumentError,
      );

      await container1
          .read(learnerStateNotifierProvider.notifier)
          .updateDisplayName('  Dilnoza Karimova  ');
      expect(
        container1.read(learnerStateNotifierProvider).value?.name,
        'Dilnoza Karimova',
      );

      final repo2 = InMemoryLearnerRepository(storage: storage);
      final restored = await repo2.getProfile();
      expect(restored.name, 'Dilnoza Karimova');
    });

    test('AppStrings M3 uz/ru alignment has no English leftovers and aligns tourReplayAction', () {
      expect(AppStrings.ru.tourReplayAction, 'Повторить обзор');
      for (final s in [AppStrings.uz, AppStrings.ru]) {
        expect(s.navRoadmap, isNot('Roadmap'));
        expect(s.demoReset, isNot('Reset'));
        expect(s.speakerDefault, isNot('Speaker'));
        expect(s.masteryLabel(20), isNotEmpty);
        expect(s.masteryLabel(45), isNotEmpty);
        expect(s.masteryLabel(68), isNotEmpty);
        expect(s.masteryLabel(88), isNotEmpty);
        expect(s.aiTutorQuickPrompts.length, 3);
      }
    });

    testWidgets('Tour PNG assets load via rootBundle and render in WelcomeScreen Light/Dark', (tester) async {
      for (final asset in [
        'assets/tour/tour_1_start.png',
        'assets/tour/tour_2_lesson.png',
        'assets/tour/tour_3_growth.png',
      ]) {
        final data = await rootBundle.load(asset);
        expect(data.lengthInBytes, greaterThan(10000));
      }

      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final isDark in [false, true]) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _wrapScreen(
            container: container,
            isDark: isDark,
            localeCode: 'uz',
            child: WelcomeScreen(key: ValueKey('tour-assets-$isDark')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(AppStrings.uz.tourNext));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(AppStrings.uz.tourNext));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('All 8 M3 routes fit 360dp @ 2.0x in uz & ru, Light & Dark with zero overflow and reduced motion', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final today = DateTime.now();
      final monthActivity = List.generate(30, (i) {
        final d = today.subtract(Duration(days: 29 - i));
        final iso =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return DailyActivitySummary(
          date: iso,
          activeMinutes: i % 3 == 0 ? 45 : 20,
          xpEarned: 20,
          lessonsCompleted: 1,
        );
      });

      for (final isDark in [false, true]) {
        for (final code in ['uz', 'ru']) {
          final repo = _ActivityRepo(entries: monthActivity);
          final container = ProviderContainer(
            overrides: [
              learnerRepositoryProvider.overrideWithValue(repo),
              courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
              lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
            ],
          );
          addTearDown(container.dispose);

          await container.read(courseStateNotifierProvider.notifier).init();
          await container
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_math_01');
          await container
              .read(learnerStateNotifierProvider.notifier)
              .seedQuickDemo();

          final screens = <Widget>[
            const CourseSelectionScreen(),
            const OnboardingScreen(),
            const PlacementTestScreen(),
            const KnowledgeMapScreen(),
            const RoadmapScreen(),
            const ProgressScreen(),
            const AITutorScreen(),
            const ProfileScreen(),
          ];

          for (final screen in screens) {
            await tester.pumpWidget(
              _wrapScreen(
                container: container,
                isDark: isDark,
                localeCode: code,
                textScale: 2.0,
                disableAnimations: true,
                child: KeyedSubtree(
                  key: ValueKey('${screen.runtimeType}-$isDark-$code'),
                  child: screen,
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType} threw at 360dp 2.0x $code dark=$isDark',
            );
            expect(find.text('Roadmap'), findsNothing);
            expect(find.text('Reset'), findsNothing);
            expect(find.text('Speaker'), findsNothing);
          }

          // Also verify ProgressScreen month view at 360dp 2.0x
          await tester.pumpWidget(
            _wrapScreen(
              container: container,
              isDark: isDark,
              localeCode: code,
              textScale: 2.0,
              disableAnimations: true,
              child: ProgressScreen(key: ValueKey('progress-month-$isDark-$code')),
            ),
          );
          await tester.pumpAndSettle();
          final s = AppStrings.forCode(code);
          await tester.tap(find.text(s.timeframeWeek));
          await tester.pumpAndSettle();
          expect(find.text(s.timeframeMonth), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('Catalog, Onboarding, Placement & KnowledgeMap cover empty/error/audio/math-pilot/result states', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Catalog empty state
      final emptyContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
          courseRepositoryProvider.overrideWithValue(_ErrorCourseRepo(emptyMode: true)),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(emptyContainer.dispose);
      await emptyContainer.read(courseStateNotifierProvider.notifier).init();
      await tester.pumpWidget(
        _wrapScreen(
          container: emptyContainer,
          isDark: true,
          localeCode: 'uz',
          child: const CourseSelectionScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.uz.coursesEmptyTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2. Placement null-course guard -> chooses courses
      final noCourseRepo = InMemoryLearnerRepository();
      final defaultProfile = await noCourseRepo.getProfile();
      await noCourseRepo.updateProfile(
        defaultProfile.copyWith(selectedCourseId: ''),
      );
      final noCourseContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(noCourseRepo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(noCourseContainer.dispose);
      await noCourseContainer.read(courseStateNotifierProvider.notifier).init();
      await tester.pumpWidget(
        _wrapScreen(
          container: noCourseContainer,
          isDark: false,
          localeCode: 'uz',
          child: const PlacementTestScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.uz.chooseSubjectFirstPrompt), findsOneWidget);
      expect(find.text(AppStrings.uz.chooseSubject), findsOneWidget);

      // 3. Placement audioSimText question + result summary screen
      final engContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(engContainer.dispose);
      await engContainer.read(courseStateNotifierProvider.notifier).init();
      await engContainer
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      final placementNotifier =
          engContainer.read(placementStateNotifierProvider.notifier);
      await placementNotifier.loadQuestions('course_eng_01');
      await tester.pumpWidget(
        _wrapScreen(
          container: engContainer,
          isDark: true,
          localeCode: 'uz',
          child: const PlacementTestScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final audioQ = const Question(
        id: 'audio_test_q',
        courseId: 'course_eng_01',
        skillId: 'eng_listening',
        text: 'Audio matndan asosiy fikrni tanlang.',
        options: ['Birinçi javob', 'Ikkinçi javob'],
        correctIndex: 0,
        explanation: 'Audio izohi',
        difficulty: QuestionDifficulty.easy,
        audioSimText: 'Hello, welcome to BilimYöl!',
        audioSimSpeaker: 'Teacher',
      );
      placementNotifier.state = placementNotifier.state.copyWith(
        currentQuestion: audioQ,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AudioSimWaveWidget), findsOneWidget);

      placementNotifier.state = placementNotifier.state.copyWith(
        result: AssessmentResult(
          assessmentId: 'a1',
          courseId: 'course_eng_01',
          submissions: const [
            QuestionAnswerSubmission(
              questionId: 'q1',
              selectedIndex: 0,
              isCorrect: true,
              timeSpentSeconds: 4,
            ),
            QuestionAnswerSubmission(
              questionId: 'q2',
              selectedIndex: 1,
              isCorrect: false,
              timeSpentSeconds: 6,
            ),
          ],
          computedScores: {
            'eng_grammar': const SkillScore(
              skillId: 'eng_grammar',
              courseId: 'course_eng_01',
              score: 82,
              lastUpdated: 1000,
              masteryLevel: MasteryLevel.mastered,
            ),
            'eng_vocab': const SkillScore(
              skillId: 'eng_vocab',
              courseId: 'course_eng_01',
              score: 38,
              lastUpdated: 1000,
              masteryLevel: MasteryLevel.needsRemediation,
            ),
          },
          weakestSkillId: 'eng_vocab',
          timestamp: 1000,
          review: const [
            PlacementReview(
              submission: QuestionAnswerSubmission(
                questionId: 'q1',
                selectedIndex: 0,
                isCorrect: true,
                timeSpentSeconds: 4,
              ),
              question: 'Choose the verb',
              selected: 'go',
              correct: 'go',
              explanation: 'Simple present tense.',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.uz.placementDoneTitle), findsOneWidget);
      expect(find.text(AppStrings.uz.skillBreakdownTitle), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AITutorScreen shows all 3 chips, keeps typing Semantics, handles keyboard & offline retry', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tutorService = _ControllableTutorService()..failNext = true;
      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          aiTutorServiceProvider.overrideWithValue(tutorService),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapScreen(
          container: container,
          isDark: true,
          localeCode: 'uz',
          viewInsetsBottom: 0,
          disableAnimations: true,
          child: const AITutorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      for (final chip in AppStrings.uz.aiTutorQuickPrompts) {
        expect(find.text(chip), findsOneWidget);
      }

      // Tap 3rd chip -> fails first -> Retry recovers cleanly
      await tester.tap(find.text(AppStrings.uz.aiTutorQuickPrompts[2]));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.uz.retry), findsOneWidget);

      await tester.tap(find.text(AppStrings.uz.retry));
      await tester.pumpAndSettle();
      expect(tutorService.calls, 2);
      expect(find.textContaining('savolingiz juda yaxşi'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify typing indicator Semantics label while request pending
      tutorService.gate = Completer<void>();
      await tester.enterText(find.byType(TextField), '2x + 4 = 10?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      expect(find.bySemanticsLabel('Yölçi AI yozmoqda...'), findsOneWidget);
      tutorService.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify keyboard open hides chips and has zero overflow on tight viewports
      for (final viewport in [
        const Size(360, 640),
        const Size(360, 800),
      ]) {
        tester.view.physicalSize = viewport * 2.0;
        tester.view.devicePixelRatio = 2.0;
        for (final scale in [1.0, 2.0]) {
          if (viewport.height == 800 && scale == 1.0) continue;
          for (final code in ['uz', 'ru']) {
            await tester.pumpWidget(
              _wrapScreen(
                container: container,
                isDark: true,
                localeCode: code,
                textScale: scale,
                viewInsetsBottom: 300,
                disableAnimations: true,
                child: KeyedSubtree(
                  key: ValueKey('kb-${viewport.height}-$scale-$code'),
                  child: const AITutorScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            for (final chip in AppStrings.forCode(code).aiTutorQuickPrompts) {
              expect(find.text(chip), findsNothing);
            }
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'AITutorScreen overflowed with keyboard open at ${viewport.width}x${viewport.height} @ ${scale}x ($code)',
            );
          }
        }
      }
    });

    testWidgets('ProfileScreen edits name, switches uz/ru & Light/Dark, and replays Product Tour preserving XP', (tester) async {
      SharedPreferences.setMockInitialValues({'bilimyol.product_tour_completed': true});
      final storage = await LocalStorageService.load();
      demoSessionActive.value = true;
      productTourCompleted.value = true;

      final repo = InMemoryLearnerRepository(storage: storage);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          learnerRepositoryProvider.overrideWithValue(repo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_math_01');
      await container.read(learnerStateNotifierProvider.notifier).seedQuickDemo();

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/welcome',
            builder: (_, state) => WelcomeScreen(
              isReplay: state.uri.queryParameters['replay'] == '1',
            ),
          ),
          GoRoute(
            path: '/courses',
            builder: (_, _) => const CourseSelectionScreen(),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final settings = ref.watch(appSettingsProvider);
              return MaterialApp.router(
                routerConfig: router,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: settings.themeMode,
                locale: settings.locale,
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Edit name
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Azizbek');
      await tester.tap(find.text(AppStrings.uz.save));
      await tester.pumpAndSettle();
      expect(find.text('Azizbek'), findsOneWidget);
      expect(container.read(learnerStateNotifierProvider).value?.name, 'Azizbek');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // 2. Toggle Dark mode
      await tester.ensureVisible(find.text(AppStrings.uz.themeDark));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.uz.themeDark));
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);

      // 3. Switch to Russian
      await tester.ensureVisible(find.text(AppStrings.uz.languageRu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.uz.languageRu));
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).localeCode, 'ru');
      expect(find.text(AppStrings.ru.myProfile), findsOneWidget);
      expect(find.text(AppStrings.ru.tourReplayAction), findsOneWidget);

      // 4. Replay Product Tour and verify XP preserved on return
      final xpBefore = container.read(learnerStateNotifierProvider).value?.xp;
      await tester.ensureVisible(find.text(AppStrings.ru.tourReplayAction));
      await tester.tap(find.text(AppStrings.ru.tourReplayAction));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.ru.tourSlide1Title), findsOneWidget);

      await tester.tap(find.text(AppStrings.ru.tourSkip));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.ru.myProfile), findsOneWidget);
      expect(container.read(learnerStateNotifierProvider).value?.xp, xpBefore);
      expect(tester.takeException(), isNull);
    });

    test('WCAG AA contrast >= 4.5:1 holds on M3 Light and Dark semantic pairs', () {
      for (final c in [AppSemanticColors.light, AppSemanticColors.dark]) {
        expect(_contrastRatio(Colors.white, c.ctaPrimary), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(c.ink, c.paper), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(c.graphite, c.paper), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(c.slatefine, c.paper), greaterThanOrEqualTo(4.5));
        expect(
          _contrastRatio(c.successText, Color.alphaBlend(c.successSoft, c.paper)),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(c.warningText, Color.alphaBlend(c.warningSoft, c.paper)),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(c.errorText, Color.alphaBlend(c.errorSoft, c.paper)),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(c.isDark ? c.brandStrong : c.brand, Color.alphaBlend(c.brandSoft, c.paper)),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    testWidgets('BilimYolBottomNav & key interactive targets meet >= 44dp touch height', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapScreen(
          container: container,
          isDark: false,
          localeCode: 'uz',
          child: const Scaffold(
            body: SizedBox.expand(),
            bottomNavigationBar: BilimYolBottomNav(currentIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final navItems = find.descendant(
        of: find.byType(BilimYolBottomNav),
        matching: find.byType(AnimatedContainer),
      );
      expect(navItems, findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        final box = tester.getSize(navItems.at(i));
        expect(box.height, greaterThanOrEqualTo(44.0));
      }
    });

    testWidgets('Real Render Verification: M3 Light & Dark PNG captures at 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final renderDir = Platform.environment['BILIMYOL_RENDER_DIR'];
      if (renderDir != null && renderDir.trim().isNotEmpty) {
        await tester.runAsync(_ensureReadableFonts);
      }

      final today = DateTime.now();
      final weekActivity = List.generate(7, (i) {
        final d = today.subtract(Duration(days: 6 - i));
        final iso =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return DailyActivitySummary(
          date: iso,
          activeMinutes: 18 + (i * 9),
          xpEarned: 25,
          lessonsCompleted: 1,
        );
      });

      for (final isDark in [false, true]) {
        final modeTag = isDark ? 'dark' : 'light';
        final tourBoundaryKey = GlobalKey();

        // 1. Product Tour 3 slides with generated PNG assets
        await tester.pumpWidget(
          ProviderScope(
            child: RepaintBoundary(
              key: tourBoundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: const Locale('uz'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: AppStrings.localizationsDelegates,
                home: const WelcomeScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _maybeCapturePng(tester, tourBoundaryKey, 'tour_page1_$modeTag.png');

        await tester.tap(find.text('Keyingi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('6').last);
        await tester.pumpAndSettle();
        await _maybeCapturePng(tester, tourBoundaryKey, 'tour_page2_$modeTag.png');

        await tester.tap(find.text('Keyingi'));
        await tester.pumpAndSettle();
        await _maybeCapturePng(tester, tourBoundaryKey, 'tour_page3_$modeTag.png');

        // Seeded container for M3 screens
        demoSessionActive.value = true;
        final repo = _ActivityRepo(entries: weekActivity);
        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(repo),
            courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
            initialAppSettingsProvider.overrideWithValue(
              AppSettingsState(
                localeCode: 'uz',
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                productTourCompleted: true,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(courseStateNotifierProvider.notifier).init();
        await container
            .read(courseStateNotifierProvider.notifier)
            .selectCourse('course_math_01');
        await container.read(learnerStateNotifierProvider.notifier).seedQuickDemo();

        final routeScreens = <String, Widget>{
          'courses_${modeTag}_360.png': const CourseSelectionScreen(),
          'placement_${modeTag}_360.png': const PlacementTestScreen(),
          'knowledge_map_${modeTag}_360.png': const KnowledgeMapScreen(),
          'roadmap_${modeTag}_360.png': const RoadmapScreen(),
          'progress_${modeTag}_360.png': const ProgressScreen(),
          'ai_tutor_${modeTag}_360.png': const AITutorScreen(),
          'profile_${modeTag}_360.png': const ProfileScreen(),
        };

        for (final entry in routeScreens.entries) {
          final screenBoundaryKey = GlobalKey();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                key: screenBoundaryKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                  locale: const Locale('uz'),
                  supportedLocales: AppStrings.supportedLocales,
                  localizationsDelegates: AppStrings.localizationsDelegates,
                  home: entry.value,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await _maybeCapturePng(tester, screenBoundaryKey, entry.key);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('Regression: KnowledgeMapScreen renders unassessed course, loading state, and single emerald badge without _TypeError', (tester) async {
      // 1. Fresh unassessed course (scoresByCourse[courseId] == null)
      for (final courseId in ['course_math_01', 'course_eng_01']) {
        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
            courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(courseStateNotifierProvider.notifier).init();
        await container
            .read(courseStateNotifierProvider.notifier)
            .selectCourse(courseId);

        await tester.pumpWidget(
          _wrapScreen(
            container: container,
            isDark: false,
            localeCode: 'uz',
            disableAnimations: true,
            child: KeyedSubtree(
              key: ValueKey('unassessed-$courseId'),
              child: const KnowledgeMapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('0%'), findsWidgets);
      }

      // 2. Course loading state (activeCourse == null && courseState.isLoading == true)
      final slowCourseRepo = _SlowCourseRepo();
      final loadingContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
          courseRepositoryProvider.overrideWithValue(slowCourseRepo),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(loadingContainer.dispose);
      unawaited(loadingContainer.read(courseStateNotifierProvider.notifier).init());

      await tester.pumpWidget(
        _wrapScreen(
          container: loadingContainer,
          isDark: false,
          localeCode: 'uz',
          disableAnimations: true,
          child: const KnowledgeMapScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      slowCourseRepo.completer.complete(const []);
      await tester.pumpAndSettle();

      // 3. Seeded Algebra asoslari card avoids duplicate emerald badges (Yuqori + Özlaştirilgan)
      final seededContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(seededContainer.dispose);
      await seededContainer.read(courseStateNotifierProvider.notifier).init();
      await seededContainer
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_math_01');
      await seededContainer
          .read(learnerStateNotifierProvider.notifier)
          .seedQuickDemo();

      await tester.pumpWidget(
        _wrapScreen(
          container: seededContainer,
          isDark: false,
          localeCode: 'uz',
          disableAnimations: true,
          child: const KnowledgeMapScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.uz.masteryLabel(82)), findsNWidgets(2));
      expect(find.text(AppStrings.uz.statusMastered), findsNothing);
    });

    testWidgets('Regression: PlacementTestScreen submit-through-dialog does not spin under dialog and routes via Şaxsiy yölni köriş', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_math_01');

      final router = GoRouter(
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
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
            locale: const Locale('uz'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: AppStrings.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final total = container.read(placementStateNotifierProvider).totalQuestionsToAsk;
      expect(total, greaterThan(0));

      for (var step = 0; step < total; step++) {
        await tester.tap(find.text('A').first);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 850)),
        );
        if (step < total - 1) {
          await tester.tap(find.text(AppStrings.uz.nextQuestion));
          await tester.pumpAndSettle();
        }
      }

      // Final question -> open confirmation dialog -> NO CircularProgressIndicator spinning underneath
      expect(find.text(AppStrings.uz.viewResults), findsOneWidget);
      await tester.tap(find.text(AppStrings.uz.viewResults));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Topşiriş'), findsOneWidget);

      // Cancel dialog returns cleanly
      await tester.tap(find.text(AppStrings.uz.back));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(AppStrings.uz.viewResults), findsOneWidget);

      // Confirm dialog -> submits and shows 'Şaxsiy yölni köriş' -> navigates to /roadmap
      await tester.tap(find.text(AppStrings.uz.viewResults));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Topşiriş'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.uz.placementDoneTitle), findsOneWidget);
      expect(find.text('Şaxsiy yölni köriş'), findsOneWidget);

      await tester.ensureVisible(find.text('Şaxsiy yölni köriş'));
      await tester.tap(find.text('Şaxsiy yölni köriş'));
      await tester.pumpAndSettle();
      expect(find.byType(RoadmapScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Regression: ProgressScreen handles activity error @360dp, weekly chart @840dp 2.0x ru, and online mathPilot fallback', (tester) async {
      // 1. Activity error at 360dp @ 1.0x and 2.0x in uz & ru
      final errorRepo = _ActivityRepo(failActivity: true);
      final errorContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(errorRepo),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(errorContainer.dispose);
      await errorContainer.read(courseStateNotifierProvider.notifier).init();
      await errorContainer
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await errorContainer.read(learnerStateNotifierProvider.notifier).loadProfile();

      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = const Size(360, 800) * scale;
        tester.view.devicePixelRatio = scale;
        for (final code in ['uz', 'ru']) {
          await tester.pumpWidget(
            _wrapScreen(
              container: errorContainer,
              isDark: false,
              localeCode: code,
              textScale: scale,
              disableAnimations: true,
              child: KeyedSubtree(
                key: ValueKey('prog-err-$scale-$code'),
                child: const ProgressScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'ProgressScreen activity error overflowed at 360dp @ ${scale}x ($code)',
          );
          expect(find.text(AppStrings.forCode(code).retry), findsOneWidget);
        }
      }

      // Retry recovery
      errorRepo.failActivity = false;
      await tester.ensureVisible(find.text(AppStrings.ru.retry));
      await tester.tap(find.text(AppStrings.ru.retry));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2. Wide 840x900 @ 2.0x (ru) weekly chart with 120-min peak
      final today = DateTime.now();
      final week120 = List.generate(7, (i) {
        final d = today.subtract(Duration(days: 6 - i));
        final iso =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return DailyActivitySummary(
          date: iso,
          activeMinutes: i == 6 ? 120 : 30,
          xpEarned: 20,
          lessonsCompleted: 1,
        );
      });
      final wideContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(_ActivityRepo(entries: week120)),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(wideContainer.dispose);
      await wideContainer.read(courseStateNotifierProvider.notifier).init();
      await wideContainer.read(learnerStateNotifierProvider.notifier).loadProfile();

      tester.view.physicalSize = const Size(840, 900) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapScreen(
          container: wideContainer,
          isDark: false,
          localeCode: 'ru',
          textScale: 2.0,
          disableAnimations: true,
          child: const ProgressScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 3. Online mathPilot fallback: Matematika remains visible when mathProgress == null
      final prevRemote = SupabaseConfig.hasRemoteConfiguration;
      SupabaseConfig.hasRemoteConfiguration = true;
      addTearDown(() => SupabaseConfig.hasRemoteConfiguration = prevRemote);

      final onlineContainer = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(_ActivityRepo(entries: week120)),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(onlineContainer.dispose);
      await onlineContainer.read(courseStateNotifierProvider.notifier).init();
      await onlineContainer
          .read(courseStateNotifierProvider.notifier)
          .selectCourse('course_eng_01');
      await onlineContainer.read(learnerStateNotifierProvider.notifier).loadProfile();

      await tester.pumpWidget(
        _wrapScreen(
          container: onlineContainer,
          isDark: false,
          localeCode: 'uz',
          disableAnimations: true,
          child: KeyedSubtree(
            key: const ValueKey('prog-online-math-fallback'),
            child: const ProgressScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Matematika'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Regression: PlacementTestScreen inline submit-error banner fits 360x640 @ 2.0x (uz & ru) and keeps viewResults unobscured', (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final code in ['uz', 'ru']) {
        final s = AppStrings.forCode(code);
        final repo = _FailingPlacementRepo(failSavePlacement: true);
        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(repo),
            courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(courseStateNotifierProvider.notifier).init();
        await container
            .read(courseStateNotifierProvider.notifier)
            .selectCourse('course_math_01');

        await tester.pumpWidget(
          _wrapScreen(
            container: container,
            isDark: false,
            localeCode: code,
            textScale: 2.0,
            disableAnimations: true,
            child: KeyedSubtree(
              key: ValueKey('placement-err-$code'),
              child: const PlacementTestScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final total =
            container.read(placementStateNotifierProvider).totalQuestionsToAsk;
        expect(total, greaterThan(0));

        for (var step = 0; step < total; step++) {
          final optA = find.text('A').first;
          await tester.ensureVisible(optA);
          await tester.pumpAndSettle();
          await tester.tap(optA);
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 850)),
          );
          if (step < total - 1) {
            await tester.tap(find.text(s.nextQuestion));
            await tester.pumpAndSettle();
          }
        }

        await tester.tap(find.text(s.viewResults));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.placementConfirmSubmit));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'PlacementTestScreen submit error overflowed at 360x640 @ 2.0x ($code)',
        );
        expect(find.text(s.placementSubmitError), findsOneWidget);
        expect(find.text(s.reloadSession), findsOneWidget);
        expect(find.text(s.viewResults), findsOneWidget);

        // Verify viewResults remains directly tappable/unobscured and opens dialog
        await tester.tap(find.text(s.viewResults));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text(s.back));
        await tester.pumpAndSettle();

        // Verify reloadSession clears the inline error banner cleanly
        await tester.tap(find.text(s.reloadSession));
        await tester.pumpAndSettle();
        expect(find.text(s.placementSubmitError), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Regression: AITutorScreen handles ultra-tight 360x560 & 360x520 @ 2.0x keyboard-open (uz & ru) across idle, multiline, typing, and retry', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final viewport in [const Size(360, 560), const Size(360, 520)]) {
        tester.view.physicalSize = viewport * 2.0;
        tester.view.devicePixelRatio = 2.0;

        for (final code in ['uz', 'ru']) {
          final s = AppStrings.forCode(code);
          final tutorService = _ControllableTutorService();
          final container = ProviderContainer(
            overrides: [
              learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
              courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
              lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
              aiTutorServiceProvider.overrideWithValue(tutorService),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            _wrapScreen(
              container: container,
              isDark: false,
              localeCode: code,
              textScale: 2.0,
              viewInsetsBottom: 300,
              disableAnimations: true,
              child: KeyedSubtree(
                key: ValueKey('ultratight-${viewport.height}-$code'),
                child: const AITutorScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'AITutorScreen idle overflowed at ${viewport.width}x${viewport.height} @ 2.0x ($code)',
          );
          expect(find.text(s.aiTutorStatusDemo), findsNothing);

          // Multiline input
          await tester.enterText(
            find.byType(TextField),
            'Line 1\nLine 2\nLine 3',
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'AITutorScreen multiline overflowed at ${viewport.width}x${viewport.height} @ 2.0x ($code)',
          );

          // Typing indicator (_isSending == true) -> then offline error -> then Retry
          tutorService.gate = Completer<void>();
          tutorService.failNext = true;
          await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
          await tester.pump();
          expect(find.byType(YolchiTypingIndicator), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'AITutorScreen typing overflowed at ${viewport.width}x${viewport.height} @ 2.0x ($code)',
          );

          tutorService.gate!.complete();
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'AITutorScreen error-retry banner overflowed at ${viewport.width}x${viewport.height} @ 2.0x ($code)',
          );
          expect(find.text(s.retry), findsOneWidget);

          await tester.tap(find.text(s.retry));
          await tester.pumpAndSettle();
          expect(tutorService.calls, 2);
          expect(
            tester.takeException(),
            isNull,
            reason: 'AITutorScreen retry recovery overflowed at ${viewport.width}x${viewport.height} @ 2.0x ($code)',
          );
        }
      }
    });

    testWidgets('Regression: ProgressScreen empty-activity branch fits 360x800 @ 2.0x (uz & ru) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          learnerRepositoryProvider.overrideWithValue(_ActivityRepo(forceEmpty: true)),
          courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
          lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(courseStateNotifierProvider.notifier).init();
      await container.read(learnerStateNotifierProvider.notifier).loadProfile();

      for (final code in ['uz', 'ru']) {
        final s = AppStrings.forCode(code);
        await tester.pumpWidget(
          _wrapScreen(
            container: container,
            isDark: false,
            localeCode: code,
            textScale: 2.0,
            disableAnimations: true,
            child: KeyedSubtree(
              key: ValueKey('prog-empty-$code'),
              child: const ProgressScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(s.progressEmptyActivity), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'ProgressScreen empty-activity overflowed at 360x800 @ 2.0x ($code)',
        );
      }
    });

    testWidgets('Regression: Placement final-question retry succeeds cleanly after transient failure without duplicate-question error', (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final code in ['uz', 'ru']) {
        final s = AppStrings.forCode(code);
        final repo = _FailingPlacementRepo(failSavePlacement: true);
        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(repo),
            courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
            lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(courseStateNotifierProvider.notifier).init();
        await container
            .read(courseStateNotifierProvider.notifier)
            .selectCourse('course_math_01');

        await tester.pumpWidget(
          _wrapScreen(
            container: container,
            isDark: code == 'ru',
            localeCode: code,
            textScale: 2.0,
            disableAnimations: true,
            child: KeyedSubtree(
              key: ValueKey('placement-final-retry-$code'),
              child: const PlacementTestScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final total =
            container.read(placementStateNotifierProvider).totalQuestionsToAsk;
        expect(total, greaterThan(0));

        for (var step = 0; step < total; step++) {
          final optA = find.text('A').first;
          await tester.ensureVisible(optA);
          await tester.pumpAndSettle();
          await tester.tap(optA);
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 850)),
          );
          if (step < total - 1) {
            await tester.tap(find.text(s.nextQuestion));
            await tester.pumpAndSettle();
          }
        }

        // First final submit fails -> inline error shown, submissions not duplicated
        await tester.tap(find.text(s.viewResults));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.placementConfirmSubmit));
        await tester.pumpAndSettle();

        expect(find.text(s.placementSubmitError), findsOneWidget);
        expect(
          container.read(placementStateNotifierProvider).submissions.length,
          total - 1,
        );
        expect(tester.takeException(), isNull);

        // Recover repo, wait >=850ms, and retry via viewResults -> placementConfirmSubmit
        repo.failSavePlacement = false;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 850)),
        );
        await tester.tap(find.text(s.viewResults));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text(s.placementConfirmSubmit));
        await tester.pumpAndSettle();

        expect(find.text(s.placementSubmitError), findsNothing);
        expect(find.text(s.placementDoneTitle), findsOneWidget);
        expect(
          container.read(placementStateNotifierProvider).result?.submissions.length,
          total,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Regression: PlacementTestScreen noticeBanner & rapid retry at 360x560 & 360x640 @ 2.0x (uz & ru, Light & Dark) have zero overflow', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final viewport in [const Size(360, 560), const Size(360, 640)]) {
        tester.view.physicalSize = viewport * 2.0;
        tester.view.devicePixelRatio = 2.0;

        for (final isDark in [false, true]) {
          for (final code in ['uz', 'ru']) {
          final s = AppStrings.forCode(code);
          final repo = _FailingPlacementRepo(failSavePlacement: true);
          final container = ProviderContainer(
            overrides: [
              learnerRepositoryProvider.overrideWithValue(repo),
              courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
              lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
            ],
          );
          addTearDown(container.dispose);

          await container.read(appSettingsProvider.notifier).setLocale(code);
          await container.read(courseStateNotifierProvider.notifier).init();
          await container
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_math_01');

          await tester.pumpWidget(
            _wrapScreen(
              container: container,
              isDark: isDark,
              localeCode: code,
              textScale: 2.0,
              disableAnimations: true,
              child: KeyedSubtree(
                key: ValueKey('placement-notice-${viewport.height}-${isDark ? "dark" : "light"}-$code'),
                child: const PlacementTestScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final total =
              container.read(placementStateNotifierProvider).totalQuestionsToAsk;

          // Answer Q1 -> immediately submit Q2 (< 800ms) to trigger standalone noticeBanner
          final optAQ1 = find.text('A').first;
          await tester.ensureVisible(optAQ1);
          await tester.pump();
          await tester.tap(optAQ1);
          await tester.pump();
          final nextBtnQ1 = find.text(s.nextQuestion);
          await tester.ensureVisible(nextBtnQ1);
          await tester.pump();
          await tester.tap(nextBtnQ1);
          await tester.pump();

          final optAQ2 = find.text('A').first;
          await tester.ensureVisible(optAQ2);
          await tester.pump();
          await tester.tap(optAQ2);
          await tester.pump();
          final nextBtnQ2 = find.text(s.nextQuestion);
          await tester.ensureVisible(nextBtnQ2);
          await tester.pump();
          await tester.tap(nextBtnQ2);
          await tester.pump();

          expect(
            tester.takeException(),
            isNull,
            reason: 'PlacementTestScreen standalone noticeBanner overflowed at 360x560 @ 2.0x ($code, dark=$isDark)',
          );
          expect(find.text(s.placementFastTapNotice), findsWidgets);
          expect(find.text(s.nextQuestion).hitTestable(), findsOneWidget);
          await Scrollable.ensureVisible(
            tester.element(find.text('Q2')),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          expect(find.text('Q2').hitTestable(), findsOneWidget);

          // Advance through remaining questions to final question
          await tester.pumpAndSettle(const Duration(seconds: 1));
          for (var step = 1; step < total; step++) {
            final optA = find.text('A').first;
            await tester.ensureVisible(optA);
            await tester.pumpAndSettle();
            await tester.tap(optA);
            await tester.pump();
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 850)),
            );
            if (step < total - 1) {
              final nextBtn = find.text(s.nextQuestion);
              await tester.ensureVisible(nextBtn);
              await tester.pumpAndSettle();
              await tester.tap(nextBtn);
              await tester.pumpAndSettle();
            }
          }

          // Fail final submit, then rapid-retry immediately (< 800ms) after repo recovery
          final viewRes1 = find.text(s.viewResults);
          await tester.ensureVisible(viewRes1);
          await tester.pumpAndSettle();
          await tester.tap(viewRes1);
          await tester.pumpAndSettle();
          await tester.tap(find.text(s.placementConfirmSubmit));
          await tester.pumpAndSettle();
          expect(find.text(s.placementSubmitError), findsOneWidget);
          expect(tester.takeException(), isNull);

          repo.failSavePlacement = false;
          final viewRes2 = find.text(s.viewResults);
          await tester.ensureVisible(viewRes2);
          await tester.pumpAndSettle();
          await tester.tap(viewRes2);
          await tester.pumpAndSettle();
          await tester.tap(find.text(s.placementConfirmSubmit));
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'PlacementTestScreen rapid retry after error overflowed at ${viewport.width}x${viewport.height} @ 2.0x ($code, dark=$isDark)',
          );
          expect(find.text(s.placementDoneTitle), findsOneWidget);
          }
        }
      }
    });

    testWidgets('Regression: AITutorScreen idle (viewInsets=0) @ 360x520, 360x560, 360x640, and 360x380 @ 2.0x (uz & ru, Light & Dark) has zero overflow and tappable chips', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final viewport in [
        const Size(360, 520),
        const Size(360, 560),
        const Size(360, 640),
        const Size(360, 380),
      ]) {
        tester.view.physicalSize = viewport * 2.0;
        tester.view.devicePixelRatio = 2.0;

        for (final isDark in [false, true]) {
          for (final code in ['uz', 'ru']) {
            final s = AppStrings.forCode(code);
            final tutorService = _ControllableTutorService();
            final container = ProviderContainer(
              overrides: [
                learnerRepositoryProvider.overrideWithValue(InMemoryLearnerRepository()),
                courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
                lessonRepositoryProvider.overrideWithValue(InMemoryLessonRepository()),
                aiTutorServiceProvider.overrideWithValue(tutorService),
              ],
            );
            addTearDown(container.dispose);

            await tester.pumpWidget(
              _wrapScreen(
                container: container,
                isDark: isDark,
                localeCode: code,
                textScale: 2.0,
                viewInsetsBottom: 0,
                disableAnimations: true,
                child: KeyedSubtree(
                  key: ValueKey('ai-idle-${viewport.height}-${isDark ? "dark" : "light"}-$code'),
                  child: const AITutorScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'AITutorScreen idle overflowed at ${viewport.width}x${viewport.height} @ 2.0x ($code, dark=$isDark)',
            );

            final firstChipText = find.text(s.aiTutorQuickPrompts.first);
            expect(firstChipText, findsOneWidget);
            expect(firstChipText.hitTestable(), findsOneWidget);
            final chipBox = find.ancestor(
              of: firstChipText,
              matching: find.byType(InkWell),
            ).first;
            expect(tester.getSize(chipBox).height, greaterThanOrEqualTo(44.0));

            await tester.tap(firstChipText);
            await tester.pumpAndSettle();
            expect(tutorService.calls, 1);
            expect(
              tester.takeException(),
              isNull,
              reason: 'AITutorScreen post-chip reply overflowed at ${viewport.width}x${viewport.height} @ 2.0x ($code, dark=$isDark)',
            );
          }
        }
      }
    });

    testWidgets('Regression: FriendlyErrorState on /knowledge-map, /roadmap, /progress, /profile fits 360x640 @ 2.0x (uz & ru, Light & Dark) with tappable retry', (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final isDark in [false, true]) {
        for (final code in ['uz', 'ru']) {
          final s = AppStrings.forCode(code);
          final profileRepo = _FailingProfileRepo(failGetProfile: false);
          final lessonRepo = _FailingRoadmapLessonRepo(failRoadmap: false);
          final container = ProviderContainer(
            overrides: [
              learnerRepositoryProvider.overrideWithValue(profileRepo),
              courseRepositoryProvider.overrideWithValue(InMemoryCourseRepository()),
              lessonRepositoryProvider.overrideWithValue(lessonRepo),
            ],
          );
          addTearDown(container.dispose);

          await container.read(courseStateNotifierProvider.notifier).init();
          await container
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');

          final screens = <String, Widget>{
            'knowledge-map': const KnowledgeMapScreen(),
            'roadmap': const RoadmapScreen(),
            'progress': const ProgressScreen(),
            'profile': const ProfileScreen(),
          };

          for (final entry in screens.entries) {
            profileRepo.failGetProfile = true;
            lessonRepo.failRoadmap = true;
            await container.read(learnerStateNotifierProvider.notifier).loadProfile();
            await container
                .read(roadmapStateNotifierProvider.notifier)
                .loadRoadmap('course_eng_01');

            await tester.pumpWidget(
              _wrapScreen(
                container: container,
                isDark: isDark,
                localeCode: code,
                textScale: 2.0,
                disableAnimations: true,
                child: KeyedSubtree(
                  key: ValueKey('err-${entry.key}-${isDark ? "dark" : "light"}-$code'),
                  child: entry.value,
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} FriendlyErrorState overflowed at 360x640 @ 2.0x ($code, dark=$isDark)',
            );
            expect(find.byType(FriendlyErrorState), findsOneWidget);

            final retryFinder = find.text(s.retry);
            await tester.ensureVisible(retryFinder);
            await tester.pumpAndSettle();
            expect(retryFinder.hitTestable(), findsOneWidget);
            final retryInkWell = find.ancestor(
              of: retryFinder,
              matching: find.byType(InkWell),
            ).first;
            expect(tester.getSize(retryInkWell).height, greaterThanOrEqualTo(44.0));

            profileRepo.failGetProfile = false;
            lessonRepo.failRoadmap = false;
            await tester.tap(retryFinder);
            await tester.pumpAndSettle();

            expect(find.byType(FriendlyErrorState), findsNothing);
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} retry recovery failed at 360x640 @ 2.0x ($code, dark=$isDark)',
            );
          }

          final prevRemote = SupabaseConfig.hasRemoteConfiguration;
          SupabaseConfig.hasRemoteConfiguration = true;
          try {
            await container
                .read(courseStateNotifierProvider.notifier)
                .selectCourse('course_math_01');
            lessonRepo.failRoadmap = true;
            await container
                .read(roadmapStateNotifierProvider.notifier)
                .loadRoadmap('course_math_01');
            await tester.pumpWidget(
              _wrapScreen(
                container: container,
                isDark: isDark,
                localeCode: code,
                textScale: 2.0,
                disableAnimations: true,
                child: KeyedSubtree(
                  key: ValueKey('err-math-pilot-${isDark ? "dark" : "light"}-$code'),
                  child: const KnowledgeMapScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(FriendlyErrorState), findsOneWidget);
            final retryFinder = find.text(s.retry);
            await tester.ensureVisible(retryFinder);
            await tester.pumpAndSettle();
            expect(retryFinder.hitTestable(), findsOneWidget);
            lessonRepo.failRoadmap = false;
            await tester.tap(retryFinder);
            await tester.pumpAndSettle();
            expect(find.byType(FriendlyErrorState), findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            SupabaseConfig.hasRemoteConfiguration = prevRemote;
          }
        }
      }
    });
  });
}
