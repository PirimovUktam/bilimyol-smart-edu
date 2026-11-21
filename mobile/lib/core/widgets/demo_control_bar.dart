import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/supabase_config.dart';
import '../l10n/app_strings.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_typography.dart';
import '../../app/providers.dart';

/// Compact demo control strip for judges: resets the whole demo state so the
/// full journey can be replayed from the course-selection screen at any time.
class DemoControlBar extends ConsumerStatefulWidget {
  const DemoControlBar({super.key});

  @override
  ConsumerState<DemoControlBar> createState() => _DemoControlBarState();
}

class _DemoControlBarState extends ConsumerState<DemoControlBar> {
  bool _resetting = false;

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

  Future<void> _resetDemo() async {
    if (_resetting || SupabaseConfig.hasRemoteConfiguration) return;
    final router = GoRouter.maybeOf(context);
    final startMatches = router?.routerDelegate.currentConfiguration.matches;
    final startLocation = (startMatches != null && startMatches.isNotEmpty)
        ? startMatches.last.matchedLocation
        : null;
    final startMatchCount = startMatches?.length;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final resetFailedMessage = _resolveStrings(context).demoResetFailed;
    setState(() => _resetting = true);
    try {
      await ref.read(learnerStateNotifierProvider.notifier).resetAll();
      final currentMatches = router?.routerDelegate.currentConfiguration.matches;
      final currentLocation =
          (currentMatches != null && currentMatches.isNotEmpty)
          ? currentMatches.last.matchedLocation
          : null;
      final currentMatchCount = currentMatches?.length;
      final isSameRoute =
          startLocation != null &&
          currentLocation == startLocation &&
          currentMatchCount == startMatchCount;
      if (router != null &&
          (router.routerDelegate.navigatorKey.currentContext?.mounted ??
              false) &&
          isSameRoute) {
        router.go('/courses');
      }
    } on Object catch (_) {
      if (mounted && ref.read(learnerStateNotifierProvider).hasError) {
        await ref.read(learnerStateNotifierProvider.notifier).loadProfile();
      }
      if (messenger != null && messenger.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(resetFailedMessage)));
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (SupabaseConfig.hasRemoteConfiguration) return const SizedBox.shrink();
    final s = _resolveStrings(context);
    final c = AppSemanticColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final stackVertically =
              textScale >= 1.15 || constraints.maxWidth < 420;

          final resetButton = TextButton(
            onPressed: _resetting ? null : _resetDemo,
            style: TextButton.styleFrom(
              foregroundColor: c.ink,
              backgroundColor: c.paper,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(44, 36),
              side: BorderSide(color: c.hairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_resetting)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.brand,
                    ),
                  )
                else
                  Icon(Icons.restart_alt_rounded, size: 15, color: c.brand),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    s.demoReset,
                    style: AppTypography.ui(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
          );

          final bannerRow = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.science_rounded,
                color: c.path,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  s.demoBanner,
                  style: AppTypography.ui(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: c.graphite,
                  ),
                ),
              ),
              if (!stackVertically) ...[
                const SizedBox(width: 8),
                Flexible(flex: 0, child: resetButton),
              ],
            ],
          );

          if (!stackVertically) return bannerRow;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              bannerRow,
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: resetButton,
              ),
            ],
          );
        },
      ),
    );
  }
}
