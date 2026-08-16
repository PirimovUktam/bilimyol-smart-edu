import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../app/providers.dart';
import '../../domain/entities/learner_profile.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  OnboardingGoal _selectedGoal = OnboardingGoal.mastery;
  int _selectedMinutes = 15;
  InitialLevel _selectedLevel = InitialLevel.intermediate;

  final List<Map<String, dynamic>> _goals = [
    {
      'goal': OnboardingGoal.mastery,
      'title': 'Mavzuni to‘liq tushunish',
      'subtitle': 'Bo‘shliqlarni aniqlash va fundamental bilim hosil qilish',
      'icon': Icons.psychology_rounded,
    },
    {
      'goal': OnboardingGoal.examPrep,
      'title': 'Imtihonga tayyorlanish',
      'subtitle': 'DTM va milliy sertifikat formatidagi masalalarni yechish',
      'icon': Icons.military_tech_rounded,
    },
    {
      'goal': OnboardingGoal.skillsBoost,
      'title': 'Bilim darajasini oshirish',
      'subtitle': 'Qisqa kunlik darslar orqali ko‘nikmalarni rivojlantirish',
      'icon': Icons.trending_up_rounded,
    },
  ];

  final List<Map<String, dynamic>> _timeOptions = [
    {
      'minutes': 15,
      'title': '15 daqiqa / kun',
      'badge': 'Tavsiya etiladi',
      'subtitle': 'Tezkor va samarali mikro-darslar',
    },
    {
      'minutes': 30,
      'title': '30 daqiqa / kun',
      'badge': 'Standart',
      'subtitle': 'Chuqurlashtirilgan o‘rganish',
    },
    {
      'minutes': 60,
      'title': '60 daqiqa / kun',
      'badge': 'Intensiv',
      'subtitle': 'Maksimal tezlikda natijaga erishish',
    },
  ];

  final List<Map<String, dynamic>> _levels = [
    {
      'level': InitialLevel.beginner,
      'title': 'Boshlang‘ich',
      'subtitle': 'Asosiy tushunchalarni yangitdan o‘rganish kerak',
    },
    {
      'level': InitialLevel.intermediate,
      'title': 'O‘rta',
      'subtitle': 'Asoslar ma’lum, murakkab masalalarda yordam kerak',
    },
    {
      'level': InitialLevel.advanced,
      'title': 'Yuqori',
      'subtitle': 'Olimpiada va murakkab darajaga tayyorlanish',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final courseState = ref.watch(courseStateNotifierProvider);
    final activeCourse = courseState.activeCourse;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('O‘quv Rejasini Sozlash'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              Row(
                children: List.generate(3, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Title and Header
              if (_currentStep == 0) ...[
                const AppBadge(text: '1-qadam / 3: Asosiy Maqsad', variant: AppBadgeVariant.blue),
                const SizedBox(height: 8),
                Text(
                  '${activeCourse?.title ?? "Kurs"} bo‘yicha asosiy maqsadingiz nima?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _goals.length,
                    itemBuilder: (context, idx) {
                      final item = _goals[idx];
                      final isSelected = _selectedGoal == item['goal'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          borderColor: isSelected ? AppColors.primary : AppColors.cardBorder,
                          borderWidth: isSelected ? 2 : 1.2,
                          backgroundColor: isSelected ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.surface,
                          onTap: () {
                            setState(() => _selectedGoal = item['goal']);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryLight : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['subtitle'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else if (_currentStep == 1) ...[
                const AppBadge(text: '2-qadam / 3: Kunlik Vaqt', variant: AppBadgeVariant.teal),
                const SizedBox(height: 8),
                Text(
                  'Kuniga qancha vaqt ajrata olasiz?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _timeOptions.length,
                    itemBuilder: (context, idx) {
                      final item = _timeOptions[idx];
                      final isSelected = _selectedMinutes == item['minutes'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          borderColor: isSelected ? AppColors.secondary : AppColors.cardBorder,
                          borderWidth: isSelected ? 2 : 1.2,
                          backgroundColor: isSelected ? AppColors.secondaryLight.withValues(alpha: 0.5) : AppColors.surface,
                          onTap: () {
                            setState(() => _selectedMinutes = item['minutes']);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item['title'],
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AppBadge(
                                          text: item['badge'],
                                          variant: isSelected ? AppBadgeVariant.teal : AppBadgeVariant.slate,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['subtitle'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? AppColors.secondary : AppColors.cardBorder,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const AppBadge(text: '3-qadam / 3: O‘z-o‘zini baholash', variant: AppBadgeVariant.amber),
                const SizedBox(height: 8),
                Text(
                  'O‘z darajangizni qanday baholaysiz?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Eslatma: Aniq ko‘nikma ballari keyingi Placement Test orqali hisoblanadi.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _levels.length,
                    itemBuilder: (context, idx) {
                      final item = _levels[idx];
                      final isSelected = _selectedLevel == item['level'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          borderColor: isSelected ? AppColors.primary : AppColors.cardBorder,
                          borderWidth: isSelected ? 2 : 1.2,
                          backgroundColor: isSelected ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.surface,
                          onTap: () {
                            setState(() => _selectedLevel = item['level']);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['subtitle'],
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? AppColors.primary : AppColors.cardBorder,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Next / Continue button
              AppButton(
                text: _currentStep < 2 ? 'Keyingi qadam' : 'Placement Testga O‘tish',
                isFullWidth: true,
                size: AppButtonSize.large,
                rightIcon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                onPressed: () async {
                  if (_currentStep < 2) {
                    setState(() => _currentStep++);
                  } else {
                    await ref.read(learnerStateNotifierProvider.notifier).updateOnboarding(
                          goal: _selectedGoal,
                          dailyMinutes: _selectedMinutes,
                          initialLevel: _selectedLevel,
                        );
                    if (context.mounted) {
                      context.push('/placement');
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
