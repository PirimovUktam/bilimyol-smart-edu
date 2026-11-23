import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bilimyol_mobile/app/app.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/core/constants/app_colors.dart';
import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/core/storage/local_storage_service.dart';
import 'package:bilimyol_mobile/core/theme/app_semantic_colors.dart';
import 'package:bilimyol_mobile/core/theme/app_theme.dart';
import 'package:bilimyol_mobile/core/widgets/app_badge.dart';
import 'package:bilimyol_mobile/core/widgets/app_button.dart';
import 'package:bilimyol_mobile/core/widgets/demo_control_bar.dart';
import 'package:bilimyol_mobile/core/widgets/edtech_section_header.dart';

double _relativeLuminance(Color c) {
  double linear(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linear(c.r) +
      0.7152 * linear(c.g) +
      0.0722 * linear(c.b);
}

double _contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Theme, Contrast, L10n & LocalStorageService', () {
    testWidgets('LocalStorageService inside testWidgets without mocked SharedPreferences does not leak MissingPluginException', (tester) async {
      final storage = LocalStorageService();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final settings = container.read(appSettingsProvider);
      expect(settings.localeCode, 'uz');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: FutureBuilder<String>(
                future: storage.getLocaleCode(),
                builder: (context, snap) => Text(snap.data ?? 'loading'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('uz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('AppColors.textMuted and primary CTAs meet WCAG AA contrast >= 4.5:1', () {
      expect(_contrastRatio(AppColors.textMuted, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textMuted, AppColors.background), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(12.0));
      expect(_contrastRatio(Colors.white, AppSemanticColors.light.ctaPrimary), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(Colors.white, AppSemanticColors.dark.ctaPrimary), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppSemanticColors.dark.slatefine, AppSemanticColors.dark.paper), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppSemanticColors.dark.brand, AppSemanticColors.dark.paper), greaterThanOrEqualTo(4.5));

      const light = AppSemanticColors.light;
      expect(_contrastRatio(light.faint, light.subtle), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(light.faint, light.paper), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(light.faint, light.canvas), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(light.path, Color.alphaBlend(light.pathSoft, light.paper)),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrastRatio(light.path, light.paper), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(light.path, light.canvas), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(light.errorText, Color.alphaBlend(light.errorSoft, light.paper)),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('AppTheme.lightTheme and darkTheme expose AppSemanticColors', () {
      final lightExt = AppTheme.lightTheme.extension<AppSemanticColors>();
      final darkExt = AppTheme.darkTheme.extension<AppSemanticColors>();
      expect(lightExt, isNotNull);
      expect(darkExt, isNotNull);
      expect(lightExt!.isDark, isFalse);
      expect(darkExt!.isDark, isTrue);
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.background);
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppColors.darkCanvas);
    });

    test('AppStrings returns distinct uz and ru translations', () {
      final uz = AppStrings.forCode('uz');
      final ru = AppStrings.forCode('ru');
      expect(uz.navHome, 'Boş sahifa');
      expect(ru.navHome, 'Главная');
      expect(uz.navRoadmap, 'Ta’lim yöli');
      expect(ru.navRoadmap, 'Путь обучения');
      expect(uz.demoReset, 'Qayta boşlaş');
      expect(ru.demoReset, 'Сбросить');
    });

    test('LocalStorageService persists preferences round-trip and falls back safely', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.load();

      expect(storage.getProductTourCompletedSync(), isFalse);
      expect(storage.getLocaleCodeSync(), 'uz');
      expect(storage.getThemeModeSync(), ThemeMode.system);
      expect(storage.getDemoSessionActiveSync(), isFalse);

      await storage.setProductTourCompleted(true);
      await storage.setLocaleCode('ru');
      await storage.setThemeMode(ThemeMode.dark);
      await storage.setDemoSessionActive(true);

      final reloaded = await LocalStorageService.load();
      expect(reloaded.getProductTourCompletedSync(), isTrue);
      expect(reloaded.getLocaleCodeSync(), 'ru');
      expect(reloaded.getThemeModeSync(), ThemeMode.dark);
      expect(reloaded.getDemoSessionActiveSync(), isTrue);

      // Isolated in-memory fallback without SharedPreferences binding
      final fallback = LocalStorageService();
      await fallback.setLocaleCode('ru');
      expect(await fallback.getLocaleCode(), 'ru');
    });

    test('AppSettingsNotifier persists locale, themeMode, and productTourCompleted', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.load();

      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setLocale('ru');
      await notifier.setThemeMode(ThemeMode.dark);
      await notifier.completeProductTour();

      final state = container.read(appSettingsProvider);
      expect(state.localeCode, 'ru');
      expect(state.locale, const Locale('ru'));
      expect(state.themeMode, ThemeMode.dark);
      expect(state.productTourCompleted, isTrue);

      expect(await storage.getLocaleCode(), 'ru');
      expect(await storage.getThemeMode(), ThemeMode.dark);
      expect(await storage.getProductTourCompleted(), isTrue);
    });

    testWidgets('BilimYolApp renders cleanly in Light/Dark and uz/ru with zero errors', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.load();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BilimYolApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await container.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);
      await container.read(appSettingsProvider.notifier).setLocale('ru');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('concurrent LocalStorageService calls before prefs resolve do not drop writes', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();

      await Future.wait([
        storage.getLocaleCode(),
        storage.setThemeMode(ThemeMode.dark),
        storage.setDemoLearnerSnapshot('{"version":1}'),
      ]);

      final reloaded = await LocalStorageService.load();
      expect(reloaded.getThemeModeSync(), ThemeMode.dark);
      expect(await reloaded.getDemoLearnerSnapshot(), '{"version":1}');
    });

    test('AppSettingsNotifier synchronous setLocale before _hydrate preserves persisted themeMode and tour', () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.localeKey: 'uz',
        LocalStorageService.themeModeKey: 'dark',
        LocalStorageService.productTourCompletedKey: true,
      });
      final storage = await LocalStorageService.load();

      final delayedStorage = _DelayedReadStorage(storage);
      final notifier = AppSettingsNotifier(delayedStorage);
      addTearDown(notifier.dispose);

      // Mutate locale synchronously while _hydrate() is awaiting storage
      unawaited(notifier.setLocale('ru'));
      delayedStorage.release();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.localeCode, 'ru');
      expect(notifier.state.themeMode, ThemeMode.dark);
      expect(notifier.state.productTourCompleted, isTrue);
    });

    testWidgets('DemoControlBar and AppBadge render without overflow at 360dp @ 2.0x in uz and ru', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final code in ['uz', 'ru']) {
        final badgeText = code == 'ru'
            ? 'Адаптивная образовательная платформа'
            : 'Moslaşuvçan ta’lim platformasi';
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              locale: Locale(code),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DemoControlBar(),
                      const SizedBox(height: 12),
                      AppBadge(
                        text: badgeText,
                        variant: AppBadgeVariant.teal,
                        icon: const Icon(Icons.auto_awesome, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow in locale $code');
      }
    });

    testWidgets('DemoControlBar stacks cleanly without squeezing or overflowing at 360dp with 1.34x text scale', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final code in ['uz', 'ru']) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              locale: Locale(code),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.34),
                ),
                child: child!,
              ),
              home: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    height: 200,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: DemoControlBar(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow at 1.34x in $code');

        final strings = AppStrings.forCode(code);
        final bannerSize = tester.getSize(find.text(strings.demoBanner));
        expect(
          bannerSize.width,
          greaterThan(200),
          reason: 'Banner text squeezed at 1.34x in $code: $bannerSize',
        );
      }
    });

    test('AppSettingsNotifier out-of-order delayed writes persist the latest value', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.load();
      final delayedStorage = _OutOfOrderWriteStorage(storage);
      final notifier = AppSettingsNotifier(
        delayedStorage,
        initial: const AppSettingsState(),
      );
      addTearDown(notifier.dispose);

      final slowRu = notifier.setLocale('ru');
      final fastUz = notifier.setLocale('uz');
      delayedStorage.completeLocaleWrite('uz');
      await fastUz;
      delayedStorage.completeLocaleWrite('ru');
      await slowRu;

      expect(notifier.state.localeCode, 'uz');
      expect(await storage.getLocaleCode(), 'uz');

      final slowDark = notifier.setThemeMode(ThemeMode.dark);
      final fastLight = notifier.setThemeMode(ThemeMode.light);
      delayedStorage.completeThemeWrite(ThemeMode.light);
      await fastLight;
      delayedStorage.completeThemeWrite(ThemeMode.dark);
      await slowDark;

      expect(notifier.state.themeMode, ThemeMode.light);
      expect(await storage.getThemeMode(), ThemeMode.light);

      final slowComplete = notifier.completeProductTour();
      final fastReset = notifier.resetProductTour();
      delayedStorage.completeTourWrite(false);
      await fastReset;
      delayedStorage.completeTourWrite(true);
      await slowComplete;

      expect(notifier.state.productTourCompleted, isFalse);
      expect(await storage.getProductTourCompleted(), isFalse);
    });

    test('LocalStorageService returns defaults instead of throwing TypeError on mismatched value types', () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.productTourCompletedKey: 'not-a-bool',
        LocalStorageService.demoSessionActiveKey: 123,
        LocalStorageService.localeKey: true,
        LocalStorageService.themeModeKey: 42,
        LocalStorageService.demoLearnerSnapshotKey: false,
      });
      final storage = await LocalStorageService.load();

      expect(storage.getProductTourCompletedSync(), isFalse);
      expect(await storage.getProductTourCompleted(), isFalse);
      expect(storage.getDemoSessionActiveSync(), isFalse);
      expect(await storage.getDemoSessionActive(), isFalse);
      expect(storage.getLocaleCodeSync(), 'uz');
      expect(await storage.getLocaleCode(), 'uz');
      expect(storage.getThemeModeSync(), ThemeMode.system);
      expect(await storage.getThemeMode(), ThemeMode.system);
      expect(await storage.getDemoLearnerSnapshot(), isNull);
    });

    testWidgets('EdTechSectionHeader with trailing renders without overflow at 360dp @ 2.0x and 1.0x in uz and ru', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final scale in [1.0, 2.0]) {
        for (final code in ['uz', 'ru']) {
          final s = AppStrings.forCode(code);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              locale: Locale(code),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: AppStrings.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: EdTechSectionHeader(
                    title: s.knowledgeMapTitle,
                    trailing: AppButton(
                      text: s.demoReset,
                      size: AppButtonSize.small,
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow in EdTechSectionHeader ($code @ ${scale}x)',
          );
          expect(find.text(s.demoReset), findsOneWidget);
        }
      }
    });
  });
}

class _DelayedReadStorage extends LocalStorageService {
  final LocalStorageService _delegate;
  final Completer<void> _gate = Completer<void>();

  _DelayedReadStorage(this._delegate);

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<String> getLocaleCode() async {
    await _gate.future;
    return _delegate.getLocaleCode();
  }

  @override
  Future<ThemeMode> getThemeMode() async {
    await _gate.future;
    return _delegate.getThemeMode();
  }

  @override
  Future<bool> getProductTourCompleted() async {
    await _gate.future;
    return _delegate.getProductTourCompleted();
  }

  @override
  Future<void> setLocaleCode(String code) => _delegate.setLocaleCode(code);
}

class _OutOfOrderWriteStorage extends LocalStorageService {
  final LocalStorageService _delegate;
  final Map<String, Completer<void>> _localeGates = {
    'ru': Completer<void>(),
    'uz': Completer<void>(),
  };
  final Map<ThemeMode, Completer<void>> _themeGates = {
    ThemeMode.dark: Completer<void>(),
    ThemeMode.light: Completer<void>(),
  };
  final Map<bool, Completer<void>> _tourGates = {
    true: Completer<void>(),
    false: Completer<void>(),
  };

  _OutOfOrderWriteStorage(this._delegate);

  void completeLocaleWrite(String code) {
    final gate = _localeGates[code];
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void completeThemeWrite(ThemeMode mode) {
    final gate = _themeGates[mode];
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void completeTourWrite(bool completed) {
    final gate = _tourGates[completed];
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<void> setLocaleCode(String code) async {
    await _localeGates[code]?.future;
    await _delegate.setLocaleCode(code);
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    await _themeGates[mode]?.future;
    await _delegate.setThemeMode(mode);
  }

  @override
  Future<void> setProductTourCompleted(bool completed) async {
    await _tourGates[completed]?.future;
    await _delegate.setProductTourCompleted(completed);
  }
}
