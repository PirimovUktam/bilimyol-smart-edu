import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../app/providers.dart';
import '../../core/auth/auth_error_message.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _scrollController = ScrollController();
  final _errorKey = GlobalKey();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
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

  void _handleRegister() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (firstName.isEmpty || email.isEmpty || password.isEmpty) {
      _setError('Iltimos, barcha majburiy maydonlarni to‘ldiring.');
      return;
    }

    if (password.length < 6) {
      _setError('Parol kamida 6 ta belgidan iborat bo‘lishi kerak.');
      return;
    }

    if (password != confirm) {
      _setError('Kiritilgan parollar bir-biriga mos kelmadi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final client = Supabase.instance.client;
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      // The auth trigger provisions the profile. With email confirmation there
      // is no session yet: do not attempt an anonymous profile write/read.
      if (res.session == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hisob yaratildi. Emaildagi tasdiqlash havolasini oching va tizimga kiring.'),
        ));
        context.go('/login');
        return;
      }

      final learnerNotifier = ref.read(learnerStateNotifierProvider.notifier);
      await learnerNotifier.loadProfile();

      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/courses');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _setError(authErrorMessage(e));
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

    InputDecoration buildInputDecoration({
      required String hintText,
      required IconData icon,
    }) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(color: textMuted),
        prefixIcon: Icon(icon, size: 18, color: textSecondary),
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
          borderSide: BorderSide(color: focusColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorFg, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorFg, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      );
    }

    final inputTextStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    );

    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        toolbarHeight: isLargeText ? 96 : null,
        title: Text(
          'Ro‘yxatdan o‘tish',
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
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const BilimYolLogo(size: 38),
                  const SizedBox(height: 16),
                  Text(
                    'Yangi hisob yaratish',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMsg != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              key: _errorKey,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: errorBg,
                                borderRadius: BorderRadius.circular(10),
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
                          const SizedBox(height: 16),
                        ],

                        Text(
                          'Ism *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _firstNameController,
                          textInputAction: TextInputAction.next,
                          style: inputTextStyle,
                          decoration: buildInputDecoration(
                            hintText: 'Ismingiz',
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'Email *',
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
                          textInputAction: TextInputAction.next,
                          style: inputTextStyle,
                          decoration: buildInputDecoration(
                            hintText: 'nomingiz@misol.uz',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'Parol *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          style: inputTextStyle,
                          decoration: buildInputDecoration(
                            hintText: 'Kamida 6 ta belgi',
                            icon: Icons.lock_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'Parolni tasdiqlang *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_isLoading) _handleRegister();
                          },
                          style: inputTextStyle,
                          decoration: buildInputDecoration(
                            hintText: 'Parolni qayta kiriting',
                            icon: Icons.lock_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 20),

                        AppButton(
                          text: 'Hisob Yaratish',
                          isFullWidth: true,
                          size: AppButtonSize.large,
                          isLoading: _isLoading,
                          rightIcon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _handleRegister,
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
