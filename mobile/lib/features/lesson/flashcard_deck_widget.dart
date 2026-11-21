import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/providers.dart';
import '../../core/audio/lesson_audio_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/lesson_media.dart';

enum FlashcardStudyMode {
  srsDue,
  enToNative,
  nativeToEn,
  audioToWord,
  imageToWord,
  randomPractice,
}

bool isFlashcardRecordDue(FlashcardSrsRecord? record, {DateTime? now}) {
  if (record == null ||
      record.status == 'new' ||
      record.status == 'need_practice' ||
      record.intervalBucket <= 0 ||
      record.nextReviewBucket == 'now' ||
      record.nextReviewBucket == 'session_next') {
    return true;
  }
  final current = (now ?? DateTime.now()).toUtc();
  if (record.nextReviewAt.trim().isNotEmpty) {
    final dueAt = DateTime.tryParse(record.nextReviewAt);
    if (dueAt != null) {
      return !dueAt.toUtc().isAfter(current);
    }
  }
  if (record.lastReviewedAt.trim().isEmpty) {
    return false;
  }
  final lastAt = DateTime.tryParse(record.lastReviewedAt);
  if (lastAt == null) {
    return false;
  }
  final bucketDays = record.intervalBucket <= 1
      ? 1
      : record.intervalBucket == 2
      ? 3
      : 7;
  final computedDue = lastAt.toUtc().add(Duration(days: bucketDays));
  return !computedDue.isAfter(current);
}

class FlashcardDeckWidget extends ConsumerStatefulWidget {
  final List<LessonFlashcard> flashcards;
  final List<LessonFlashcard> allCourseFlashcards;
  final String courseId;
  final bool standaloneSrsMode;
  final LessonAudioController? audioController;
  final String? uiLocale;
  final VoidCallback? onDeckReviewed;

  const FlashcardDeckWidget({
    super.key,
    required this.flashcards,
    this.allCourseFlashcards = const [],
    this.courseId = 'course_eng_01',
    this.standaloneSrsMode = false,
    this.audioController,
    this.uiLocale,
    this.onDeckReviewed,
  });

  @override
  ConsumerState<FlashcardDeckWidget> createState() =>
      _FlashcardDeckWidgetState();
}

class _FlashcardDeckWidgetState extends ConsumerState<FlashcardDeckWidget> {
  late List<LessonFlashcard> _queue;
  late FlashcardStudyMode _studyMode;
  final Set<String> _reviewedIds = <String>{};
  final Set<String> _sessionSrsReviewedIds = <String>{};
  final Random _random = Random();
  bool _isRevealed = false;
  String? _lastSyncedSrsSignature;
  bool _hasInitializedStandaloneFromProfile = false;

  LessonAudioController? _ownedAudioController;
  StreamSubscription<LessonAudioState>? _audioSub;
  LessonAudioState _audioState = const LessonAudioState();
  String? _loadedAudioSource;

  LessonAudioController? get _activeAudioController =>
      widget.audioController ?? _ownedAudioController;

  List<LessonFlashcard> get _basePool {
    if (widget.flashcards.isNotEmpty) return widget.flashcards;
    return widget.allCourseFlashcards;
  }

  bool _isDueInStandaloneSrs(
    LessonFlashcard card,
    Map<String, FlashcardSrsRecord> srsMap,
  ) {
    return isFlashcardRecordDue(srsMap[card.id]);
  }

  List<LessonFlashcard> _buildQueueForMode(
    FlashcardStudyMode mode, {
    Map<String, FlashcardSrsRecord> srsMap = const {},
  }) {
    final pool = widget.standaloneSrsMode && widget.allCourseFlashcards.isNotEmpty
        ? widget.allCourseFlashcards
        : _basePool;
    switch (mode) {
      case FlashcardStudyMode.srsDue:
        if (srsMap.isEmpty) {
          return List<LessonFlashcard>.from(pool);
        }
        final needPractice = pool
            .where((card) => srsMap[card.id]?.status == 'need_practice')
            .toList();
        final unreviewed = pool.where((card) => srsMap[card.id] == null).toList();
        if (widget.standaloneSrsMode) {
          final dueRemembered = pool
              .where(
                (card) =>
                    srsMap[card.id] != null &&
                    srsMap[card.id]?.status != 'need_practice' &&
                    _isDueInStandaloneSrs(card, srsMap),
              )
              .toList();
          return [...needPractice, ...unreviewed, ...dueRemembered];
        }
        final remembered = pool
            .where((card) => srsMap[card.id]?.status == 'remembered')
            .toList();
        return [...needPractice, ...unreviewed, ...remembered];
      case FlashcardStudyMode.randomPractice:
        final shuffled = List<LessonFlashcard>.from(
          widget.allCourseFlashcards.isNotEmpty ? widget.allCourseFlashcards : pool,
        );
        shuffled.shuffle(_random);
        return shuffled;
      case FlashcardStudyMode.enToNative:
      case FlashcardStudyMode.nativeToEn:
      case FlashcardStudyMode.audioToWord:
      case FlashcardStudyMode.imageToWord:
        return List<LessonFlashcard>.from(pool);
    }
  }

  @override
  void initState() {
    super.initState();
    _studyMode = widget.standaloneSrsMode
        ? FlashcardStudyMode.srsDue
        : FlashcardStudyMode.enToNative;
    _queue = _buildQueueForMode(_studyMode);
    _initAudioController();
  }

  String _srsSignature(Map<String, FlashcardSrsRecord> srsMap) {
    final entries = srsMap.entries
        .map(
          (e) =>
              '${e.key}:${e.value.status}:${e.value.reviewCount}:${e.value.intervalBucket}:${e.value.nextReviewAt}',
        )
        .toList()
      ..sort();
    return entries.join('|');
  }

  void _syncStandaloneSrsQueue(
    LearnerProfile? profile,
    Map<String, FlashcardSrsRecord> srsMap,
  ) {
    if (!widget.standaloneSrsMode || _studyMode != FlashcardStudyMode.srsDue) {
      return;
    }
    final pool = widget.allCourseFlashcards.isNotEmpty
        ? widget.allCourseFlashcards
        : _basePool;
    if (profile == null) {
      if (_lastSyncedSrsSignature == null) {
        _lastSyncedSrsSignature = '';
        _queue = pool
            .where((c) => !_sessionSrsReviewedIds.contains(c.id))
            .toList();
      }
      return;
    }
    final sig = _srsSignature(srsMap);
    if (!_hasInitializedStandaloneFromProfile) {
      _hasInitializedStandaloneFromProfile = true;
      _lastSyncedSrsSignature = sig;
      _queue = _buildQueueForMode(FlashcardStudyMode.srsDue, srsMap: srsMap)
          .where((c) => !_sessionSrsReviewedIds.contains(c.id))
          .toList();
      return;
    }
    if (_lastSyncedSrsSignature == sig) return;
    _lastSyncedSrsSignature = sig;

    final poolIds = pool.map((c) => c.id).toSet();
    final filtered = _queue
        .where(
          (c) =>
              poolIds.contains(c.id) &&
              !_sessionSrsReviewedIds.contains(c.id) &&
              _isDueInStandaloneSrs(c, srsMap),
        )
        .toList();
    final existingIds = filtered.map((c) => c.id).toSet();
    for (final c in pool) {
      if (!existingIds.contains(c.id) &&
          !_sessionSrsReviewedIds.contains(c.id) &&
          _isDueInStandaloneSrs(c, srsMap)) {
        filtered.add(c);
      }
    }
    _queue = filtered;
  }

  @override
  void didUpdateWidget(covariant FlashcardDeckWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioController != widget.audioController) {
      _rebindAudioController();
    }
    if (oldWidget.flashcards != widget.flashcards ||
        oldWidget.allCourseFlashcards != widget.allCourseFlashcards) {
      final profile = ref.read(learnerStateNotifierProvider).valueOrNull;
      final srsMap =
          profile?.flashcardSrsByCourse[widget.courseId] ??
          const <String, FlashcardSrsRecord>{};
      _hasInitializedStandaloneFromProfile = profile != null;
      _lastSyncedSrsSignature = profile != null ? _srsSignature(srsMap) : null;
      _queue = _buildQueueForMode(_studyMode, srsMap: srsMap);
      _reviewedIds.clear();
      _isRevealed = false;
      _resetCardAudioState();
    }
  }

  void _selectStudyMode(FlashcardStudyMode mode) {
    final profile = ref.read(learnerStateNotifierProvider).valueOrNull;
    final srsMap =
        profile?.flashcardSrsByCourse[widget.courseId] ??
        const <String, FlashcardSrsRecord>{};
    setState(() {
      _studyMode = mode;
      _hasInitializedStandaloneFromProfile = profile != null;
      _lastSyncedSrsSignature = profile != null ? _srsSignature(srsMap) : null;
      _queue = _buildQueueForMode(mode, srsMap: srsMap);
      _reviewedIds.clear();
      _isRevealed = false;
      _resetCardAudioState();
    });
  }

  void _rebindAudioController() {
    unawaited(_audioSub?.cancel());
    _audioSub = null;
    final owned = _ownedAudioController;
    _ownedAudioController = null;
    if (owned != null) {
      unawaited(owned.stop().catchError((_) {}).whenComplete(owned.dispose));
    }
    _loadedAudioSource = null;
    _initAudioController();
  }

  void _resetCardAudioState() {
    if (_audioState.isPlaying) {
      unawaited(_activeAudioController?.stop());
    }
    _loadedAudioSource = null;
    _audioState = const LessonAudioState();
  }

  void _initAudioController() {
    final controller =
        widget.audioController ?? ref.read(lessonAudioControllerFactoryProvider)();
    if (widget.audioController == null) {
      _ownedAudioController = controller;
    }
    _audioState = controller.state;
    _audioSub = controller.stateStream.listen((next) {
      if (!mounted) return;
      setState(() {
        _audioState = next;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_audioSub?.cancel());
    unawaited(_ownedAudioController?.dispose());
    super.dispose();
  }

  String _resolveLocale(BuildContext context) {
    final explicit = widget.uiLocale;
    if (explicit == 'ru' || explicit == 'uz') return explicit!;
    final code = Localizations.maybeLocaleOf(context)?.languageCode;
    if (code == 'ru' || code == 'uz') return code!;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return platformCode == 'ru' ? 'ru' : 'uz';
  }

  Future<void> _playCardAudio(LessonFlashcard card) async {
    final controller = _activeAudioController;
    final assetPath = LessonMedia.resolveAssetPath(card.audioSrc);
    if (controller == null || assetPath == null) return;
    if (_loadedAudioSource != assetPath ||
        _audioState.assetPath != assetPath ||
        _audioState.hasError) {
      _loadedAudioSource = assetPath;
      if (mounted && _audioState.hasError) {
        setState(() {
          _audioState = const LessonAudioState();
        });
      }
      await controller.loadAsset(assetPath);
      if (!mounted ||
          _activeAudioController != controller ||
          _queue.isEmpty ||
          _queue.first.id != card.id ||
          controller.state.hasError) {
        if (controller.state.hasError && _loadedAudioSource == assetPath) {
          _loadedAudioSource = null;
        }
        return;
      }
    }
    if (!mounted ||
        _activeAudioController != controller ||
        _queue.isEmpty ||
        _queue.first.id != card.id ||
        controller.state.hasError) {
      return;
    }
    await controller.replay();
  }

  void _reveal() {
    if (_isRevealed) return;
    setState(() {
      _isRevealed = true;
    });
  }

  void _markNeedPractice() {
    if (_queue.isEmpty) return;
    final current = _queue.first;
    unawaited(
      ref
          .read(learnerStateNotifierProvider.notifier)
          .recordFlashcardReview(
            courseId: widget.courseId,
            cardId: current.id,
            remembered: false,
          ),
    );
    setState(() {
      _queue.removeAt(0);
      _queue.add(current);
      _isRevealed = false;
      _resetCardAudioState();
    });
  }

  void _markRemembered() {
    if (_queue.isEmpty) return;
    final current = _queue.first;
    _sessionSrsReviewedIds.add(current.id);
    unawaited(
      ref
          .read(learnerStateNotifierProvider.notifier)
          .recordFlashcardReview(
            courseId: widget.courseId,
            cardId: current.id,
            remembered: true,
          ),
    );
    setState(() {
      _queue.removeAt(0);
      _reviewedIds.add(current.id);
      _isRevealed = false;
      _resetCardAudioState();
    });
    if (_queue.isEmpty) {
      widget.onDeckReviewed?.call();
    }
  }

  void _resetDeck() {
    final profile = ref.read(learnerStateNotifierProvider).valueOrNull;
    final srsMap =
        profile?.flashcardSrsByCourse[widget.courseId] ??
        const <String, FlashcardSrsRecord>{};
    setState(() {
      _sessionSrsReviewedIds.clear();
      _hasInitializedStandaloneFromProfile = false;
      _lastSyncedSrsSignature = null;
      _queue = _buildQueueForMode(_studyMode, srsMap: srsMap);
      _reviewedIds.clear();
      _isRevealed = false;
      _resetCardAudioState();
    });
  }

  String _modeLabel(FlashcardStudyMode mode, bool isRu) {
    switch (mode) {
      case FlashcardStudyMode.srsDue:
        return isRu ? 'Следующее повторение (SRS)' : 'Keyingi takrorlash (SRS)';
      case FlashcardStudyMode.enToNative:
        return isRu ? 'En → Ru' : 'En → Uz';
      case FlashcardStudyMode.nativeToEn:
        return isRu ? 'Ru → En' : 'Uz → En';
      case FlashcardStudyMode.audioToWord:
        return 'Audio → Word';
      case FlashcardStudyMode.imageToWord:
        return 'Image → Word';
      case FlashcardStudyMode.randomPractice:
        return 'Random';
    }
  }

  String _bucketLabel(String bucket, bool isRu) {
    switch (bucket) {
      case 'session_next':
        return isRu ? 'Сейчас ещё раз' : 'Shu darsda';
      case 'daily':
        return isRu ? '1 день' : '1 kun';
      case '3_days':
        return isRu ? '3 дня' : '3 kun';
      case 'mastered':
        return isRu ? 'Освоено' : 'O‘zlashtirildi';
      default:
        return bucket;
    }
  }

  Widget _buildModeSelector(bool isRu) {
    final modes = widget.standaloneSrsMode
        ? FlashcardStudyMode.values
        : FlashcardStudyMode.values
              .where((m) => m != FlashcardStudyMode.srsDue)
              .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: modes.map((mode) {
          final selected = _studyMode == mode;
          return ChoiceChip(
            label: Text(
              _modeLabel(mode, isRu),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            selected: selected,
            onSelected: (_) => _selectStudyMode(mode),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = _basePool;
    if (pool.isEmpty) {
      return const SizedBox.shrink();
    }

    final locale = _resolveLocale(context);
    final isRu = locale == 'ru';
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;
    final profile = ref.watch(learnerStateNotifierProvider).valueOrNull;
    final srsMap =
        profile?.flashcardSrsByCourse[widget.courseId] ??
        const <String, FlashcardSrsRecord>{};
    _syncStandaloneSrsQueue(profile, srsMap);
    final total = _queue.length + _reviewedIds.length;

    if (_queue.isEmpty) {
      return EdTechReveal(
        index: 1,
        child: AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeSelector(isRu),
              Row(
                children: [
                  Flexible(
                    child: AppBadge(
                      text: isRu
                          ? 'Карточки • ${pool.length} / ${pool.length}'
                          : 'Flashcard • ${pool.length} / ${pool.length}',
                      variant: AppBadgeVariant.emerald,
                      icon: Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.successTextOnTint(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isRu
                    ? 'Все карточки повторены!'
                    : 'Barcha kartochkalar ko‘rib chiqildi!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isRu
                    ? 'Все карточки для текущего интервала SRS повторены. Вы можете запустить случайную тренировку или перейти к уроку.'
                    : 'Joriy SRS navbatidagi barcha kartochkalar bajarildi. Tasodifiy mashqni boshlashingiz yoki keyingi qadamga o‘tishingiz mumkin.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppButton(
                    text: isRu
                        ? 'Случайная тренировка'
                        : 'Tasodifiy mashq',
                    variant: AppButtonVariant.primary,
                    onPressed: () =>
                        _selectStudyMode(FlashcardStudyMode.randomPractice),
                  ),
                  if (!widget.standaloneSrsMode)
                    AppButton(
                      text: isRu ? 'Повторить снова' : 'Qayta takrorlash',
                      variant: AppButtonVariant.outline,
                      onPressed: _resetDeck,
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final card = _queue.first;
    final resolvedImage = LessonMedia.resolveAssetPath(card.imageSrc);
    final resolvedAudio = LessonMedia.resolveAssetPath(card.audioSrc);
    final srsRecord = srsMap[card.id];
    final meaning = isRu && card.backRu.trim().isNotEmpty
        ? card.backRu
        : card.backUz;
    final exampleTranslation = isRu && card.exampleRu.trim().isNotEmpty
        ? card.exampleRu
        : card.exampleUz;
    final isNativePrompt = _studyMode == FlashcardStudyMode.nativeToEn;
    final isAudioPrompt = _studyMode == FlashcardStudyMode.audioToWord;
    final isImagePrompt = _studyMode == FlashcardStudyMode.imageToWord;
    final hideFrontTextBeforeReveal = isAudioPrompt || isImagePrompt;
    final promptText = isNativePrompt
        ? meaning
        : hideFrontTextBeforeReveal
        ? (isAudioPrompt
              ? (isRu
                    ? 'Прослушайте и вспомните слово'
                    : 'Audioni tinglab so‘zni toping')
              : (isRu
                    ? 'Посмотрите на картинку и вспомните слово'
                    : 'Rasmga qarab so‘zni toping'))
        : card.front;
    final answerHeading = isNativePrompt
        ? card.front
        : hideFrontTextBeforeReveal
        ? '${card.front} — $meaning'
        : meaning;
    final altText = card.localizedAlt(locale) ?? card.front;

    return EdTechReveal(
      index: 1,
      child: AppCard(
        padding: const EdgeInsets.all(18),
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
                      ? 'Карточки • ${_reviewedIds.length}/$total'
                      : 'Flashcard • ${_reviewedIds.length}/$total',
                  variant: AppBadgeVariant.blue,
                ),
                if (card.cefrLevel != null && card.cefrLevel!.isNotEmpty)
                  AppBadge(
                    text: card.cefrLevel!,
                    variant: AppBadgeVariant.teal,
                  ),
                if (srsRecord != null)
                  AppBadge(
                    text: isRu
                        ? 'Повт.: ${srsRecord.reviewCount} • ${_bucketLabel(srsRecord.nextReviewBucket, true)}'
                        : 'Takrorlash: ${srsRecord.reviewCount} • ${_bucketLabel(srsRecord.nextReviewBucket, false)}',
                    variant: srsRecord.status == 'remembered'
                        ? AppBadgeVariant.emerald
                        : AppBadgeVariant.amber,
                  ),
                if (card.partOfSpeech != null && card.partOfSpeech!.isNotEmpty)
                  AppBadge(
                    text: card.partOfSpeech!,
                    variant: AppBadgeVariant.slate,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            if (resolvedImage != null) ...[
              Semantics(
                image: true,
                label: altText,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Image.asset(
                      resolvedImage,
                      fit: BoxFit.cover,
                      semanticLabel: altText,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.subtleSurface(context),
                        padding: const EdgeInsets.all(12),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textMutedColor(context),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              altText,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMutedColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else if (isImagePrompt) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.subtleSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textMutedColor(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      altText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Front recall prompt + audio button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    promptText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                ),
                if (resolvedAudio != null) ...[
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: isRu
                        ? 'Прослушать произношение'
                        : 'Talaffuzni tinglash',
                    child: IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: AppColors.primaryTint(context),
                      ),
                      tooltip: isRu
                          ? 'Прослушать произношение'
                          : 'Talaffuzni tinglash',
                      onPressed: () => _playCardAudio(card),
                      icon: Icon(
                        Icons.volume_up_rounded,
                        color: AppColors.primaryAccentOnSurface(context),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if (_audioState.hasError) ...[
              const SizedBox(height: 6),
              Text(
                _audioState.localizedErrorMessage(locale) ??
                    (isRu
                        ? 'Аудио недоступно.'
                        : 'Talaffuz audiosini ijro etib bo‘lmadi.'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 14),

            if (!_isRevealed)
              AppButton(
                text: isRu ? 'Показать ответ' : 'Javobni ko‘rish',
                isFullWidth: true,
                leftIcon: const Icon(
                  Icons.visibility_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: _reveal,
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.subtleSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      answerHeading,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    if ((card.ipa != null && card.ipa!.trim().isNotEmpty) ||
                        (card.ipaAmE != null &&
                            card.ipaAmE!.trim().isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (card.ipa != null && card.ipa!.trim().isNotEmpty)
                            AppBadge(
                              text: card.ipa!,
                              variant: AppBadgeVariant.slate,
                            ),
                          if (card.ipaAmE != null &&
                              card.ipaAmE!.trim().isNotEmpty &&
                              card.ipaAmE!.trim() != card.ipa?.trim())
                            AppBadge(
                              text: card.ipaAmE!,
                              variant: AppBadgeVariant.slate,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      card.example,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryAccentOnSurface(context),
                      ),
                    ),
                    if (exampleTranslation.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        exampleTranslation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (isLargeText)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      text: isRu ? 'Повторить ещё' : 'Yana mashq qilaman',
                      variant: AppButtonVariant.outline,
                      isFullWidth: true,
                      onPressed: _markNeedPractice,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      text: isRu ? 'Запомнил(а)' : 'Eslab qoldim',
                      variant: AppButtonVariant.secondary,
                      isFullWidth: true,
                      onPressed: _markRemembered,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: isRu ? 'Повторить ещё' : 'Yana mashq qilaman',
                        variant: AppButtonVariant.outline,
                        onPressed: _markNeedPractice,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        text: isRu ? 'Запомнил(а)' : 'Eslab qoldim',
                        variant: AppButtonVariant.secondary,
                        onPressed: _markRemembered,
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 12),
            _buildModeSelector(isRu),
          ],
        ),
      ),
    );
  }
}
