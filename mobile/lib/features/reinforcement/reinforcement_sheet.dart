import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../domain/entities/question.dart';
import '../../domain/usecases/submit_reinforcement_use_case.dart';

class ReinforcementSheet extends StatefulWidget {
  final Question question;
  final Future<ReinforcementResult?> Function(int selectedIndex) onSubmit;
  final VoidCallback onGoToDashboard;

  const ReinforcementSheet({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.onGoToDashboard,
  });

  @override
  State<ReinforcementSheet> createState() => _ReinforcementSheetState();
}

class _ReinforcementSheetState extends State<ReinforcementSheet> {
  int? _selectedOption;
  bool _isSubmitting = false;
  ReinforcementResult? _result;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_result == null || !_result!.isCorrect) ...[
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              AppBadge(text: 'Mustahkamlash Mashqi', variant: AppBadgeVariant.amber),
                              SizedBox(width: 6),
                              AppBadge(text: '+30 XP', variant: AppBadgeVariant.emerald),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bilimingizni amalda sinab ko‘ring',
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
                const SizedBox(height: 16),

                // Question Card
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.question.text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      if (widget.question.formulaLatex != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.question.formulaLatex!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Options
                ...List.generate(widget.question.options.length, (idx) {
                  final opt = widget.question.options[idx];
                  final isSelected = _selectedOption == idx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.7) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => setState(() => _selectedOption = idx),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.cardBorder,
                              width: isSelected ? 2 : 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    ['A', 'B', 'C', 'D'][idx],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  opt,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                AppButton(
                  text: 'Javobni Tekshirish',
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  isLoading: _isSubmitting,
                  onPressed: _selectedOption == null
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          final res = await widget.onSubmit(_selectedOption!);
                          setState(() {
                            _isSubmitting = false;
                            _result = res;
                          });
                        },
                ),
              ] else ...[
                // SUCCESS CELEBRATION MODAL VIEW
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                    child: const Icon(Icons.celebration_rounded, color: AppColors.success, size: 32),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Ajoyib Natija! 🎉',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Tushuncha muvaffaqiyatli o‘zlashtirildi va bilim bali oshdi.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 18),

                // Score Boost Animation Card
                AppCard(
                  backgroundColor: AppColors.surfaceDark,
                  borderColor: const Color(0xFF334155),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Eski Bal',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                              Text(
                                '${_result!.oldScore}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF38BDF8), size: 24),
                          const SizedBox(width: 20),
                          Column(
                            children: [
                              Text(
                                'Yangi Bal',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                              Text(
                                '${_result!.newScore}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFBBF24)),
                            const SizedBox(width: 4),
                            Text(
                              '+30 XP mukofoti qo‘shildi!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFBBF24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Unlocked route notification
                AppCard(
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderColor: AppColors.primary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Navbatdagi mavzu yo‘l xaritasida blokdan ochildi!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                AppButton(
                  text: 'Dashboardga O‘tish',
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  rightIcon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  onPressed: widget.onGoToDashboard,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
