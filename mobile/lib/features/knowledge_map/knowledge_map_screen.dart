import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/edtech_section_header.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../app/providers.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/skill.dart';
import '../../domain/entities/skill_score.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/personalization/learning_start.dart';
import '../../domain/personalization/skill_scoring_engine.dart';

class KnowledgeMapScreen extends ConsumerStatefulWidget {
  const KnowledgeMapScreen({super.key});

  @override
  ConsumerState<KnowledgeMapScreen> createState() => _KnowledgeMapScreenState();
}

class _KnowledgeMapScreenState extends ConsumerState<KnowledgeMapScreen> {
  String? _requestedCourseId;
  bool _isStartingLesson = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCourseRoadmap(
        ref.read(courseStateNotifierProvider).activeCourse?.id,
        force: true,
      );
    });
  }

  void _loadCourseRoadmap(String? courseId, {bool force = false}) {
    if (courseId == null || courseId.isEmpty || !usesMathMastery(courseId)) {
      return;
    }
    if (!force && _requestedCourseId == courseId) return;
    _requestedCourseId = courseId;
    ref.read(roadmapStateNotifierProvider.notifier).loadRoadmap(courseId);
  }

  Future<void> _startFirstExercise(
    Course course,
    LearnerProfile profile,
    LearningPath path,
  ) async {
    if (_isStartingLesson) return;
    final lessonId = resolveNextLearningLesson(course, profile, path);
    if (lessonId == null) {
      context.push('/roadmap');
      return;
    }
    setState(() => _isStartingLesson = true);
    try {
      await ref.read(lessonSessionNotifierProvider.notifier).startLesson(lessonId);
      if (!mounted ||
          ref.read(courseStateNotifierProvider).activeCourse?.id != course.id) {
        return;
      }
      if (ref.read(lessonSessionNotifierProvider).lesson?.id == lessonId) {
        await context.push('/lesson');
        if (mounted) {
          _loadCourseRoadmap(course.id, force: true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dars yuklanmadi. Qayta urinib ko‘ring.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingLesson = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      courseStateNotifierProvider.select((state) => state.activeCourse?.id),
      (prev, next) {
        if (next != null && next != prev) {
          _loadCourseRoadmap(next, force: true);
        }
      },
    );

    final courseState = ref.watch(courseStateNotifierProvider);
    final learnerAsync = ref.watch(learnerStateNotifierProvider);
    final activeCourse = courseState.activeCourse;
    final mathPath = usesMathMastery(activeCourse?.id)
        ? ref.watch(roadmapStateNotifierProvider)
        : null;

    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        toolbarHeight: isLargeText ? 144 : null,
        title: Text(
          activeCourse != null
              ? 'Bilim Xaritasi • ${activeCourse.title}'
              : 'Bilim Xaritasi',
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: isLargeText ? 15 : 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route_rounded),
            tooltip: 'Roadmap',
            onPressed: () => context.push('/roadmap'),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            // Reference 2 Top Toggle Switch: [Bilim xaritasi | Roadmap]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Bilim xaritasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/roadmap'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: Text(
                            'Roadmap',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: courseState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : courseState.error != null
                  ? FriendlyErrorState(
                      message: courseState.error!,
                      onRetry: () =>
                          ref.read(courseStateNotifierProvider.notifier).init(),
                    )
                  : activeCourse == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Davom etish uchun mavjud fanlardan birini tanlang.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                text: 'Fan tanlash',
                                onPressed: () => context.go('/courses'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : mathPath != null
                  ? mathPath.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => FriendlyErrorState(
                        message: 'Ta’lim yo‘lini yuklab bo‘lmadi.',
                        onRetry: () => _loadCourseRoadmap(
                          activeCourse.id,
                          force: true,
                        ),
                      ),
                      data: (path) => learnerAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => FriendlyErrorState(
                          message: 'Profil ma’lumotlarini yuklab bo‘lmadi.',
                          onRetry: () => ref
                              .read(learnerStateNotifierProvider.notifier)
                              .loadProfile(),
                        ),
                        data: (profile) => _buildMathPilotBody(
                          context,
                          course: activeCourse,
                          skills: courseState.activeSkills,
                          profile: profile,
                          path: path,
                        ),
                      ),
                    )
                  : learnerAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => FriendlyErrorState(
                  message: 'Profil ma’lumotlarini yuklab bo‘lmadi.',
                  onRetry: () => ref
                      .read(learnerStateNotifierProvider.notifier)
                      .loadProfile(),
                ),
                data: (profile) {
                  final scores = profile.scoresByCourse[activeCourse.id] ?? {};
                  final skills = courseState.activeSkills;

                  SkillScore? weakestSkill;
                  for (final s in scores.values) {
                    if (weakestSkill == null || s.score < weakestSkill.score) {
                      weakestSkill = s;
                    }
                  }

                  final avgScore = SkillScoringEngine.computeOverallScore(scores);
                  final weakestSkillObj = skills.where((s) => s.id == weakestSkill?.skillId).firstOrNull;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview Card
                        AppCard(
                          backgroundColor: AppColors.surfaceDark,
                          borderColor: const Color(0xFF334155),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Umumiy O‘zlashtirish',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$avgScore%',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF475569)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFBBF24)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+${profile.xp} XP',
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
                              const SizedBox(height: 14),
                              Text(
                                'Haqiqiy javoblaringiz tahlili asosida bilim xaritangiz shakllantirildi.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFFCBD5E1),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // WEAKEST SKILL ALERT BANNER
                        if (weakestSkill != null && weakestSkill.score < 50)
                          AppCard(
                            backgroundColor: AppColors.errorTint(context),
                            borderColor: AppColors.errorTextOnTint(context).withValues(alpha: 0.35),
                            borderWidth: 1.5,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorTextOnTint(context).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.errorTextOnTint(context),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          const AppBadge(
                                            text: 'DIQQAT: Zaif Bo‘g‘in',
                                            variant: AppBadgeVariant.rose,
                                          ),
                                          Text(
                                            '${weakestSkill.score}%',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.errorTextOnTint(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${weakestSkillObj?.name ?? "Mavzu"} bo‘yicha tushunchalarni mustahkamlash talab etiladi.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimaryColor(context),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Yo‘l xaritasida ushbu mavzuga maxsus mustahkamlash qadami qo‘shildi.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.secondaryTextOnTint(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Skills Breakdown List
                        const EdTechReveal(
                          index: 1,
                          child: EdTechSectionHeader(
                            pillText: 'Tahlil va o‘zlashtirish',
                            title: 'Ko‘nikmalar Tahlili',
                            highlightWord: 'Tahlili',
                          ),
                        ),
                        const SizedBox(height: 12),

                        ...skills.indexed.map((entry) {
                          final index = entry.$1;
                          final skill = entry.$2;
                          final scoreObj = scores[skill.id];
                          final score = scoreObj?.score ?? 0;
                          final isWeak = weakestSkill?.skillId == skill.id && score < 50;

                          Color progressColor = AppColors.primaryAccentOnSurface(context);
                          if (score < 40) {
                            progressColor = AppColors.errorTextOnTint(context);
                          } else if (score < 60) {
                            progressColor = AppColors.isDark(context)
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFB45309);
                          } else if (score >= 80) {
                            progressColor = AppColors.successTextOnTint(context);
                          }

                          return EdTechReveal(
                            index: index + 2,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                padding: const EdgeInsets.all(16),
                                borderColor: isWeak
                                    ? AppColors.errorTextOnTint(context).withValues(alpha: 0.45)
                                    : AppColors.borderColor(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    skill.name,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textPrimaryColor(context),
                                                    ),
                                                  ),
                                                  AppBadge(
                                                    text: SkillScoringEngine.getMasteryLabelUz(score),
                                                    variant: isWeak ? AppBadgeVariant.rose : AppBadgeVariant.blue,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                skill.description,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11.5,
                                                  color: AppColors.textMutedColor(context),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '$score%',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: progressColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: score / 100,
                                        minHeight: 7,
                                        backgroundColor: AppColors.subtleSurface(context),
                                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 16),
                        // Roadmap Navigation Button
                        AppButton(
                          text: 'Moslashuvchan Yo‘l Xaritasi',
                          isFullWidth: true,
                          size: AppButtonSize.large,
                          rightIcon: const Icon(Icons.alt_route_rounded, size: 18, color: Colors.white),
                          onPressed: () {
                            context.push('/roadmap');
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMathPilotBody(
    BuildContext context, {
    required Course course,
    required List<Skill> skills,
    required LearnerProfile profile,
    required LearningPath path,
  }) {
    if (path.courseId != course.id) {
      return const Center(child: CircularProgressIndicator());
    }
    if (path.nodes.isEmpty) {
      return Center(
        child: AppButton(
          text: 'Ta’lim yo‘lini ochish',
          onPressed: () => context.push('/roadmap'),
        ),
      );
    }

    final scores =
        profile.scoresByCourse[course.id] ?? const <String, SkillScore>{};
    final diagnosticScores = scores.values.toList();
    final hasDiagnosticScores = diagnosticScores.isNotEmpty;
    final hasPilotAnswers = path.nodes.any(
      (node) => node.mastery != null
          ? node.mastery!.answered > 0
          : (!node.isOptional &&
                (node.status == NodeStatus.inProgress ||
                    node.status == NodeStatus.completed)),
    );
    final overallMastery = path.masteryPercent ?? 0;
    final diagnosticAvg = SkillScoringEngine.computeOverallScore(scores);
    final diagnosticGaps = diagnosticScores.where((s) => s.score < 100).toList()
      ..sort((a, b) {
        final scoreOrder = a.score.compareTo(b.score);
        return scoreOrder != 0 ? scoreOrder : a.skillId.compareTo(b.skillId);
      });
    final evaluatedTopicsCount = path.nodes
        .where(
          (node) =>
              !node.isOptional &&
              (node.mastery != null
                  ? node.mastery!.answered > 0
                  : (node.status != NodeStatus.locked &&
                        node.status != NodeStatus.available)),
        )
        .length;

    String resolveSkillName(String skillId) =>
        skills.where((s) => s.id == skillId).firstOrNull?.name ??
        path.nodes.where((n) => n.skillId == skillId).firstOrNull?.title ??
        skillId;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!hasDiagnosticScores && !hasPilotAnswers)
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppBadge(
                  text: 'Diagnostika holati',
                  variant: AppBadgeVariant.blue,
                ),
                const SizedBox(height: 10),
                Text(
                  'Baholangan mavzular',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Diagnostika o‘quv rejangizni moslashtirishga yordam beradi.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondaryColor(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  text: 'Diagnostikani boshlash',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.small,
                  onPressed: () => context.push('/placement'),
                ),
              ],
            ),
          )
        else if (hasDiagnosticScores && !hasPilotAnswers) ...[
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppBadge(
                      text: 'Diagnostika holati',
                      variant: AppBadgeVariant.blue,
                    ),
                    Text(
                      '$overallMastery%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryAccentOnSurface(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Diagnostika natijasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Diagnostika: $diagnosticAvg% (${diagnosticScores.length} ta ko‘nikma). Darslardagi o‘zlashtirish: $overallMastery%.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondaryColor(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBadge(
                  text: 'Diqqat markazi',
                  variant: diagnosticGaps.isNotEmpty
                      ? AppBadgeVariant.rose
                      : AppBadgeVariant.emerald,
                ),
                const SizedBox(height: 10),
                Text(
                  'Keyingi qadam',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 6),
                if (diagnosticGaps.isNotEmpty) ...[
                  Text(
                    'Diagnostikada quyidagi ko‘nikmalar bo‘yicha qo‘shimcha mashq kerak:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondaryColor(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final gap in diagnosticGaps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: AppColors.errorTextOnTint(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${resolveSkillName(gap.skillId)} · ${gap.score}%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Keyingi qadam: tayanch darsdagi birinchi mashqni bajarib, bilimingizni mustahkamlang.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondaryColor(context),
                      height: 1.4,
                    ),
                  ),
                ] else
                  Text(
                    'Diagnostikadagi barcha savollarga to‘g‘ri javob berdingiz. Bilimingizni amalda tasdiqlash uchun tayanch mashq beriladi, shundan so‘ng keyingi mavzu ochiladi.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondaryColor(context),
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 14),
                AppButton(
                  text: 'Birinchi mashqni boshlash',
                  isFullWidth: true,
                  isLoading: _isStartingLesson,
                  rightIcon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  onPressed: () => _startFirstExercise(course, profile, path),
                ),
              ],
            ),
          ),
        ] else
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppBadge(
                      text: 'Umumiy o‘zlashtirish',
                      variant: AppBadgeVariant.emerald,
                    ),
                    Text(
                      '$overallMastery%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryAccentOnSurface(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$evaluatedTopicsCount · Baholangan mavzular',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (overallMastery / 100).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppColors.subtleSurface(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryAccentOnSurface(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const EdTechReveal(
          index: 0,
          child: EdTechSectionHeader(
            pillText: 'O‘quv maqsadlari',
            title: 'Mavzular va o‘zlashtirish',
            highlightWord: 'o‘zlashtirish',
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < path.nodes.length; i++) ...[
          EdTechReveal(
            index: i + 1,
            child: _buildMathNodeCard(context, path.nodes[i], i + 1),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMathNodeCard(
    BuildContext context,
    LearningPathNode node,
    int topicNumber,
  ) {
    final label = node.reviewDue
        ? 'Takrorlash vaqti keldi'
        : switch (node.status) {
            NodeStatus.locked => 'Tayanch mavzu talab qilinadi',
            NodeStatus.completed => 'O‘zlashtirilgan',
            NodeStatus.reinforcement => 'Qayta mashq kerak',
            NodeStatus.inProgress => 'Mashq qilinyapti',
            NodeStatus.available => 'Ochiq',
          };
    final mastery = node.mastery;
    final requiredItems = mastery != null && mastery.requiredItems > 0
        ? mastery.requiredItems
        : 5;
    final answered = mastery?.answered ?? 0;
    final accuracy = mastery != null && mastery.answered > 0
        ? ((100 * mastery.correct) / mastery.answered).round()
        : null;
    final isCompleted = node.status == NodeStatus.completed;
    final isLocked = node.status == NodeStatus.locked;
    final iconColor = isCompleted
        ? AppColors.successTextOnTint(context)
        : isLocked
        ? AppColors.textMutedColor(context)
        : AppColors.primaryAccentOnSurface(context);
    final iconBg = isCompleted
        ? AppColors.successTint(context)
        : isLocked
        ? AppColors.subtleSurface(context)
        : AppColors.primaryTint(context);
    final iconData = isLocked
        ? Icons.lock_outline_rounded
        : isCompleted
        ? Icons.check_rounded
        : Icons.explore_outlined;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge(
                      text: '$topicNumber-mavzu',
                      variant: isCompleted
                          ? AppBadgeVariant.emerald
                          : isLocked
                          ? AppBadgeVariant.slate
                          : AppBadgeVariant.blue,
                    ),
                    if (node.isOptional)
                      const AppBadge(
                        text: 'Ixtiyoriy',
                        variant: AppBadgeVariant.blue,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            node.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          if (node.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              node.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondaryColor(context),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isLocked
                  ? AppColors.textMutedColor(context)
                  : AppColors.primaryAccentOnSurface(context),
            ),
          ),
          if (mastery != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$answered/$requiredItems',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                if (accuracy != null)
                  Text(
                    '$accuracy%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successTextOnTint(context),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (answered / requiredItems).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.subtleSurface(context),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted
                      ? AppColors.successTextOnTint(context)
                      : AppColors.primaryAccentOnSurface(context),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.borderColor(context)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  node.prerequisites.isEmpty
                      ? 'Mustaqil boshlang‘ich modul'
                      : 'Tayanch bosqich: ${node.prerequisites.length} ta',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedColor(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${node.estimatedMinutes} daqiqa',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryAccentOnSurface(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
