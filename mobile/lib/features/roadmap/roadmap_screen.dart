import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../core/widgets/edtech_section_header.dart';
import '../../core/widgets/friendly_error_state.dart';
import '../../data/datasources/english/a1_lessons_data.dart';
import '../../data/datasources/english/a2_lessons_data.dart';
import '../../data/datasources/english/b1_lessons_data.dart';
import '../../data/datasources/english/cefr_skeleton_data.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/learning_path_node.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import '../lesson/flashcard_deck_widget.dart';
import '../reinforcement/reinforcement_sheet.dart';

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
    if (Localizations.of<AppStrings>(context, AppStrings) case final strings?) {
      return strings.isRu ? 'ru' : 'uz';
    }
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
    AppSemanticColors c,
    String lang,
    List<LessonFlashcard> unlockedFlashcards,
  ) {
    final isRu = lang == 'ru';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.paper,
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
                        style: AppTypography.ui(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
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

  Future<void> _openStandaloneReinforcementSheet(
    BuildContext context,
    LearningPathNode node,
    List<LearningPathNode> allNodes,
    String lang,
  ) async {
    final isRu = lang == 'ru';
    try {
      final baseNode = resolveRoadmapPracticeBaseNode(allNodes, node);
      final targetLessonId = node.targetLessonId ?? baseNode?.targetLessonId;
      final lessonRepo = ref.read(lessonRepositoryProvider);
      final lesson =
          (targetLessonId != null && targetLessonId.trim().isNotEmpty)
          ? await lessonRepo.getLessonById(targetLessonId)
          : await lessonRepo.getLessonByCourseAndSkill(
              node.courseId,
              node.skillId,
            );
      if (!context.mounted) return;
      if (lesson == null || lesson.courseId != node.courseId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRu
                  ? 'Упражнение закрепления не найдено.'
                  : 'Mustahkamlash mashqi topilmadi.',
            ),
          ),
        );
        return;
      }

      final q = lesson.reinforcementExercise;
      final resolvedReinfNodeId = node.isReinforcement
          ? node.id
          : (baseNode != null ? 'reinf_${baseNode.id}' : 'reinf_${node.id}');
      final notifier = ref.read(roadmapStateNotifierProvider.notifier);

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => ReinforcementSheet(
          question: q,
          completionActionLabel:
              isRu ? 'Вернуться к плану' : 'Yo‘l xaritasiga qaytish',
          onGoToDashboard: () => Navigator.of(sheetCtx).pop(),
          onSubmit: (selectedIndex) => notifier.submitStandaloneReinforcement(
            courseId: q.courseId,
            skillId: q.skillId,
            reinforcementNodeId: resolvedReinfNodeId,
            question: q,
            selectedIndex: selectedIndex,
          ),
          onSubmitRichWithRubric: ({
            required int selectedIndex,
            String? selectedText,
            Map<String, String>? matchedPairs,
            List<String>? orderedTokens,
            List<String>? checkedCriteriaIds,
          }) => notifier.submitStandaloneReinforcement(
            courseId: q.courseId,
            skillId: q.skillId,
            reinforcementNodeId: resolvedReinfNodeId,
            question: q,
            selectedIndex: selectedIndex,
            selectedText: selectedText,
            matchedPairs: matchedPairs,
            orderedTokens: orderedTokens,
            checkedCriteriaIds: checkedCriteriaIds,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Не удалось загрузить упражнение.'
                : 'Mashqni yuklab bo‘lmadi.',
          ),
        ),
      );
    }
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
    final c = AppSemanticColors.of(context);
    final lang = _resolveLang(context);
    final isRu = lang == 'ru';
    final s =
        Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings.forCode(lang);
    final courseState = ref.watch(courseStateNotifierProvider);
    final activeCourse = courseState.activeCourse;
    final roadmapAsync = ref.watch(roadmapStateNotifierProvider);
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 144 : null,
        title: Text(
          isRu ? 'Мой учебный путь' : s.myRoadmapTitle,
          softWrap: true,
          maxLines: isLargeText ? null : 1,
          overflow: isLargeText
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded),
            tooltip: s.knowledgeMapTitle,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => context.go('/knowledge-map'),
          ),
        ],
      ),
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // Top Toggle Switch: [Bilim xaritasi | Ta’lim yo‘li]
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.paper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.hairline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: false,
                            child: InkWell(
                              onTap: () => context.go('/knowledge-map'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  s.knowledgeMapTitle,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.ui(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.graphite,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: true,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.ctaPrimary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                s.navRoadmap,
                                textAlign: TextAlign.center,
                                style: AppTypography.ui(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
                  child: activeCourse == null &&
                          !courseState.isLoading &&
                          roadmapAsync.valueOrNull == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: AppCard(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.alt_route_rounded,
                                    size: 38,
                                    color: c.brand,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    s.chooseCoursePrompt,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.ui(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  AppButton(
                                    text: s.chooseSubject,
                                    onPressed: () => context.go('/courses'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : roadmapAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => FriendlyErrorState(
                            message: s.roadmapLoadError,
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
                            final allRoadmapNodes = roadmap.nodes;
                            final nodes = allRoadmapNodes
                                .where(
                                  (n) => !(n.isReinforcement &&
                                      n.status == NodeStatus.completed),
                                )
                                .toList();
                            if (nodes.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: AppCard(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.route_outlined,
                                          size: 36,
                                          color: c.slatefine,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          s.roadmapEmptyTitle,
                                          textAlign: TextAlign.center,
                                          style: AppTypography.ui(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: c.graphite,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        AppButton(
                                          text: s.chooseSubject,
                                          variant: AppButtonVariant.outline,
                                          onPressed: () =>
                                              context.go('/courses'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (roadmap.courseId == 'course_eng_01') {
                              return _buildEnglishCefrRoadmap(
                                context,
                                c,
                                s,
                                nodes,
                                lang,
                              );
                            }

                            final nodeById = <String, LearningPathNode>{
                              for (final n in nodes) n.id: n,
                            };
                            final completedCount = nodes
                                .where((n) => n.status == NodeStatus.completed)
                                .length;
                            final totalCount = nodes.length;
                            final ratio =
                                totalCount > 0 ? completedCount / totalCount : 0.0;

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
                                      pillText: s.roadmapPill,
                                      title:
                                          '${s.roadmapHeading} ${s.roadmapHighlight}',
                                      highlightWord: s.roadmapHighlight,
                                      subtitle: s.roadmapSubtitle,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  AppCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                s.roadmapSummaryTitle,
                                                style: AppTypography.ui(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: c.ink,
                                                ),
                                              ),
                                              Text(
                                                s.roadmapStepsProgress(
                                                  completedCount,
                                                  totalCount,
                                                ),
                                                style: AppTypography.mono(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: c.brand,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            value: ratio,
                                            minHeight: 7,
                                            backgroundColor: c.subtle,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  ratio >= 1.0
                                                      ? c.success
                                                      : c.brand,
                                                ),
                                          ),
                                        ),
                                      ],
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
                                        c,
                                        s,
                                        node,
                                        isLast,
                                        index + 1,
                                        nodeById: nodeById,
                                        lang: lang,
                                      ),
                                    );
                                  }),
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
        ),
      ),
    );
  }

  Widget _buildEnglishCefrRoadmap(
    BuildContext context,
    AppSemanticColors c,
    AppStrings s,
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
              borderColor: c.brand.withValues(alpha: 0.45),
              borderWidth: 1.5,
              backgroundColor: Color.alphaBlend(c.brandSoft, c.paper),
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
                    style: AppTypography.ui(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRu
                        ? 'Результат диагностики открыл стартовый урок. Уровни B2–C2 ожидаются на следующем этапе (DEFERRED).'
                        : 'Diagnostika natijasi boshlang‘ich darsni tavsiya qildi. B2–C2 bosqichlari keyingi bosqichda (DEFERRED) qo‘shiladi.',
                    style: AppTypography.ui(
                      fontSize: 11.5,
                      color: c.graphite,
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
                      style: AppTypography.ui(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRu
                          ? 'Закрепляйте ${_englishAllFlashcards.length} карточек $wiredRangeLabel по режиму SRS • ${unlockedFlashcards.length} открыто'
                          : '$wiredRangeLabel bosqichlaridagi ${_englishAllFlashcards.length} ta so‘z va iborani SRS asosida takrorlang • ${unlockedFlashcards.length} ta ochiq',
                      style: AppTypography.ui(
                        fontSize: 11.5,
                        color: c.graphite,
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
                    c,
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
                          ? c.hairline
                          : isPlacedLevel
                              ? (c.isDark ? c.brandStrong : c.brand)
                              : c.brand.withValues(alpha: 0.35),
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
                                  style: AppTypography.ui(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: c.ink,
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
                                  color: c.slatefine,
                                ),
                                AppBadge(
                                  text: s.lockedNode,
                                  variant: AppBadgeVariant.slate,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            lvl.localizedCanDos(lang).first,
                            style: AppTypography.ui(
                              fontSize: 12,
                              color: c.graphite,
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
                                  backgroundColor: c.subtle,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              mod.localizedTitle(lang),
                                              style: AppTypography.ui(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: c.ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          AppBadge(
                                            text:
                                                '$doneCount/${modBaseNodes.length}',
                                            variant: doneCount ==
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
                                        style: AppTypography.ui(
                                          fontSize: 12,
                                          color: c.graphite,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: modProgress,
                                          minHeight: 5,
                                          backgroundColor: c.hairline,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                c.isDark
                                                    ? c.brandStrong
                                                    : c.brand,
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
                                    c,
                                    s,
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
                          c,
                          s,
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
                c,
                s,
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
              style: AppTypography.ui(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.ink,
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
                      childrenPadding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        14,
                      ),
                      leading: Icon(
                        Icons.schedule_rounded,
                        color: c.slatefine,
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
                            style: AppTypography.ui(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
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
                        style: AppTypography.ui(
                          fontSize: 11.5,
                          color: c.slatefine,
                        ),
                      ),
                      children: [
                        for (final mod in lvl.modules)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.schedule_rounded,
                              size: 16,
                            ),
                            title: Text(
                              mod.localizedTitle(lang),
                              style: AppTypography.ui(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.graphite,
                              ),
                            ),
                            subtitle: Text(
                              mod.localizedCanDo(lang),
                              style: AppTypography.ui(
                                fontSize: 11.5,
                                color: c.slatefine,
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
    AppSemanticColors c,
    AppStrings s,
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

    final Color iconBg;
    final IconData iconData;
    final Color iconColor;
    if (isCompleted) {
      iconBg = c.isDark ? c.success : c.successText;
      iconData = Icons.check_rounded;
      iconColor = c.isDark ? c.canvas : Colors.white;
    } else if (isReinforcement) {
      iconBg = c.isDark ? c.warning : c.warningText;
      iconData = Icons.warning_amber_rounded;
      iconColor = c.isDark ? c.canvas : Colors.white;
    } else if (isLocked) {
      iconBg = c.subtle;
      iconData = Icons.lock_outline_rounded;
      iconColor = c.slatefine;
    } else {
      iconBg = c.ctaPrimary;
      iconData = Icons.play_arrow_rounded;
      iconColor = Colors.white;
    }

    final connectorColor = isCompleted
        ? c.success
        : isAvailable
            ? c.brand
            : c.hairline;

    final statusBadge = node.reviewDue
        ? AppBadge(
            text: s.statusReviewDue,
            variant: AppBadgeVariant.amber,
            icon: Icon(Icons.schedule_rounded, size: 12, color: c.warningText),
          )
        : isReinforcement
            ? AppBadge(
                text: s.statusReinforcement,
                variant: AppBadgeVariant.amber,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 12,
                  color: c.warningText,
                ),
              )
            : isCompleted
                ? AppBadge(
                    text: node.serverMastery
                        ? s.statusMastered
                        : s.statusCompleted100,
                    variant: AppBadgeVariant.emerald,
                    icon: Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: c.successText,
                    ),
                  )
                : isAvailable
                    ? AppBadge(
                        text: s.statusActiveLesson,
                        variant: AppBadgeVariant.blue,
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          size: 12,
                          color: c.isDark ? c.brandStrong : c.brand,
                        ),
                      )
                    : AppBadge(
                        text: s.lockedNode,
                        variant: AppBadgeVariant.slate,
                        icon: Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: c.graphite,
                        ),
                      );

    final description = node.localizedDescription(lang);
    final canDo = node.localizedCanDo(lang);

    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 18.75,
            top: 40,
            bottom: 0,
            width: 2.5,
            child: ColoredBox(color: connectorColor),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 54, bottom: 16),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            onTap: isLocked
                ? () => _showLockedNodeSnackBar(context, node, nodeById, lang)
                : null,
            borderColor: isReinforcement
                ? c.warning.withValues(alpha: 0.48)
                : isAvailable
                    ? c.brand.withValues(alpha: 0.45)
                    : isCompleted
                        ? c.success.withValues(alpha: 0.42)
                        : c.hairline,
            borderWidth: isAvailable ? 1.5 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        node.isOptional
                            ? s.optionalTag
                            : s.stageNumLabel(stepNum),
                        style: AppTypography.mono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: c.slatefine,
                          letterSpacing: 0.3,
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
                          statusBadge,
                          if (isAvailable &&
                              !isReinforcement &&
                              node.isPlacementUnlocked)
                            AppBadge(
                              text: isRu
                                  ? 'Освоено • Диагностика'
                                  : 'O‘zlashtirilgan • Diagnostika',
                              variant: AppBadgeVariant.emerald,
                            ),
                          if (isAvailable &&
                              !isReinforcement &&
                              !node.reviewDue &&
                              node.needsTargetedPractice)
                            AppBadge(
                              text: isRu
                                  ? 'Целевая практика'
                                  : 'Maqsadli mashq',
                              variant: AppBadgeVariant.amber,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  node.localizedTitle(lang),
                  style: AppTypography.ui(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isLocked ? c.slatefine : c.ink,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTypography.ui(
                      fontSize: 12.5,
                      color: c.graphite,
                      height: 1.38,
                    ),
                  ),
                ],
                if (canDo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    canDo,
                    style: AppTypography.ui(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: c.isDark ? c.brandStrong : c.brand,
                    ),
                  ),
                ],
                if (isLocked && node.prerequisites.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: c.slatefine,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          s.statusPrerequisiteNeeded,
                          style: AppTypography.ui(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: c.slatefine,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: c.slatefine,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s.minutesDuration(node.estimatedMinutes),
                            style: AppTypography.mono(
                              fontSize: 11.5,
                              color: c.slatefine,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (isAvailable && (isReinforcement || target != null))
                        AppButton(
                          text: isReinforcement ? s.practiceNode : s.startNode,
                          size: AppButtonSize.small,
                          variant: AppButtonVariant.primary,
                          rightIcon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            if (node.isReinforcement) {
                              await _openStandaloneReinforcementSheet(
                                context,
                                node,
                                nodeById.values.toList(),
                                lang,
                              );
                              return;
                            }
                            await ref
                                .read(lessonSessionNotifierProvider.notifier)
                                .startLesson(target!, uiLocale: lang);
                            if (context.mounted) context.push('/lesson');
                          },
                        )
                      else if (isCompleted && target != null)
                        AppButton(
                          text: s.repeatNode,
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
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: isLocked ? Border.all(color: c.hairline) : null,
              boxShadow: isAvailable || isCompleted
                  ? [
                      BoxShadow(
                        color: (isCompleted ? c.success : c.ctaPrimary)
                            .withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(iconData, color: iconColor, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
