import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class BilimYolBottomNav extends StatelessWidget {
  final int currentIndex;

  const BilimYolBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    final items = [
      _NavItem(
        icon: Icons.home_rounded,
        label: isRu ? 'Главная' : 'Bosh sahifa',
        route: '/dashboard',
      ),
      _NavItem(
        icon: Icons.alt_route_rounded,
        label: isRu ? 'Учебный путь' : 'Ta’lim yo‘li',
        route: '/roadmap',
      ),
      _NavItem(
        icon: Icons.smart_toy_rounded,
        label: 'Yo‘lchi AI',
        route: '/ai-tutor',
      ),
      _NavItem(
        icon: Icons.bar_chart_rounded,
        label: isRu ? 'Прогресс' : 'Natijalar',
        route: '/progress',
      ),
      _NavItem(
        icon: Icons.person_rounded,
        label: isRu ? 'Профиль' : 'Profil',
        route: '/profile',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        border: Border(
          top: BorderSide(
            color: AppColors.borderColor(context),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
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
              final activeColor = AppColors.primaryAccentOnSurface(context);
              final inactiveColor = AppColors.textMutedColor(context);

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
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryTint(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: isSelected ? activeColor : inactiveColor,
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected ? activeColor : inactiveColor,
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
