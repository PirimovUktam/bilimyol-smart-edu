import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/demo_session.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/edtech_section_header.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../app/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    if (demoSessionActive.value) {
      demoSessionActive.value = false;
      context.go('/login');
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _isLoggingOut = true);
    try {
      final auth = SupabaseConfig.client?.auth;
      if (auth == null) throw StateError('Hisob xizmatiga ulanish yo‘q.');
      await auth.signOut(scope: SignOutScope.local);
      container.invalidate(learnerStateNotifierProvider);
      container.invalidate(courseStateNotifierProvider);
      container.invalidate(roadmapStateNotifierProvider);
      container.invalidate(placementStateNotifierProvider);
      container.invalidate(lessonSessionNotifierProvider);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hisobdan chiqib bo‘lmadi. Qayta urinib ko‘ring.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final courseState = ref.watch(courseStateNotifierProvider);
    final activeCourse = courseState.activeCourse;
    final demo = demoSessionActive.value;
    final email = SupabaseConfig.client?.auth.currentUser?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profilim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 4),
      body: SafeArea(
        child: learnerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: 'Profilni yuklab bo‘lmadi.',
            onRetry: () =>
                ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
          ),
          data: (profile) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar & Name Card
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              profile.name.isNotEmpty
                                  ? profile.name[0].toUpperCase()
                                  : 'A',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
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
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AppBadge(
                                    text: demo ? 'Namuna' : 'O‘quvchi',
                                    variant: AppBadgeVariant.emerald,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                demo
                                    ? 'Namuna hisobi'
                                    : (email ??
                                          'Elektron pochta ko‘rsatilmagan'),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: Color(0xFFFBBF24),
                                size: 18,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${profile.xp} XP',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Tajriba',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFEA580C),
                                size: 18,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${profile.streakDays} kun',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Ketma-ket',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.school_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeCourse?.title ?? 'Fan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Joriy fan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Settings Card
                  const EdTechReveal(
                    index: 2,
                    child: EdTechSectionHeader(
                      pillText: 'Moslashtirish',
                      title: 'O‘quv sozlamalari',
                      highlightWord: 'sozlamalari',
                    ),
                  ),
                  const SizedBox(height: 10),

                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.menu_book_outlined),
                            title: const Text('Fanni o‘zgartirish'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/courses'),
                          ),
                          if (activeCourse != null)
                            ListTile(
                              leading: const Icon(Icons.tune_rounded),
                              title: const Text('Boshlash darajasini sozlash'),
                              subtitle: Text(activeCourse.title),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.push('/onboarding'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  if (demo)
                    AppButton(
                      text: 'Namuna natijalarini tiklash',
                      isFullWidth: true,
                      variant: AppButtonVariant.outline,
                      leftIcon: const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                      onPressed: () async {
                        await ref
                            .read(learnerStateNotifierProvider.notifier)
                            .resetAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo muvaffaqiyatli tiklandi.'),
                            ),
                          );
                          context.go('/courses');
                        }
                      },
                    ),
                  const SizedBox(height: 10),

                  AppButton(
                    text: 'Hisobdan chiqish',
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
    );
  }
}
