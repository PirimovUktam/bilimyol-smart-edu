import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/demo_session.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilim_yol_logo.dart';
import '../../core/widgets/edtech_reveal.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(22),
              children: [
                const BilimYolLogo(size: 42),
                const SizedBox(height: 22),
                EdTechReveal(
                  index: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.explore_rounded,
                              size: 14,
                              color: AppColors.primaryAccentOnSurface(context),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isRu
                                    ? 'Персональный путь обучения'
                                    : 'Shaxsiy ta’lim yo‘li',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryAccentOnSurface(
                                    context,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isRu
                            ? 'Учитесь по удобному для вас пути.'
                            : 'O‘zingizga mos yo‘ldan o‘rganing.',
                        style: theme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isRu
                            ? 'Выберите предмет и начните с урока вашего уровня. Если возникнут трудности, Yo‘lchi поможет.'
                            : 'Fan tanlang, darajangizga mos darsdan boshlang. Tushunmagan joyingizda Yo‘lchi yordam beradi.',
                        style: theme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                EdTechReveal(
                  index: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => context.push('/register'),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          isRu ? 'Регистрация' : 'Ro‘yxatdan o‘tish',
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        child: Text(isRu ? 'Войти' : 'Kirish'),
                      ),
                      if (!SupabaseConfig.hasRemoteConfiguration)
                        TextButton(
                          onPressed: () {
                            demoSessionActive.value = true;
                            context.go('/courses');
                          },
                          child: Text(
                            isRu
                                ? 'Войти в деморежим'
                                : 'Namuna hisobi bilan kirish',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                EdTechReveal(
                  index: 2,
                  child: AppCard(
                    backgroundColor: AppColors.primaryTint(context),
                    borderColor: AppColors.primary.withValues(alpha: 0.2),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRu
                              ? 'Начните за три шага'
                              : 'Uch qadamda boshlang',
                          style: theme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.explore_outlined,
                            color: AppColors.primaryAccentOnSurface(context),
                          ),
                          title: Text(
                            isRu ? 'Выберите предмет' : 'Fanni tanlang',
                            style: TextStyle(
                              color: AppColors.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.primaryAccentOnSurface(context),
                          ),
                          title: Text(
                            isRu
                                ? 'Пройдите подходящий урок'
                                : 'Mos darsni o‘qing',
                            style: TextStyle(
                              color: AppColors.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.primaryAccentOnSurface(context),
                          ),
                          title: Text(
                            isRu
                                ? 'Откройте следующий шаг'
                                : 'Keyingi qadamni toping',
                            style: TextStyle(
                              color: AppColors.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
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
    );
  }
}
