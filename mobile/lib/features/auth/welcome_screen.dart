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
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.explore_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Shaxsiy ta’lim yo‘li',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'O‘zingizga mos yo‘ldan o‘rganing.',
                        style: theme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Fan tanlang, darajangizga mos darsdan boshlang. Tushunmagan joyingizda Yo‘lchi yordam beradi.',
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
                        label: const Text('Ro‘yxatdan o‘tish'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        child: const Text('Kirish'),
                      ),
                      if (!SupabaseConfig.hasRemoteConfiguration)
                        TextButton(
                          onPressed: () {
                            demoSessionActive.value = true;
                            context.go('/courses');
                          },
                          child: const Text('Namuna hisobi bilan kirish'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                EdTechReveal(
                  index: 2,
                  child: AppCard(
                    backgroundColor: AppColors.primaryLight.withValues(
                      alpha: 0.7,
                    ),
                    borderColor: AppColors.primary.withValues(alpha: 0.2),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uch qadamda boshlang',
                          style: theme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.explore_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text('Fanni tanlang'),
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text('Mos darsni o‘qing'),
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text('Keyingi qadamni toping'),
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
