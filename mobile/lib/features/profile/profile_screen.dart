import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../app/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _darkMode = false;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final courseState = ref.watch(courseStateNotifierProvider);
    final activeCourse = courseState.activeCourse;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profilim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: learnerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Xatolik: $e')),
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
                              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'A',
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
                                  Text(
                                    profile.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const AppBadge(text: 'Faol', variant: AppBadgeVariant.emerald),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'demo@bilimyol.uz',
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
                              const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 18),
                              const SizedBox(height: 4),
                              Text(
                                '${profile.xp} XP',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text('Tajriba', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textMuted)),
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
                              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 18),
                              const SizedBox(height: 4),
                              Text(
                                '${profile.streakDays} kun',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text('Streak', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textMuted)),
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
                              const Icon(Icons.school_rounded, color: AppColors.primary, size: 18),
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
                              Text('Joriy fan', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Settings Card
                  Text(
                    'Sozlamalar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.dark_mode_outlined, size: 20, color: AppColors.textSecondary),
                                const SizedBox(width: 10),
                                Text(
                                  'Qorong‘i rejim',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _darkMode,
                              onChanged: (val) => setState(() => _darkMode = val),
                              activeThumbColor: AppColors.primary,
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notifications_none_rounded, size: 20, color: AppColors.textSecondary),
                                const SizedBox(width: 10),
                                Text(
                                  'Eslatmalar',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _notifications,
                              onChanged: (val) => setState(() => _notifications = val),
                              activeThumbColor: AppColors.secondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  AppButton(
                    text: 'Demo Holatiga Qaytarish',
                    isFullWidth: true,
                    variant: AppButtonVariant.outline,
                    leftIcon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFF59E0B)),
                    onPressed: () async {
                      await ref.read(learnerStateNotifierProvider.notifier).resetAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Demo muvaffaqiyatli tiklandi.')),
                        );
                        context.go('/courses');
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  AppButton(
                    text: 'Hisobdan Chiqish',
                    isFullWidth: true,
                    variant: AppButtonVariant.danger,
                    leftIcon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
                    onPressed: () {
                      context.go('/login');
                    },
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
