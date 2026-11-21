import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/auth/demo_session.dart';
import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../data/datasources/starter_lessons_data.dart';
import '../../domain/entities/question.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  final bool isReplay;

  const WelcomeScreen({super.key, this.isReplay = false});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int? _miniQuizSelectedIndex;
  bool _isCompleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeTour() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await ref.read(appSettingsProvider.notifier).completeProductTour();
      if (!mounted) return;
      final hasActiveSession = SupabaseConfig.hasRemoteConfiguration
          ? SupabaseConfig.client?.auth.currentUser != null
          : demoSessionActive.value;
      if (widget.isReplay && hasActiveSession) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/profile');
        }
      } else {
        context.go('/login');
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _handleNext() async {
    if (_currentPage < 2) {
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      final nextPage = _currentPage + 1;
      if (disableAnimations) {
        _pageController.jumpToPage(nextPage);
      } else {
        await _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    await _completeTour();
  }

  static AppStrings _resolveStrings(BuildContext context) {
    final localized = Localizations.of<AppStrings>(context, AppStrings);
    if (localized != null) return localized;
    final appLang = Localizations.maybeLocaleOf(context)?.languageCode;
    if (appLang == 'ru') return AppStrings.ru;
    if (appLang == 'uz') return AppStrings.uz;
    return WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ru'
        ? AppStrings.ru
        : AppStrings.uz;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final settings = ref.watch(appSettingsProvider);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final starterLesson = starterLessons['lesson_math_starter'];
    final Question? miniQuestion =
        starterLesson?.steps
            .where((step) => step.interactiveQuestion != null)
            .map((step) => step.interactiveQuestion!)
            .firstOrNull;

    final slides = [
      _TourSlideSpec(
        stage: 0,
        title: s.tourSlide1Title,
        body: s.tourSlide1Body,
        visualBuilder: (context) => _DiagnosticConstellationStage(
          c: c,
          s: s,
        ),
      ),
      _TourSlideSpec(
        stage: 1,
        title: s.tourSlide2Title,
        body: s.tourSlide2Body,
        visualBuilder: (context) => _InteractiveLessonStage(
          c: c,
          s: s,
          lessonTitle: s.tourSlide2MiniLessonTitle(
            starterLesson?.title ?? s.lessonLabel,
          ),
          question: miniQuestion,
          selectedIndex: _miniQuizSelectedIndex,
          onSelect: (idx) => setState(() => _miniQuizSelectedIndex = idx),
        ),
      ),
      _TourSlideSpec(
        stage: 2,
        title: s.tourSlide3Title,
        body: s.tourSlide3Body,
        visualBuilder: (context) => _GrowthMapStage(
          c: c,
          s: s,
        ),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar: Logo, UZ/RU, Theme, Skip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(context).scale(1.0);

                      final langBtn = Tooltip(
                        message: s.tourLanguageToggleTooltip,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            final next =
                                settings.localeCode == 'uz' ? 'ru' : 'uz';
                            ref
                                .read(appSettingsProvider.notifier)
                                .setLocale(next);
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.subtle,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: c.hairline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  settings.localeCode.toUpperCase(),
                                  style: AppTypography.mono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: c.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      final themeBtn = IconButton(
                        tooltip: s.tourThemeToggleTooltip,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final nextMode = c.isDark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                          ref
                              .read(appSettingsProvider.notifier)
                              .setThemeMode(nextMode);
                        },
                        icon: Icon(
                          c.isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: c.ink,
                          size: 20,
                        ),
                      );

                      final skipBtn = TextButton(
                        onPressed: _isCompleting ? null : _completeTour,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: c.slatefine,
                        ),
                        child: Text(
                          s.tourSkip,
                          style: AppTypography.ui(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.slatefine,
                          ),
                        ),
                      );

                      final actionsWrap = Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.end,
                        children: [langBtn, themeBtn, skipBtn],
                      );

                      if (constraints.maxWidth < 370 || textScale >= 1.3) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: BilimYolLogo(
                                    size: 26,
                                    showSubtitle: false,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(child: skipBtn),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.end,
                              children: [langBtn, themeBtn],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Expanded(
                            child: BilimYolLogo(size: 26, showSubtitle: false),
                          ),
                          const SizedBox(width: 8),
                          actionsWrap,
                        ],
                      );
                    },
                  ),
                ),

                // 3-Page Swipeable Tour Body
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: (idx) {
                      setState(() => _currentPage = idx);
                    },
                    itemBuilder: (context, index) {
                      return _TourSlideView(
                        spec: slides[index],
                        c: c,
                        s: s,
                      );
                    },
                  ),
                ),

                // Bottom Controls: Dots + Step Counter + Primary Action
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(slides.length, (idx) {
                              final active = idx == _currentPage;
                              return Semantics(
                                selected: active,
                                label: s.tourStepCounter(idx + 1, slides.length),
                                child: AnimatedContainer(
                                  duration: disableAnimations
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                  margin: const EdgeInsets.only(right: 8),
                                  width: active ? 26 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: active ? c.brand : c.hairline,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              );
                            }),
                          ),
                          Text(
                            s.tourStepCounter(_currentPage + 1, slides.length),
                            style: AppTypography.mono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.slatefine,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        text: _currentPage < slides.length - 1
                            ? s.tourNext
                            : s.tourFinish,
                        isFullWidth: true,
                        size: AppButtonSize.large,
                        isLoading: _isCompleting,
                        rightIcon: Icon(
                          _currentPage < slides.length - 1
                              ? Icons.arrow_forward_rounded
                              : Icons.rocket_launch_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: _handleNext,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TourSlideSpec {
  final int stage;
  final String title;
  final String body;
  final WidgetBuilder visualBuilder;

  const _TourSlideSpec({
    required this.stage,
    required this.title,
    required this.body,
    required this.visualBuilder,
  });
}

class _TourSlideView extends StatelessWidget {
  final _TourSlideSpec spec;
  final AppSemanticColors c;
  final AppStrings s;

  const _TourSlideView({
    required this.spec,
    required this.c,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_rounded, size: 14, color: c.brand),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    s.tourConceptPill,
                    style: AppTypography.ui(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          spec.visualBuilder(context),
          const SizedBox(height: 20),
          Text(
            spec.title,
            style: AppTypography.ui(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: -0.5,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            spec.body,
            style: AppTypography.ui(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: c.graphite,
              height: 1.48,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticConstellationStage extends StatelessWidget {
  final AppSemanticColors c;
  final AppStrings s;

  const _DiagnosticConstellationStage({
    required this.c,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: c.subtle,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar_rounded, size: 14, color: c.path),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    s.tourSlide1VisualTitle,
                    style: AppTypography.ui(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 156,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _TourAssetFrame(
                      assetPath: 'assets/tour/tour_1_start.png',
                      stage: 0,
                      c: c,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 8,
                    child: const YolchiAIMascot(
                      size: 46,
                      mood: YolchiMood.thinking,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StageNodePill(
                label: s.tourSlide1Chip1,
                fg: c.successText,
                bg: c.successSoft,
                icon: Icons.check_circle_rounded,
              ),
              _StageNodePill(
                label: s.tourSlide1Chip2,
                fg: c.brand,
                bg: c.brandSoft,
                icon: Icons.my_location_rounded,
              ),
              _StageNodePill(
                label: s.tourSlide1Chip3,
                fg: c.slatefine,
                bg: c.subtle,
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InteractiveLessonStage extends StatelessWidget {
  final AppSemanticColors c;
  final AppStrings s;
  final String lessonTitle;
  final Question? question;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _InteractiveLessonStage({
    required this.c,
    required this.s,
    required this.lessonTitle,
    required this.question,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final hasSelection = selectedIndex != null && q != null;
    final isCorrect = hasSelection && selectedIndex == q.correctIndex;

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.brand.withValues(alpha: 0.25)),
                ),
                child: Icon(
                  Icons.calculate_outlined,
                  size: 16,
                  color: c.brand,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lessonTitle,
                  style: AppTypography.ui(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 124,
            width: double.infinity,
            child: _TourAssetFrame(
              assetPath: 'assets/tour/tour_2_lesson.png',
              stage: 1,
              c: c,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.tourSlide2InteractiveHint,
            style: AppTypography.ui(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.path,
            ),
          ),
          const SizedBox(height: 4),
          if (q != null) ...[
            Text(
              s.tourSlide2MiniQuestionText(q.text),
              style: AppTypography.ui(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: c.ink,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(q.options.length, (idx) {
                final picked = selectedIndex == idx;
                final correctPick = picked && idx == q.correctIndex;
                final wrongPick = picked && idx != q.correctIndex;
                return Semantics(
                  button: true,
                  selected: picked,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(idx),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 56,
                        minHeight: 44,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: correctPick
                              ? c.successSoft
                              : wrongPick
                              ? c.warningSoft
                              : picked
                              ? c.brandSoft
                              : c.subtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: correctPick
                                ? c.success
                                : wrongPick
                                ? c.warning
                                : picked
                                ? c.brand
                                : c.hairline,
                            width: picked ? 1.8 : 1.0,
                          ),
                        ),
                        child: Text(
                          q.options[idx],
                          textAlign: TextAlign.center,
                          style: AppTypography.mono(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: correctPick
                                ? c.successText
                                : wrongPick
                                ? c.warningText
                                : c.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (hasSelection) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isCorrect ? c.successSoft : c.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isCorrect ? c.success : c.warning)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: isCorrect ? c.successText : c.warningText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCorrect
                            ? (s.isRu
                                  ? s.tourSlide2CorrectFeedback
                                  : q.explanation)
                            : s.tourSlide2WrongFeedback,
                        style: AppTypography.ui(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isCorrect ? c.successText : c.warningText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _GrowthMapStage extends StatelessWidget {
  final AppSemanticColors c;
  final AppStrings s;

  const _GrowthMapStage({
    required this.c,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 156,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _TourAssetFrame(
                      assetPath: 'assets/tour/tour_3_growth.png',
                      stage: 2,
                      c: c,
                      fallbackChild: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _KnowledgePathPainter(stage: 2, c: c),
                            ),
                          ),
                          const Positioned(
                            right: 12,
                            bottom: 10,
                            child: YolchiAIMascot(
                              size: 56,
                              mood: YolchiMood.celebrating,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(c.successSoft, c.paper),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: c.success.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: c.successText,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                s.tourSlide3XpChip,
                                style: AppTypography.mono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: c.successText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.subtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StageNodePill(
                      label: s.tourSlide3MasteredBadge,
                      fg: c.successText,
                      bg: c.successSoft,
                      icon: Icons.check_circle_rounded,
                    ),
                    _StageNodePill(
                      label: s.tourSlide3NextBadge,
                      fg: c.isDark ? c.brandStrong : c.brand,
                      bg: c.brandSoft,
                      icon: Icons.play_arrow_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.tourSlide3NextLessonTitle,
                  style: AppTypography.ui(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageNodePill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final IconData icon;

  const _StageNodePill({
    required this.label,
    required this.fg,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: AppTypography.ui(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared evolving "Mening bilim yo‘lim" knowledge-constellation painter
/// across all 3 Product Tour pages.
class _KnowledgePathPainter extends CustomPainter {
  final int stage;
  final AppSemanticColors c;

  _KnowledgePathPainter({required this.stage, required this.c});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          c.subtle,
          Color.alphaBlend(c.brandSoft, c.paper),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final w = size.width;
    final h = size.height;

    final points = <Offset>[
      Offset(w * 0.14, h * 0.72),
      Offset(w * 0.36, h * 0.42),
      Offset(w * 0.58, h * 0.62),
      Offset(w * 0.80, h * 0.28),
    ];

    // Background scattered constellation dots (strongest in stage 0)
    final scatterPaint = Paint()
      ..color = c.slatefine.withValues(alpha: stage == 0 ? 0.35 : 0.16);
    for (var i = 0; i < 9; i++) {
      final px = w * (0.12 + ((i * 37) % 80) / 100.0);
      final py = h * (0.18 + ((i * 53) % 68) / 100.0);
      canvas.drawCircle(Offset(px, py), 2.5 + (i % 2), scatterPaint);
    }

    // Path curve connecting knowledge nodes
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final baseTrackPaint = Paint()
      ..color = c.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, baseTrackPaint);

    // Highlighted progress segment depending on stage
    final activePath = Path()..moveTo(points[0].dx, points[0].dy);
    final limit = math.min(stage + 1, points.length - 1);
    for (var i = 0; i < limit; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      activePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }
    final activeLinePaint = Paint()
      ..shader = LinearGradient(
        colors: [c.success, c.brand, c.path],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activeLinePaint);

    // Draw nodes
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final isMastered = (stage == 0 && i == 0) ||
          (stage == 1 && i <= 1) ||
          (stage == 2 && i <= 2);
      final isFocus = (stage == 0 && i == 1) ||
          (stage == 1 && i == 2) ||
          (stage == 2 && i == 3);

      if (isFocus) {
        canvas.drawCircle(
          p,
          16,
          Paint()..color = c.brand.withValues(alpha: 0.18),
        );
      }

      final fill = isMastered
          ? c.success
          : isFocus
          ? c.brand
          : c.paper;
      final border = isMastered
          ? c.success
          : isFocus
          ? c.brand
          : c.hairline;

      canvas.drawCircle(p, isFocus ? 9 : 7, Paint()..color = fill);
      canvas.drawCircle(
        p,
        isFocus ? 9 : 7,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (isMastered || isFocus) {
        canvas.drawCircle(
          p,
          3,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KnowledgePathPainter oldDelegate) =>
      oldDelegate.stage != stage || oldDelegate.c != c;
}

class _TourAssetFrame extends StatelessWidget {
  final String assetPath;
  final int stage;
  final AppSemanticColors c;
  final Widget? fallbackChild;

  const _TourAssetFrame({
    required this.assetPath,
    required this.stage,
    required this.c,
    this.fallbackChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: c.isDark ? c.brand.withValues(alpha: 0.32) : c.hairline,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) =>
              fallbackChild ??
              CustomPaint(
                painter: _KnowledgePathPainter(stage: stage, c: c),
              ),
        ),
      ),
    );
  }
}
