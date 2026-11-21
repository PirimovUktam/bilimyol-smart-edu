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

  String _resolveLang(BuildContext context) {
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(courseStateNotifierProvider);
    final learner = ref.watch(learnerStateNotifierProvider);
    final course = courses.activeCourse;
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';

    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 96 : null,
        title: Text(
          isRu ? 'План обучения' : 'O‘rganish rejasi',
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: learner.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => FriendlyErrorState(
            message: isRu
                ? 'Не удалось загрузить профиль.'
                : 'Profilni yuklab bo‘lmadi.',
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
                  text: isRu ? 'Выбрать предмет' : 'Fan tanlash',
                  onPressed: () {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    context.go('/courses');
                  },
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

List<(InitialLevel, String, String)> _levelChoicesFor(bool isRu) => [
  (
    InitialLevel.beginner,
    isRu ? 'Начать с нуля' : 'Noldan boshlayman',
    isRu
        ? 'Начните с понятных объяснений и разобранных примеров.'
        : 'O‘zbekcha izoh va ishlangan misoldan boshlang.',
  ),
  (
    InitialLevel.intermediate,
    isRu ? 'Знаю основы' : 'Asoslarini bilaman',
    isRu
        ? 'Изучайте темы или проверьте текущий уровень.'
        : 'Mavzularni o‘rganing yoki darajangizni tekshiring.',
  ),
  (
    InitialLevel.advanced,
    isRu ? 'У меня крепкие знания' : 'Mustahkam bilimim bor',
    isRu
        ? 'Откройте учебный маршрут или пройдите необязательную диагностику.'
        : 'Ta’lim rejasini oching yoki ixtiyoriy diagnostikani tanlang.',
  ),
];

Map<OnboardingGoal, String> _goalsFor(bool isRu) => {
  OnboardingGoal.mastery:
      isRu ? 'Изучить основные темы' : 'Asosiy mavzularni o‘rganish',
  OnboardingGoal.examPrep:
      isRu ? 'Подготовиться к экзамену' : 'Imtihonga tayyorlanish',
  OnboardingGoal.skillsBoost:
      isRu ? 'Развить практические навыки' : 'Amaliy ko‘nikmalarni rivojlantirish',
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      }
    });
  }

  String _resolveLang(BuildContext context) {
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  Future<void> _start({bool diagnostic = false}) async {
    final level = _level;
    if (_saving || level == null) return;
    final course = widget.course;
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
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
            .startLesson(starter, uiLocale: lang);
        if (!mounted ||
            ref.read(courseStateNotifierProvider).activeCourse?.id !=
                course.id) {
          return;
        }
        if (ref.read(lessonSessionNotifierProvider).lesson?.id != starter) {
          setState(
            () => _error = isRu
                ? 'Не удалось загрузить первый урок. Попробуйте снова.'
                : 'Birinchi darsni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
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
          () => _error = isRu
              ? 'Не удалось сохранить план. Попробуйте снова.'
              : 'Rejani saqlab bo‘lmadi. Qayta urinib ko‘ring.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
    final levelChoices = _levelChoicesFor(isRu);
    final goals = _goalsFor(isRu);
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
                      color: AppColors.primaryTint(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.course.localizedTitle(lang),
                      style: theme.labelLarge?.copyWith(
                        color: AppColors.primaryAccentOnSurface(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRu
                        ? 'С чего вы хотите начать?'
                        : 'Qayerdan boshlamoqchisiz?',
                    style: theme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRu
                        ? 'Выберите уровень для этого предмета. Его можно изменить позже.'
                        : 'Bu fan uchun darajangizni tanlang. Uni keyin ham o‘zgartirishingiz mumkin.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final (idx, (level, title, detail))
                in levelChoices.indexed) ...[
              EdTechReveal(
                index: idx + 1,
                child: AppCard(
                  padding: EdgeInsets.zero,
                  borderColor: _level == level
                      ? AppColors.primaryAccentOnSurface(context)
                      : AppColors.borderColor(context),
                  borderWidth: _level == level ? 1.6 : 1.0,
                  backgroundColor: _level == level
                      ? AppColors.primaryTint(context).withValues(alpha: 0.5)
                      : AppColors.surfaceColor(context),
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
                            ? AppColors.primaryAccentOnSurface(context)
                            : AppColors.textMutedColor(context),
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
              decoration: InputDecoration(
                labelText: isRu ? 'Цель' : 'Maqsad',
              ),
              items: [
                for (final entry in goals.entries)
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
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isRu ? 'Ежедневное время' : 'Kunlik vaqt',
              ),
              items: [
                for (final time in [15, 30, 60])
                  DropdownMenuItem(
                    value: time,
                    child: Text(
                      isRu ? '$time минут' : '$time daqiqa',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                  ? (isRu
                        ? 'Начать первый урок'
                        : 'Birinchi darsni boshlash')
                  : (isRu
                        ? 'Открыть маршрут обучения'
                        : 'Ta’lim yo‘lini ochish'),
              isLoading: _saving,
              onPressed: _level == null ? null : _start,
            ),
            if (_level != null && !beginner) ...[
              const SizedBox(height: 8),
              AppButton(
                text: isRu
                    ? 'Дополнительная диагностика'
                    : 'Ixtiyoriy diagnostika',
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
