import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import 'auth_error_banner.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _visible = false;
  bool _busy = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _resetProvidersIfMounted() async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await resetSessionState(container);
    } catch (_) {
      // Standalone widget tests without ProviderScope do not hold session providers.
    }
  }

  Future<void> _save() async {
    final s = AppStrings.of(context);
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    SupabaseConfig.setCompletingRecoverySignOut(true);
    try {
      final client = SupabaseConfig.client;
      if (client == null) {
        throw StateError(s.authServiceOfflineShort);
      }
      await client.auth.updateUser(UserAttributes(password: _password.text));
      final updatedSession = client.auth.currentSession;
      await client.auth.signOut(scope: SignOutScope.local);
      SupabaseConfig.syncCurrentAuthState();
      await SupabaseConfig.clearPasswordRecovery(session: updatedSession);
      await _resetProvidersIfMounted();
      if (mounted) {
        _password.clear();
        setState(() => _saved = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = s.resetSaveFailedError);
      }
    } finally {
      SupabaseConfig.setCompletingRecoverySignOut(false);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final s = AppStrings.of(context);
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = SupabaseConfig.client?.auth;
      final session = auth?.currentSession;
      await auth?.signOut(scope: SignOutScope.local);
      SupabaseConfig.syncCurrentAuthState();
      await SupabaseConfig.clearPasswordRecovery(session: session);
      await _resetProvidersIfMounted();
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        setState(() => _error = s.signOutFailedError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(s.resetPasswordTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BilimYolLogo(size: 36)),
                  const SizedBox(height: 18),
                  AppCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _saved
                                ? s.passwordUpdatedHeading
                                : s.newPasswordHeading,
                            style: AppTypography.ui(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_saved) ...[
                            TextFormField(
                              controller: _password,
                              obscureText: !_visible,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: s.newPasswordLabel,
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                  color: c.brand,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _visible
                                      ? s.passwordHideTooltip
                                      : s.passwordShowTooltip,
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  onPressed: () =>
                                      setState(() => _visible = !_visible),
                                  icon: Icon(
                                    _visible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: c.slatefine,
                                  ),
                                ),
                              ),
                              validator: (value) => (value?.length ?? 0) < 8
                                  ? s.shortPassword8Error
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              obscureText: !_visible,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) => _save(),
                              decoration: InputDecoration(
                                labelText: s.repeatPasswordLabel,
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                  color: c.brand,
                                ),
                              ),
                              validator: (value) => value != _password.text
                                  ? s.passwordMismatchError
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AppButton(
                              text: s.savePasswordAction,
                              isFullWidth: true,
                              size: AppButtonSize.large,
                              isLoading: _busy,
                              onPressed: _save,
                            ),
                          ],
                          if (_error case final error?) ...[
                            const SizedBox(height: 12),
                            AuthErrorBanner(message: error),
                          ],
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _busy ? null : _leave,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor: c.brand,
                            ),
                            child: Text(
                              _saved ? s.backToLoginAction : s.cancel,
                            ),
                          ),
                        ],
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
