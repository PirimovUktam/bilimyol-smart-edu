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
import '../../data/datasources/english/a1_lessons_data.dart';
import '../../data/datasources/english/a2_lessons_data.dart';
import '../../data/datasources/english/b1_lessons_data.dart';
import '../../data/datasources/english/cefr_skeleton_data.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import '../lesson/flashcard_deck_widget.dart';

const List<LessonFlashcard> _englishAllFlashcards = [
  ...a1AllFlashcards,
  ...a2AllFlashcards,
  ...b1AllFlashcards,
];

final Map<String, String> _englishCardLessonIdMap = _buildCardLessonIdMap();

Map<String, String> _buildCardLessonIdMap() {
  final map = <String, String>{};
  for (final lesson in [
    ...a1LessonsData.values,
    ...a2LessonsData.values,
    ...b1LessonsData.values,
  ]) {
    for (final step in lesson.steps) {
      for (final card in step.flashcards ?? const <LessonFlashcard>[]) {
        map[card.id] = lesson.id;
      }
    }
  }
  return map;
}

class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final activeCourse = ref.read(courseStateNotifierProvider).activeCourse;
      if (activeCourse != null) {
        ref
            .read(roadmapStateNotifierProvider.notifier)
            .loadRoadmap(activeCourse.id);
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

  List<LessonFlashcard> _unlockedEnglishFlashcards(
    List<LearningPathNode> nodes,
    LearnerProfile? profile,
  ) {
    final unlockedLessonIds = <String>{
      'lesson_eng_starter',
      'lesson_eng_foundation_02',
      ...profile?.completedLessonIds ?? const [],
      for (final node in nodes)
        if (node.status != NodeStatus.locked &&
            node.targetLessonId != null &&
            node.targetLessonId!.trim().isNotEmpty)
          node.targetLessonId!,
    };
    final filtered = _englishAllFlashcards.where((card) {
      final lessonId = _englishCardLessonIdMap[card.id];
      return lessonId == null || unlockedLessonIds.contains(lessonId);
    }).toList();
    return filtered.isNotEmpty
        ? filtered
        : _englishAllFlashcards.take(2).toList();
  }

  void _openSrsFlashcardsModal(
    BuildContext context,
    String lang,
    List<LessonFlashcard> unlockedFlashcards,
  ) {
    final isRu = lang == 'ru';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isRu ? 'Повторение SRS' : 'SRS Takrorlash',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FlashcardDeckWidget(
                  flashcards: unlockedFlashcards,
                  allCourseFlashcards: unlockedFlashcards,
                  courseId: 'course_eng_01',
                  standaloneSrsMode: true,
                  uiLocale: lang,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLockedNodeSnackBar(
    BuildContext context,
    LearningPathNode node,
    Map<String, LearningPathNode> nodeById,
    String lang,
  ) {
    final isRu = lang == 'ru';
    final prereqLabels = node.prerequisites
        .map((id) => nodeById[id]?.localizedTitle(lang) ?? id)
        .toList();
    final msg = prereqLabels.isEmpty
        ? (isRu
              ? 'Этот этап пока заблокирован.'
              : 'Bu bosqich hozircha bloklangan.')
        : (isRu
              ? 'Сначала завершите: ${prereqLabels.join(', ')}'
              : 'Avval oldingi bosqichni yakunlang: ${prereqLabels.join(', ')}');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showLockedCefrSnackBar(
    BuildContext context,
    CefrLevelSkeleton level,
    bool isRu, {
    bool isUpcoming = false,
    Map<String, LearningPathNode> nodeById = const {},
  }) {
    final lang = isRu ? 'ru' : 'uz';
    final String msg;
    if (isUpcoming) {
      msg = isRu
          ? 'Уровень ${level.cefrLevel} появится на следующем этапе (DEFERRED). Пока завершите модули A1–B1.'
          : '${level.cefrLevel} bosqichi keyingi bosqichda (DEFERRED) qo‘shiladi. Hozircha A1–B1 darslarini yakunlang.';
    } else {
      final prereqTitles = level.prerequisites
          .map((id) => nodeById[id]?.localizedTitle(lang))
          .whereType<String>()
          .where((t) => t.trim().isNotEmpty)
          .toList();
      final prereqText = prereqTitles.isEmpty
          ? (isRu ? 'предыдущий уровень' : 'oldingi bosqichni')
          : prereqTitles.join(', ');
      msg = isRu
          ? 'Уровень ${level.cefrLevel} заблокирован. Сначала завершите: $prereqText'
          : '${level.cefrLevel} darajasi bloklangan. Avval oldingi bosqichni yakunlang: $prereqText';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final roadmapAsync = ref.watch(roadmapStateNotifierProvider);
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';

    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        toolbarHeight: isLargeText ? 144 : null,
        title: Text(
          isRu ? 'Мой учебный путь' : 'Mening ta’lim yo‘lim',
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: isLargeText ? 15 : 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded),
            tooltip: isRu ? 'Карта знаний' : 'Bilim Xaritasi',
            onPressed: () => context.push('/knowledge-map'),
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
                      child: InkWell(
                        onTap: () => context.push('/knowledge-map'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: Text(
                            isRu ? 'Карта знаний' : 'Bilim xaritasi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                          'Roadmap',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: roadmapAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => FriendlyErrorState(
                  message: isRu
                      ? 'Не удалось загрузить учебный путь.'
                      : 'Ta’lim yo‘lini yuklab bo‘lmadi.',
                  onRetry: () {
                    final course = ref
                        .read(courseStateNotifierProvider)
                        .activeCourse;
                    if (course != null) {
                      ref
                          .read(roadmapStateNotifierProvider.notifier)
                          .loadRoadmap(course.id);
                    }
                  },
                ),
                data: (roadmap) {
                  final nodes = roadmap.nodes;
                  if (roadmap.courseId == 'course_eng_01') {
                    return _buildEnglishCefrRoadmap(context, nodes, lang);
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EdTechReveal(
                          index: 0,
                          child: EdTechSectionHeader(
                            pillText: isRu
                                ? 'Учебный маршрут'
                                : 'O‘quv marshruti',
                            title: isRu
                                ? 'Персональные этапы обучения'
                                : 'Shaxsiy ta’lim bosqichlari',
                            highlightWord: isRu ? 'обучения' : 'bosqichlari',
                            subtitle: isRu
                                ? 'Осваивайте темы шаг за шагом, чтобы открыть следующий уровень.'
                                : 'Mavzularni bosqichma-bosqich o‘zlashtirib, keyingi darajani oching.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(nodes.length, (index) {
                          final node = nodes[index];
                          final isLast = index == nodes.length - 1;

                          return EdTechReveal(
                            index: index + 1,
                            child: _buildTimelineItem(
                              context,
                              node,
                              isLast,
                              index + 1,
                            ),
                          );
                        }),

                        const SizedBox(height: 24),
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

  Widget _buildEnglishCefrRoadmap(
    BuildContext context,
    List<LearningPathNode> nodes,
    String lang,
  ) {
    final isRu = lang == 'ru';
    final profile = ref.watch(learnerStateNotifierProvider).valueOrNull;
    final placementCefr = profile?.placementCefrByCourse['course_eng_01'];
    final placementScore = profile?.placementScoreByCourse['course_eng_01'];
    final placementTarget = placementCefr != null
        ? SkillScoringEngine.englishEntryTargetForCefr(placementCefr)
        : null;
    final unlockedFlashcards = _unlockedEnglishFlashcards(nodes, profile);
    final nodeById = <String, LearningPathNode>{
      for (final n in nodes) n.id: n,
    };
    final wiredLevels = cefrSkeletonLevels
        .where((lvl) => nodes.any((n) => n.cefrLevel == lvl.cefrLevel))
        .toList();
    final plannedLevels = cefrSkeletonLevels
        .where((lvl) => !nodes.any((n) => n.cefrLevel == lvl.cefrLevel))
        .toList();
    final wiredCodes = wiredLevels.map((l) => l.cefrLevel).toSet();
    final unassignedNodes = nodes
        .where((n) => n.cefrLevel == null || !wiredCodes.contains(n.cefrLevel))
        .toList();
    final wiredRangeLabel = wiredLevels.length <= 1
        ? (wiredLevels.isEmpty ? 'A1' : wiredLevels.first.cefrLevel)
        : '${wiredLevels.first.cefrLevel}–${wiredLevels.last.cefrLevel}';

    String entryLessonTitle(String cefr) {
      if (cefr == 'A2') {
        return isRu
            ? 'Транспорт и ориентирование'
            : 'Transport va yo‘l so‘rash';
      }
      if (cefr == 'B1') {
        return isRu
            ? 'Поездки и опыт: Present Perfect и Past Simple'
            : 'Sayohat logistikasi: Present Perfect vs Past Simple';
      }
      return isRu ? 'Первые английские слова' : 'Birinchi inglizcha so‘zlar';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EdTechReveal(
            index: 0,
            child: EdTechSectionHeader(
              pillText: isRu
                  ? 'Маршрут CEFR $wiredRangeLabel'
                  : 'CEFR $wiredRangeLabel marshruti',
              title: isRu
                  ? 'Пошаговый курс английского'
                  : 'Ingliz tili CEFR yo‘li',
              highlightWord: isRu ? 'английского' : 'CEFR',
              subtitle: isRu
                  ? cefrOfficialDisclaimerRu
                  : cefrOfficialDisclaimerUz,
            ),
          ),
          if (placementCefr != null && placementTarget != null) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(14),
              borderColor: AppColors.primary.withValues(alpha: 0.45),
              borderWidth: 1.5,
              backgroundColor: AppColors.primaryTint(
                context,
              ).withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppBadge(
                        text: isRu
                            ? 'Рекомендуемый старт • ${placementTarget.cefrLevel}'
                            : 'Tavsiya etilgan boshlanish • ${placementTarget.cefrLevel}',
                        variant: AppBadgeVariant.blue,
                      ),
                      if (placementScore != null)
                        AppBadge(
                          text: '$placementScore%',
                          variant: AppBadgeVariant.slate,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entryLessonTitle(placementTarget.cefrLevel),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRu
                        ? 'Результат диагностики открыл стартовый урок. Уровни B2–C2 ожидаются на следующем этапе (DEFERRED).'
                        : 'Diagnostika natijasi boshlang‘ich darsni tavsiya qildi. B2–C2 bosqichlari keyingi bosqichda (DEFERRED) qo‘shiladi.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: AppColors.secondaryTextOnTint(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    text: isRu ? 'Начать урок' : 'Darsni boshlash',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.primary,
                    onPressed: () async {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      await ref
                          .read(lessonSessionNotifierProvider.notifier)
                          .startLesson(
                            placementTarget.lessonId,
                            uiLocale: lang,
                          );
                      if (context.mounted) context.push('/lesson');
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Builder(
              builder: (context) {
                final isLargeText =
                    MediaQuery.textScalerOf(context).scale(1.0) > 1.35;
                final srsDetails = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRu
                          ? 'Карточки интервального повторения'
                          : 'Intervalli takrorlash (SRS)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRu
                          ? 'Закрепляйте ${_englishAllFlashcards.length} карточек $wiredRangeLabel по режиму SRS • ${unlockedFlashcards.length} открыто'
                          : '$wiredRangeLabel bosqichlaridagi ${_englishAllFlashcards.length} ta so‘z va iborani SRS asosida takrorlang • ${unlockedFlashcards.length} ta ochiq',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                );
                final srsButton = AppButton(
                  text: isRu ? 'Повторение SRS' : 'SRS Takrorlash',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _openSrsFlashcardsModal(
                    context,
                    lang,
                    unlockedFlashcards,
                  ),
                );
                if (isLargeText) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      srsDetails,
                      const SizedBox(height: 12),
                      srsButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: srsDetails),
                    const SizedBox(width: 10),
                    srsButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Active / Wired CEFR Levels (e.g., A1, A2, B1)
          for (final lvl in wiredLevels) ...[
            Builder(
              builder: (context) {
                final lvlNodes = nodes
                    .where((n) => n.cefrLevel == lvl.cefrLevel)
                    .toList();
                final lvlBaseNodes = lvlNodes
                    .where((n) => !n.isReinforcement)
                    .toList();
                final lvlCompleted = lvlBaseNodes
                    .where((n) => n.status == NodeStatus.completed)
                    .length;
                final hasUnlockedNode = lvlBaseNodes.any(
                  (n) => n.status != NodeStatus.locked,
                );
                final isLevelLocked =
                    !hasUnlockedNode &&
                    lvl.prerequisites.isNotEmpty &&
                    !lvl.prerequisites.every(
                      (pid) => nodeById[pid]?.status == NodeStatus.completed,
                    );
                final isPlacedLevel =
                    placementTarget?.cefrLevel == lvl.cefrLevel;
                final lvlModuleIds = lvl.modules.map((m) => m.id).toSet();
                final moduleGroups =
                    <(CefrModuleSkeleton, List<LearningPathNode>)>[];
                for (final mod in lvl.modules) {
                  final modNodes = lvlNodes
                      .where(
                        (n) =>
                            n.moduleId == mod.id &&
                            n.nodeKind != LearningNodeKind.levelAssessment,
                      )
                      .toList();
                  moduleGroups.add((mod, modNodes));
                }
                final exitAndOtherNodes = lvlNodes
                    .where(
                      (n) =>
                          n.nodeKind == LearningNodeKind.levelAssessment ||
                          !lvlModuleIds.contains(n.moduleId),
                    )
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      borderColor: isLevelLocked
                          ? AppColors.borderColor(context)
                          : isPlacedLevel
                          ? AppColors.primaryAccentOnSurface(context)
                          : AppColors.primary.withValues(alpha: 0.35),
                      borderWidth: isPlacedLevel ? 1.6 : 1.0,
                      onTap: isLevelLocked
                          ? () => _showLockedCefrSnackBar(
                              context,
                              lvl,
                              isRu,
                              nodeById: nodeById,
                            )
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppBadge(
                                text: lvl.cefrLevel,
                                variant: isLevelLocked
                                    ? AppBadgeVariant.slate
                                    : AppBadgeVariant.blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lvl.localizedTitle(lang),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimaryColor(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppBadge(
                                text: '$lvlCompleted / ${lvlBaseNodes.length}',
                                variant: isLevelLocked
                                    ? AppBadgeVariant.slate
                                    : AppBadgeVariant.emerald,
                              ),
                            ],
                          ),
                          if (isLevelLocked) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 14,
                                  color: AppColors.textMutedColor(context),
                                ),
                                AppBadge(
                                  text: isRu ? 'Заблокировано' : 'Bloklangan',
                                  variant: AppBadgeVariant.slate,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            lvl.localizedCanDos(lang).first,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    for (var mIdx = 0; mIdx < moduleGroups.length; mIdx++) ...[
                      Builder(
                        builder: (context) {
                          final mod = moduleGroups[mIdx].$1;
                          final modNodes = moduleGroups[mIdx].$2;
                          final modBaseNodes = modNodes
                              .where((n) => !n.isReinforcement)
                              .toList();
                          final doneCount = modBaseNodes
                              .where((n) => n.status == NodeStatus.completed)
                              .length;
                          final modProgress = modBaseNodes.isEmpty
                              ? 0.0
                              : doneCount / modBaseNodes.length;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppCard(
                                  padding: const EdgeInsets.all(14),
                                  backgroundColor: AppColors.subtleSurface(
                                    context,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              mod.localizedTitle(lang),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    AppColors.textPrimaryColor(
                                                      context,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          AppBadge(
                                            text:
                                                '$doneCount/${modBaseNodes.length}',
                                            variant:
                                                doneCount ==
                                                        modBaseNodes.length &&
                                                    modBaseNodes.isNotEmpty
                                                ? AppBadgeVariant.emerald
                                                : AppBadgeVariant.slate,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        mod.localizedCanDo(lang),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.textMutedColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: modProgress,
                                          minHeight: 5,
                                          backgroundColor:
                                              AppColors.borderColor(context),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.primaryAccentOnSurface(
                                                  context,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                for (var i = 0; i < modNodes.length; i++)
                                  _buildTimelineItem(
                                    context,
                                    modNodes[i],
                                    i == modNodes.length - 1,
                                    modNodes[i].order.round(),
                                    nodeById: nodeById,
                                    lang: lang,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    if (exitAndOtherNodes.isNotEmpty) ...[
                      for (var i = 0; i < exitAndOtherNodes.length; i++)
                        _buildTimelineItem(
                          context,
                          exitAndOtherNodes[i],
                          i == exitAndOtherNodes.length - 1,
                          exitAndOtherNodes[i].order.round(),
                          nodeById: nodeById,
                          lang: lang,
                        ),
                    ],
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ],

          if (unassignedNodes.isNotEmpty) ...[
            for (var i = 0; i < unassignedNodes.length; i++)
              _buildTimelineItem(
                context,
                unassignedNodes[i],
                i == unassignedNodes.length - 1,
                unassignedNodes[i].order.round(),
                nodeById: nodeById,
                lang: lang,
              ),
          ],

          if (plannedLevels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              isRu
                  ? 'Следующие уровни (${plannedLevels.first.cefrLevel}–${plannedLevels.last.cefrLevel})'
                  : 'Keyingi darajalar (${plannedLevels.first.cefrLevel}–${plannedLevels.last.cefrLevel})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 10),

            // Upcoming CEFR Levels (B2..C2 — DEFERRED)
            for (final lvl in plannedLevels)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () => _showLockedCefrSnackBar(
                    context,
                    lvl,
                    isRu,
                    isUpcoming: true,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      onExpansionChanged: (expanded) {
                        if (expanded) {
                          _showLockedCefrSnackBar(
                            context,
                            lvl,
                            isRu,
                            isUpcoming: true,
                          );
                        }
                      },
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      leading: Icon(
                        Icons.schedule_rounded,
                        color: AppColors.textMutedColor(context),
                      ),
                      title: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppBadge(
                            text: lvl.cefrLevel,
                            variant: AppBadgeVariant.slate,
                          ),
                          Text(
                            lvl.localizedTitle(lang),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                          AppBadge(
                            text: isRu
                                ? 'Скоро (DEFERRED)'
                                : 'Keyingi bosqich (DEFERRED)',
                            variant: AppBadgeVariant.slate,
                          ),
                        ],
                      ),
                      subtitle: Text(
                        isRu
                            ? '${lvl.modules.length} модуля • Скоро в следующих этапах'
                            : '${lvl.modules.length} modul • Keyingi bosqichda ochiladi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                      children: [
                        for (final mod in lvl.modules)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule_rounded, size: 16),
                            title: Text(
                              mod.localizedTitle(lang),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryColor(context),
                              ),
                            ),
                            subtitle: Text(
                              mod.localizedCanDo(lang),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppColors.textMutedColor(context),
                              ),
                            ),
                            onTap: () => _showLockedCefrSnackBar(
                              context,
                              lvl,
                              isRu,
                              isUpcoming: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    LearningPathNode node,
    bool isLast,
    int stepNum, {
    Map<String, LearningPathNode> nodeById = const {},
    String lang = 'uz',
  }) {
    final isRu = lang == 'ru';
    final isCompleted = node.status == NodeStatus.completed;
    final isReinforcement =
        node.status == NodeStatus.reinforcement || node.isReinforcement;
    final isLocked = node.status == NodeStatus.locked;
    final isAvailable =
        node.status == NodeStatus.available ||
        node.status == NodeStatus.inProgress ||
        node.status == NodeStatus.reinforcement;
    final target = node.targetLessonId;
    final isCheckpointNode =
        node.isCheckpoint ||
        node.nodeKind == LearningNodeKind.unitCheckpoint ||
        node.nodeKind == LearningNodeKind.levelAssessment;

    Color iconBg;
    IconData iconData;
    Color iconColor;

    if (isCompleted) {
      iconBg = const Color(0xFF047857);
      iconData = Icons.check_rounded;
      iconColor = Colors.white;
    } else if (isReinforcement) {
      iconBg = const Color(0xFFC2410C);
      iconData = Icons.warning_amber_rounded;
      iconColor = Colors.white;
    } else if (isLocked) {
      iconBg = AppColors.subtleSurface(context);
      iconData = Icons.lock_outline_rounded;
      iconColor = AppColors.textMutedColor(context);
    } else {
      iconBg = AppColors.primary;
      iconData = Icons.play_arrow_rounded;
      iconColor = Colors.white;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Node
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                boxShadow: isAvailable || isCompleted
                    ? [
                        BoxShadow(
                          color:
                              (isCompleted
                                      ? const Color(0xFF10B981)
                                      : AppColors.primary)
                                  .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(child: Icon(iconData, color: iconColor, size: 20)),
            ),
            if (!isLast)
              Container(
                width: 2.5,
                height: 80,
                color: isCompleted
                    ? const Color(0xFF10B981)
                    : isAvailable
                    ? AppColors.primaryAccentOnSurface(context)
                    : AppColors.borderColor(context),
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Node Content Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              onTap: isLocked
                  ? () => _showLockedNodeSnackBar(context, node, nodeById, lang)
                  : null,
              borderColor: isReinforcement
                  ? const Color(0xFFFFCCBC)
                  : isAvailable
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : isCompleted
                  ? const Color(0xFFA7F3D0)
                  : AppColors.borderColor(context),
              borderWidth: isAvailable ? 1.5 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          node.isOptional
                              ? (isRu ? 'Необязательно' : 'Ixtiyoriy')
                              : (isRu ? '$stepNum-й этап' : '$stepNum-Bosqich'),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMutedColor(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (isCheckpointNode)
                              AppBadge(
                                text: isRu ? 'Тест модуля' : 'Modul sinovi',
                                variant: AppBadgeVariant.amber,
                              ),
                            if (node.reviewDue)
                              AppBadge(
                                text: isRu
                                    ? 'Время повторить'
                                    : 'Takrorlash vaqti',
                                variant: AppBadgeVariant.amber,
                              )
                            else if (isReinforcement)
                              AppBadge(
                                text: isRu ? 'Закрепление' : 'Mustahkamlash',
                                variant: AppBadgeVariant.amber,
                              )
                            else if (isCompleted)
                              AppBadge(
                                text: node.serverMastery
                                    ? (isRu ? 'Освоено' : 'O‘zlashtirilgan')
                                    : (isRu
                                          ? 'Выполнено (100%)'
                                          : 'Bajarildi (100%)'),
                                variant: AppBadgeVariant.emerald,
                              )
                            else if (isAvailable) ...[
                              AppBadge(
                                text: isRu ? 'Активный урок' : 'Faol dars',
                                variant: AppBadgeVariant.blue,
                              ),
                              if (node.needsTargetedPractice)
                                AppBadge(
                                  text: isRu
                                      ? 'Целевая практика'
                                      : 'Maqsadli mashq',
                                  variant: AppBadgeVariant.amber,
                                ),
                            ] else
                              AppBadge(
                                text: isRu ? 'Заблокировано' : 'Bloklangan',
                                variant: AppBadgeVariant.slate,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    node.localizedTitle(lang),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isLocked
                          ? AppColors.textMutedColor(context)
                          : AppColors.textPrimaryColor(context),
                    ),
                  ),
                  if (node.localizedDescription(lang).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      node.localizedDescription(lang),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (node.localizedCanDo(lang) != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      node.localizedCanDo(lang)!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryAccentOnSurface(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: AppColors.textMutedColor(context),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isRu
                                    ? '${node.estimatedMinutes} мин'
                                    : '${node.estimatedMinutes} daqiqa',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textMutedColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isAvailable && target != null)
                          AppButton(
                            text: isReinforcement
                                ? (isRu ? 'Тренировка' : 'Mashq qilish')
                                : (isRu ? 'Начать' : 'Boshlash'),
                            size: AppButtonSize.small,
                            variant: AppButtonVariant.primary,
                            rightIcon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              await ref
                                  .read(lessonSessionNotifierProvider.notifier)
                                  .startLesson(target, uiLocale: lang);
                              if (context.mounted) context.push('/lesson');
                            },
                          )
                        else if (isCompleted && target != null)
                          AppButton(
                            text: isRu ? 'Повторить' : 'Takrorlash',
                            size: AppButtonSize.small,
                            variant: AppButtonVariant.outline,
                            onPressed: () async {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              await ref
                                  .read(lessonSessionNotifierProvider.notifier)
                                  .startLesson(target, uiLocale: lang);
                              if (context.mounted) context.push('/lesson');
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
