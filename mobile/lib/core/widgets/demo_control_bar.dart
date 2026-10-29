import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../../app/providers.dart';

/// Compact demo control strip for judges: resets the whole demo state so the
/// full journey can be replayed from the course-selection screen at any time.
class DemoControlBar extends ConsumerStatefulWidget {
  const DemoControlBar({super.key});

  @override
  ConsumerState<DemoControlBar> createState() => _DemoControlBarState();
}

class _DemoControlBarState extends ConsumerState<DemoControlBar> {
  bool _resetting = false;

  Future<void> _resetDemo() async {
    if (_resetting) return;
    setState(() => _resetting = true);
    try {
      await ref.read(learnerStateNotifierProvider.notifier).resetAll();
      if (mounted) context.go('/courses');
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_rounded,
            color: Color(0xFF38BDF8),
            size: 16,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Demo rejimi — hakamlar istalgan vaqtda qayta boshlashi mumkin',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _resetting ? null : _resetDemo,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _resetting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.restart_alt_rounded, size: 15),
            label: Text(
              'Reset',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}