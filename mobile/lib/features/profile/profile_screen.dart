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

  String _resolveLang(BuildContext context) {
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    if (demoSessionActive.value) {
      demoSessionActive.value = false;
      context.go('/login');
      return;
    }
    final isRu = _resolveLang(context) == 'ru';
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _isLoggingOut = true);
    try {
      final auth = SupabaseConfig.client?.auth;
      if (auth == null) {
        throw StateError(
          isRu
              ? 'Нет подключения к сервису аккаунта.'
              : 'Hisob xizmatiga ulanish yo‘q.',
        );
      }
      await auth.signOut(scope: SignOutScope.local);
      container.invalidate(learnerStateNotifierProvider);
      container.invalidate(courseStateNotifierProvider);
      container.invalidate(roadmapStateNotifierProvider);
      container.invalidate(placementStateNotifierProvider);
      container.invalidate(lessonSessionNotifierProvider);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                isRu
                    ? 'Не удалось выйти из аккаунта. Попробуйте снова.'
                    : 'Hisobdan chiqib bo‘lmadi. Qayta urinib ko‘ring.',
              ),
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
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        toolbarHeight: isLargeText ? 96 : null,
        title: Text(
          isRu ? 'Мой профиль' : 'Profilim',
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            context.go('/dashboard');
          },
        ),
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 4),
      body: SafeArea(
        child: learnerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: isRu
                ? 'Не удалось загрузить профиль.'
                : 'Profilni yuklab bo‘lmadi.',
            onRetry: () =>
                ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
          ),
          data: (profile) {
            final xpCard = AppCard(
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
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    isRu ? 'Опыт' : 'Tajriba',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: AppColors.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            );
            final streakCard = AppCard(
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
                    isRu ? '${profile.streakDays} дн.' : '${profile.streakDays} kun',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    isRu ? 'Серия' : 'Ketma-ket',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: AppColors.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            );
            final courseCard = AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.school_rounded,
                    color: AppColors.primaryAccentOnSurface(context),
                    size: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activeCourse?.localizedTitle(lang) ??
                        (isRu ? 'Предмет' : 'Fan'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    isRu ? 'Текущий предмет' : 'Joriy fan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: AppColors.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            );

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
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    profile.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimaryColor(context),
                                    ),
                                  ),
                                  AppBadge(
                                    text: demo
                                        ? (isRu ? 'Демо' : 'Namuna')
                                        : (isRu ? 'Ученик' : 'O‘quvchi'),
                                    variant: AppBadgeVariant.emerald,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                demo
                                    ? (isRu ? 'Демо-аккаунт' : 'Namuna hisobi')
                                    : (email ??
                                          (isRu
                                              ? 'Эл. почта не указана'
                                              : 'Elektron pochta ko‘rsatilmagan')),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textMutedColor(context),
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
                  if (isLargeText)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        xpCard,
                        const SizedBox(height: 10),
                        streakCard,
                        const SizedBox(height: 10),
                        courseCard,
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: xpCard),
                        const SizedBox(width: 8),
                        Expanded(child: streakCard),
                        const SizedBox(width: 8),
                        Expanded(child: courseCard),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Settings Card
                  EdTechReveal(
                    index: 2,
                    child: EdTechSectionHeader(
                      pillText: isRu ? 'Настройка' : 'Moslashtirish',
                      title: isRu ? 'Настройки обучения' : 'O‘quv sozlamalari',
                      highlightWord: isRu ? 'обучения' : 'sozlamalari',
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
                            title: Text(
                              isRu ? 'Сменить предмет' : 'Fanni o‘zgartirish',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              context.push('/courses');
                            },
                          ),
                          if (activeCourse != null)
                            ListTile(
                              leading: const Icon(Icons.tune_rounded),
                              title: Text(
                                isRu
                                    ? 'Настроить стартовый уровень'
                                    : 'Boshlash darajasini sozlash',
                              ),
                              subtitle: Text(activeCourse.localizedTitle(lang)),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                context.push('/onboarding');
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  if (demo)
                    AppButton(
                      text: isRu
                          ? 'Сбросить результаты демо'
                          : 'Namuna natijalarini tiklash',
                      isFullWidth: true,
                      variant: AppButtonVariant.outline,
                      leftIcon: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: AppColors.isDark(context)
                            ? AppColors.warning
                            : const Color(0xFFB45309),
                      ),
                      onPressed: () async {
                        await ref
                            .read(learnerStateNotifierProvider.notifier)
                            .resetAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  isRu
                                      ? 'Демо-режим успешно сброшен.'
                                      : 'Demo muvaffaqiyatli tiklandi.',
                                ),
                              ),
                            );
                          context.go('/courses');
                        }
                      },
                    ),
                  const SizedBox(height: 10),

                  AppButton(
                    text: isRu ? 'Выйти из аккаунта' : 'Hisobdan chiqish',
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
