import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_error_message.dart';
import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import 'auth_error_banner.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _scrollController = ScrollController();
  final _errorKey = GlobalKey();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
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
    _scrollController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setError(String message) {
    setState(() => _errorMsg = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final errCtx = _errorKey.currentContext;
      if (errCtx != null) {
        Scrollable.ensureVisible(
          errCtx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
      } else if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleRegister() async {
    final s = _resolveStrings(context);
    final firstName = _firstNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (firstName.isEmpty || email.isEmpty || password.isEmpty) {
      _setError(s.emptyRegisterFieldsError);
      return;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _setError(s.invalidEmailError);
      return;
    }

    if (password.length < 6) {
      _setError(s.shortPassword6Error);
      return;
    }

    if (password != confirm) {
      _setError(s.passwordMismatchError);
      return;
    }

    final client = SupabaseConfig.client;
    if (client == null) {
      _setError(
        SupabaseConfig.hasRemoteConfiguration
            ? s.authServiceUnavailable
            : s.demoNoRegisterError,
      );
      return;
    }

    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final existingSession = client.auth.currentSession;
      final hasMatchingActiveSession =
          !SupabaseConfig.isRecoveryActive &&
          existingSession != null &&
          existingSession.user.email?.trim().toLowerCase() ==
              email.toLowerCase();

      if (!hasMatchingActiveSession) {
        if (!SupabaseConfig.isRecoveryActive && existingSession != null) {
          // Purge stale half-signed-up session for a different email before
          // attempting registration so a failed or confirmation-gated signup
          // never leaves the prior account authenticated.
          try {
            await client.auth.signOut(scope: SignOutScope.local);
          } catch (_) {}
          SupabaseConfig.syncCurrentAuthState();
        }
        final res = await client.auth.signUp(
          email: email,
          password: password,
          data: {'first_name': firstName},
        );

        if (res.session == null) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.registerEmailConfirmNotice)),
          );
          context.go('/login');
          return;
        }
      }

      SupabaseConfig.syncCurrentAuthState();
      container.invalidate(courseStateNotifierProvider);
      container.invalidate(roadmapStateNotifierProvider);
      container.invalidate(placementStateNotifierProvider);
      container.invalidate(lessonSessionNotifierProvider);
      await container.read(learnerStateNotifierProvider.notifier).loadProfile();
      final learnerState = container.read(learnerStateNotifierProvider);
      if (learnerState.hasError) {
        throw learnerState.error!;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/courses');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _setError(authErrorMessage(e, strings: s));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 96 : null,
        title: Text(
          s.registerAction,
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: s.back,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BilimYolLogo(size: 38)),
                  const SizedBox(height: 16),
                  Text(
                    s.registerHeading,
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 18),

                  AppCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMsg != null) ...[
                          KeyedSubtree(
                            key: _errorKey,
                            child: AuthErrorBanner(message: _errorMsg!),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Text(
                          s.firstNameLabel,
                          style: AppTypography.ui(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.graphite,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _firstNameController,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.givenName],
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
                            hintText: s.firstNameHint,
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: c.brand,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          s.registerEmailLabel,
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

                        Text(
                          s.registerPasswordLabel,
                          style: AppTypography.ui(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.graphite,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
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
                            hintText: s.passwordMin6Hint,
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
                        const SizedBox(height: 14),

                        Text(
                          s.confirmPasswordLabel,
                          style: AppTypography.ui(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.graphite,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: !_confirmVisible,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: (_) {
                            if (_errorMsg != null) {
                              setState(() => _errorMsg = null);
                            }
                          },
                          onSubmitted: (_) {
                            if (!_isLoading) _handleRegister();
                          },
                          style: AppTypography.ui(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: s.confirmPasswordHint,
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: c.brand,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _confirmVisible
                                  ? s.passwordHideTooltip
                                  : s.passwordShowTooltip,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              onPressed: () => setState(
                                () => _confirmVisible = !_confirmVisible,
                              ),
                              icon: Icon(
                                _confirmVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: c.slatefine,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        AppButton(
                          text: s.createAccountAction,
                          isFullWidth: true,
                          size: AppButtonSize.large,
                          isLoading: _isLoading,
                          rightIcon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _handleRegister,
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              s.haveAccountQuestion,
                              style: AppTypography.ui(
                                fontSize: 13,
                                color: c.slatefine,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/login');
                                }
                              },
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                foregroundColor: c.brand,
                              ),
                              child: Text(
                                s.loginAction,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
