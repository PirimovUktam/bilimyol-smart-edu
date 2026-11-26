import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../core/auth/demo_session.dart';
import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/friendly_error_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;
  bool _isResetting = false;

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

  Future<void> _showEditNameDialog(String currentName) async {
    final s = _resolveStrings(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await showDialog<void>(
      context: context,
      builder: (_) => _EditNameDialog(
        initialName: currentName,
        s: s,
        onSaveName: (trimmed) => ref
            .read(learnerStateNotifierProvider.notifier)
            .updateDisplayName(trimmed),
        onSaved: () {
          if (messenger != null && messenger.mounted) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(s.editNameSaved),
                  duration: const Duration(milliseconds: 800),
                ),
              );
          }
        },
      ),
    );
  }

  Future<void> _resetDemo() async {
    if (_isResetting) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final s = _resolveStrings(context);
    setState(() => _isResetting = true);
    try {
      await ref.read(learnerStateNotifierProvider.notifier).resetAll();
      if (mounted) {
        if (messenger != null && messenger.mounted) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(s.demoResetSuccess),
                duration: const Duration(milliseconds: 800),
              ),
            );
        }
        context.go('/courses');
      }
    } on Object catch (_) {
      if (mounted && ref.read(learnerStateNotifierProvider).hasError) {
        await ref.read(learnerStateNotifierProvider.notifier).loadProfile();
      }
      if (messenger != null && messenger.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.demoResetFailed)));
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _isLoggingOut = true);
    try {
      demoSessionActive.value = false;
      final auth = SupabaseConfig.client?.auth;
      if (auth != null) {
        try {
          await auth.signOut(scope: SignOutScope.local);
        } catch (_) {
          // Proceed with local session purge even when GoTrue throws offline.
        }
      }
      SupabaseConfig.syncCurrentAuthState();
      await SupabaseConfig.clearPasswordRecovery();
      await resetSessionState(container);
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final settings = ref.watch(appSettingsProvider);
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final courseState = ref.watch(courseStateNotifierProvider);
    final activeCourse = courseState.activeCourse;
    final demo = demoSessionActive.value;
    final email = SupabaseConfig.client?.auth.currentUser?.email;
    final canPop =
        GoRouter.maybeOf(context)?.canPop() ?? Navigator.canPop(context);
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 96 : null,
        title: Text(
          s.myProfile,
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        leading: canPop
            ? IconButton(
                tooltip: s.back,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: learnerAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => FriendlyErrorState(
                message: s.profileLoadFailed,
                onRetry: () => ref
                    .read(learnerStateNotifierProvider.notifier)
                    .loadProfile(),
              ),
              data: (profile) {
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final statCards = [
                  _ProfileStatCard(
                    c: c,
                    icon: Icons.bolt_rounded,
                    iconColor: c.warningText,
                    value: '${profile.xp} XP',
                    label: s.statXpLabel,
                  ),
                  _ProfileStatCard(
                    c: c,
                    icon: Icons.local_fire_department_rounded,
                    iconColor: c.errorText,
                    value: s.streakDays(profile.streakDays),
                    label: s.statStreakLabel,
                  ),
                  _ProfileStatCard(
                    c: c,
                    icon: Icons.school_rounded,
                    iconColor: c.isDark ? c.brandStrong : c.brand,
                    value: activeCourse != null
                        ? s.localizedCourseTitle(activeCourse)
                        : '—',
                    label: s.statSubjectLabel,
                    isMono: false,
                  ),
                ];

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Identity Card + Edit Name
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [c.ctaPrimary, c.ctaPrimaryHover],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  profile.name.isNotEmpty
                                      ? profile.name[0].toUpperCase()
                                      : 'O',
                                  style: AppTypography.ui(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        profile.name,
                                        style: AppTypography.ui(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: c.ink,
                                        ),
                                      ),
                                      AppBadge(
                                        text: demo
                                            ? s.profileBadgeDemo
                                            : s.profileBadgeStudent,
                                        variant: AppBadgeVariant.emerald,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    demo
                                        ? s.profileDemoAccount
                                        : (email ?? s.profileNoEmail),
                                    style: AppTypography.ui(
                                      fontSize: 12.5,
                                      color: c.slatefine,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: s.editNameAction,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: c.isDark ? c.brandStrong : c.brand,
                              ),
                              onPressed: () =>
                                  _showEditNameDialog(profile.name),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Responsive Stats
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final rowLayout =
                              constraints.maxWidth >= 320 && textScale < 1.35;
                          if (rowLayout) {
                            return Row(
                              children: [
                                Expanded(child: statCards[0]),
                                const SizedBox(width: 8),
                                Expanded(child: statCards[1]),
                                const SizedBox(width: 8),
                                Expanded(child: statCards[2]),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (final (idx, card) in statCards.indexed) ...[
                                SizedBox(width: double.infinity, child: card),
                                if (idx < statCards.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),

                      Text(
                        s.learningSettings,
                        style: AppTypography.ui(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Preferences: Language & Theme
                      SizedBox(
                        width: double.infinity,
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.languageLabel,
                                style: AppTypography.ui(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.graphite,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ChoiceChip(
                                    c: c,
                                    label: s.languageUz,
                                    selected: settings.localeCode == 'uz',
                                    onTap: () => ref
                                        .read(appSettingsProvider.notifier)
                                        .setLocale('uz'),
                                  ),
                                  _ChoiceChip(
                                    c: c,
                                    label: s.languageRu,
                                    selected: settings.localeCode == 'ru',
                                    onTap: () => ref
                                        .read(appSettingsProvider.notifier)
                                        .setLocale('ru'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                s.themeLabel,
                                style: AppTypography.ui(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.graphite,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ChoiceChip(
                                    c: c,
                                    label: s.themeSystem,
                                    selected:
                                        settings.themeMode == ThemeMode.system,
                                    onTap: () => ref
                                        .read(appSettingsProvider.notifier)
                                        .setThemeMode(ThemeMode.system),
                                  ),
                                  _ChoiceChip(
                                    c: c,
                                    label: s.themeLight,
                                    selected:
                                        settings.themeMode == ThemeMode.light,
                                    onTap: () => ref
                                        .read(appSettingsProvider.notifier)
                                        .setThemeMode(ThemeMode.light),
                                  ),
                                  _ChoiceChip(
                                    c: c,
                                    label: s.themeDark,
                                    selected:
                                        settings.themeMode == ThemeMode.dark,
                                    onTap: () => ref
                                        .read(appSettingsProvider.notifier)
                                        .setThemeMode(ThemeMode.dark),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Course, Level & Tour Replay Actions
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Material(
                          type: MaterialType.transparency,
                          child: Column(
                            children: [
                              ListTile(
                                minTileHeight: 52,
                                leading: const Icon(Icons.menu_book_outlined),
                                title: Text(s.switchSubjectAction),
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                                onTap: () {
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  context.push('/courses');
                                },
                              ),
                              if (activeCourse != null) ...[
                                Divider(height: 1, color: c.hairline),
                                ListTile(
                                  minTileHeight: 52,
                                  leading: const Icon(Icons.tune_rounded),
                                  title: Text(s.adjustStartLevelAction),
                                  subtitle: Text(
                                    s.localizedCourseTitle(activeCourse),
                                    style: AppTypography.ui(
                                      fontSize: 12.5,
                                      color: c.slatefine,
                                    ),
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () {
                                    ScaffoldMessenger.of(context)
                                        .clearSnackBars();
                                    context.push('/onboarding');
                                  },
                                ),
                              ],
                              Divider(height: 1, color: c.hairline),
                              ListTile(
                                minTileHeight: 52,
                                leading: const Icon(
                                  Icons.play_circle_outline_rounded,
                                ),
                                title: Text(s.tourReplayAction),
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                                onTap: () {
                                  ScaffoldMessenger.maybeOf(context)
                                      ?.hideCurrentSnackBar();
                                  context.go('/welcome?replay=1');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      if (demo) ...[
                        AppButton(
                          text: s.demoResetAction,
                          isFullWidth: true,
                          variant: AppButtonVariant.outline,
                          leftIcon: Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: c.warningText,
                          ),
                          isLoading: _isResetting,
                          onPressed: _resetDemo,
                        ),
                        const SizedBox(height: 10),
                      ],
                      AppButton(
                        text: s.logout,
                        isFullWidth: true,
                        variant: AppButtonVariant.danger,
                        leftIcon: const Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        isLoading: _isLoggingOut,
                        onPressed: _handleLogout,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final AppSemanticColors c;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isMono;

  const _ProfileStatCard({
    required this.c,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.isMono = true,
  });

  @override
  Widget build(BuildContext context) {
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            softWrap: true,
            maxLines: isLargeText ? null : 2,
            overflow: isLargeText ? TextOverflow.visible : TextOverflow.ellipsis,
            style: (isMono ? AppTypography.mono : AppTypography.ui)(
              fontSize: isMono ? 14.5 : 13,
              fontWeight: FontWeight.w800,
              color: c.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            softWrap: true,
            maxLines: isLargeText ? null : 1,
            overflow: isLargeText ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTypography.ui(
              fontSize: 11,
              color: c.slatefine,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final AppSemanticColors c;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.c,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? c.ctaPrimary : c.subtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? c.ctaPrimary : c.hairline,
              ),
            ),
            child: Text(
              label,
              style: AppTypography.ui(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : c.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String initialName;
  final AppStrings s;
  final Future<void> Function(String trimmed) onSaveName;
  final VoidCallback onSaved;

  const _EditNameDialog({
    required this.initialName,
    required this.s,
    required this.onSaveName,
    required this.onSaved,
  });

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  String? _errorText;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = widget.s.editNameEmptyError);
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await widget.onSaveName(trimmed);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = widget.s.editNameFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.s.editNameDialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.s.editNameFieldLabel,
          errorText: _errorText,
        ),
        onSubmitted: (_) => _saving ? null : _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(widget.s.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(widget.s.save),
        ),
      ],
    );
  }
}
