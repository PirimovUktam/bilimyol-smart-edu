import 'package:flutter/material.dart';
import '../../core/auth/auth_error_message.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errorMsg = 'Email manzilini to‘g‘ri kiriting.');
      return;
    }
    final client = SupabaseConfig.client;
    if (client == null) {
      setState(
        () => _errorMsg = SupabaseConfig.hasRemoteConfiguration
            ? 'Hisob xizmatiga ulanib bo‘lmadi. Qayta urinib ko‘ring.'
            : 'Namuna rejimida tiklash xati yuborilmaydi.',
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
          _errorMsg = authErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);
    final textMuted = AppColors.textMutedColor(context);
    final inputFill = AppColors.subtleSurface(context);
    // Input boundary must reach 3:1 against the fill and card (WCAG 1.4.11).
    final borderColor = AppColors.textMutedColor(context);
    final focusColor = AppColors.primaryAccentOnSurface(context);
    final errorFg = AppColors.errorTextOnTint(context);
    final errorBg = AppColors.errorTint(context);

    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        toolbarHeight: isLargeText ? 96 : null,
        title: Text(
          'Parolni tiklash',
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const BilimYolLogo(size: 38),
                  const SizedBox(height: 16),
                  Text(
                    'Parolni qayta tiklash',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: _isSent
                        ? Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.successTint(context),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.successTextOnTint(context),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Havola yuborildi!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_emailController.text} manziliga tiklash havolasi yuborildi.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                text: 'Kirish sahifasiga qaytish',
                                isFullWidth: true,
                                onPressed: () => context.pop(),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!_isLoading) _handleReset();
                                },
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'nomingiz@misol.uz',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: textMuted,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.mail_outline_rounded,
                                    size: 18,
                                    color: textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: focusColor,
                                      width: 1.8,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: errorFg,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: errorFg,
                                      width: 1.8,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_errorMsg != null) ...[
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: errorBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: errorFg.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: errorFg,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMsg!,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: errorFg,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              AppButton(
                                text: 'Tiklash havolasini yuborish',
                                isFullWidth: true,
                                size: AppButtonSize.large,
                                isLoading: _isLoading,
                                onPressed: _handleReset,
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
