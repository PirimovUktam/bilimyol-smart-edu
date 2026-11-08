import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../domain/entities/course.dart';
import '../../domain/personalization/learning_start.dart';
import '../../domain/entities/learner_profile.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider);
    final course = courses.activeCourse;

    return Scaffold(
      appBar: AppBar(title: const Text('O‘rganish rejasi')),
      body: SafeArea(
        child: learner.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: 'Profilni yuklab bo‘lmadi.',
            onRetry: () =>
                ref.read(learnerStateNotifierProvider.notifier).loadProfile(),
          ),
          data: (profile) {
            if (courses.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (course == null) {
              return Center(
                child: AppButton(
                  text: 'Fan tanlash',
                  onPressed: () => context.go('/courses'),
                ),
              );
            }
            return _LearningPlanForm(
              key: ValueKey(course.id),
              course: course,
              profile: profile,
            );
          },
        ),
      ),
    );
  }
}

const _levelChoices = [
  (
    InitialLevel.beginner,
    'Noldan boshlayman',
    'O‘zbekcha izoh va ishlangan misoldan boshlang.',
  ),
  (
    InitialLevel.intermediate,
    'Asoslarini bilaman',
    'Mavzularni o‘rganing yoki darajangizni tekshiring.',
  ),
  (
    InitialLevel.advanced,
    'Mustahkam bilimim bor',
    'Ta’lim rejasini oching yoki ixtiyoriy diagnostikani tanlang.',
  ),
];

const _goals = {
  OnboardingGoal.mastery: 'Asosiy mavzularni o‘rganish',
  OnboardingGoal.examPrep: 'Imtihonga tayyorlanish',
  OnboardingGoal.skillsBoost: 'Amaliy ko‘nikmalarni rivojlantirish',
};

class _LearningPlanForm extends ConsumerStatefulWidget {
  const _LearningPlanForm({
    super.key,
    required this.course,
    required this.profile,
  });

  final Course course;
  final LearnerProfile profile;

  @override
  ConsumerState<_LearningPlanForm> createState() => _LearningPlanFormState();
}

class _LearningPlanFormState extends ConsumerState<_LearningPlanForm> {
  late InitialLevel? _level = widget.profile.courseLevels[widget.course.id];
  late OnboardingGoal _goal = widget.profile.goal;
  late int _minutes = [15, 30, 60].contains(widget.profile.dailyMinutes)
      ? widget.profile.dailyMinutes
      : 15;
  bool _saving = false;
  String? _error;

  Future<void> _start({bool diagnostic = false}) async {
    final level = _level;
    if (_saving || level == null) return;
    final course = widget.course;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(learnerStateNotifierProvider.notifier)
          .updateOnboarding(
            courseId: course.id,
            goal: _goal,
            dailyMinutes: _minutes,
            initialLevel: level,
          );
      if (!mounted ||
          ref.read(courseStateNotifierProvider).activeCourse?.id != course.id) {
        return;
      }
      if (diagnostic && level != InitialLevel.beginner) {
        context.pushReplacement('/placement');
        return;
      }

      final starter = pendingFoundationLesson(course, ref.read(learnerStateNotifierProvider).valueOrNull);
      if (level == InitialLevel.beginner && starter != null) {
        await ref
            .read(lessonSessionNotifierProvider.notifier)
            .startLesson(starter);
        if (!mounted ||
            ref.read(courseStateNotifierProvider).activeCourse?.id !=
                course.id) {
          return;
        }
        if (ref.read(lessonSessionNotifierProvider).lesson?.id != starter) {
          setState(
            () => _error =
                'Birinchi darsni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
          );
          return;
        }
        context.pushReplacement('/lesson');
      } else {
        context.pushReplacement('/roadmap');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Rejani saqlab bo‘lmadi. Qayta urinib ko‘ring.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final hasStarter = widget.course.starterLessonId != null;
    final beginner = _level == InitialLevel.beginner;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                    child: Text(
                      widget.course.title,
                      style: theme.labelLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Qayerdan boshlamoqchisiz?', style: theme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu fan uchun darajangizni tanlang. Uni keyin ham o‘zgartirishingiz mumkin.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final (idx, (level, title, detail))
                in _levelChoices.indexed) ...[
              EdTechReveal(
                index: idx + 1,
                child: AppCard(
                  padding: EdgeInsets.zero,
                  borderColor: _level == level
                      ? AppColors.primary
                      : AppColors.cardBorder,
                  borderWidth: _level == level ? 1.6 : 1.0,
                  backgroundColor: _level == level
                      ? AppColors.primaryLight.withValues(alpha: 0.5)
                      : AppColors.surface,
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(detail),
                      leading: Icon(
                        _level == level
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _level == level
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      selected: _level == level,
                      onTap: _saving
                          ? null
                          : () => setState(() => _level = level),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<OnboardingGoal>(
              initialValue: _goal,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Maqsad'),
              items: [
                for (final entry in _goals.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _goal = value ?? _goal),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _minutes,
              decoration: const InputDecoration(labelText: 'Kunlik vaqt'),
              items: [
                for (final time in [15, 30, 60])
                  DropdownMenuItem(value: time, child: Text('$time daqiqa')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _minutes = value ?? _minutes),
            ),
            const SizedBox(height: 16),
            if (_error case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            AppButton(
              text: beginner && hasStarter
                  ? 'Birinchi darsni boshlash'
                  : 'Ta’lim yo‘lini ochish',
              isLoading: _saving,
              onPressed: _level == null ? null : _start,
            ),
            if (_level != null && !beginner) ...[
              const SizedBox(height: 8),
              AppButton(
                text: 'Ixtiyoriy diagnostika',
                variant: AppButtonVariant.outline,
                onPressed: _saving ? null : () => _start(diagnostic: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
