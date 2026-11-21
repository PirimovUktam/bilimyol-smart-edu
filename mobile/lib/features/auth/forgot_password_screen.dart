import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_error_message.dart';
import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import 'auth_error_banner.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSent = false;
  bool _isLoading = false;
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
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Future<void> _handleReset() async {
    final s = _resolveStrings(context);
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errorMsg = s.invalidEmailError);
      return;
    }
    final client = SupabaseConfig.client;
    if (client == null) {
      setState(
        () => _errorMsg = SupabaseConfig.hasRemoteConfiguration
            ? s.authServiceUnavailable
            : s.demoNoResetError,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.passwordRecoveryUrl,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSent = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = authErrorMessage(error, strings: s);
        });
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
          s.resetPasswordTitle,
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: s.back,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
      ),
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
                  const Center(child: BilimYolLogo(size: 38)),
                  const SizedBox(height: 16),
                  Text(
                    s.forgotPasswordHeading,
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.forgotPasswordSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(
                      fontSize: 13,
                      color: c.slatefine,
                    ),
                  ),
                  const SizedBox(height: 18),

                  AppCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: _isSent
                        ? Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: c.successSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: c.successText,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                s.resetLinkSentTitle,
                                textAlign: TextAlign.center,
                                style: AppTypography.ui(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: c.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.resetLinkSentBody(_emailController.text.trim()),
                                style: AppTypography.ui(
                                  fontSize: 13,
                                  color: c.slatefine,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              AppButton(
                                text: s.backToLoginAction,
                                isFullWidth: true,
                                size: AppButtonSize.large,
                                onPressed: _goBack,
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                onChanged: (_) {
                                  if (_errorMsg != null) {
                                    setState(() => _errorMsg = null);
                                  }
                                },
                                onSubmitted: (_) {
                                  if (!_isLoading) _handleReset();
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
                              const SizedBox(height: 16),
                              if (_errorMsg != null) ...[
                                AuthErrorBanner(message: _errorMsg!),
                                const SizedBox(height: 14),
                              ],
                              AppButton(
                                text: s.sendResetLinkAction,
                                isFullWidth: true,
                                size: AppButtonSize.large,
                                isLoading: _isLoading,
                                onPressed: _isLoading ? null : _handleReset,
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
