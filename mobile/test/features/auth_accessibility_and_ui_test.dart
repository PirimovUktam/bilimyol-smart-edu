import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bilimyol_mobile/app/app.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/app/router.dart';
import 'package:bilimyol_mobile/core/audio/lesson_audio_controller.dart';
import 'package:bilimyol_mobile/core/auth/demo_session.dart';
import 'package:bilimyol_mobile/core/config/supabase_config.dart';
import 'package:bilimyol_mobile/core/constants/app_colors.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/core/widgets/app_badge.dart';
import 'package:bilimyol_mobile/core/widgets/app_button.dart';
import 'package:bilimyol_mobile/core/widgets/app_card.dart';
import 'package:bilimyol_mobile/core/widgets/bilim_yol_logo.dart';
import 'package:bilimyol_mobile/core/widgets/bilimyol_bottom_nav.dart';
import 'package:bilimyol_mobile/core/widgets/edtech_section_header.dart';
import 'package:bilimyol_mobile/data/datasources/english/a1_lessons_data.dart';
import 'package:bilimyol_mobile/data/datasources/english/cefr_skeleton_data.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_learner_repository.dart';
import 'package:bilimyol_mobile/data/services/i_ai_tutor_service.dart';
import 'package:bilimyol_mobile/domain/entities/course.dart';
import 'package:bilimyol_mobile/domain/entities/learner_profile.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/lesson.dart';
import 'package:bilimyol_mobile/domain/entities/lesson_media.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/domain/repositories/i_learner_repository.dart';
import 'package:bilimyol_mobile/domain/usecases/submit_reinforcement_use_case.dart';
import 'package:bilimyol_mobile/features/ai_tutor/ai_tutor_screen.dart';
import 'package:bilimyol_mobile/features/ai_tutor/yolchi_bubble.dart';
import 'package:bilimyol_mobile/features/auth/forgot_password_screen.dart';
import 'package:bilimyol_mobile/features/auth/login_screen.dart';
import 'package:bilimyol_mobile/features/auth/register_screen.dart';
import 'package:bilimyol_mobile/features/auth/welcome_screen.dart';
import 'package:bilimyol_mobile/features/course_selection/course_selection_screen.dart';
import 'package:bilimyol_mobile/features/dashboard/dashboard_screen.dart';
import 'package:bilimyol_mobile/features/knowledge_map/knowledge_map_screen.dart';
import 'package:bilimyol_mobile/features/lesson/audio_sim_wave_widget.dart';
import 'package:bilimyol_mobile/features/lesson/flashcard_deck_widget.dart';
import 'package:bilimyol_mobile/features/lesson/interactive_lesson_screen.dart';
import 'package:bilimyol_mobile/features/lesson/lesson_media_widget.dart';
import 'package:bilimyol_mobile/features/lesson/math_function_graph_widget.dart';
import 'package:bilimyol_mobile/features/onboarding/onboarding_screen.dart';
import 'package:bilimyol_mobile/features/placement/placement_test_screen.dart';
import 'package:bilimyol_mobile/features/profile/profile_screen.dart';
import 'package:bilimyol_mobile/features/progress/progress_screen.dart';
import 'package:bilimyol_mobile/features/reinforcement/reinforcement_sheet.dart';
import 'package:bilimyol_mobile/features/roadmap/roadmap_screen.dart';

double _channelLuminance(double channel) {
  return channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color color) {
  final r = _channelLuminance(color.r);
  final g = _channelLuminance(color.g);
  final b = _channelLuminance(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color fg, Color bg) {
  final effectiveFg = fg.a < 1.0 ? Color.alphaBlend(fg, bg) : fg;
  final l1 = _relativeLuminance(effectiveFg);
  final l2 = _relativeLuminance(bg);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

class _FakeActivityLearnerRepository extends SupabaseLearnerRepository {
  @override
  Future<List<DailyActivitySummary>> getDailyActivity([int days = 7]) async {
    final anchor = DateTime(2026, 11, 20);
    return List.generate(days, (i) {
      final d = anchor.subtract(Duration(days: days - 1 - i));
      final dateStr = d.toIso8601String().substring(0, 10);
      return DailyActivitySummary(
        date: dateStr,
        activeMinutes: 30 + (i % 5) * 15,
        xpEarned: 20 + (i % 4) * 10,
        lessonsCompleted: 1 + (i % 2),
      );
    });
  }
}

class _FakeOnlineAITutorService implements IAITutorService {
  final bool shouldFail;

  const _FakeOnlineAITutorService({this.shouldFail = false});

  @override
  Future<AskTutorResponse> askTutor(AskTutorRequest request) async {
    if (shouldFail) {
      throw Exception('network timeout');
    }
    return const AskTutorResponse(
      tutorName: 'Yo‘lchi AI',
      answer: 'Test AI javob matni.',
      isAiGenerated: true,
    );
  }

  @override
  Future<AIExplanationResponse> explainMistake(
    AIExplanationRequest request,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<GeneratedLessonResponse> generateLesson(
    GenerateLessonRequest request,
  ) async {
    throw UnimplementedError();
  }
}

Widget _wrapScreen(
  Widget child, {
  required ThemeData theme,
  double textScale = 1.0,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Locale? locale,
  Key? scopeKey,
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    key: scopeKey,
    overrides: [
      lessonAudioControllerFactoryProvider.overrideWithValue(
        () => FakeLessonAudioController(),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      builder: (context, inner) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: viewInsets,
          ),
          child: inner!,
        );
      },
      home: child,
    ),
  );
}

void _configurePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpWithAllErrorsChecked(
  WidgetTester tester,
  Future<void> Function() act,
) async {
  final errors = <FlutterErrorDetails>[];
  final prevOnError = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await act();
  } finally {
    FlutterError.onError = prevOnError;
  }
  expect(
    errors,
    isEmpty,
    reason: errors.map((e) => e.exceptionAsString()).join('\n'),
  );
}

void _assertNoZeroWidthText(
  WidgetTester tester, {
  required String screenName,
}) {
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    final label = text.data ?? text.textSpan?.toPlainText() ?? '';
    if (label.trim().isEmpty) continue;
    final box = element.renderObject;
    if (box is RenderBox && box.hasSize) {
      expect(
        box.size.width,
        greaterThan(0.0),
        reason: 'Zero-width crushed Text("$label") on $screenName',
      );
    }
  }
}

void _assertNoUnexpectedTruncation(
  WidgetTester tester, {
  required String screenName,
}) {
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    final label = text.data ?? text.textSpan?.toPlainText() ?? '';
    if (label.trim().isEmpty) continue;
    var inAppBar = false;
    var inInputDecorator = false;
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      if (w is AppBar) inAppBar = true;
      if (w is InputDecorator) inInputDecorator = true;
      return !(inAppBar && inInputDecorator);
    });
    if (!inAppBar &&
        text.maxLines == 2 &&
        text.overflow == TextOverflow.ellipsis) {
      continue;
    }
    if (inInputDecorator) {
      continue;
    }
    final ro = element.renderObject;
    if (ro is RenderParagraph && ro.hasSize) {
      expect(
        ro.didExceedMaxLines,
        isFalse,
        reason: 'Unexpected truncation of Text("$label") on $screenName',
      );
    }
  }
  _assertAppBarNoClipping(tester, screenName: screenName);
}

void _assertAppBarNoClipping(
  WidgetTester tester, {
  required String screenName,
}) {
  for (final appBarEl in find.byType(AppBar).evaluate()) {
    if (!(ModalRoute.of(appBarEl)?.isCurrent ?? true)) continue;
    final appBarBox = appBarEl.renderObject;
    if (appBarBox is! RenderBox || !appBarBox.hasSize) continue;
    final appBarRect = appBarBox.localToGlobal(Offset.zero) & appBarBox.size;
    final appBarFinder = find.byElementPredicate((el) => el == appBarEl);
    for (final textEl
        in find
            .descendant(of: appBarFinder, matching: find.byType(Text))
            .evaluate()) {
      final text = textEl.widget as Text;
      final label = text.data ?? text.textSpan?.toPlainText() ?? '';
      if (label.trim().isEmpty) continue;
      final ro = textEl.renderObject;
      if (ro is RenderParagraph && ro.hasSize) {
        expect(
          ro.didExceedMaxLines,
          isFalse,
          reason: 'AppBar Text("$label") exceeded maxLines on $screenName',
        );
        if (ro.overflow == TextOverflow.visible) {
          expect(
            ro.softWrap,
            isTrue,
            reason:
                'AppBar Text("$label") uses TextOverflow.visible without softWrap=true on $screenName',
          );
        }
        for (var i = 0; i < label.length; i++) {
          if (label[i].trim().isEmpty) continue;
          final boxes = ro.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          );
          for (final b in boxes) {
            expect(
              b.right,
              lessThanOrEqualTo(ro.size.width + 0.5),
              reason:
                  'AppBar Text("$label") horizontal overflow at char $i (${b.right} > ${ro.size.width}) on $screenName',
            );
          }
        }
        final textRect = ro.localToGlobal(Offset.zero) & ro.size;
        expect(
          textRect.top,
          greaterThanOrEqualTo(appBarRect.top - 0.5),
          reason:
              'AppBar Text("$label") top clipped on $screenName ($textRect vs $appBarRect)',
        );
        expect(
          textRect.bottom,
          lessThanOrEqualTo(appBarRect.bottom + 0.5),
          reason:
              'AppBar Text("$label") bottom clipped on $screenName ($textRect vs $appBarRect)',
        );
      }
    }
  }
}

void _assertNoButtonOverlaps(
  WidgetTester tester, [
  Iterable<Finder>? finders,
]) {
  final effectiveFinders =
      finders ??
      [
        find.byType(ElevatedButton),
        find.byType(FilledButton),
        find.byType(OutlinedButton),
        find.byType(TextButton),
        find.byType(AppButton),
        find.byType(IconButton),
      ];
  final seen = <Element>{};
  final rects = <Rect>[];
  for (final finder in effectiveFinders) {
    for (final element in finder.evaluate()) {
      if (!seen.add(element)) continue;
      if (!(ModalRoute.of(element)?.isCurrent ?? true)) continue;
      final box = element.renderObject;
      if (box is RenderBox &&
          box.hasSize &&
          box.size.width > 0 &&
          box.size.height > 0) {
        rects.add(box.localToGlobal(Offset.zero) & box.size);
      }
    }
  }
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      expect(
        rects[i].overlaps(rects[j]),
        isFalse,
        reason: 'Buttons overlap: ${rects[i]} vs ${rects[j]}',
      );
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    demoSessionActive.value = true;
  });

  tearDown(() {
    demoSessionActive.value = false;
  });

  group('Light & Dark WCAG Contrast Contracts', () {
    for (final isDark in [false, true]) {
      ThemeData buildTheme() =>
          isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
      final bg = isDark ? AppColors.darkBackground : AppColors.background;
      final surface = isDark ? AppColors.darkSurface : AppColors.surface;
      final subtle = isDark
          ? AppColors.darkSubtleSurface
          : const Color(0xFFF1F5F9);
      final modeLabel = isDark ? 'Dark' : 'Light';

      testWidgets(
        'BilimYolLogo scales via Text.rich and meets contrast in $modeLabel',
        (tester) async {
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: const Center(child: BilimYolLogo(size: 40)),
              ),
              theme: buildTheme(),
            ),
          );
          await tester.pump();

          expect(find.byType(RichText), findsWidgets);
          final logoText = tester.widget<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.textSpan != null &&
                  w.textSpan!.toPlainText() == 'BilimYo‘l',
            ),
          );
          final rootSpan = logoText.textSpan! as TextSpan;
          final bilimColor = rootSpan.style!.color!;
          final yolColor = (rootSpan.children![1] as TextSpan).style!.color!;
          final subtitle = tester.widget<Text>(
            find.text('Moslashuvchan ta’lim platformasi'),
          );
          final subtitleColor = subtitle.style!.color!;

          expect(_contrastRatio(bilimColor, bg), greaterThanOrEqualTo(4.5));
          expect(_contrastRatio(yolColor, bg), greaterThanOrEqualTo(3.0));
          expect(_contrastRatio(subtitleColor, bg), greaterThanOrEqualTo(4.5));
        },
      );

      testWidgets(
        'WelcomeScreen links and ListTile items meet contrast in $modeLabel',
        (tester) async {
          await tester.pumpWidget(
            _wrapScreen(const WelcomeScreen(), theme: buildTheme()),
          );
          await tester.pumpAndSettle();

          final loginBtn = tester.widget<TextButton>(
            find.widgetWithText(TextButton, 'Kirish'),
          );
          final ctx = tester.element(find.widgetWithText(TextButton, 'Kirish'));
          final btnFg =
              loginBtn.style?.foregroundColor?.resolve({}) ??
              Theme.of(ctx).textButtonTheme.style?.foregroundColor?.resolve({}) ??
              Theme.of(ctx).colorScheme.primary;
          expect(_contrastRatio(btnFg, bg), greaterThanOrEqualTo(4.5));

          final stepTitle = tester.widget<Text>(find.text('Fanni tanlang'));
          final tintBg =
              isDark ? const Color(0xFF312E81) : AppColors.primaryLight;
          expect(
            _contrastRatio(stepTitle.style!.color!, tintBg),
            greaterThanOrEqualTo(4.5),
          );
        },
      );

      testWidgets(
        'RegisterScreen & ForgotPasswordScreen labels, inputs, banners meet contrast in $modeLabel',
        (tester) async {
          final theme = buildTheme();
          await tester.pumpWidget(
            _wrapScreen(const RegisterScreen(), theme: theme),
          );
          await tester.pumpAndSettle();

          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          expect(scaffold.backgroundColor, equals(bg));

          for (final label in [
            'Ism *',
            'Email *',
            'Parol *',
            'Parolni tasdiqlang *',
          ]) {
            final text = tester.widget<Text>(find.text(label));
            expect(
              _contrastRatio(text.style!.color!, surface),
              greaterThanOrEqualTo(4.5),
              reason: '$label contrast on $surface in $modeLabel',
            );
          }

          final fields = tester.widgetList<TextField>(find.byType(TextField));
          expect(fields.length, equals(4));
          for (final field in fields) {
            final dec = field.decoration!;
            final fill = dec.fillColor!;
            final textColor = field.style!.color!;
            final hintColor = dec.hintStyle!.color!;
            final iconColor = (dec.prefixIcon! as Icon).color!;
            expect(_contrastRatio(textColor, fill), greaterThanOrEqualTo(4.5));
            expect(_contrastRatio(hintColor, fill), greaterThanOrEqualTo(4.5));
            expect(_contrastRatio(iconColor, fill), greaterThanOrEqualTo(3.0));
          }

          await tester.pumpWidget(
            _wrapScreen(const ForgotPasswordScreen(), theme: theme),
          );
          await tester.pumpAndSettle();

          final forgotScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          expect(forgotScaffold.backgroundColor, equals(bg));
          final emailLabel = tester.widget<Text>(find.text('Email'));
          expect(
            _contrastRatio(emailLabel.style!.color!, surface),
            greaterThanOrEqualTo(4.5),
          );
          final forgotField = tester.widget<TextField>(find.byType(TextField));
          expect(
            _contrastRatio(
              forgotField.style!.color!,
              forgotField.decoration!.fillColor!,
            ),
            greaterThanOrEqualTo(4.5),
          );
        },
      );

      testWidgets(
        'Unfocused input boundaries (enabledBorder) meet 3:1 non-text contrast in $modeLabel',
        (tester) async {
          final theme = buildTheme();
          Color enabledSide(TextField field) =>
              (field.decoration!.enabledBorder! as OutlineInputBorder)
                  .borderSide
                  .color;

          // Theme default (DictionarySheet, ResetPasswordScreen, ReinforcementSheet).
          final themeSide =
              (theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
                  .borderSide
                  .color;
          expect(_contrastRatio(themeSide, surface), greaterThanOrEqualTo(3.0));
          expect(_contrastRatio(themeSide, subtle), greaterThanOrEqualTo(3.0));

          await tester.pumpWidget(
            _wrapScreen(const RegisterScreen(), theme: theme),
          );
          await tester.pumpAndSettle();
          final registerFields =
              tester.widgetList<TextField>(find.byType(TextField));
          expect(registerFields.length, equals(4));
          for (final field in registerFields) {
            final side = enabledSide(field);
            expect(
              _contrastRatio(side, field.decoration!.fillColor!),
              greaterThanOrEqualTo(3.0),
            );
            expect(_contrastRatio(side, surface), greaterThanOrEqualTo(3.0));
          }

          await tester.pumpWidget(
            _wrapScreen(const ForgotPasswordScreen(), theme: theme),
          );
          await tester.pumpAndSettle();
          final forgotField = tester.widget<TextField>(find.byType(TextField));
          expect(
            _contrastRatio(
              enabledSide(forgotField),
              forgotField.decoration!.fillColor!,
            ),
            greaterThanOrEqualTo(3.0),
          );
          expect(
            _contrastRatio(enabledSide(forgotField), surface),
            greaterThanOrEqualTo(3.0),
          );

          await tester.pumpWidget(
            _wrapScreen(const LoginScreen(), theme: theme),
          );
          await tester.pumpAndSettle();
          final loginFields =
              tester.widgetList<TextField>(find.byType(TextField));
          expect(loginFields.length, equals(2));
          for (final field in loginFields) {
            final side = enabledSide(field);
            expect(
              _contrastRatio(side, field.decoration!.fillColor!),
              greaterThanOrEqualTo(3.0),
            );
            expect(
              _contrastRatio(side, Colors.white),
              greaterThanOrEqualTo(3.0),
            );
          }
        },
      );

      testWidgets(
        'LoginScreen onDark logo and white-card inputs meet contrast in $modeLabel',
        (tester) async {
          await tester.pumpWidget(
            _wrapScreen(const LoginScreen(), theme: buildTheme()),
          );
          await tester.pumpAndSettle();

          final logo = tester.widget<BilimYolLogo>(find.byType(BilimYolLogo));
          expect(logo.onDark, isTrue);

          final fields = tester.widgetList<TextField>(find.byType(TextField));
          expect(fields.length, equals(2));
          for (final field in fields) {
            final dec = field.decoration!;
            final fill = dec.fillColor!;
            expect(
              _contrastRatio(field.style!.color!, fill),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              _contrastRatio(dec.hintStyle!.color!, fill),
              greaterThanOrEqualTo(4.5),
            );
          }

          final yoki = tester.widget<Text>(find.text('yoki'));
          expect(
            _contrastRatio(yoki.style!.color!, Colors.white),
            greaterThanOrEqualTo(4.5),
          );
        },
      );

      testWidgets(
        'CourseSelectionScreen (unselected & selected), KnowledgeMapScreen, ProgressScreen, ProfileScreen, BottomNav & AppBadge meet contrast in $modeLabel',
        (tester) async {
          final theme = buildTheme();
          await tester.pumpWidget(
            _wrapScreen(const CourseSelectionScreen(), theme: theme),
          );
          await tester.pumpAndSettle();

          final indicators = tester.widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(indicators, isNotEmpty);
          for (final ind in indicators) {
            final track = ind.backgroundColor!;
            final fill =
                (ind.valueColor! as AlwaysStoppedAnimation<Color>).value;
            expect(_contrastRatio(fill, track), greaterThanOrEqualTo(3.0));
            expect(_contrastRatio(fill, surface), greaterThanOrEqualTo(3.0));
          }

          // Item (a): Selected CourseSelectionScreen card contrast
          final csContainer = ProviderScope.containerOf(
            tester.element(find.byType(CourseSelectionScreen)),
          );
          await csContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await csContainer
              .read(learnerStateNotifierProvider.notifier)
              .updateOnboarding(
                courseId: 'course_eng_01',
                goal: OnboardingGoal.skillsBoost,
                dailyMinutes: 15,
                initialLevel: InitialLevel.beginner,
              );
          await tester.pumpAndSettle();

          expect(find.text('Tanlangan'), findsOneWidget);
          final selectedCard = find
              .ancestor(
                of: find.text('Tanlangan'),
                matching: find.byType(AppCard),
              )
              .first;
          final tintBg =
              isDark ? const Color(0xFF312E81) : AppColors.primaryLight;
          final selectedCardBg = Color.alphaBlend(
            tintBg.withValues(alpha: 0.45),
            bg,
          );
          final selectedDesc = tester.widget<Text>(
            find
                .descendant(
                  of: selectedCard,
                  matching: find.textContaining('Lug‘at, grammatika'),
                )
                .first,
          );
          final selectedDescColor =
              selectedDesc.style?.color ??
              DefaultTextStyle.of(
                tester.element(find.byWidget(selectedDesc)),
              ).style.color!;
          expect(
            _contrastRatio(selectedDescColor, selectedCardBg),
            greaterThanOrEqualTo(4.5),
            reason:
                'Selected CourseSelectionScreen description contrast in $modeLabel',
          );
          final selectedMeta = tester.widget<Text>(
            find
                .descendant(
                  of: selectedCard,
                  matching: find.textContaining('dars · +'),
                )
                .first,
          );
          expect(
            _contrastRatio(selectedMeta.style!.color!, selectedCardBg),
            greaterThanOrEqualTo(4.5),
            reason:
                'Selected CourseSelectionScreen metadata contrast in $modeLabel',
          );

          // Item (e) part 1: KnowledgeMapScreen with seeded scores + errorTint banner
          await tester.pumpWidget(
            _wrapScreen(const KnowledgeMapScreen(), theme: theme),
          );
          await tester.pumpAndSettle();
          final kmContainer = ProviderScope.containerOf(
            tester.element(find.byType(KnowledgeMapScreen)),
          );
          await kmContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await kmContainer
              .read(learnerStateNotifierProvider.notifier)
              .seedQuickDemo();
          await tester.pumpAndSettle();

          final kmScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          expect(kmScaffold.backgroundColor, equals(bg));
          expect(find.byType(EdTechSectionHeader), findsOneWidget);

          final kmHeaderLabel = tester.widget<Text>(
            find.text('Umumiy O‘zlashtirish'),
          );
          final kmHeaderSub = tester.widget<Text>(
            find.text(
              'Haqiqiy javoblaringiz tahlili asosida bilim xaritangiz shakllantirildi.',
            ),
          );
          expect(
            _contrastRatio(
              kmHeaderLabel.style!.color!,
              const Color(0xFF0F172A),
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrastRatio(
              kmHeaderSub.style!.color!,
              const Color(0xFF0F172A),
            ),
            greaterThanOrEqualTo(4.5),
          );

          final weakAlertFinder = find.text(
            'Yo‘l xaritasida ushbu mavzuga maxsus mustahkamlash qadami qo‘shildi.',
          );
          expect(weakAlertFinder, findsOneWidget);
          final weakAlertSub = tester.widget<Text>(weakAlertFinder);
          expect(
            _contrastRatio(
              weakAlertSub.style!.color!,
              AppColors.errorTint(tester.element(weakAlertFinder)),
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'KnowledgeMap errorTint explanation contrast in $modeLabel',
          );

          final skillDescFinder = find.textContaining('so‘z boyligi').first;
          final skillDesc = tester.widget<Text>(skillDescFinder);
          expect(
            _contrastRatio(skillDesc.style!.color!, surface),
            greaterThanOrEqualTo(4.5),
          );

          // Item (e) part 2: ProgressScreen interior cards
          await tester.pumpWidget(
            _wrapScreen(const ProgressScreen(), theme: theme),
          );
          await tester.pumpAndSettle();
          final progScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          expect(progScaffold.backgroundColor, equals(bg));
          for (final label in [
            'Bajarilgan dars',
            'O‘zlashtirish',
            'O‘qish vaqti',
          ]) {
            final t = tester.widget<Text>(find.text(label));
            expect(
              _contrastRatio(t.style!.color!, surface),
              greaterThanOrEqualTo(4.5),
              reason: 'ProgressScreen "$label" contrast in $modeLabel',
            );
          }
          final badgeTitle = tester.widget<Text>(find.text('Ilk Qadam'));
          final badgeDesc = tester.widget<Text>(
            find.text('Birinchi dars yakunlandi'),
          );
          expect(
            _contrastRatio(badgeTitle.style!.color!, subtle),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrastRatio(badgeDesc.style!.color!, subtle),
            greaterThanOrEqualTo(4.5),
          );

          // ProfileScreen
          await tester.pumpWidget(
            _wrapScreen(const ProfileScreen(), theme: theme),
          );
          await tester.pumpAndSettle();
          final demoLabel = tester.widget<Text>(find.text('Namuna hisobi'));
          expect(
            _contrastRatio(demoLabel.style!.color!, surface),
            greaterThanOrEqualTo(4.5),
          );
          final schoolIcon = tester.widget<Icon>(
            find.byIcon(Icons.school_rounded),
          );
          expect(
            _contrastRatio(schoolIcon.color!, surface),
            greaterThanOrEqualTo(3.0),
          );

          // BilimYolBottomNav
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                bottomNavigationBar: const BilimYolBottomNav(currentIndex: 0),
              ),
              theme: theme,
            ),
          );
          await tester.pumpAndSettle();
          final navText = tester.widget<Text>(find.text('Natijalar'));
          expect(
            _contrastRatio(navText.style!.color!, surface),
            greaterThanOrEqualTo(4.5),
          );

          // Item (d): Verify ALL 6 AppBadge variants
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: const Column(
                  children: [
                    AppBadge(text: 'Blue', variant: AppBadgeVariant.blue),
                    AppBadge(text: 'Teal', variant: AppBadgeVariant.teal),
                    AppBadge(text: 'Amber', variant: AppBadgeVariant.amber),
                    AppBadge(text: 'Rose', variant: AppBadgeVariant.rose),
                    AppBadge(text: 'Emerald', variant: AppBadgeVariant.emerald),
                    AppBadge(text: 'Slate', variant: AppBadgeVariant.slate),
                  ],
                ),
              ),
              theme: theme,
            ),
          );
          await tester.pump();
          for (final label in [
            'Blue',
            'Teal',
            'Amber',
            'Rose',
            'Emerald',
            'Slate',
          ]) {
            final textFinder = find.text(label);
            final textWidget = tester.widget<Text>(textFinder);
            final badgeContainer = tester.widget<Container>(
              find
                  .ancestor(
                    of: textFinder,
                    matching: find.byType(Container),
                  )
                  .first,
            );
            final boxDec = badgeContainer.decoration! as BoxDecoration;
            final effectiveBg = Color.alphaBlend(boxDec.color!, bg);
            expect(
              _contrastRatio(textWidget.style!.color!, effectiveBg),
              greaterThanOrEqualTo(4.5),
              reason: 'AppBadge($label) contrast in $modeLabel',
            );
          }
        },
      );

      // Item (c): InteractiveLessonScreen, ReinforcementSheet, AudioSimWaveWidget & PlacementTestScreen contrast
      testWidgets(
        'InteractiveLessonScreen, ReinforcementSheet, AudioSimWaveWidget & PlacementTestScreen meet contrast in $modeLabel',
        (tester) async {
          final theme = buildTheme();

          // 1. Free-text focusedBorder + progress bar
          await tester.pumpWidget(
            _wrapScreen(const InteractiveLessonScreen(), theme: theme),
          );
          await tester.pumpAndSettle();
          final lessonContainer = ProviderScope.containerOf(
            tester.element(find.byType(InteractiveLessonScreen)),
          );
          await lessonContainer
              .read(courseStateNotifierProvider.notifier)
              .init();
          await lessonContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await lessonContainer
              .read(lessonSessionNotifierProvider.notifier)
              .startLesson('lesson_eng_a1_m2_daily_life', uiLocale: 'uz');
          await lessonContainer
              .read(lessonSessionNotifierProvider.notifier)
              .nextStep(uiLocale: 'uz');
          await lessonContainer
              .read(lessonSessionNotifierProvider.notifier)
              .nextStep(uiLocale: 'uz');
          await tester.pumpAndSettle();

          final stepProgress = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator).first,
          );
          final stepTrack = stepProgress.backgroundColor!;
          final stepFill =
              (stepProgress.valueColor! as AlwaysStoppedAnimation<Color>).value;
          expect(
            _contrastRatio(stepFill, stepTrack),
            greaterThanOrEqualTo(3.0),
          );

          final freeText = tester.widget<TextField>(
            find.byKey(const Key('free_text_answer_input')),
          );
          final focusedSide =
              (freeText.decoration!.focusedBorder! as OutlineInputBorder)
                  .borderSide;
          expect(
            _contrastRatio(focusedSide.color, subtle),
            greaterThanOrEqualTo(3.0),
          );
          expect(
            _contrastRatio(focusedSide.color, surface),
            greaterThanOrEqualTo(3.0),
          );
          final enabledFreeTextSide =
              (freeText.decoration!.enabledBorder! as OutlineInputBorder)
                  .borderSide;
          expect(
            _contrastRatio(enabledFreeTextSide.color, subtle),
            greaterThanOrEqualTo(3.0),
          );
          expect(
            _contrastRatio(enabledFreeTextSide.color, surface),
            greaterThanOrEqualTo(3.0),
          );

          // 2. WordMatch active border on primaryTint
          await lessonContainer
              .read(lessonSessionNotifierProvider.notifier)
              .startLesson('lesson_eng_a1_m1_greetings', uiLocale: 'uz');
          await tester.pumpAndSettle();
          for (var i = 0; i < 3; i++) {
            await lessonContainer
                .read(lessonSessionNotifierProvider.notifier)
                .nextStep(uiLocale: 'uz');
          }
          await tester.pumpAndSettle();
          await tester.tap(find.text('Good morning'));
          await tester.pump();

          final activeMatchContainer = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('Good morning'),
                  matching: find.byType(Container),
                )
                .first,
          );
          final matchDec = activeMatchContainer.decoration! as BoxDecoration;
          expect(
            _contrastRatio(matchDec.border!.top.color, matchDec.color!),
            greaterThanOrEqualTo(3.0),
            reason: 'Active wordMatch border vs primaryTint in $modeLabel',
          );

          // Complete one match pair and verify matched border on successTint >= 3.0:1
          final rightMatchChip = find.text('Xayrli tong');
          await tester.ensureVisible(rightMatchChip);
          await tester.pumpAndSettle();
          await tester.tap(rightMatchChip);
          await tester.pump();
          final matchedContainer = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('Good morning'),
                  matching: find.byType(Container),
                )
                .first,
          );
          final matchedDec = matchedContainer.decoration! as BoxDecoration;
          expect(
            _contrastRatio(
              matchedDec.border!.top.color,
              matchedDec.color!,
            ),
            greaterThanOrEqualTo(3.0),
            reason: 'Matched wordMatch border vs successTint in $modeLabel',
          );

          // 3. Multiple-choice inline 'to‘g‘ri javob' pill + isWrongPick border/icon + errorTint explanation
          await lessonContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_math_01');
          await lessonContainer
              .read(lessonSessionNotifierProvider.notifier)
              .startLesson('lesson_math_starter', uiLocale: 'uz');
          await tester.pumpAndSettle();
          for (var i = 0; i < 2; i++) {
            await lessonContainer
                .read(lessonSessionNotifierProvider.notifier)
                .nextStep(uiLocale: 'uz');
          }
          await tester.pumpAndSettle();
          await tester.tap(find.text('2').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('TEKSHIRISH'));
          await tester.pumpAndSettle();

          final cancelIconFinder = find.byIcon(Icons.cancel_rounded);
          expect(cancelIconFinder, findsOneWidget);
          final cancelIcon = tester.widget<Icon>(cancelIconFinder);
          final wrongTintBg = AppColors.errorTint(
            tester.element(cancelIconFinder),
          );
          expect(
            _contrastRatio(cancelIcon.color!, wrongTintBg),
            greaterThanOrEqualTo(3.0),
            reason: 'isWrongPick cancel icon vs errorTint in $modeLabel',
          );
          final wrongOptionContainer = tester.widget<Container>(
            find
                .ancestor(
                  of: cancelIconFinder,
                  matching: find.byType(Container),
                )
                .first,
          );
          final wrongOptionDec =
              wrongOptionContainer.decoration! as BoxDecoration;
          expect(
            _contrastRatio(wrongOptionDec.border!.top.color, wrongTintBg),
            greaterThanOrEqualTo(3.0),
            reason: 'isWrongPick border vs errorTint in $modeLabel',
          );

          final pillFinder = find.text('to‘g‘ri javob');
          expect(pillFinder, findsOneWidget);
          final pillText = tester.widget<Text>(pillFinder);
          final pillContainer = tester.widget<Container>(
            find
                .ancestor(
                  of: pillFinder,
                  matching: find.byType(Container),
                )
                .first,
          );
          final pillBg = (pillContainer.decoration! as BoxDecoration).color!;
          expect(
            _contrastRatio(pillText.style!.color!, pillBg),
            greaterThanOrEqualTo(4.5),
            reason: 'Inline "to‘g‘ri javob" pill contrast in $modeLabel',
          );

          final lessonErrFinder = find.text(
            '4 ta va 2 ta qalamni birlashtiramiz. 4 + 2 = 6.',
          );
          expect(lessonErrFinder, findsOneWidget);
          final lessonErrText = tester.widget<Text>(lessonErrFinder);
          expect(
            _contrastRatio(
              lessonErrText.style!.color!,
              AppColors.errorTint(tester.element(lessonErrFinder)),
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'InteractiveLesson errorTint explanation in $modeLabel',
          );

          // 3b. Inline success banner check icon on successTint >= 3.0:1
          await lessonContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await lessonContainer
              .read(lessonSessionNotifierProvider.notifier)
              .startLesson('lesson_eng_a1_m1_speaking', uiLocale: 'uz');
          await tester.pumpAndSettle();
          for (var i = 0; i < 2; i++) {
            await lessonContainer
                .read(lessonSessionNotifierProvider.notifier)
                .nextStep(uiLocale: 'uz');
          }
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('self_assessed_text_input')),
            'Hello! My name is Dilnoza. I am from Tashkent. Nice to meet you.',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('TEKSHIRISH'));
          await tester.pumpAndSettle();
          final bannerCheckFinder = find.byIcon(Icons.check_circle_rounded);
          expect(bannerCheckFinder, findsOneWidget);
          final bannerCheckIcon = tester.widget<Icon>(bannerCheckFinder);
          expect(
            _contrastRatio(
              bannerCheckIcon.color!,
              AppColors.successTint(tester.element(bannerCheckFinder)),
            ),
            greaterThanOrEqualTo(3.0),
            reason:
                'Inline success banner check icon vs successTint in $modeLabel',
          );

          // 4. AudioSimWaveWidget transcript contrast
          await tester.pumpWidget(
            _wrapScreen(
              const Scaffold(
                body: AudioSimWaveWidget(
                  transcript: 'Aziza: Hi, I am Aziza.',
                  speakerName: 'Aziza',
                ),
              ),
              theme: theme,
            ),
          );
          await tester.pump();
          final transcriptText = tester.widget<Text>(
            find.text('Aziza: Hi, I am Aziza.'),
          );
          expect(
            _contrastRatio(transcriptText.style!.color!, subtle),
            greaterThanOrEqualTo(4.5),
          );

          // 5. ReinforcementSheet bolt icon, wrong-answer explanation, correct badge
          final sampleQuestion = const Question(
            id: 'q_reinf_test',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            text: 'Choose the polite greeting:',
            options: ['Goodbye.', 'Nice to meet you.'],
            correctIndex: 1,
            difficulty: QuestionDifficulty.easy,
            explanation: 'Use "Nice to meet you." when meeting someone.',
          );
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                body: ReinforcementSheet(
                  question: sampleQuestion,
                  onSubmit: (idx) async => const ReinforcementResult(
                    isCorrect: false,
                    oldScore: 40,
                    newScore: 40,
                    xpAwarded: 0,
                    updatedRoadmap: LearningPath(
                      id: 'lp_test',
                      courseId: 'course_eng_01',
                      title: 'Test',
                      nodes: [],
                      activeNodeId: '',
                      updatedAt: 0,
                    ),
                  ),
                  onGoToDashboard: () {},
                ),
              ),
              theme: theme,
            ),
          );
          await tester.pumpAndSettle();

          final boltFinder = find.byIcon(Icons.bolt_rounded);
          final boltIcon = tester.widget<Icon>(boltFinder);
          expect(
            _contrastRatio(
              boltIcon.color!,
              AppColors.warningTint(tester.element(boltFinder)),
            ),
            greaterThanOrEqualTo(3.0),
          );

          await tester.tap(find.text('Goodbye.'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Javobni Tekshirish'));
          await tester.pumpAndSettle();

          final reinfExpFinder = find.text(
            'Use "Nice to meet you." when meeting someone.',
          );
          expect(reinfExpFinder, findsOneWidget);
          final reinfExp = tester.widget<Text>(reinfExpFinder);
          expect(
            _contrastRatio(
              reinfExp.style!.color!,
              AppColors.errorTint(tester.element(reinfExpFinder)),
            ),
            greaterThanOrEqualTo(4.5),
          );

          final letterB = tester.widget<Text>(find.text('B'));
          final letterBBox = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('B'),
                  matching: find.byType(Container),
                )
                .first,
          );
          expect(
            _contrastRatio(
              letterB.style!.color!,
              (letterBBox.decoration! as BoxDecoration).color!,
            ),
            greaterThanOrEqualTo(4.5),
          );

          // 6. PlacementTestScreen loading CircularProgressIndicator on bg
          await tester.pumpWidget(
            _wrapScreen(
              const PlacementTestScreen(),
              theme: theme,
              scopeKey: ValueKey('placement_loading_$modeLabel'),
            ),
          );
          final spinner = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
          expect(
            _contrastRatio(spinner.color!, bg),
            greaterThanOrEqualTo(3.0),
          );
        },
      );

      testWidgets(
        'Iteration 4 WCAG contrast contracts (SnackBar, YolchiBubble, FlashcardDeck, LessonMedia, Roadmap, Onboarding, Profile, AITutor & option boxes) in $modeLabel',
        (tester) async {
          final theme = buildTheme();

          // 1. InteractiveLessonScreen completion SnackBar (>= 4.5:1)
          final snackContainer = ProviderContainer(
            overrides: [
              lessonAudioControllerFactoryProvider.overrideWithValue(
                () => FakeLessonAudioController(),
              ),
            ],
          );
          addTearDown(snackContainer.dispose);
          addTearDown(() => appRouter.go('/welcome'));
          await snackContainer
              .read(learnerStateNotifierProvider.notifier)
              .loadProfile();
          await snackContainer
              .read(courseStateNotifierProvider.notifier)
              .init();
          await snackContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await snackContainer
              .read(lessonSessionNotifierProvider.notifier)
              .startLesson('lesson_eng_starter', uiLocale: 'uz');
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: snackContainer,
              child: MaterialApp.router(theme: theme, routerConfig: appRouter),
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
          await tester.enterText(freeInput, 'My name is Sam');
          await tester.pumpAndSettle();
          await tester.tap(find.text('TEKSHIRISH'));
          await tester.pumpAndSettle();
          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          final snackText = tester.widget<Text>(
            find.text('To‘g‘ri javob! Dars muvaffaqiyatli yakunlandi.'),
          );
          final snackCtx = tester.element(find.byType(SnackBar));
          final snackBg =
              snackBar.backgroundColor ??
              Theme.of(snackCtx).snackBarTheme.backgroundColor!;
          final snackFg =
              snackText.style?.color ??
              Theme.of(snackCtx).snackBarTheme.contentTextStyle?.color ??
              Colors.white;
          expect(
            _contrastRatio(snackFg, snackBg),
            greaterThanOrEqualTo(4.5),
            reason: 'Completion SnackBar contrast in $modeLabel',
          );

          // 2. YolchiBubble helpful, unhelpful, user timestamp & error bubble
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: const Column(
                  children: [
                    YolchiBubble(
                      id: 'b_help',
                      message: 'Test',
                      isYolchi: true,
                      time: '12:00',
                      showHelpfulAction: true,
                      isHelpful: true,
                    ),
                    YolchiBubble(
                      id: 'b_unhelp',
                      message: 'Test 2',
                      isYolchi: true,
                      time: '12:01',
                      showHelpfulAction: true,
                      isHelpful: false,
                    ),
                    YolchiBubble(
                      id: 'b_user',
                      message: 'Salom',
                      isYolchi: false,
                      time: '12:02',
                    ),
                    YolchiBubble(
                      id: 'b_err',
                      message: 'Xato yuz berdi',
                      isYolchi: true,
                      isError: true,
                      time: '12:03',
                    ),
                  ],
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('yolchi_bubble_contrast_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();

          final thumbUpFinder = find.byIcon(Icons.thumb_up_alt_rounded);
          final thumbUpIcon = tester.widget<Icon>(thumbUpFinder);
          final thumbUpBg =
              (tester
                          .widget<Container>(
                            find
                                .ancestor(
                                  of: thumbUpFinder,
                                  matching: find.byType(Container),
                                )
                                .first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .color!;
          expect(
            _contrastRatio(thumbUpIcon.color!, thumbUpBg),
            greaterThanOrEqualTo(3.0),
            reason: 'YolchiBubble isHelpful thumb icon in $modeLabel',
          );

          final unhelpfulFinder = find.text('Foydali javob');
          final unhelpfulText = tester.widget<Text>(unhelpfulFinder);
          final unhelpfulBg =
              (tester
                          .widget<Container>(
                            find
                                .ancestor(
                                  of: unhelpfulFinder,
                                  matching: find.byType(Container),
                                )
                                .first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .color!;
          expect(
            _contrastRatio(unhelpfulText.style!.color!, unhelpfulBg),
            greaterThanOrEqualTo(4.5),
            reason: 'YolchiBubble unhelpful label in $modeLabel',
          );

          final userTime = tester.widget<Text>(find.text('12:02'));
          expect(
            _contrastRatio(userTime.style!.color!, const Color(0xFF4F46E5)),
            greaterThanOrEqualTo(4.5),
            reason: 'YolchiBubble user timestamp in $modeLabel',
          );

          final errRichFinder = find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == 'Xato yuz berdi',
          );
          final errBubbleContainer = tester.widget<Container>(
            find
                .ancestor(
                  of: errRichFinder,
                  matching: find.byType(Container),
                )
                .first,
          );
          final errBubbleDec = errBubbleContainer.decoration! as BoxDecoration;
          final errSpan =
              tester.widget<RichText>(errRichFinder).text as TextSpan;
          expect(
            _contrastRatio(errSpan.style!.color!, errBubbleDec.color!),
            greaterThanOrEqualTo(4.5),
            reason: 'YolchiBubble error text in $modeLabel',
          );
          expect(
            _contrastRatio(errBubbleDec.border!.top.color, bg),
            greaterThanOrEqualTo(3.0),
            reason: 'YolchiBubble error border vs bg in $modeLabel',
          );

          // 3. FlashcardDeckWidget audio error text & emerald completed badge icon
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: SingleChildScrollView(
                  child: FlashcardDeckWidget(
                    flashcards: [
                      a1AllFlashcards.firstWhere((c) => c.audioSrc != null),
                    ],
                    audioController: FakeLessonAudioController(
                      failOnLoad: true,
                    ),
                  ),
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('fc_err_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.volume_up_rounded));
          await tester.pumpAndSettle();
          final fcErrFinder = find.text('Audio faylni yuklab bo‘lmadi.');
          expect(fcErrFinder, findsOneWidget);
          final fcErrText = tester.widget<Text>(fcErrFinder);
          expect(
            _contrastRatio(fcErrText.style!.color!, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'FlashcardDeckWidget audio error text in $modeLabel',
          );

          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: SingleChildScrollView(
                  child: FlashcardDeckWidget(
                    flashcards: [a1AllFlashcards.first],
                  ),
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('fc_done_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Javobni ko‘rish'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Eslab qoldim'));
          await tester.pumpAndSettle();
          final fcCheckFinder = find.byIcon(Icons.check_circle_rounded);
          expect(fcCheckFinder, findsOneWidget);
          final fcCheckIcon = tester.widget<Icon>(fcCheckFinder);
          final fcBadgeDec =
              (tester
                          .widget<Container>(
                            find
                                .ancestor(
                                  of: fcCheckFinder,
                                  matching: find.byType(Container),
                                )
                                .first,
                          )
                          .decoration!
                      as BoxDecoration);
          final fcBadgeBg = Color.alphaBlend(fcBadgeDec.color!, surface);
          expect(
            _contrastRatio(fcCheckIcon.color!, fcBadgeBg),
            greaterThanOrEqualTo(3.0),
            reason: 'FlashcardDeckWidget emerald badge icon in $modeLabel',
          );

          // 4. LessonMediaWidget Slider.activeColor & _audioState.hasError
          const audioMedia = LessonMedia(
            id: 'media_test_audio',
            kind: LessonMediaKind.audio,
            language: LessonMediaLanguage.en,
            source: '/lesson-media/english/a1/test.wav',
            title: 'Audio Dialogue',
            durationSeconds: 35,
            transcript: 'Aziza: Hello!\nBen: Hi!',
          );
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: const SingleChildScrollView(
                  child: LessonMediaWidget(media: audioMedia),
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('media_slider_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          final slider = tester.widget<Slider>(find.byType(Slider));
          expect(
            _contrastRatio(slider.activeColor!, subtle),
            greaterThanOrEqualTo(3.0),
            reason: 'LessonMediaWidget Slider activeColor in $modeLabel',
          );

          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: const SingleChildScrollView(
                  child: LessonMediaWidget(media: audioMedia),
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('media_err_$modeLabel'),
              extraOverrides: [
                lessonAudioControllerFactoryProvider.overrideWithValue(
                  () => FakeLessonAudioController(failOnLoad: true),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
          final mediaErrCtx = tester.element(find.byType(LessonMediaWidget));
          final errTintBg = AppColors.errorTint(mediaErrCtx);
          final errVolIcon = tester.widget<Icon>(
            find.byIcon(Icons.volume_off_rounded),
          );
          final mediaErrText = tester.widget<Text>(
            find.text('Audio faylni yuklab bo‘lmadi.'),
          );
          expect(
            _contrastRatio(errVolIcon.color!, errTintBg),
            greaterThanOrEqualTo(3.0),
            reason: 'LessonMediaWidget error icon on errorTint in $modeLabel',
          );
          expect(
            _contrastRatio(mediaErrText.style!.color!, errTintBg),
            greaterThanOrEqualTo(4.5),
            reason: 'LessonMediaWidget error text on errorTint in $modeLabel',
          );

          // 5. RoadmapScreen isPlacedLevel border + completed & reinforcement circles
          await tester.pumpWidget(
            _wrapScreen(
              const RoadmapScreen(),
              theme: theme,
              scopeKey: ValueKey('roadmap_placed_$modeLabel'),
            ),
          );
          final rmContainer = ProviderScope.containerOf(
            tester.element(find.byType(RoadmapScreen)),
          );
          await rmContainer
              .read(learnerRepositoryProvider)
              .savePlacementSummary(
                courseId: 'course_eng_01',
                score: 65,
                cefrTier: 'A1',
              );
          await rmContainer
              .read(learnerStateNotifierProvider.notifier)
              .loadProfile();
          await rmContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await rmContainer
              .read(roadmapStateNotifierProvider.notifier)
              .loadRoadmap('course_eng_01');
          await tester.pumpAndSettle();
          final a1Card = tester.widget<AppCard>(
            find
                .ancestor(
                  of: find.text('A1').first,
                  matching: find.byType(AppCard),
                )
                .first,
          );
          expect(
            _contrastRatio(a1Card.borderColor!, surface),
            greaterThanOrEqualTo(3.0),
            reason: 'RoadmapScreen isPlacedLevel border vs surface in $modeLabel',
          );
          expect(
            _contrastRatio(a1Card.borderColor!, bg),
            greaterThanOrEqualTo(3.0),
            reason: 'RoadmapScreen isPlacedLevel border vs bg in $modeLabel',
          );

          await rmContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_math_01');
          rmContainer
              .read(roadmapStateNotifierProvider.notifier)
              .updateRoadmapDirect(
                const LearningPath(
                  id: 'lp_math_contrast',
                  courseId: 'course_math_01',
                  title: 'Matematika yo‘li',
                  activeNodeId: 'node_reinf',
                  updatedAt: 0,
                  nodes: [
                    LearningPathNode(
                      id: 'node_done',
                      courseId: 'course_math_01',
                      skillId: 'skill_math_algebra',
                      title: 'Algebraga kirish',
                      description: 'Tugallangan mavzu',
                      prerequisites: [],
                      requiredScore: 60,
                      estimatedMinutes: 5,
                      isReinforcement: false,
                      order: 1,
                      status: NodeStatus.completed,
                    ),
                    LearningPathNode(
                      id: 'node_reinf',
                      courseId: 'course_math_01',
                      skillId: 'skill_math_functions',
                      title: 'Funksiyalar',
                      description: 'Mustahkamlash mavzusi',
                      prerequisites: [],
                      requiredScore: 60,
                      estimatedMinutes: 5,
                      order: 2,
                      status: NodeStatus.reinforcement,
                      isReinforcement: true,
                    ),
                  ],
                ),
              );
          await tester.pumpAndSettle();
          for (final iconData in [
            Icons.check_rounded,
            Icons.warning_amber_rounded,
          ]) {
            final iconFinder = find.byIcon(iconData).first;
            await tester.ensureVisible(iconFinder);
            await tester.pumpAndSettle();
            final iconWidget = tester.widget<Icon>(iconFinder);
            final circleDec =
                (tester
                            .widget<Container>(
                              find
                                  .ancestor(
                                    of: iconFinder,
                                    matching: find.byType(Container),
                                  )
                                  .first,
                            )
                            .decoration!
                        as BoxDecoration);
            expect(
              _contrastRatio(iconWidget.color!, circleDec.color!),
              greaterThanOrEqualTo(3.0),
              reason: 'RoadmapScreen $iconData circle contrast in $modeLabel',
            );
          }

          // 6. OnboardingScreen selected level card border
          await tester.pumpWidget(
            _wrapScreen(
              const OnboardingScreen(),
              theme: theme,
              scopeKey: ValueKey('onboarding_border_$modeLabel'),
            ),
          );
          final obContainer = ProviderScope.containerOf(
            tester.element(find.byType(OnboardingScreen)),
          );
          await obContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Noldan boshlayman'));
          await tester.pumpAndSettle();
          final obCard = tester.widget<AppCard>(
            find
                .ancestor(
                  of: find.text('Noldan boshlayman'),
                  matching: find.byType(AppCard),
                )
                .first,
          );
          final obEffectiveBg = Color.alphaBlend(obCard.backgroundColor!, bg);
          expect(
            _contrastRatio(obCard.borderColor!, obEffectiveBg),
            greaterThanOrEqualTo(3.0),
            reason: 'OnboardingScreen selected border vs fill in $modeLabel',
          );
          expect(
            _contrastRatio(obCard.borderColor!, bg),
            greaterThanOrEqualTo(3.0),
            reason: 'OnboardingScreen selected border vs bg in $modeLabel',
          );

          // 7. ProfileScreen reset demo icon
          await tester.pumpWidget(
            _wrapScreen(
              const ProfileScreen(),
              theme: theme,
              scopeKey: ValueKey('profile_reset_icon_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          final resetIcon = tester.widget<Icon>(
            find.byIcon(Icons.refresh_rounded),
          );
          expect(
            _contrastRatio(resetIcon.color!, surface),
            greaterThanOrEqualTo(3.0),
            reason: 'ProfileScreen reset icon contrast in $modeLabel',
          );

          // 8. Unselected option letter boxes on InteractiveLessonScreen,
          // ReinforcementSheet & PlacementTestScreen (>= 4.5:1)
          await tester.pumpWidget(
            _wrapScreen(
              const InteractiveLessonScreen(),
              theme: theme,
              scopeKey: ValueKey('lesson_letter_a_$modeLabel'),
            ),
          );
          final lContainer = ProviderScope.containerOf(
            tester.element(find.byType(InteractiveLessonScreen)),
          );
          await lContainer.read(courseStateNotifierProvider.notifier).init();
          await lContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_math_01');
          await lContainer
              .read(lessonSessionNotifierProvider.notifier)
              .startLesson('lesson_math_starter', uiLocale: 'uz');
          for (var i = 0; i < 2; i++) {
            await lContainer
                .read(lessonSessionNotifierProvider.notifier)
                .nextStep(uiLocale: 'uz');
          }
          await tester.pumpAndSettle();
          final lessonLetterA = tester.widget<Text>(find.text('A').first);
          final lessonLetterABox = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('A').first,
                  matching: find.byType(Container),
                )
                .first,
          );
          expect(
            _contrastRatio(
              lessonLetterA.style!.color!,
              (lessonLetterABox.decoration! as BoxDecoration).color!,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'InteractiveLesson unselected letter A in $modeLabel',
          );

          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                body: ReinforcementSheet(
                  question: const Question(
                    id: 'q_reinf_unselected',
                    courseId: 'course_eng_01',
                    skillId: 'skill_eng_vocab',
                    text: 'Choose greeting:',
                    options: ['Hello', 'Bye'],
                    correctIndex: 0,
                    difficulty: QuestionDifficulty.easy,
                    explanation: 'Hello is a greeting.',
                  ),
                  onSubmit: (_) async => const ReinforcementResult(
                    isCorrect: true,
                    oldScore: 40,
                    newScore: 60,
                    xpAwarded: 10,
                    updatedRoadmap: LearningPath(
                      id: 'lp_test',
                      courseId: 'course_eng_01',
                      title: 'Test',
                      nodes: [],
                      activeNodeId: '',
                      updatedAt: 0,
                    ),
                  ),
                  onGoToDashboard: () {},
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('reinf_letter_a_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          final reinfLetterA = tester.widget<Text>(find.text('A').first);
          final reinfLetterABox = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('A').first,
                  matching: find.byType(Container),
                )
                .first,
          );
          expect(
            _contrastRatio(
              reinfLetterA.style!.color!,
              (reinfLetterABox.decoration! as BoxDecoration).color!,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'ReinforcementSheet unselected letter A in $modeLabel',
          );

          await tester.pumpWidget(
            _wrapScreen(
              const PlacementTestScreen(),
              theme: theme,
              scopeKey: ValueKey('placement_letter_a_$modeLabel'),
            ),
          );
          final pContainer = ProviderScope.containerOf(
            tester.element(find.byType(PlacementTestScreen)),
          );
          await pContainer
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await pContainer
              .read(placementStateNotifierProvider.notifier)
              .loadQuestions('course_eng_01');
          await tester.pumpAndSettle();
          final placementLetterA = tester.widget<Text>(find.text('A').first);
          final placementLetterABox = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('A').first,
                  matching: find.byType(Container),
                )
                .first,
          );
          expect(
            _contrastRatio(
              placementLetterA.style!.color!,
              (placementLetterABox.decoration! as BoxDecoration).color!,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'PlacementTest unselected letter A in $modeLabel',
          );

          // 9. AITutorScreen _serviceOnline == true subtitle, ActionChip border & send button
          final prevRemoteConfig = SupabaseConfig.hasRemoteConfiguration;
          SupabaseConfig.hasRemoteConfiguration = true;
          addTearDown(() {
            SupabaseConfig.hasRemoteConfiguration = prevRemoteConfig;
          });
          await tester.pumpWidget(
            _wrapScreen(
              const AITutorScreen(),
              theme: theme,
              scopeKey: ValueKey('ai_online_$modeLabel'),
              extraOverrides: [
                aiTutorServiceProvider.overrideWithValue(
                  const _FakeOnlineAITutorService(),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Qoidani sodda tushuntir'));
          await tester.pumpAndSettle();
          final onlineTextFinder = find.text('Pedagogik yordamchi');
          expect(onlineTextFinder, findsOneWidget);
          final onlineText = tester.widget<Text>(onlineTextFinder);
          final aiAppBar = tester.widget<AppBar>(find.byType(AppBar));
          final aiAppBarCtx = tester.element(find.byType(AppBar));
          final rawAppBarBg =
              aiAppBar.backgroundColor ??
              Theme.of(aiAppBarCtx).appBarTheme.backgroundColor ??
              bg;
          final effectiveAppBarBg = Color.alphaBlend(rawAppBarBg, bg);
          expect(
            _contrastRatio(onlineText.style!.color!, effectiveAppBarBg),
            greaterThanOrEqualTo(4.5),
            reason: 'AITutorScreen online status subtitle in $modeLabel',
          );

          final chip = tester.widget<ActionChip>(find.byType(ActionChip).first);
          expect(
            _contrastRatio(chip.side!.color, surface),
            greaterThanOrEqualTo(3.0),
            reason: 'AITutorScreen ActionChip border vs surface in $modeLabel',
          );
          expect(
            _contrastRatio(chip.side!.color, bg),
            greaterThanOrEqualTo(3.0),
            reason: 'AITutorScreen ActionChip border vs bg in $modeLabel',
          );

          final sendIconFinder = find.byIcon(Icons.arrow_upward_rounded);
          final sendIcon = tester.widget<Icon>(sendIconFinder);
          final sendCircle = tester.widget<Container>(
            find
                .ancestor(
                  of: sendIconFinder,
                  matching: find.byType(Container),
                )
                .first,
          );
          final sendGrad = (sendCircle.decoration! as BoxDecoration).gradient!
              as LinearGradient;
          for (final stopColor in sendGrad.colors) {
            expect(
              _contrastRatio(sendIcon.color!, stopColor),
              greaterThanOrEqualTo(3.0),
              reason: 'AITutorScreen send icon on $stopColor in $modeLabel',
            );
          }
        },
      );

      testWidgets(
        'Iteration 5 WCAG contrast contracts (AppButton.secondary, ProgressScreen SubjectBars & 7 subtleSurface/primaryTint text pairs) in $modeLabel',
        (tester) async {
          final theme = buildTheme();

          // 1. AppButtonVariant.secondary on RoadmapScreen ('SRS Takrorlash') & FlashcardDeckWidget ('Eslab qoldim') (>= 4.5:1)
          await tester.pumpWidget(
            _wrapScreen(
              const RoadmapScreen(),
              theme: theme,
              scopeKey: ValueKey('iter5_roadmap_$modeLabel'),
            ),
          );
          final rmC = ProviderScope.containerOf(
            tester.element(find.byType(RoadmapScreen)),
          );
          await rmC
              .read(learnerRepositoryProvider)
              .savePlacementSummary(
                courseId: 'course_eng_01',
                score: 65,
                cefrTier: 'A1',
              );
          await rmC.read(learnerStateNotifierProvider.notifier).loadProfile();
          await rmC
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await rmC
              .read(roadmapStateNotifierProvider.notifier)
              .loadRoadmap('course_eng_01');
          await tester.pumpAndSettle();

          final srsBtnTextFinder = find.text('SRS Takrorlash');
          await tester.ensureVisible(srsBtnTextFinder);
          await tester.pumpAndSettle();
          final srsBtnText = tester.widget<Text>(srsBtnTextFinder);
          final srsBtnContainer = tester.widget<AnimatedContainer>(
            find
                .ancestor(
                  of: srsBtnTextFinder,
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          );
          final srsBtnBg =
              (srsBtnContainer.decoration! as BoxDecoration).color!;
          expect(
            _contrastRatio(srsBtnText.style!.color!, srsBtnBg),
            greaterThanOrEqualTo(4.5),
            reason: 'AppButtonVariant.secondary on RoadmapScreen in $modeLabel',
          );

          // RoadmapScreen diagnostic banner & localizedCanDo
          final diagTextFinder = find.textContaining(
            'Diagnostika natijasi boshlang‘ich darsni tavsiya qildi.',
          );
          expect(diagTextFinder, findsOneWidget);
          final diagText = tester.widget<Text>(diagTextFinder);
          final diagCard = tester.widget<AppCard>(
            find
                .ancestor(
                  of: diagTextFinder,
                  matching: find.byType(AppCard),
                )
                .first,
          );
          final diagBg = Color.alphaBlend(diagCard.backgroundColor!, bg);
          expect(
            _contrastRatio(diagText.style!.color!, diagBg),
            greaterThanOrEqualTo(4.5),
            reason: 'RoadmapScreen diagnostic banner text in $modeLabel',
          );

          final canDoTextStr =
              cefrSkeletonLevels.first.modules.first.localizedCanDo('uz');
          final canDoFinder = find.text(canDoTextStr);
          await tester.ensureVisible(canDoFinder);
          await tester.pumpAndSettle();
          final canDoText = tester.widget<Text>(canDoFinder);
          expect(
            _contrastRatio(canDoText.style!.color!, subtle),
            greaterThanOrEqualTo(4.5),
            reason: 'RoadmapScreen mod.localizedCanDo on subtleSurface in $modeLabel',
          );

          // 2. ProgressScreen _SubjectBar ('Ingliz tili', 'IT & Algoritmlar', 'Mantiqiy fikrlash') & 'O‘qish vaqti' bar chart (>= 3.0:1)
          await tester.pumpWidget(
            _wrapScreen(
              const ProgressScreen(),
              theme: theme,
              scopeKey: ValueKey('iter5_progress_$modeLabel'),
              extraOverrides: [
                learnerRepositoryProvider.overrideWithValue(
                  _FakeActivityLearnerRepository(),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
          final cardBg = surface;
          for (final subjectTitle in const [
            'Ingliz tili',
            'IT & Algoritmlar',
            'Mantiqiy fikrlash',
          ]) {
            final titleFinder = find.text(subjectTitle);
            await tester.ensureVisible(titleFinder);
            await tester.pumpAndSettle();
            final barFinder = find
                .descendant(
                  of: find
                      .ancestor(
                        of: titleFinder,
                        matching: find.byType(Column),
                      )
                      .first,
                  matching: find.byType(LinearProgressIndicator),
                )
                .first;
            final ind = tester.widget<LinearProgressIndicator>(barFinder);
            final fill =
                (ind.valueColor! as AlwaysStoppedAnimation<Color>).value;
            final rawTrack = ind.backgroundColor!;
            final track =
                rawTrack.a < 1.0 ? Color.alphaBlend(rawTrack, cardBg) : rawTrack;
            expect(
              _contrastRatio(fill, cardBg),
              greaterThanOrEqualTo(3.0),
              reason: '$subjectTitle bar vs cardBg in $modeLabel',
            );
            expect(
              _contrastRatio(fill, track),
              greaterThanOrEqualTo(3.0),
              reason: '$subjectTitle bar vs track in $modeLabel',
            );
          }

          final chartTitleFinder = find.text('O‘qish vaqti');
          await tester.ensureVisible(chartTitleFinder);
          await tester.pumpAndSettle();
          final chartCardFinder = find
              .ancestor(of: chartTitleFinder, matching: find.byType(AppCard))
              .first;
          final chartCard = tester.widget<AppCard>(chartCardFinder);
          final rawChartCardBg = chartCard.backgroundColor ?? cardBg;
          final chartCardBg = rawChartCardBg.a < 1.0
              ? Color.alphaBlend(rawChartCardBg, bg)
              : rawChartCardBg;
          final activityBars = tester.widgetList<Container>(
            find.descendant(
              of: chartCardFinder,
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).gradient is LinearGradient,
              ),
            ),
          );
          expect(activityBars.length, equals(7));
          for (final bar in activityBars) {
            final gradient =
                (bar.decoration! as BoxDecoration).gradient! as LinearGradient;
            for (final stopColor in gradient.colors) {
              expect(
                _contrastRatio(stopColor, chartCardBg),
                greaterThanOrEqualTo(3.0),
                reason:
                    'O‘qish vaqti activity bar gradient stop $stopColor vs cardBg in $modeLabel',
              );
            }
          }

          // 3. PlacementTestScreen contextSnippet (>= 4.5:1 on subtleSurface)
          await tester.pumpWidget(
            _wrapScreen(
              const PlacementTestScreen(),
              theme: theme,
              scopeKey: ValueKey('iter5_placement_ctx_$modeLabel'),
            ),
          );
          final pC = ProviderScope.containerOf(
            tester.element(find.byType(PlacementTestScreen)),
          );
          await pC.read(courseStateNotifierProvider.notifier).init();
          await pC
              .read(courseStateNotifierProvider.notifier)
              .selectCourse('course_eng_01');
          await tester.pumpAndSettle();
          const snippetQuestion = Question(
            id: 'q_iter5_ctx',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_reading',
            text: 'Read the notice:',
            contextSnippet: 'Library opens at 09:00 on Mondays.',
            options: ['09:00', '10:00'],
            correctIndex: 0,
            difficulty: QuestionDifficulty.easy,
            explanation: 'Notice says 09:00.',
          );
          pC.read(placementStateNotifierProvider.notifier).state =
              const PlacementState(
                courseId: 'course_eng_01',
                allQuestions: [snippetQuestion],
                currentQuestion: snippetQuestion,
                questionNumber: 1,
                totalQuestionsToAsk: 1,
                history: [],
                submissions: [],
                hasLoaded: true,
              );
          await tester.pumpAndSettle();
          final snippetText = tester.widget<Text>(
            find.text('Library opens at 09:00 on Mondays.'),
          );
          expect(
            _contrastRatio(snippetText.style!.color!, subtle),
            greaterThanOrEqualTo(4.5),
            reason: 'PlacementTestScreen contextSnippet on subtleSurface in $modeLabel',
          );

          // 4. FlashcardDeckWidget altText (errorBuilder + imagePrompt), exampleTranslation & 'Eslab qoldim' AppButtonVariant.secondary
          const fcWithMissingImg = LessonFlashcard(
            id: 'fc_iter5_missing_img',
            front: 'desk',
            backUz: 'stol',
            backRu: 'стол',
            example: 'My book is on the desk.',
            exampleUz: 'Kitobim stol ustida.',
            imageSrc: '/lesson-media/english/missing_iter5.png',
            alt: 'Yog‘och o‘quv stoli tasviri',
          );
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: SingleChildScrollView(
                  child: FlashcardDeckWidget(flashcards: const [fcWithMissingImg]),
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('iter5_fc_img_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          final fcAltErrFinder = find.text('Yog‘och o‘quv stoli tasviri');
          expect(fcAltErrFinder, findsOneWidget);
          expect(
            _contrastRatio(
              tester.widget<Text>(fcAltErrFinder).style!.color!,
              subtle,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'FlashcardDeckWidget image errorBuilder altText in $modeLabel',
          );

          await tester.tap(find.text('Javobni ko‘rish'));
          await tester.pumpAndSettle();
          final fcExampleTrFinder = find.text('Kitobim stol ustida.');
          expect(fcExampleTrFinder, findsOneWidget);
          expect(
            _contrastRatio(
              tester.widget<Text>(fcExampleTrFinder).style!.color!,
              subtle,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'FlashcardDeckWidget exampleTranslation in $modeLabel',
          );
          final remBtnTextFinder = find.text('Eslab qoldim');
          final remBtnContainer = tester.widget<AnimatedContainer>(
            find
                .ancestor(
                  of: remBtnTextFinder,
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          );
          expect(
            _contrastRatio(
              tester.widget<Text>(remBtnTextFinder).style!.color!,
              (remBtnContainer.decoration! as BoxDecoration).color!,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'FlashcardDeckWidget AppButtonVariant.secondary in $modeLabel',
          );

          // FlashcardDeckWidget isImagePrompt fallback branch (resolvedImage == null)
          const fcImagePromptNoSrc = LessonFlashcard(
            id: 'fc_iter5_prompt_no_src',
            front: 'lamp',
            backUz: 'chiroq',
            backRu: 'лампа',
            example: 'Turn on the lamp.',
            exampleUz: 'Chiroqni yoqing.',
            alt: 'Stol chirog‘i illyustratsiyasi',
          );
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: SingleChildScrollView(
                  child: FlashcardDeckWidget(
                    flashcards: const [fcImagePromptNoSrc],
                  ),
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('iter5_fc_prompt_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Image → Word'));
          await tester.pumpAndSettle();
          final fcAltPromptFinder = find.text('Stol chirog‘i illyustratsiyasi');
          expect(fcAltPromptFinder, findsOneWidget);
          expect(
            _contrastRatio(
              tester.widget<Text>(fcAltPromptFinder).style!.color!,
              subtle,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'FlashcardDeckWidget imagePrompt fallback altText in $modeLabel',
          );

          // 5. LessonMediaWidget imageAlt & audio timestampLabel (>= 4.5:1 on subtleSurface)
          const missingImageMedia = LessonMedia(
            id: 'media_iter5_img',
            kind: LessonMediaKind.image,
            language: LessonMediaLanguage.en,
            source: '/lesson-media/english/missing_media_iter5.png',
            title: 'Room Map',
            alt: 'Xona buyumlari sxemasi',
          );
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: const SingleChildScrollView(
                  child: LessonMediaWidget(media: missingImageMedia),
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('iter5_media_img_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          final mediaImgAltFinder = find.text('Xona buyumlari sxemasi');
          expect(mediaImgAltFinder, findsOneWidget);
          expect(
            _contrastRatio(
              tester.widget<Text>(mediaImgAltFinder).style!.color!,
              subtle,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'LessonMediaWidget imageAlt on subtleSurface in $modeLabel',
          );

          const audioMediaIter5 = LessonMedia(
            id: 'media_iter5_audio',
            kind: LessonMediaKind.audio,
            language: LessonMediaLanguage.en,
            source: '/lesson-media/english/a1/test.wav',
            title: 'Audio Dialogue',
            durationSeconds: 35,
          );
          await tester.pumpWidget(
            _wrapScreen(
              Scaffold(
                backgroundColor: bg,
                body: const SingleChildScrollView(
                  child: LessonMediaWidget(media: audioMediaIter5),
                ),
              ),
              theme: theme,
              scopeKey: ValueKey('iter5_media_ts_$modeLabel'),
            ),
          );
          await tester.pumpAndSettle();
          final tsFinder = find.text('0:00 / 0:35');
          expect(tsFinder, findsOneWidget);
          expect(
            _contrastRatio(
              tester.widget<Text>(tsFinder).style!.color!,
              subtle,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'LessonMediaWidget timestampLabel on subtleSurface in $modeLabel',
          );
        },
      );
    }

    // Item (b): DashboardScreen Light-mode fixed-dark canvas regression guard
    testWidgets(
      'DashboardScreen FriendlyErrorState and search cursor meet contrast in Light mode',
      (tester) async {
        await tester.pumpWidget(
          _wrapScreen(
            const DashboardScreen(),
            theme: AppTheme.lightTheme,
            scopeKey: const ValueKey('dash_err'),
          ),
        );
        await tester.pumpAndSettle();

        final dashContainer = ProviderScope.containerOf(
          tester.element(find.byType(DashboardScreen)),
        );
        dashContainer.read(learnerStateNotifierProvider.notifier).state =
            AsyncValue.error(Exception('offline'), StackTrace.empty);
        await tester.pumpAndSettle();

        const cosmosBg = Color(0xFF090C22);
        final errMsg = tester.widget<Text>(
          find.text('Profil ma’lumotlarini yuklab bo‘lmadi.'),
        );
        final errSub = tester.widget<Text>(
          find.text('Internet aloqasini tekshirib, qayta urinib ko‘ring.'),
        );
        expect(
          _contrastRatio(errMsg.style!.color!, cosmosBg),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(errSub.style!.color!, cosmosBg),
          greaterThanOrEqualTo(4.5),
        );

        await tester.pumpWidget(
          _wrapScreen(
            const DashboardScreen(),
            theme: AppTheme.lightTheme,
            scopeKey: const ValueKey('dash_search'),
          ),
        );
        await tester.pumpAndSettle();
        final searchField = tester.widget<TextField>(find.byType(TextField));
        final searchCtx = tester.element(find.byType(TextField));
        final effectiveCursor =
            searchField.cursorColor ?? Theme.of(searchCtx).colorScheme.primary;
        expect(
          _contrastRatio(effectiveCursor, const Color(0xFF14183E)),
          greaterThanOrEqualTo(3.0),
          reason: 'Dashboard search cursor on #14183E in Light mode',
        );
      },
    );
  });

  // Item (f): 360dp + 200% Text Scaling across ALL 13 screens in Light & Dark
  group('360dp Width + 200% Text Scaling Layout Safety', () {
    for (final isDark in [false, true]) {
      final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
      final modeLabel = isDark ? 'Dark' : 'Light';

      final simpleScreens = <String, Widget Function()>{
        'WelcomeScreen': () => const WelcomeScreen(),
        'RegisterScreen': () => const RegisterScreen(),
        'LoginScreen': () => const LoginScreen(),
        'ForgotPasswordScreen': () => const ForgotPasswordScreen(),
        'CourseSelectionScreen': () => const CourseSelectionScreen(),
        'KnowledgeMapScreen': () => const KnowledgeMapScreen(),
        'DashboardScreen': () => const DashboardScreen(),
      };

      for (final entry in simpleScreens.entries) {
        testWidgets(
          '${entry.key} renders at 360x800 with 2.0x textScaler in $modeLabel without overflow',
          (tester) async {
            _configurePhoneViewport(tester);
            await _pumpWithAllErrorsChecked(tester, () async {
              await tester.pumpWidget(
                _wrapScreen(entry.value(), theme: theme, textScale: 2.0),
              );
              await tester.pumpAndSettle();
            });
            _assertNoZeroWidthText(tester, screenName: entry.key);
            _assertNoUnexpectedTruncation(tester, screenName: entry.key);
            _assertNoButtonOverlaps(tester);
          },
        );
      }

      testWidgets(
        'DashboardScreen seeded beginner Hero CTA ("Birinchi darsni ochish") renders without truncation at 360x800 + 2.0x in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const DashboardScreen(),
                theme: theme,
                textScale: 2.0,
              ),
            );
            final c = ProviderScope.containerOf(
              tester.element(find.byType(DashboardScreen)),
            );
            await c
                .read(courseStateNotifierProvider.notifier)
                .selectCourse('course_eng_01');
            await c
                .read(learnerStateNotifierProvider.notifier)
                .updateOnboarding(
                  courseId: 'course_eng_01',
                  goal: OnboardingGoal.skillsBoost,
                  dailyMinutes: 15,
                  initialLevel: InitialLevel.beginner,
                );
            await tester.pumpAndSettle();
          });
          expect(find.text('Birinchi darsni ochish'), findsOneWidget);
          _assertNoZeroWidthText(tester, screenName: 'DashboardScreen(seeded)');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'DashboardScreen(seeded)',
          );
          _assertNoButtonOverlaps(tester);
        },
      );

      testWidgets(
        'CourseSelectionScreen Russian locale renders Программирование cleanly at 360x800 + 2.0x in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);
          tester.platformDispatcher.localeTestValue = const Locale('ru');
          addTearDown(tester.platformDispatcher.clearLocaleTestValue);
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const CourseSelectionScreen(),
                theme: theme,
                textScale: 2.0,
              ),
            );
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('Программирование'),
              200,
            );
            await tester.pumpAndSettle();
          });
          expect(find.text('Программирование'), findsOneWidget);
          _assertNoZeroWidthText(
            tester,
            screenName: 'CourseSelectionScreen(ru)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'CourseSelectionScreen(ru)',
          );
          _assertNoButtonOverlaps(tester);
        },
      );

      testWidgets(
        'OnboardingScreen, RoadmapScreen (English & Math), PlacementTestScreen, InteractiveLessonScreen, ProgressScreen, ProfileScreen, ReinforcementSheet & MathFunctionGraphWidget render at 360x800 + 2.0x in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);

          // 1. OnboardingScreen
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const OnboardingScreen(),
                theme: theme,
                textScale: 2.0,
              ),
            );
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(tester, screenName: 'OnboardingScreen');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'OnboardingScreen',
          );
          _assertNoButtonOverlaps(tester);

          // 2. RoadmapScreen (English CEFR + Math pilot)
          for (final courseId in ['course_eng_01', 'course_math_01']) {
            await _pumpWithAllErrorsChecked(tester, () async {
              await tester.pumpWidget(
                _wrapScreen(
                  const RoadmapScreen(),
                  theme: theme,
                  textScale: 2.0,
                ),
              );
              final c = ProviderScope.containerOf(
                tester.element(find.byType(RoadmapScreen)),
              );
              await c
                  .read(courseStateNotifierProvider.notifier)
                  .selectCourse(courseId);
              await c
                  .read(roadmapStateNotifierProvider.notifier)
                  .loadRoadmap(courseId);
              await tester.pumpAndSettle();
            });
            _assertNoZeroWidthText(
              tester,
              screenName: 'RoadmapScreen($courseId)',
            );
            _assertNoUnexpectedTruncation(
              tester,
              screenName: 'RoadmapScreen($courseId)',
            );
            _assertNoButtonOverlaps(tester);
          }

          // 3. PlacementTestScreen (Long MCQ option + Submit Dialog + Result view)
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const PlacementTestScreen(),
                theme: theme,
                textScale: 2.0,
              ),
            );
            final c = ProviderScope.containerOf(
              tester.element(find.byType(PlacementTestScreen)),
            );
            await c
                .read(courseStateNotifierProvider.notifier)
                .selectCourse('course_eng_01');
            await c
                .read(placementStateNotifierProvider.notifier)
                .loadQuestions('course_eng_01');
            await tester.pumpAndSettle();

            final longOptionQuestion = const Question(
              id: 'q_eng_long_opt',
              courseId: 'course_eng_01',
              skillId: 'skill_eng_grammar',
              text: 'Choose the correct sentence:',
              options: [
                'I study English.',
                'I have been studying English for two years',
              ],
              correctIndex: 1,
              difficulty: QuestionDifficulty.medium,
              explanation: 'Present perfect continuous fits duration.',
            );
            c.read(placementStateNotifierProvider.notifier).state =
                PlacementState(
                  courseId: 'course_eng_01',
                  allQuestions: [longOptionQuestion],
                  currentQuestion: longOptionQuestion,
                  questionNumber: 1,
                  totalQuestionsToAsk: 1,
                  history: const [],
                  submissions: const [],
                  hasLoaded: true,
                );
            await tester.pumpAndSettle();
          });
          expect(find.text('Tezkor demo'), findsOneWidget);
          expect(
            find.text('I have been studying English for two years'),
            findsOneWidget,
          );
          _assertNoZeroWidthText(tester, screenName: 'PlacementTestScreen');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'PlacementTestScreen',
          );
          _assertNoButtonOverlaps(tester);

          // Exercise Submit AlertDialog + Result view with a real course_eng_01 question
          await _pumpWithAllErrorsChecked(tester, () async {
            final c = ProviderScope.containerOf(
              tester.element(find.byType(PlacementTestScreen)),
            );
            await c
                .read(placementStateNotifierProvider.notifier)
                .loadQuestions('course_eng_01');
            await tester.pumpAndSettle();
            final loaded = c.read(placementStateNotifierProvider);
            c.read(placementStateNotifierProvider.notifier).state = loaded
                .copyWith(questionNumber: loaded.totalQuestionsToAsk);
            await tester.pumpAndSettle();

            final firstOptFinder = find.text(
              loaded.currentQuestion!.options.first,
            );
            await tester.ensureVisible(firstOptFinder);
            await tester.pumpAndSettle();
            await tester.tap(firstOptFinder);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Natijalarni Ko‘rish'));
            await tester.pumpAndSettle();
            expect(find.text('Javoblarni topshirasizmi?'), findsOneWidget);
            _assertNoZeroWidthText(
              tester,
              screenName: 'PlacementTestScreen(SubmitDialog)',
            );
            _assertNoUnexpectedTruncation(
              tester,
              screenName: 'PlacementTestScreen(SubmitDialog)',
            );
            _assertNoButtonOverlaps(tester);

            await tester.tap(find.text('Topshirish'));
            await tester.pumpAndSettle();
            expect(find.text('Diagnostika natijasi'), findsOneWidget);
            expect(find.text('Diagnostika yakunlandi'), findsOneWidget);
          });
          _assertNoZeroWidthText(
            tester,
            screenName: 'PlacementTestScreen(Result)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'PlacementTestScreen(Result)',
          );
          _assertNoButtonOverlaps(tester);

          // 4. InteractiveLessonScreen (step 3 + sentenceOrder + selfAssessed + MathFunctionGraphWidget)
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const InteractiveLessonScreen(),
                theme: theme,
                textScale: 2.0,
              ),
            );
            final c = ProviderScope.containerOf(
              tester.element(find.byType(InteractiveLessonScreen)),
            );
            await c
                .read(lessonSessionNotifierProvider.notifier)
                .startLesson('lesson_math_starter', uiLocale: 'uz');
            await c
                .read(lessonSessionNotifierProvider.notifier)
                .nextStep(uiLocale: 'uz');
            await c
                .read(lessonSessionNotifierProvider.notifier)
                .nextStep(uiLocale: 'uz');
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(tester, screenName: 'InteractiveLessonScreen');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'InteractiveLessonScreen',
          );
          _assertNoButtonOverlaps(tester);

          // 4b. InteractiveLessonScreen sentenceOrder & selfAssessed at 360x800 + 2.0x
          for (final entry in [
            ('lesson_eng_a1_m2_sentence_builder', 3, 'sentenceOrder'),
            ('lesson_eng_a1_m1_speaking', 2, 'selfAssessed'),
          ]) {
            await _pumpWithAllErrorsChecked(tester, () async {
              await tester.pumpWidget(
                _wrapScreen(
                  const InteractiveLessonScreen(),
                  theme: theme,
                  textScale: 2.0,
                ),
              );
              final c = ProviderScope.containerOf(
                tester.element(find.byType(InteractiveLessonScreen)),
              );
              await c.read(courseStateNotifierProvider.notifier).init();
              await c
                  .read(courseStateNotifierProvider.notifier)
                  .selectCourse('course_eng_01');
              await c
                  .read(lessonSessionNotifierProvider.notifier)
                  .startLesson(entry.$1, uiLocale: 'uz');
              for (var i = 0; i < entry.$2; i++) {
                await c
                    .read(lessonSessionNotifierProvider.notifier)
                    .nextStep(uiLocale: 'uz');
              }
              await tester.pumpAndSettle();
            });
            _assertNoZeroWidthText(
              tester,
              screenName: 'InteractiveLessonScreen(${entry.$3})',
            );
            _assertNoUnexpectedTruncation(
              tester,
              screenName: 'InteractiveLessonScreen(${entry.$3})',
            );
            _assertNoButtonOverlaps(tester);
          }

          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const Scaffold(body: MathFunctionGraphWidget()),
                theme: theme,
                textScale: 2.0,
              ),
            );
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(tester, screenName: 'MathFunctionGraphWidget');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'MathFunctionGraphWidget',
          );

          // 5. ReinforcementSheet success state
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                Scaffold(
                  body: ReinforcementSheet(
                    question: const Question(
                      id: 'q_reinf_200',
                      courseId: 'course_eng_01',
                      skillId: 'skill_eng_vocab',
                      text: 'Pick B:',
                      options: ['A', 'B'],
                      correctIndex: 1,
                      difficulty: QuestionDifficulty.easy,
                      explanation: 'B is right.',
                    ),
                    onSubmit: (idx) async => const ReinforcementResult(
                      isCorrect: true,
                      oldScore: 41,
                      newScore: 68,
                      xpAwarded: 15,
                      updatedRoadmap: LearningPath(
                        id: 'lp_test',
                        courseId: 'course_eng_01',
                        title: 'Test',
                        nodes: [],
                        activeNodeId: '',
                        updatedAt: 0,
                      ),
                    ),
                    onGoToDashboard: () {},
                  ),
                ),
                theme: theme,
                textScale: 2.0,
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('B').last);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Javobni Tekshirish'));
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(
            tester,
            screenName: 'ReinforcementSheet(success)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'ReinforcementSheet(success)',
          );
          _assertNoButtonOverlaps(tester);

          // 6. ProgressScreen (non-empty 7-day + 30-day activity charts & didExceedMaxLines == false)
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const ProgressScreen(),
                theme: theme,
                textScale: 2.0,
                scopeKey: ValueKey('progress_activity_$modeLabel'),
                extraOverrides: [
                  learnerRepositoryProvider.overrideWithValue(
                    _FakeActivityLearnerRepository(),
                  ),
                ],
              ),
            );
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(tester, screenName: 'ProgressScreen(7d)');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'ProgressScreen(7d)',
          );
          _assertNoButtonOverlaps(tester);
          for (final label in [
            'Bajarilgan dars',
            'O‘zlashtirish',
            'Kun ketma-ket 🔥',
            'Umumiy ballar ✨',
            'Ilk Qadam',
          ]) {
            final p = tester.renderObject<RenderParagraph>(find.text(label));
            expect(
              p.didExceedMaxLines,
              isFalse,
              reason: 'ProgressScreen "$label" truncated in $modeLabel',
            );
          }

          await _pumpWithAllErrorsChecked(tester, () async {
            final timeframeChip = find.text('Bu hafta');
            await tester.ensureVisible(timeframeChip);
            await tester.pumpAndSettle();
            await tester.tap(timeframeChip);
            await tester.pumpAndSettle();
            expect(find.text('Bu oy'), findsOneWidget);
          });
          _assertNoZeroWidthText(tester, screenName: 'ProgressScreen(30d)');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'ProgressScreen(30d)',
          );

          // 7. ProfileScreen (didExceedMaxLines == false on name & course title)
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const ProfileScreen(),
                theme: theme,
                textScale: 2.0,
                scopeKey: ValueKey('profile_a11y_$modeLabel'),
              ),
            );
            final c = ProviderScope.containerOf(
              tester.element(find.byType(ProfileScreen)),
            );
            await c
                .read(courseStateNotifierProvider.notifier)
                .selectCourse('course_eng_01');
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(tester, screenName: 'ProfileScreen');
          _assertNoUnexpectedTruncation(tester, screenName: 'ProfileScreen');
          _assertNoButtonOverlaps(tester);
          for (final label in ['Foydalanuvchi', 'Ingliz tili']) {
            final matches = find.text(label);
            expect(matches, findsWidgets);
            for (final el in matches.evaluate()) {
              final p = el.renderObject;
              if (p is RenderParagraph) {
                expect(
                  p.didExceedMaxLines,
                  isFalse,
                  reason: 'ProfileScreen "$label" truncated in $modeLabel',
                );
              }
            }
          }
        },
      );

      testWidgets(
        'PlacementTestScreen & RoadmapScreen Russian locale render cleanly at 360x800 + 2.0x in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);
          tester.platformDispatcher.localeTestValue = const Locale('ru');
          addTearDown(tester.platformDispatcher.clearLocaleTestValue);

          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const PlacementTestScreen(),
                theme: theme,
                textScale: 2.0,
                locale: const Locale('en'),
              ),
            );
            final c = ProviderScope.containerOf(
              tester.element(find.byType(PlacementTestScreen)),
            );
            await c
                .read(courseStateNotifierProvider.notifier)
                .selectCourse('course_eng_01');
            await c
                .read(placementStateNotifierProvider.notifier)
                .loadQuestions('course_eng_01');
            await tester.pumpAndSettle();
          });
          expect(find.text('Быстрое демо'), findsOneWidget);
          _assertNoZeroWidthText(
            tester,
            screenName: 'PlacementTestScreen(ru)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'PlacementTestScreen(ru)',
          );

          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const RoadmapScreen(),
                theme: theme,
                textScale: 2.0,
                locale: const Locale('en'),
              ),
            );
            final c = ProviderScope.containerOf(
              tester.element(find.byType(RoadmapScreen)),
            );
            await c
                .read(courseStateNotifierProvider.notifier)
                .selectCourse('course_eng_01');
            await c
                .read(roadmapStateNotifierProvider.notifier)
                .loadRoadmap('course_eng_01');
            await tester.pumpAndSettle();
          });
          expect(find.text('Мой учебный путь'), findsOneWidget);
          _assertNoZeroWidthText(tester, screenName: 'RoadmapScreen(ru)');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'RoadmapScreen(ru)',
          );
        },
      );

      testWidgets(
        'InteractiveLessonScreen longest uz/ru titles render with both action buttons & zero AppBar clipping at 360x800 + 2.0x in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);
          for (final entry in [
            ('lesson_eng_vocab_01', 'uz'),
            ('lesson_eng_vocab_01', 'ru'),
            ('lesson_eng_b1_m2_work_study', 'uz'),
          ]) {
            final lessonId = entry.$1;
            final lang = entry.$2;
            tester.platformDispatcher.localeTestValue = Locale(lang);
            addTearDown(tester.platformDispatcher.clearLocaleTestValue);
            await _pumpWithAllErrorsChecked(tester, () async {
              await tester.pumpWidget(
                _wrapScreen(
                  const InteractiveLessonScreen(),
                  theme: theme,
                  textScale: 2.0,
                  locale: const Locale('en'),
                  scopeKey: ValueKey('lesson_long_${lessonId}_${lang}_$modeLabel'),
                ),
              );
              final c = ProviderScope.containerOf(
                tester.element(find.byType(InteractiveLessonScreen)),
              );
              await c.read(courseStateNotifierProvider.notifier).init();
              await c
                  .read(courseStateNotifierProvider.notifier)
                  .selectCourse('course_eng_01');
              await c
                  .read(lessonSessionNotifierProvider.notifier)
                  .startLesson(lessonId, uiLocale: lang);
              await tester.pumpAndSettle();
              expect(
                c.read(courseStateNotifierProvider).activeCourse?.subject,
                SubjectType.english,
              );
            });
            expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
            expect(
              find.text(seedLessons[lessonId]!.localizedTitle(lang)),
              findsWidgets,
            );
            _assertNoZeroWidthText(
              tester,
              screenName: 'InteractiveLessonScreen($lessonId,$lang)',
            );
            _assertNoUnexpectedTruncation(
              tester,
              screenName: 'InteractiveLessonScreen($lessonId,$lang)',
            );
            _assertNoButtonOverlaps(tester);
          }
        },
      );

      testWidgets(
        'Pushed (canPop == true) AppBars for PlacementTestScreen, RoadmapScreen & KnowledgeMapScreen fit 360x800 + 2.0x without clipping in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);

          Future<void> pushAndVerify({
            required String name,
            required Widget child,
            required Future<void> Function(ProviderContainer c) prepare,
            Locale? platformLocale,
          }) async {
            if (platformLocale != null) {
              tester.platformDispatcher.localeTestValue = platformLocale;
              addTearDown(tester.platformDispatcher.clearLocaleTestValue);
            } else {
              tester.platformDispatcher.clearLocaleTestValue();
            }
            await _pumpWithAllErrorsChecked(tester, () async {
              await tester.pumpWidget(
                _wrapScreen(
                  Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute(builder: (_) => child),
                            );
                          },
                          child: const Text('PushRoute'),
                        ),
                      ),
                    ),
                  ),
                  theme: theme,
                  textScale: 2.0,
                  locale: const Locale('en'),
                  scopeKey: ValueKey('pushed_${name}_$modeLabel'),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text('PushRoute'));
              await tester.pumpAndSettle();
              final c = ProviderScope.containerOf(
                tester.element(find.byWidget(child)),
              );
              await prepare(c);
              await tester.pumpAndSettle();
            });
            _assertNoZeroWidthText(tester, screenName: 'Pushed($name)');
            _assertNoUnexpectedTruncation(tester, screenName: 'Pushed($name)');
            _assertNoButtonOverlaps(tester);
          }

          await pushAndVerify(
            name: 'PlacementTestScreen(course_it,ru)',
            child: const PlacementTestScreen(),
            platformLocale: const Locale('ru'),
            prepare: (c) async {
              await c.read(courseStateNotifierProvider.notifier).init();
              await c
                  .read(courseStateNotifierProvider.notifier)
                  .selectCourse('course_it');
              await c
                  .read(placementStateNotifierProvider.notifier)
                  .loadQuestions('course_it');
            },
          );

          await pushAndVerify(
            name: 'RoadmapScreen(ru)',
            child: const RoadmapScreen(),
            platformLocale: const Locale('ru'),
            prepare: (c) async {
              await c.read(courseStateNotifierProvider.notifier).init();
              await c
                  .read(courseStateNotifierProvider.notifier)
                  .selectCourse('course_eng_01');
              await c
                  .read(roadmapStateNotifierProvider.notifier)
                  .loadRoadmap('course_eng_01');
            },
          );

          await pushAndVerify(
            name: 'KnowledgeMapScreen(course_it)',
            child: const KnowledgeMapScreen(),
            prepare: (c) async {
              await c.read(courseStateNotifierProvider.notifier).init();
              await c
                  .read(courseStateNotifierProvider.notifier)
                  .selectCourse('course_it');
            },
          );
        },
      );

      testWidgets(
        'FlashcardDeckWidget (revealed + empty) & LessonMediaWidget (audio + error + transcript) fit 360x800 + 2.0x in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);

          // FlashcardDeckWidget revealed + empty queue
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FlashcardDeckWidget(
                      flashcards: [a1AllFlashcards.first],
                      uiLocale: 'ru',
                    ),
                  ),
                ),
                theme: theme,
                textScale: 2.0,
                scopeKey: ValueKey('fc_200_$modeLabel'),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Показать ответ'));
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(
            tester,
            screenName: 'FlashcardDeckWidget(revealed)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'FlashcardDeckWidget(revealed)',
          );
          _assertNoButtonOverlaps(tester);

          await _pumpWithAllErrorsChecked(tester, () async {
            final remBtn = find.text('Запомнил(а)');
            await tester.ensureVisible(remBtn);
            await tester.pumpAndSettle();
            await tester.tap(remBtn);
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(
            tester,
            screenName: 'FlashcardDeckWidget(empty)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'FlashcardDeckWidget(empty)',
          );
          _assertNoButtonOverlaps(tester);

          // LessonMediaWidget audio + error + expanded transcript
          const mediaWithTranscript = LessonMedia(
            id: 'media_200_test',
            kind: LessonMediaKind.audio,
            language: LessonMediaLanguage.en,
            source: '/lesson-media/english/a1/test.wav',
            title: 'Listening Dialogue',
            durationSeconds: 35,
            transcript: 'Aziza: Hello Ben!\nBen: Hi Aziza, nice to meet you.',
          );
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: LessonMediaWidget(
                      media: mediaWithTranscript,
                      initiallyExpandTranscript: true,
                    ),
                  ),
                ),
                theme: theme,
                textScale: 2.0,
                scopeKey: ValueKey('media_200_err_$modeLabel'),
                extraOverrides: [
                  lessonAudioControllerFactoryProvider.overrideWithValue(
                    () => FakeLessonAudioController(failOnLoad: true),
                  ),
                ],
              ),
            );
            await tester.pumpAndSettle();
          });
          _assertNoZeroWidthText(
            tester,
            screenName: 'LessonMediaWidget(2.0x+error)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'LessonMediaWidget(2.0x+error)',
          );
          _assertNoButtonOverlaps(tester);
          final transcriptPara = tester.renderObject<RenderParagraph>(
            find.byWidgetPredicate(
              (w) =>
                  w is RichText &&
                  w.text.toPlainText().contains('Aziza: Hello Ben!'),
            ),
          );
          expect(
            transcriptPara.textScaler,
            const TextScaler.linear(2.0),
          );
        },
      );

      testWidgets(
        'CourseSelectionScreen (course_it selected, uz & ru) & ProfileScreen (pushed ru) fit 360x800 + 2.0x without overflow or AppBar clipping in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);

          for (final localeCode in ['uz', 'ru']) {
            tester.platformDispatcher.localeTestValue = Locale(localeCode);
            addTearDown(tester.platformDispatcher.clearLocaleTestValue);
            await _pumpWithAllErrorsChecked(tester, () async {
              await tester.pumpWidget(
                _wrapScreen(
                  const CourseSelectionScreen(),
                  theme: theme,
                  textScale: 2.0,
                  scopeKey: ValueKey('cs_it_${localeCode}_$modeLabel'),
                ),
              );
              final c = ProviderScope.containerOf(
                tester.element(find.byType(CourseSelectionScreen)),
              );
              await c.read(courseStateNotifierProvider.notifier).init();
              await c
                  .read(courseStateNotifierProvider.notifier)
                  .selectCourse('course_it');
              await c
                  .read(learnerStateNotifierProvider.notifier)
                  .updateOnboarding(
                    courseId: 'course_it',
                    goal: OnboardingGoal.skillsBoost,
                    dailyMinutes: 15,
                    initialLevel: InitialLevel.beginner,
                  );
              await tester.pumpAndSettle();
              final badgeLabel = localeCode == 'ru' ? 'Выбрано' : 'Tanlangan';
              await tester.scrollUntilVisible(find.text(badgeLabel), 200);
              await tester.pumpAndSettle();
              expect(find.text(badgeLabel), findsOneWidget);
            });
            _assertNoZeroWidthText(
              tester,
              screenName: 'CourseSelectionScreen(course_it,$localeCode)',
            );
            _assertNoUnexpectedTruncation(
              tester,
              screenName: 'CourseSelectionScreen(course_it,$localeCode)',
            );
            _assertNoButtonOverlaps(tester);
          }

          // Pushed ProfileScreen (canPop == true) in ru
          tester.platformDispatcher.localeTestValue = const Locale('ru');
          addTearDown(tester.platformDispatcher.clearLocaleTestValue);
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                        child: const Text('PushProfile'),
                      ),
                    ),
                  ),
                ),
                theme: theme,
                textScale: 2.0,
                scopeKey: ValueKey('pushed_profile_ru_$modeLabel'),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('PushProfile'));
            await tester.pumpAndSettle();
          });
          expect(find.text('Мой профиль'), findsOneWidget);
          _assertNoZeroWidthText(
            tester,
            screenName: 'Pushed(ProfileScreen,ru)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'Pushed(ProfileScreen,ru)',
          );
          _assertNoButtonOverlaps(tester);
        },
      );

      testWidgets(
        'InteractiveLessonScreen B1 steps & sentenceOrder (unselected + selected chips) fit 360x800 + 2.0x without overflow in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);

          for (final entry in [
            ('lesson_eng_b1_m2_work_study', 3, 'b1_m2_step4'),
            ('lesson_eng_b1_m3_narrative', 3, 'b1_m3_step4'),
            ('lesson_eng_b1_m3_narrative', 4, 'b1_m3_wordMatch'),
            ('lesson_eng_b1_exit', 4, 'b1_exit_sentenceOrder'),
          ]) {
            await _pumpWithAllErrorsChecked(tester, () async {
              await tester.pumpWidget(
                _wrapScreen(
                  const InteractiveLessonScreen(),
                  theme: theme,
                  textScale: 2.0,
                  scopeKey: ValueKey('${entry.$3}_$modeLabel'),
                ),
              );
              final c = ProviderScope.containerOf(
                tester.element(find.byType(InteractiveLessonScreen)),
              );
              await c.read(courseStateNotifierProvider.notifier).init();
              await c
                  .read(courseStateNotifierProvider.notifier)
                  .selectCourse('course_eng_01');
              await c
                  .read(lessonSessionNotifierProvider.notifier)
                  .startLesson(entry.$1, uiLocale: 'uz');
              for (var i = 0; i < entry.$2; i++) {
                await c
                    .read(lessonSessionNotifierProvider.notifier)
                    .nextStep(uiLocale: 'uz');
              }
              await tester.pumpAndSettle();

              if (entry.$3 == 'b1_exit_sentenceOrder') {
                final tokens = [
                  'The mentor',
                  'said that',
                  'we ought',
                  'to test',
                  'our backup',
                  'plan today.',
                ];
                for (final tok in tokens) {
                  final chip = find.widgetWithText(ActionChip, tok);
                  await tester.ensureVisible(chip);
                  await tester.pumpAndSettle();
                  await tester.tap(chip);
                  await tester.pumpAndSettle();
                }
                expect(find.byType(InputChip), findsNWidgets(tokens.length));
              }
            });
            _assertNoZeroWidthText(
              tester,
              screenName: 'InteractiveLessonScreen(${entry.$3})',
            );
            _assertNoUnexpectedTruncation(
              tester,
              screenName: 'InteractiveLessonScreen(${entry.$3})',
            );
            _assertNoButtonOverlaps(tester);
          }

          // Synthetic long-token sentenceOrder (both ActionChip and InputChip)
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const InteractiveLessonScreen(),
                theme: theme,
                textScale: 2.0,
                scopeKey: ValueKey('long_token_sentenceOrder_$modeLabel'),
              ),
            );
            final c = ProviderScope.containerOf(
              tester.element(find.byType(InteractiveLessonScreen)),
            );
            await c.read(courseStateNotifierProvider.notifier).init();
            await c
                .read(courseStateNotifierProvider.notifier)
                .selectCourse('course_eng_01');
            const longTokenLesson = Lesson(
              id: 'lesson_long_token_test',
              courseId: 'course_eng_01',
              skillId: 'skill_eng_grammar',
              title: 'Long Token Test',
              estimatedMinutes: 5,
              summary: 'Test',
              steps: [
                LessonStep(
                  id: 'step_long_token',
                  stepNumber: 1,
                  type: LessonStepType.interactiveQuestion,
                  title: 'Sentence Order',
                  content: 'Order the tokens',
                  interactiveQuestion: Question(
                    id: 'q_long_token',
                    courseId: 'course_eng_01',
                    skillId: 'skill_eng_grammar',
                    text: 'Arrange the clauses:',
                    mode: QuestionMode.sentenceOrder,
                    options: [],
                    correctIndex: 0,
                    orderedTokens: [
                      'Although the presentation was postponed,',
                      'our entire engineering team',
                      'collaborated effectively.',
                    ],
                    difficulty: QuestionDifficulty.medium,
                    explanation: 'Clause order.',
                  ),
                ),
              ],
              reinforcementExercise: Question(
                id: 'q_long_token_reinf',
                courseId: 'course_eng_01',
                skillId: 'skill_eng_grammar',
                text: 'Fallback question:',
                options: ['A', 'B'],
                correctIndex: 0,
                difficulty: QuestionDifficulty.easy,
                explanation: 'A.',
              ),
            );
            c.read(lessonSessionNotifierProvider.notifier).state =
                const LessonSessionState(
                  lesson: longTokenLesson,
                  currentStepIndex: 0,
                );
            await tester.pumpAndSettle();

            final longChip = find.widgetWithText(
              ActionChip,
              'Although the presentation was postponed,',
            );
            await tester.ensureVisible(longChip);
            await tester.pumpAndSettle();
            await tester.tap(longChip);
            await tester.pumpAndSettle();
            expect(find.byType(InputChip), findsOneWidget);
          });
          _assertNoZeroWidthText(
            tester,
            screenName: 'InteractiveLessonScreen(long_token_sentenceOrder)',
          );
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'InteractiveLessonScreen(long_token_sentenceOrder)',
          );
          _assertNoButtonOverlaps(tester);
        },
      );

      testWidgets(
        'Pushed AITutorScreen (lesson_eng_vocab_01, initial/online/offline, uz & ru) & YolchiBubble render at 360x800 + 2.0x without overflow or AppBar clipping in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);

          // Standalone AITutorScreen + tap quick ActionChip -> YolchiBubble
          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const AITutorScreen(),
                theme: theme,
                textScale: 2.0,
                scopeKey: ValueKey('ai_200_ok_$modeLabel'),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Qoidani sodda tushuntir'));
            await tester.pumpAndSettle();
          });
          expect(find.text('Foydali javob'), findsOneWidget);
          await _pumpWithAllErrorsChecked(tester, () async {
            final helpfulBtn = find.text('Foydali javob');
            await tester.ensureVisible(helpfulBtn);
            await tester.pumpAndSettle();
            await tester.tap(helpfulBtn);
            await tester.pumpAndSettle();
          });
          expect(find.text('Foydali deb belgilandi'), findsOneWidget);
          _assertNoZeroWidthText(tester, screenName: 'AITutorScreen(helpful)');
          _assertNoUnexpectedTruncation(
            tester,
            screenName: 'AITutorScreen(helpful)',
          );
          _assertNoButtonOverlaps(tester);

          // Pushed lesson-scoped AITutorScreen (canPop == true, remote config = true) across uz & ru: initial, online, offline
          final prevRemote = SupabaseConfig.hasRemoteConfiguration;
          SupabaseConfig.hasRemoteConfiguration = true;
          addTearDown(() {
            SupabaseConfig.hasRemoteConfiguration = prevRemote;
          });

          for (final localeCode in ['uz', 'ru']) {
            for (final shouldFail in [false, true]) {
              tester.platformDispatcher.localeTestValue = Locale(localeCode);
              addTearDown(tester.platformDispatcher.clearLocaleTestValue);

              await _pumpWithAllErrorsChecked(tester, () async {
                await tester.pumpWidget(
                  _wrapScreen(
                    Builder(
                      builder: (context) => Scaffold(
                        body: Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => AITutorScreen(
                                    lesson: seedLessons['lesson_eng_vocab_01'],
                                  ),
                                ),
                              );
                            },
                            child: const Text('PushTutor'),
                          ),
                        ),
                      ),
                    ),
                    theme: theme,
                    textScale: 2.0,
                    scopeKey: ValueKey(
                      'ai_pushed_${localeCode}_${shouldFail}_$modeLabel',
                    ),
                    extraOverrides: [
                      aiTutorServiceProvider.overrideWithValue(
                        _FakeOnlineAITutorService(shouldFail: shouldFail),
                      ),
                    ],
                  ),
                );
                await tester.pumpAndSettle();
                await tester.tap(find.text('PushTutor'));
                await tester.pumpAndSettle();
              });

              // Initial (_serviceOnline == null) shows full lesson_eng_vocab_01 title
              _assertNoZeroWidthText(
                tester,
                screenName: 'AITutorScreen($localeCode,initial)',
              );
              _assertNoUnexpectedTruncation(
                tester,
                screenName: 'AITutorScreen($localeCode,initial)',
              );
              _assertNoButtonOverlaps(tester);

              // Trigger quick prompt -> online or offline state
              final chipLabel = localeCode == 'ru'
                  ? 'Объясни правило проще'
                  : 'Qoidani sodda tushuntir';
              await _pumpWithAllErrorsChecked(tester, () async {
                await tester.tap(find.text(chipLabel));
                await tester.pumpAndSettle();
              });
              final stateTag = shouldFail ? 'offline' : 'online';
              _assertNoZeroWidthText(
                tester,
                screenName: 'AITutorScreen($localeCode,$stateTag)',
              );
              _assertNoUnexpectedTruncation(
                tester,
                screenName: 'AITutorScreen($localeCode,$stateTag)',
              );
              _assertNoButtonOverlaps(tester);
            }
          }
        },
      );
    }
  });

  // Item (g): RegisterScreen keyboard open (bottom <= 500) for all 3 errors in Light & Dark
  group('RegisterScreen Keyboard & Error Visibility', () {
    for (final isDark in [false, true]) {
      final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
      final modeLabel = isDark ? 'Dark' : 'Light';

      testWidgets(
        'scrolled user with keyboard open sees all 3 signup error states with >= 4.5:1 contrast in $modeLabel',
        (tester) async {
          _configurePhoneViewport(tester);

          void assertErrorVisibleAboveKeyboard(Finder errFinder) {
            expect(errFinder, findsOneWidget);
            final rect = tester.getRect(errFinder);
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(500));
            final text = tester.widget<Text>(errFinder);
            expect(
              _contrastRatio(
                text.style!.color!,
                AppColors.errorTint(tester.element(errFinder)),
              ),
              greaterThanOrEqualTo(4.5),
            );
          }

          await _pumpWithAllErrorsChecked(tester, () async {
            await tester.pumpWidget(
              _wrapScreen(
                const RegisterScreen(),
                theme: theme,
                viewInsets: const EdgeInsets.only(bottom: 300),
              ),
            );
            await tester.pumpAndSettle();

            final confirmLabel = find.text('Parolni tasdiqlang *');
            await tester.ensureVisible(confirmLabel);
            await tester.pumpAndSettle();

            final submitBtn = find.text('Hisob Yaratish');
            await tester.ensureVisible(submitBtn);
            await tester.pumpAndSettle();
            expect(tester.getRect(submitBtn).bottom, lessThanOrEqualTo(500));

            // 1. Empty submit
            await tester.tap(submitBtn);
            await tester.pumpAndSettle();
            assertErrorVisibleAboveKeyboard(
              find.text('Iltimos, barcha majburiy maydonlarni to‘ldiring.'),
            );

            // 2. Short password
            final fields = find.byType(TextField);
            await tester.enterText(fields.at(0), 'Ali');
            await tester.enterText(fields.at(1), 'ali@example.com');
            await tester.enterText(fields.at(2), '123');
            await tester.enterText(fields.at(3), '123');
            await tester.ensureVisible(submitBtn);
            await tester.pumpAndSettle();
            await tester.tap(submitBtn);
            await tester.pumpAndSettle();
            assertErrorVisibleAboveKeyboard(
              find.text('Parol kamida 6 ta belgidan iborat bo‘lishi kerak.'),
            );

            // 3. Mismatched password
            await tester.enterText(fields.at(2), '123456');
            await tester.enterText(fields.at(3), '654321');
            await tester.ensureVisible(submitBtn);
            await tester.pumpAndSettle();
            await tester.tap(submitBtn);
            await tester.pumpAndSettle();
            assertErrorVisibleAboveKeyboard(
              find.text('Kiritilgan parollar bir-biriga mos kelmadi.'),
            );
          });
        },
      );
    }
  });

  // Item (h): Offline Demo Journey in BOTH Light & Dark Modes
  group('Offline Demo Journey in Light & Dark Modes (360x800)', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final modeLabel = brightness == Brightness.dark ? 'Dark' : 'Light';
      testWidgets(
        'Namuna hisobi bilan kirish -> fan tanlash -> darsni ochish ($modeLabel)',
        (tester) async {
          _configurePhoneViewport(tester);
          demoSessionActive.value = false;
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );

          await _pumpWithAllErrorsChecked(tester, () async {
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

            final demoBtn = find.text('Namuna hisobi bilan kirish');
            await tester.ensureVisible(demoBtn);
            await tester.tap(demoBtn);
            await tester.pumpAndSettle();

            expect(find.text('Ingliz tili'), findsWidgets);
            await tester.tap(find.text('Ingliz tili').first);
            await tester.pumpAndSettle();

            expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);
            await tester.tap(find.text('Noldan boshlayman'));
            await tester.pumpAndSettle();

            final startLesson = find.text('Birinchi darsni boshlash');
            await tester.scrollUntilVisible(startLesson, 180);
            await tester.ensureVisible(startLesson);
            await tester.pumpAndSettle();
            await tester.tap(startLesson);
            await tester.pumpAndSettle();

            expect(find.text('Birinchi inglizcha so‘zlar'), findsWidgets);
          });
        },
      );
    }

    testWidgets(
      'Namuna hisobi bilan kirish -> Matematika (course_math_01) -> darsni ochish (Light)',
      (tester) async {
        _configurePhoneViewport(tester);
        demoSessionActive.value = false;
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
        addTearDown(
          tester.platformDispatcher.clearPlatformBrightnessTestValue,
        );

        await _pumpWithAllErrorsChecked(tester, () async {
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

          final demoBtn = find.text('Namuna hisobi bilan kirish');
          await tester.ensureVisible(demoBtn);
          await tester.tap(demoBtn);
          await tester.pumpAndSettle();

          expect(find.text('Matematika'), findsWidgets);
          await tester.tap(find.text('Matematika').first);
          await tester.pumpAndSettle();

          expect(find.text('Qayerdan boshlamoqchisiz?'), findsOneWidget);
          await tester.tap(find.text('Noldan boshlayman'));
          await tester.pumpAndSettle();

          final startLesson = find.text('Birinchi darsni boshlash');
          await tester.scrollUntilVisible(startLesson, 180);
          await tester.ensureVisible(startLesson);
          await tester.pumpAndSettle();
          await tester.tap(startLesson);
          await tester.pumpAndSettle();

          expect(
            find.text('Qo‘shish va ayirishdan boshlaymiz'),
            findsWidgets,
          );
        });
      },
    );
  });
}
