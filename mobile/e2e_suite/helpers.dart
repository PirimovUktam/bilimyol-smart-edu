import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bilimyol_mobile/app/app.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/widgets/app_card.dart';
import 'package:bilimyol_mobile/data/services/demo_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/data/services/supabase_ai_tutor_service.dart';

enum ViewportPreset {
  mobile390(Size(390, 844)),
  desktop1440(Size(1440, 900));

  const ViewportPreset(this.size);
  final Size size;
}

enum AppLocalePreset {
  uz(Locale('uz')),
  ru(Locale('ru'));

  const AppLocalePreset(this.locale);
  final Locale locale;
}

const Map<String, List<String>> _courseTitleCandidates = {
  'course_eng_01': ['Ingliz tili', 'Английский язык', 'Английский'],
  'course_math_01': ['Matematika', 'Математика'],
  'course_it': ['IT & Kodlash', 'IT и программирование'],
  'course_logic': ['Mantiq', 'Логика'],
};

const List<String> _demoEntryLabels = [
  'Namuna hisobi bilan kirish',
  'Войти в деморежим',
];

const List<String> _courseSelectionHeadings = [
  'Qaysi fanni o‘rganishni istaysiz?',
  'Какой предмет вы хотите изучать?',
];

const List<String> _backToRoadmapTooltips = [
  'Ta’lim yo‘liga qaytish',
  'Вернуться к маршруту',
];

const List<String> _switchCourseTooltips = [
  'Fanni almashtirish',
  'Сменить предмет',
];

const List<String> _profileTabLabels = ['Profil', 'Профиль'];

const List<String> _changeCourseLabels = [
  'Fanni o‘zgartirish',
  'Сменить предмет',
];

const List<String> _askYolchiTooltips = [
  'Yo‘lchidan so‘rash',
  'Спросить Yo‘lchi',
];

void ensureE2eTestBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SupabaseConfig.isConfigured = false;
  SupabaseConfig.hasRemoteConfiguration = false;
}

Future<void> setSurfaceSize(WidgetTester tester, ViewportPreset preset) async {
  tester.view.physicalSize = preset.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pump();
}

Future<void> setThemeBrightness(
  WidgetTester tester,
  Brightness brightness,
) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pump();
}

Future<void> setLocale(
  WidgetTester tester,
  AppLocalePreset locale,
) async {
  tester.platformDispatcher.localeTestValue = locale.locale;
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  await tester.pump();
}

Future<void> _pumpAfterAction(WidgetTester tester, {required bool settle}) async {
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await pumpFrames(tester);
  }
}

Future<void> pumpBilimYolApp(
  WidgetTester tester, {
  ViewportPreset viewport = ViewportPreset.mobile390,
  Brightness brightness = Brightness.light,
  AppLocalePreset locale = AppLocalePreset.uz,
  bool resetStorage = true,
  Map<String, Object> initialPrefs = const {},
  bool settle = true,
  List<Override> overrides = const [],
}) async {
  ensureE2eTestBinding();
  await setSurfaceSize(tester, viewport);

  if (brightness != Brightness.light) {
    await setThemeBrightness(tester, brightness);
  }
  if (locale != AppLocalePreset.uz) {
    await setLocale(tester, locale);
  }

  if (resetStorage) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // e2e_suite lives outside test/ to isolate it from unit/widget runs, so
    // reset SharedPreferences' private singleton completer explicitly here.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(initialPrefs);
    demoSessionActive.value = false;
    appRouter.go('/welcome');
  }

  addTearDown(() {
    demoSessionActive.value = false;
    SupabaseConfig.isConfigured = false;
    SupabaseConfig.hasRemoteConfiguration = false;
    appRouter.go('/welcome');
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const BilimYolApp(),
    ),
  );
  await _pumpAfterAction(tester, settle: settle);
}

Future<void> simulateAppRestart(
  WidgetTester tester, {
  ViewportPreset viewport = ViewportPreset.mobile390,
  Brightness? brightness,
  AppLocalePreset? locale,
  bool keepDemoSession = true,
  bool settle = true,
  List<Override> overrides = const [],
}) async {
  await setSurfaceSize(tester, viewport);
  if (brightness != null) {
    await setThemeBrightness(tester, brightness);
  }
  if (locale != null) {
    await setLocale(tester, locale);
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  demoSessionActive.value = keepDemoSession;
  appRouter.go(keepDemoSession ? '/courses' : '/welcome');

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const BilimYolApp(),
    ),
  );
  await _pumpAfterAction(tester, settle: settle);
}

Future<Map<String, dynamic>> readDemoProgressSnapshot() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('bilimyol_demo_progress_v1');
  if (raw == null || raw.trim().isEmpty) {
    return <String, dynamic>{};
  }
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return <String, dynamic>{};
}

Finder findTextAny(List<String> candidates) {
  final candidateSet = candidates.toSet();
  return find.byWidgetPredicate(
    (widget) {
      if (widget is Text) {
        final value = widget.data ?? widget.textSpan?.toPlainText();
        return value != null && candidateSet.contains(value);
      }
      return false;
    },
    description: 'Text matching any of $candidates',
  );
}

Finder findTextMatching(Pattern pattern, {bool findRichText = false}) {
  return find.textContaining(pattern, findRichText: findRichText);
}

Future<void> _revealFinder(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: scrollable.first,
      );
    }
  } else {
    await tester.ensureVisible(finder.first);
  }
}

Future<void> enterDemoMode(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final demoFinder = findTextAny(_demoEntryLabels);
  await _revealFinder(tester, demoFinder);
  await tester.tap(demoFinder.first);
  await _pumpAfterAction(tester, settle: settle);
  expect(findTextAny(_courseSelectionHeadings), findsOneWidget);
}

Future<void> selectCourse(
  WidgetTester tester,
  String courseId, {
  bool settle = true,
}) async {
  final titles = _courseTitleCandidates[courseId];
  if (titles == null) {
    throw ArgumentError.value(courseId, 'courseId', 'Unknown courseId');
  }

  bool isOnCourseSelection() =>
      findTextAny(_courseSelectionHeadings).evaluate().isNotEmpty;

  if (!isOnCourseSelection()) {
    for (final tooltip in _backToRoadmapTooltips) {
      final f = find.byTooltip(tooltip);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first);
        await _pumpAfterAction(tester, settle: settle);
        break;
      }
    }

    if (!isOnCourseSelection()) {
      Finder? switchFinder;
      for (final tooltip in _switchCourseTooltips) {
        final f = find.byTooltip(tooltip);
        if (f.evaluate().isNotEmpty) {
          switchFinder = f;
          break;
        }
      }
      if (switchFinder != null) {
        await tester.tap(switchFinder.first);
        await _pumpAfterAction(tester, settle: settle);
      } else if (findTextAny(_profileTabLabels).evaluate().isNotEmpty) {
        await tester.tap(findTextAny(_profileTabLabels).last);
        await _pumpAfterAction(tester, settle: settle);
        await tapTextAny(tester, _changeCourseLabels, settle: settle);
      } else if (find.byTooltip('Back').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Back').first);
        await _pumpAfterAction(tester, settle: settle);
      }
    }

    if (!isOnCourseSelection()) {
      Finder? switchFinder;
      for (final tooltip in _switchCourseTooltips) {
        final f = find.byTooltip(tooltip);
        if (f.evaluate().isNotEmpty) {
          switchFinder = f;
          break;
        }
      }
      if (switchFinder != null) {
        await tester.tap(switchFinder.first);
        await _pumpAfterAction(tester, settle: settle);
      } else if (findTextAny(_profileTabLabels).evaluate().isNotEmpty) {
        await tester.tap(findTextAny(_profileTabLabels).last);
        await _pumpAfterAction(tester, settle: settle);
        await tapTextAny(tester, _changeCourseLabels, settle: settle);
      } else {
        appRouter.go('/courses');
        await _pumpAfterAction(tester, settle: settle);
      }
    }
  }

  expect(findTextAny(_courseSelectionHeadings), findsOneWidget);
  final courseFinder = findTextAny(titles);
  await _revealFinder(tester, courseFinder);
  await tester.tap(courseFinder.first);
  await _pumpAfterAction(tester, settle: settle);
}

Future<void> tapText(
  WidgetTester tester,
  String text, {
  bool scroll = true,
  bool settle = true,
}) async {
  final finder = find.text(text);
  if (scroll) {
    await _revealFinder(tester, finder);
  } else {
    await tester.ensureVisible(finder.first);
  }
  await tester.tap(finder.first);
  await _pumpAfterAction(tester, settle: settle);
}

Future<void> tapTextAny(
  WidgetTester tester,
  List<String> candidates, {
  bool scroll = true,
  bool settle = true,
}) async {
  final finder = findTextAny(candidates);
  if (scroll) {
    await _revealFinder(tester, finder);
  } else {
    await tester.ensureVisible(finder.first);
  }
  await tester.tap(finder.first);
  await _pumpAfterAction(tester, settle: settle);
}

Future<void> tapTooltip(
  WidgetTester tester,
  String tooltip, {
  bool settle = true,
}) async {
  final finder = find.byTooltip(tooltip);
  await _revealFinder(tester, finder);
  await tester.tap(finder.first);
  await _pumpAfterAction(tester, settle: settle);
}

Future<void> tapTooltipAny(
  WidgetTester tester,
  List<String> tooltips, {
  bool settle = true,
}) async {
  for (final tooltip in tooltips) {
    final finder = find.byTooltip(tooltip);
    if (finder.evaluate().isNotEmpty) {
      await _revealFinder(tester, finder);
      await tester.tap(finder.first);
      await _pumpAfterAction(tester, settle: settle);
      return;
    }
  }
  final fallback = find.byTooltip(tooltips.first);
  await _revealFinder(tester, fallback);
  await tester.tap(fallback.first);
  await _pumpAfterAction(tester, settle: settle);
}

Future<void> openAndCloseYolchiAi(
  WidgetTester tester, {
  String? askText,
  Finder? preserveFinder,
  String? preserveText,
  bool settle = true,
}) async {
  final stepRegex = RegExp(r'^(Qadam|Шаг) \d+ / \d+$');
  final stepFinder = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data != null &&
        stepRegex.hasMatch(widget.data!),
  );
  String? capturedStepText;
  if (stepFinder.evaluate().isNotEmpty) {
    capturedStepText = tester.widget<Text>(stepFinder.first).data;
  }

  if (preserveFinder != null) {
    expect(preserveFinder, findsWidgets);
  }
  if (preserveText != null) {
    expect(find.textContaining(preserveText), findsWidgets);
  }

  await tapTooltipAny(tester, _askYolchiTooltips, settle: settle);
  expect(find.text('Yo‘lchi AI'), findsWidgets);

  if (askText != null && askText.trim().isNotEmpty) {
    final input = find.byType(TextField).last;
    await tester.enterText(input, askText);
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded).last);
    await pumpFrames(tester, count: 25, step: const Duration(milliseconds: 50));
  }

  await tester.pageBack();
  await _pumpAfterAction(tester, settle: settle);

  expect(find.text('Yo‘lchi AI'), findsNothing);
  expect(
    find.byWidgetPredicate(
      (w) => w is Tooltip && _askYolchiTooltips.contains(w.message),
    ),
    findsWidgets,
  );

  if (capturedStepText != null) {
    expect(find.text(capturedStepText), findsOneWidget);
  }
  if (preserveFinder != null) {
    expect(preserveFinder, findsWidgets);
  }
  if (preserveText != null) {
    expect(find.textContaining(preserveText), findsWidgets);
  }
}

Future<void> pumpFrames(
  WidgetTester tester, {
  int count = 5,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

Finder findCourseCard(String title) => find.text(title);

Finder findLessonStepCounter(int step, int total) => find.byWidgetPredicate(
  (widget) {
    if (widget is Text) {
      final value = widget.data ?? widget.textSpan?.toPlainText();
      return value == 'Qadam $step / $total' || value == 'Шаг $step / $total';
    }
    return false;
  },
);

Finder findBottomNavTab(String label) => find.text(label);

class AudioTestHarness {
  AudioTestHarness({
    this.failOnLoad = false,
    this.failOnPlay = false,
    this.autoAdvanceOnPlay = false,
    this.simulatedDuration = const Duration(seconds: 5),
    this.tickStep = const Duration(milliseconds: 250),
  });

  bool failOnLoad;
  bool failOnPlay;
  bool autoAdvanceOnPlay;
  Duration simulatedDuration;
  Duration tickStep;

  final List<FakeLessonAudioController> controllers = [];

  FakeLessonAudioController? get latestController =>
      controllers.isEmpty ? null : controllers.last;

  Override buildOverride() {
    return lessonAudioControllerFactoryProvider.overrideWithValue(() {
      final controller = FakeLessonAudioController(
        failOnLoad: failOnLoad,
        failOnPlay: failOnPlay,
        autoAdvanceOnPlay: autoAdvanceOnPlay,
        simulatedDuration: simulatedDuration,
        tickStep: tickStep,
      );
      controllers.add(controller);
      return controller;
    });
  }
}

Override createAudioOverride({
  bool failOnLoad = false,
  bool failOnPlay = false,
  bool autoAdvanceOnPlay = false,
  Duration simulatedDuration = const Duration(seconds: 5),
}) {
  return AudioTestHarness(
    failOnLoad: failOnLoad,
    failOnPlay: failOnPlay,
    autoAdvanceOnPlay: autoAdvanceOnPlay,
    simulatedDuration: simulatedDuration,
  ).buildOverride();
}

class FakeFailingAiTutorService implements IAITutorService {
  FakeFailingAiTutorService({this.shouldFail = true});

  bool shouldFail;
  final DemoAITutorService _delegate = DemoAITutorService();
  int askTutorCalls = 0;

  @override
  Future<AskTutorResponse> askTutor(AskTutorRequest request) async {
    askTutorCalls++;
    if (shouldFail) {
      throw const AITutorUnavailableException(
        'Yo‘lchi AI xizmatiga ulanib bo‘lmadi.',
      );
    }
    return _delegate.askTutor(request);
  }

  @override
  Future<AIExplanationResponse> explainMistake(AIExplanationRequest request) {
    if (shouldFail) {
      return Future.error(
        const AITutorUnavailableException(
          'Yo‘lchi AI xizmatiga ulanib bo‘lmadi.',
        ),
      );
    }
    return _delegate.explainMistake(request);
  }

  @override
  Future<GeneratedLessonResponse> generateLesson(GenerateLessonRequest request) {
    return _delegate.generateLesson(request);
  }
}

Future<void> dismissSnackBarIfVisible(WidgetTester tester) async {
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }
}

Future<void> advanceLessonStep(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await dismissSnackBarIfVisible(tester);
  await tapTextAny(
    tester,
    const ['Keyingi qadam', 'Yakunlash', 'Следующий шаг', 'Завершить'],
    settle: settle,
  );
}

Future<void> toggleAudioTranscript(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tapTextAny(
    tester,
    const ['Matnli bayon', 'Текст'],
    settle: settle,
  );
}

Future<void> tapAudioPlayPause(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tapTooltipAny(
    tester,
    const ['Tinglash', 'Pauza', 'Слушать', 'Пауза'],
    settle: settle,
  );
}

Future<void> tapAudioReplay(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tapTooltipAny(
    tester,
    const ['Qayta tinglash', 'Повторить'],
    settle: settle,
  );
}

Future<void> revealFlashcard(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tapTextAny(
    tester,
    const ['Javobni ko‘rish', 'Показать ответ'],
    settle: settle,
  );
}

Future<void> markFlashcardNeedPractice(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tapTextAny(
    tester,
    const ['Yana mashq qilaman', 'Повторить ещё'],
    settle: settle,
  );
}

Future<void> markFlashcardRemembered(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tapTextAny(
    tester,
    const ['Eslab qoldim', 'Запомнил(а)'],
    settle: settle,
  );
}

Future<void> submitFreeTextAnswer(
  WidgetTester tester,
  String answer, {
  bool settle = true,
}) async {
  final keyedField = find.byKey(const Key('free_text_answer_input'));
  final inputFinder = keyedField.evaluate().isNotEmpty
      ? keyedField
      : find.byType(TextField).first;
  await _revealFinder(tester, inputFinder);
  await tester.enterText(inputFinder, answer);
  await tester.pump();
  await tapTextAny(
    tester,
    const ['TEKSHIRISH', 'Проверить'],
    settle: settle,
  );
}

Future<void> selectMcqAndSubmit(
  WidgetTester tester,
  String optionText, {
  bool settle = true,
}) async {
  await tapText(tester, optionText, settle: settle);
  await tapTextAny(
    tester,
    const ['TEKSHIRISH', 'Проверить'],
    settle: settle,
  );
}

Future<void> completeStarterLessonFlow(
  WidgetTester tester, {
  String answer = "I'm Sam",
  bool selectCourseFirst = true,
  bool settle = true,
}) async {
  if (selectCourseFirst) {
    await selectCourse(tester, 'course_eng_01', settle: settle);
  }
  await tapTextAny(
    tester,
    const ['Noldan boshlayman', 'Начать с нуля'],
    settle: settle,
  );
  await tapTextAny(
    tester,
    const ['Birinchi darsni boshlash', 'Начать первый урок'],
    settle: settle,
  );
  await advanceLessonStep(tester, settle: settle); // Step 1 -> Step 2
  await advanceLessonStep(tester, settle: settle); // Step 2 -> Step 3
  await revealFlashcard(tester, settle: settle);
  await markFlashcardRemembered(tester, settle: settle);
  await revealFlashcard(tester, settle: settle);
  await markFlashcardRemembered(tester, settle: settle);
  await advanceLessonStep(tester, settle: settle); // Step 3 -> Step 4
  await submitFreeTextAnswer(tester, answer, settle: settle);
}

Future<void> openEnglishRoadmapViaOnboarding(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await selectCourse(tester, 'course_eng_01', settle: settle);
  await tapTextAny(
    tester,
    const ['Asoslarini bilaman', 'Знаю основы'],
    settle: settle,
  );
  await tapTextAny(
    tester,
    const ['Ta’lim yo‘lini ochish', 'Открыть маршрут обучения'],
    settle: settle,
  );
}

Future<void> completeEnglishPathThroughGrammar(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await openEnglishRoadmapViaOnboarding(tester, settle: settle);
  await openRoadmapNodeAction(
    tester,
    RegExp(r'^(Vocabulary|Лексика)$'),
    settle: settle,
  );
  await advanceToInteractiveExerciseStep(tester, settle: settle);
  await selectMcqAndSubmit(
    tester,
    'between the chair and the shelf',
    settle: settle,
  );

  await openRoadmapNodeAction(
    tester,
    RegExp(r'^(Grammar|Грамматика)$'),
    settle: settle,
  );
  await advanceToInteractiveExerciseStep(tester, settle: settle);
  await selectMcqAndSubmit(tester, 'does', settle: settle);
}

Future<void> openNextLessonViaDashboard(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await dismissSnackBarIfVisible(tester);
  await tapTextAny(
    tester,
    const ['Bosh sahifa', 'Главная'],
    scroll: false,
    settle: settle,
  );
  await tapTextAny(
    tester,
    const ['Davom etish', 'Birinchi darsni ochish', 'Продолжить'],
    settle: settle,
  );
}

bool _isTargetFocused(Finder target) {
  final targetElements = target.evaluate();
  if (targetElements.isEmpty) {
    fail('pressTabUntilFocused target not found in widget tree: $target');
  }
  final targetNode = targetElements.first;
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null || primaryFocus is FocusScopeNode) {
    return false;
  }
  final focusContext = primaryFocus.context;
  if (focusContext == null) return false;
  if (focusContext == targetNode) return true;
  var matched = false;
  targetNode.visitAncestorElements((ancestor) {
    if (ancestor == focusContext) {
      matched = true;
      return false;
    }
    return true;
  });
  if (!matched) {
    focusContext.visitAncestorElements((ancestor) {
      if (ancestor == targetNode) {
        matched = true;
        return false;
      }
      return true;
    });
  }
  return matched;
}

Future<void> pressTabUntilFocused(
  WidgetTester tester,
  Finder target, {
  int maxTabs = 80,
}) async {
  for (var i = 0; i < maxTabs; i++) {
    if (_isTargetFocused(target)) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  fail(
    'Failed to reach keyboard focus on $target within $maxTabs Tab presses.',
  );
}

Future<bool> scrollUntilFoundOrEnd(
  WidgetTester tester,
  Finder finder, {
  double delta = 240,
  int maxScrolls = 60,
}) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    return true;
  }
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return false;
  for (var i = 0; i < maxScrolls; i++) {
    await tester.drag(scrollable.first, Offset(0, -delta));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      return true;
    }
  }
  return finder.evaluate().isNotEmpty;
}

Future<void> expectCourseProgressCount(
  WidgetTester tester,
  String courseTitle,
  int completedCount, {
  bool requireDarsSuffix = true,
}) async {
  final titleFinder = find.text(courseTitle);
  await scrollUntilFoundOrEnd(tester, titleFinder);
  expect(titleFinder, findsWidgets);
  final card = find.ancestor(
    of: titleFinder.first,
    matching: find.byType(AppCard),
  );
  expect(card, findsWidgets);
  final pattern = requireDarsSuffix
      ? RegExp('^$completedCount / \\d+ dars')
      : RegExp('^$completedCount / \\d+');
  expect(
    find.descendant(of: card.first, matching: find.textContaining(pattern)),
    findsOneWidget,
  );
}

Future<void> openRoadmapNodeAction(
  WidgetTester tester,
  Pattern titlePattern, {
  List<String> buttonLabels = const [
    'Boshlash',
    'Mashq qilish',
    'Takrorlash',
    'Начать',
    'Тренировка',
    'Повторить',
  ],
  bool settle = true,
}) async {
  final titleFinder = find.textContaining(titlePattern);
  await scrollUntilFoundOrEnd(tester, titleFinder);
  expect(
    titleFinder,
    findsWidgets,
    reason: 'Expected roadmap node matching $titlePattern to be visible.',
  );

  Finder? matchedAction;
  final matchingCards = find.ancestor(
    of: titleFinder,
    matching: find.byType(AppCard),
  );
  for (final cardEl in matchingCards.evaluate()) {
    final cardFinder = find.byWidget(cardEl.widget);
    final actionInCard = find.descendant(
      of: cardFinder,
      matching: findTextAny(buttonLabels),
    );
    if (actionInCard.evaluate().isNotEmpty) {
      matchedAction = actionInCard;
      break;
    }
  }
  expect(
    matchedAction,
    isNotNull,
    reason:
        'Expected action button ($buttonLabels) on roadmap node $titlePattern.',
  );
  await tester.ensureVisible(matchedAction!.first);
  await tester.tap(matchedAction.first);
  await _pumpAfterAction(tester, settle: settle);
}

Future<void> advanceToInteractiveExerciseStep(
  WidgetTester tester, {
  int maxSteps = 8,
  bool settle = true,
}) async {
  for (var i = 0; i < maxSteps; i++) {
    final submitBtn = findTextAny(const [
      'TEKSHIRISH',
      'Проверить',
      'Yuborish',
      'Saqlash',
    ]);
    if (submitBtn.evaluate().isNotEmpty) {
      return;
    }
    for (var cardIdx = 0; cardIdx < 12; cardIdx++) {
      if (findTextAny(const ['Javobni ko‘rish', 'Показать ответ'])
          .evaluate()
          .isEmpty) {
        break;
      }
      await revealFlashcard(tester, settle: settle);
      await markFlashcardRemembered(tester, settle: settle);
    }
    if (submitBtn.evaluate().isNotEmpty) {
      return;
    }
    final nextBtn = findTextAny(const [
      'Keyingi qadam',
      'Yakunlash',
      'Следующий шаг',
      'Завершить',
    ]);
    if (nextBtn.evaluate().isEmpty) return;
    await advanceLessonStep(tester, settle: settle);
  }
}

Future<Finder> findNextUnitCardAfter(
  WidgetTester tester,
  Pattern checkpointPattern,
) async {
  final checkpointText = find.textContaining(checkpointPattern);
  await scrollUntilFoundOrEnd(tester, checkpointText, maxScrolls: 60);
  expect(
    checkpointText,
    findsWidgets,
    reason: 'Expected checkpoint node matching $checkpointPattern on roadmap.',
  );
  final checkpointCard = find.ancestor(
    of: checkpointText.first,
    matching: find.byType(AppCard),
  );
  expect(checkpointCard, findsWidgets);
  final cpWidget = tester.widget<AppCard>(checkpointCard.first);

  Finder? locateNext() {
    final allCards = find.byType(AppCard).evaluate().toList();
    final cpIdx = allCards.indexWhere((el) => identical(el.widget, cpWidget));
    if (cpIdx < 0) return null;
    for (final candidate in allCards.skip(cpIdx + 1)) {
      final candidateFinder = find.byWidget(candidate.widget);
      final isNodeCard = find.descendant(
        of: candidateFinder,
        matching: find.textContaining(
          RegExp(
            r'(daqiqa|мин|Bloklangan|Заблокировано|Faol dars|Boshlash|Mashq qilish|Takrorlash|Mustahkamlash|Начать|Тренировка|Повторить)',
          ),
        ),
      );
      if (isNodeCard.evaluate().isNotEmpty) {
        return candidateFinder;
      }
    }
    return null;
  }

  var nextCard = locateNext();
  if (nextCard == null) {
    final scrollable = find.byType(Scrollable);
    for (var i = 0; i < 6 && nextCard == null; i++) {
      if (scrollable.evaluate().isEmpty) break;
      await tester.drag(scrollable.first, const Offset(0, -240));
      await tester.pump();
      nextCard = locateNext();
    }
  }
  expect(
    nextCard,
    isNotNull,
    reason:
        'Expected a next unit / CEFR level AppCard after checkpoint $checkpointPattern.',
  );
  await tester.ensureVisible(nextCard!.first);
  return nextCard;
}

class PlacementQuestionAnswerSpec {
  final String promptUz;
  final String promptRu;
  final String correctOption;
  final String wrongOption;

  const PlacementQuestionAnswerSpec({
    required this.promptUz,
    required this.promptRu,
    required this.correctOption,
    required this.wrongOption,
  });
}

const List<PlacementQuestionAnswerSpec> englishPlacementAnswerSpecs = [
  PlacementQuestionAnswerSpec(
    promptUz:
        'Choose the best word to complete the sentence: "It is raining outside, so please take your ____ before you leave."',
    promptRu:
        'Выберите подходящее слово, чтобы дополнить предложение: «It is raining outside, so please take your ____ before you leave.»',
    correctOption: 'umbrella',
    wrongOption: 'pillow',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Complete the sentence with the most natural word: "Timur forgot his wallet at home, so he asked his friend to ____ him some money for lunch."',
    promptRu:
        'Дополните предложение наиболее подходящим словом: «Timur forgot his wallet at home, so he asked his friend to ____ him some money for lunch.»',
    correctOption: 'lend',
    wrongOption: 'borrow',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Choose the word that best fits the context: "To ____ traffic jams during the morning rush, many office workers take the metro instead of driving."',
    promptRu:
        'Выберите слово, наиболее подходящее по смыслу: «To ____ traffic jams during the morning rush, many office workers take the metro instead of driving.»',
    correctOption: 'avoid',
    wrongOption: 'create',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Choose the correct option to complete the sentence: "There ____ three books on the teacher’s desk."',
    promptRu:
        'Выберите правильный вариант для дополнения предложения: «There ____ three books on the teacher’s desk.»',
    correctOption: 'are',
    wrongOption: 'is',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Choose the correct verb form: "Yesterday evening, Madina ____ fresh fruit at the market on her way home."',
    promptRu:
        'Выберите правильную форму глагола: «Yesterday evening, Madina ____ fresh fruit at the market on her way home.»',
    correctOption: 'bought',
    wrongOption: 'buys',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Choose the grammatically correct option: "Dilshod has lived in Samarkand ____ 2019, so he knows the old city very well."',
    promptRu:
        'Выберите грамматически правильный вариант: «Dilshod has lived in Samarkand ____ 2019, so he knows the old city very well.»',
    correctOption: 'since',
    wrongOption: 'for',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Listen to the conversation. What time does the music club start?',
    promptRu:
        'Прослушайте диалог. Во сколько начинается музыкальный кружок?',
    correctOption: '09:00 in the morning',
    wrongOption: '09:00 in the evening',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Listen to the phone call. When is the beginner swimming class this week?',
    promptRu:
        'Прослушайте телефонный разговор. Когда пройдёт занятие по плаванию для начинающих на этой неделе?',
    correctOption: 'Thursday at 16:00',
    wrongOption: 'Wednesday at 16:00',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Listen to the conversation. What will the speakers do for the morning session?',
    promptRu:
        'Прослушайте разговор. Что собеседники сделают для утренней сессии?',
    correctOption:
        'Send the PDF link in the group chat first and give out booklets after lunch',
    wrongOption: 'Cancel the morning session and wait until two o’clock',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Read the sign: "Green Park Bookshop. Open Monday to Saturday from 9:00 AM to 6:00 PM. Closed on Sunday." When can a customer visit the bookshop?',
    promptRu:
        'Прочитайте вывеску: «Green Park Bookshop. Open Monday to Saturday from 9:00 AM to 6:00 PM. Closed on Sunday.» Когда покупатель может посетить книжный магазин?',
    correctOption: 'On Wednesday at 11:00 AM',
    wrongOption: 'On Sunday at 11:00 AM',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Read the message from Anvar: "Hi Jasur, the weather forecast says heavy rain tomorrow, so we are going to play chess at my house instead of football in the park. See you at 3:00 PM!" Why did Anvar change the plan?',
    promptRu:
        'Прочитайте сообщение от Анвара: «Hi Jasur, the weather forecast says heavy rain tomorrow, so we are going to play chess at my house instead of football in the park. See you at 3:00 PM!» Почему Анвар изменил план?',
    correctOption: 'Bad weather is expected tomorrow',
    wrongOption: 'The park is closed at 3:00 PM',
  ),
  PlacementQuestionAnswerSpec(
    promptUz:
        'Read the notice: "City Bike Pass members can ride for up to 45 minutes per trip at no extra cost. However, if a ride lasts longer than 45 minutes and the rider does not report a dock problem, an hourly fee is charged." How can a member avoid paying the extra fee?',
    promptRu:
        'Прочитайте объявление: «City Bike Pass members can ride for up to 45 minutes per trip at no extra cost. However, if a ride lasts longer than 45 minutes and the rider does not report a dock problem, an hourly fee is charged.» Как участник может избежать дополнительной платы?',
    correctOption: 'Return the bike within 45 minutes',
    wrongOption: 'Use the bike only once a week',
  ),
];

final RegExp englishPlacementTranscriptRegex = RegExp(
  r"(Lola:|nine o'clock in the morning|City Sports Center|four o'clock in the afternoon|workshop booklets|print shop)",
  caseSensitive: false,
);

Future<void> answerCurrentPlacementQuestion(
  WidgetTester tester, {
  required bool preferCorrect,
  bool settle = true,
}) async {
  String? chosenOption;
  for (final spec in englishPlacementAnswerSpecs) {
    final matchedPrompt = find.text(spec.promptUz).evaluate().isNotEmpty ||
        find.text(spec.promptRu).evaluate().isNotEmpty;
    if (matchedPrompt) {
      final candidate = preferCorrect ? spec.correctOption : spec.wrongOption;
      if (find.text(candidate).evaluate().isNotEmpty) {
        chosenOption = candidate;
      }
      break;
    }
  }
  expect(
    chosenOption,
    isNotNull,
    reason: 'Current placement question did not match any q_eng_place_* spec.',
  );

  await tapText(tester, chosenOption!, settle: settle);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 850)),
  );
  await tester.pump(const Duration(milliseconds: 850));

  final finishBtn = findTextAny(
    const ['Natijalarni Ko‘rish', 'Посмотреть результаты'],
  );
  if (finishBtn.evaluate().isNotEmpty) {
    await tapTextAny(
      tester,
      const ['Natijalarni Ko‘rish', 'Посмотреть результаты'],
      settle: settle,
    );
    await tapTextAny(tester, const ['Topshirish', 'Отправить'], settle: settle);
  } else {
    await tapTextAny(
      tester,
      const ['Keyingi Savol', 'Следующий вопрос'],
      settle: settle,
    );
  }
}

Future<void> completeEnglishPlacementToB1(
  WidgetTester tester, {
  bool selectCourseFirst = true,
  bool settle = true,
}) async {
  if (selectCourseFirst) {
    await selectCourse(tester, 'course_eng_01', settle: settle);
  }
  await tapTextAny(
    tester,
    const ['Asoslarini bilaman', 'Знаю основы'],
    settle: settle,
  );
  await tapTextAny(
    tester,
    const [
      'Ixtiyoriy diagnostika',
      'Дополнительная диагностика',
      'Необязательная диагностика',
    ],
    settle: settle,
  );
  for (var step = 1; step <= 8; step++) {
    await answerCurrentPlacementQuestion(
      tester,
      preferCorrect: true,
      settle: settle,
    );
  }
  expect(
    find.textContaining(
      RegExp(
        r'(Tavsiya etilgan bosqich|Стартовый уровень): B1\b',
      ),
    ),
    findsOneWidget,
  );
  await tapTextAny(
    tester,
    const ['Shaxsiy yo‘lni ko‘rish', 'Посмотреть маршрут'],
    settle: settle,
  );
}

Future<Finder> findRoadmapNodeCard(
  WidgetTester tester,
  Pattern titlePattern, {
  int maxScrolls = 60,
}) async {
  final titleFinder = find.textContaining(titlePattern);
  await scrollUntilFoundOrEnd(tester, titleFinder, maxScrolls: maxScrolls);
  expect(
    titleFinder,
    findsWidgets,
    reason: 'Expected roadmap node card matching $titlePattern.',
  );
  final nodeLabelPattern = RegExp(
    r'(-Bosqich|Ixtiyoriy|-й этап|Необязательно)$',
  );
  final cardFinder = find.ancestor(
    of: titleFinder,
    matching: find.byType(AppCard),
  );
  expect(cardFinder, findsWidgets);
  Finder? matchedNodeCard;
  for (final cardEl in cardFinder.evaluate()) {
    final candidate = find.byWidget(cardEl.widget);
    if (find
        .descendant(
          of: candidate,
          matching: find.textContaining(nodeLabelPattern),
        )
        .evaluate()
        .isNotEmpty) {
      matchedNodeCard = candidate;
      break;
    }
  }
  final resolved = matchedNodeCard ?? cardFinder.first;
  await tester.ensureVisible(resolved);
  return resolved;
}

Finder findDeferredCefrCard(String level) => find.ancestor(
  of: find.text(level),
  matching: find.ancestor(
    of: findTextAny(const ['Keyingi bosqich (DEFERRED)', 'Скоро (DEFERRED)']),
    matching: find.byType(AppCard),
  ),
);

Future<void> expectDeferredCefrLevelsRendered(WidgetTester tester) async {
  final sectionHeading = findTextAny(
    const ['Keyingi darajalar (B2–C2)', 'Следующие уровни (B2–C2)'],
  );
  await scrollUntilFoundOrEnd(tester, sectionHeading, maxScrolls: 60);
  expect(
    sectionHeading,
    findsOneWidget,
    reason: 'Upcoming B2–C2 deferred levels heading must render on roadmap.',
  );
  for (final level in const ['B2', 'C1', 'C2']) {
    final card = findDeferredCefrCard(level);
    await scrollUntilFoundOrEnd(tester, card, maxScrolls: 60);
    expect(
      card,
      findsOneWidget,
      reason: 'Deferred CEFR level $level must render as an upcoming card.',
    );
    expect(
      find.descendant(
        of: card,
        matching: findTextAny(const [
          'Boshlash',
          'Mashq qilish',
          'Takrorlash',
          'Darsni boshlash',
          'Faol dars',
          'Начать',
          'Тренировка',
          'Повторить',
          'Начать урок',
        ]),
      ),
      findsNothing,
      reason: 'Deferred CEFR level $level must not expose openable buttons.',
    );
  }
}

void verifyNoExceptions(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}
