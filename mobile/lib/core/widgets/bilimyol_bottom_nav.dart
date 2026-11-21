import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_strings.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_typography.dart';

class BilimYolBottomNav extends StatelessWidget {
  final int currentIndex;

  const BilimYolBottomNav({super.key, required this.currentIndex});

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
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final items = [
      _NavItem(
        icon: Icons.home_rounded,
        label: s.navHome,
        route: '/dashboard',
      ),
      _NavItem(
        icon: Icons.alt_route_rounded,
        label: s.navRoadmap,
        route: '/roadmap',
      ),
      _NavItem(
        icon: Icons.smart_toy_rounded,
        label: s.navAiTutor,
        route: '/ai-tutor',
      ),
      _NavItem(
        icon: Icons.bar_chart_rounded,
        label: s.navProgress,
        route: '/progress',
      ),
      _NavItem(
        icon: Icons.person_rounded,
        label: s.navProfile,
        route: '/profile',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.paper,
        border: Border(
          top: BorderSide(
            color: c.hairline,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: (c.isDark ? Colors.black : const Color(0xFF0F172A))
                .withValues(alpha: c.isDark ? 0.28 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;

              return Expanded(
                child: Semantics(
                  selected: isSelected,
                  button: true,
                  child: InkWell(
                    onTap: () {
                      if (!isSelected) {
                        context.go(item.route);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      constraints: const BoxConstraints(minHeight: 44),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? c.brandSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: isSelected ? c.brand : c.slatefine,
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.ui(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected ? c.brand : c.slatefine,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  _NavItem({required this.icon, required this.label, required this.route});
}
