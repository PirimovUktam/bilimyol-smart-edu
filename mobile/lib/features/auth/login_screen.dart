import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_error_message.dart';
import '../../core/auth/demo_session.dart';
import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../domain/personalization/learning_start.dart';
import 'auth_error_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMsg;

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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final s = _resolveStrings(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = s.emptyLoginFieldsError);
      return;
    }

    final client = SupabaseConfig.client;
    if (client == null) {
      setState(() => _errorMsg = s.authServiceOfflineShort);
      return;
    }

    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    postLoginHydrating.value = true;
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      demoSessionActive.value = false;
      SupabaseConfig.syncCurrentAuthState();
      container.invalidate(authSessionUserIdProvider);
      container.invalidate(learnerStateNotifierProvider);
      container.invalidate(courseStateNotifierProvider);
      container.invalidate(roadmapStateNotifierProvider);
      container.invalidate(placementStateNotifierProvider);
      container.invalidate(lessonSessionNotifierProvider);
      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      await container.read(courseStateNotifierProvider.notifier).init();

      postLoginHydrating.value = false;
      if (mounted) {
        setState(() => _isLoading = false);
        context.go(
          activeSessionHasStartedCourse.value ? '/dashboard' : '/courses',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = authErrorMessage(error, strings: s);
        });
      }
    } finally {
      postLoginHydrating.value = false;
    }
  }

  Future<void> _handleQuickDemo() async {
    if (SupabaseConfig.isProductionEnv || SupabaseConfig.hasRemoteConfiguration) {
      return;
    }
    final storage = ref.read(localStorageServiceProvider);
    final profile = ref.read(learnerStateNotifierProvider).valueOrNull;
    final courses = ref.read(courseStateNotifierProvider).courses;
    var hasStarted =
        (profile != null &&
            (courses.isNotEmpty
                ? courses.any((c) => hasStartedCourse(c, profile))
                : (profile.courseLevels.isNotEmpty ||
                      profile.scoresByCourse.values.any((m) => m.isNotEmpty) ||
                      profile.completedLessonIds.isNotEmpty))) ||
        hasStartedCourseInDemoSnapshot(
          storage.getStringSync(LocalStorageService.demoLearnerSnapshotKey),
        );
    if (!hasStarted) {
      final asyncSnapshot = await storage.getDemoLearnerSnapshot();
      if (!mounted) return;
      hasStarted = hasStartedCourseInDemoSnapshot(asyncSnapshot);
    }
    activeSessionHasStartedCourse.value = hasStarted;
    demoSessionActive.value = true;
    context.go(hasStarted ? '/dashboard' : '/courses');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  Center(
                    child: Column(
                      children: [
                        const BilimYolLogo(size: 38),
                        const SizedBox(height: 6),
                        Text(
                          s.authTagline,
                          textAlign: TextAlign.center,
                          style: AppTypography.ui(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.slatefine,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Single focal Hero Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: c.heroGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: c.cardShadow,
                    ),
                    child: Row(
                      children: [
                        const YolchiAIMascot(
                          size: 54,
                          mood: YolchiMood.waving,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.authHeroHeadline1,
                                style: AppTypography.ui(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                              ),
                              Text(
                                s.authHeroHeadline2,
                                style: AppTypography.ui(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF67E8F9),
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.authHeroSubtitle,
                                style: AppTypography.ui(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Unified Login Form Card
                  AppCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          s.loginTitle,
                          style: AppTypography.ui(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.loginSubtitle,
                          style: AppTypography.ui(
                            fontSize: 13,
                            color: c.slatefine,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),

                        if (_errorMsg != null) ...[
                          AuthErrorBanner(message: _errorMsg!),
                          const SizedBox(height: 14),
                        ],

                        Text(
                          s.emailLabel,
                          style: AppTypography.ui(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.graphite,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (_) {
                            if (_errorMsg != null) {
                              setState(() => _errorMsg = null);
                            }
                          },
                          style: AppTypography.ui(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: s.emailHint,
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              size: 18,
                              color: c.brand,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              s.passwordLabel,
                              style: AppTypography.ui(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.graphite,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: c.brand,
                              ),
                              child: Text(
                                s.forgotPassword,
                                style: AppTypography.ui(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onChanged: (_) {
                            if (_errorMsg != null) {
                              setState(() => _errorMsg = null);
                            }
                          },
                          onSubmitted: (_) {
                            if (!_isLoading) _handleLogin();
                          },
                          style: AppTypography.ui(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: s.passwordPlaceholder,
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: c.brand,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _passwordVisible
                                  ? s.passwordHideTooltip
                                  : s.passwordShowTooltip,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: c.slatefine,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        AppButton(
                          text: s.loginAction,
                          isFullWidth: true,
                          size: AppButtonSize.large,
                          isLoading: _isLoading,
                          rightIcon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                        ),
                        const SizedBox(height: 14),

                        if (!SupabaseConfig.isProductionEnv &&
                            !SupabaseConfig.hasRemoteConfiguration) ...[
                          Row(
                            children: [
                              Expanded(child: Divider(color: c.hairline)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  s.orDivider,
                                  style: AppTypography.ui(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.faint,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: c.hairline)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AppButton(
                            text: s.demoEnterAction,
                            variant: AppButtonVariant.outline,
                            isFullWidth: true,
                            size: AppButtonSize.large,
                            leftIcon: Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: c.warning,
                            ),
                            onPressed: _handleQuickDemo,
                          ),
                          const SizedBox(height: 14),
                        ],

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            Text(
                              s.noAccountQuestion,
                              style: AppTypography.ui(
                                fontSize: 13,
                                color: c.slatefine,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/register'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                foregroundColor: c.brand,
                              ),
                              child: Text(
                                s.registerAction,
                                style: AppTypography.ui(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: c.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/welcome?replay=1'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        foregroundColor: c.slatefine,
                      ),
                      icon: Icon(
                        Icons.explore_outlined,
                        size: 17,
                        color: c.path,
                      ),
                      label: Text(
                        s.tourReplayAction,
                        style: AppTypography.ui(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.path,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
