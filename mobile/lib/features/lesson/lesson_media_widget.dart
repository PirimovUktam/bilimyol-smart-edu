import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/providers.dart';
import '../../core/audio/lesson_audio_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/edtech_reveal.dart';
import '../../domain/entities/lesson_media.dart';

class LessonMediaWidget extends ConsumerStatefulWidget {
  final LessonMedia media;
  final String? uiLocale;
  final bool initiallyExpandTranscript;

  const LessonMediaWidget({
    super.key,
    required this.media,
    this.uiLocale,
    this.initiallyExpandTranscript = false,
  });

  @override
  ConsumerState<LessonMediaWidget> createState() => _LessonMediaWidgetState();
}

class _LessonMediaWidgetState extends ConsumerState<LessonMediaWidget> {
  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5];

  LessonAudioController? _controller;
  StreamSubscription<LessonAudioState>? _subscription;
  LessonAudioState _audioState = const LessonAudioState();
  late bool _transcriptExpanded;

  @override
  void initState() {
    super.initState();
    _transcriptExpanded = widget.initiallyExpandTranscript;
    _initAudioIfNeeded();
  }

  @override
  void didUpdateWidget(covariant LessonMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mediaChanged =
        oldWidget.media.id != widget.media.id ||
        oldWidget.media.source != widget.media.source ||
        oldWidget.media.kind != widget.media.kind;
    if (mediaChanged) {
      _transcriptExpanded = widget.initiallyExpandTranscript;
      if (widget.media.kind != LessonMediaKind.audio) {
        _disposeAudioController();
      } else {
        _loadCurrentMedia();
      }
    } else if (widget.media.kind != LessonMediaKind.audio &&
        _controller != null) {
      _disposeAudioController();
    }
  }

  void _disposeAudioController() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    final controller = _controller;
    _controller = null;
    _audioState = const LessonAudioState();
    if (controller != null) {
      unawaited(
        controller.stop().catchError((_) {}).whenComplete(controller.dispose),
      );
    }
  }

  void _initAudioIfNeeded() {
    if (widget.media.kind != LessonMediaKind.audio) return;
    final controller = ref.read(lessonAudioControllerFactoryProvider)();
    _controller = controller;
    _audioState = controller.state;
    _subscription = controller.stateStream.listen((nextState) {
      if (!mounted) return;
      setState(() {
        _audioState = nextState;
      });
    });
    _loadCurrentMedia();
  }

  Future<void> _loadCurrentMedia() async {
    if (widget.media.kind != LessonMediaKind.audio || !widget.media.isApproved) {
      return;
    }
    var controller = _controller;
    if (controller == null) {
      _initAudioIfNeeded();
      return;
    }
    final assetPath = widget.media.resolvedSourceAssetPath;
    if (assetPath == null) {
      setState(() {
        _audioState = const LessonAudioState(
          status: LessonAudioStatus.error,
          errorMessage: 'Media manzili notöğri.',
          errorCode: LessonAudioErrorCode.invalidSource,
        );
      });
      return;
    }
    final fallbackDuration = widget.media.durationSeconds != null
        ? Duration(milliseconds: (widget.media.durationSeconds! * 1000).round())
        : null;
    await controller.loadAsset(assetPath, fallbackDuration: fallbackDuration);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_controller?.dispose());
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

  String _formatDuration(Duration? d) {
    if (d == null || d.isNegative) return '0:00';
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) return;
    if (_audioState.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.replay();
  }

  Future<void> _cycleSpeed() async {
    final controller = _controller;
    if (controller == null) return;
    final currentIndex = _speedOptions.indexWhere(
      (s) => (s - _audioState.speed).abs() < 0.01,
    );
    final nextSpeed =
        _speedOptions[(currentIndex + 1) % _speedOptions.length];
    await controller.setSpeed(nextSpeed);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.media.isApproved) {
      return const SizedBox.shrink();
    }
    final locale = _resolveLocale(context);
    final isRu = locale == 'ru';
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;
    final imagePath = widget.media.kind == LessonMediaKind.image
        ? widget.media.resolvedSourceAssetPath
        : widget.media.resolvedPosterAssetPath;
    final imageAlt =
        widget.media.localizedPosterAlt(locale) ??
        widget.media.localizedTitle(locale);

    final fallbackDuration = widget.media.durationSeconds != null
        ? Duration(milliseconds: (widget.media.durationSeconds! * 1000).round())
        : Duration.zero;
    final totalDuration =
        (_audioState.duration != null && _audioState.duration! > Duration.zero)
        ? _audioState.duration!
        : fallbackDuration;
    final totalMs = totalDuration.inMilliseconds;
    final posMs = totalMs > 0
        ? _audioState.position.inMilliseconds.clamp(0, totalMs)
        : 0;

    return EdTechReveal(
      index: 1,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badges + title + duration
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppBadge(
                        text: widget.media.languageDisplayLabel,
                        variant: AppBadgeVariant.blue,
                        icon: Icon(
                          Icons.translate_rounded,
                          size: 13,
                          color: AppColors.isDark(context)
                              ? const Color(0xFFC7D2FE)
                              : AppColors.primary,
                        ),
                      ),
                      AppBadge(
                        text: widget.media.kind == LessonMediaKind.image
                            ? (isRu ? 'Иллюстрация' : 'Rasm')
                            : (isRu ? 'Аудио' : 'Audio'),
                        variant: AppBadgeVariant.teal,
                      ),
                    ],
                  ),
                ),
                if (widget.media.kind == LessonMediaKind.audio &&
                    totalDuration > Duration.zero) ...[
                  const SizedBox(width: 8),
                  AppBadge(
                    text: _formatDuration(totalDuration),
                    variant: AppBadgeVariant.slate,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.media.localizedTitle(locale),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryColor(context),
              ),
            ),

            // Illustration / Poster image
            if (imagePath != null) ...[
              const SizedBox(height: 12),
              Semantics(
                image: true,
                label: imageAlt,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.asset(
                      imagePath,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: imageAlt,
                      errorBuilder: (context, _, _) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.subtleSurface(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.borderColor(context),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 32,
                                color: AppColors.textMutedColor(context),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                imageAlt,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMutedColor(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],

            // Audio transport controls
            if (widget.media.kind == LessonMediaKind.audio) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.subtleSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: Builder(
                  builder: (context) {
                    final playButton = Semantics(
                      button: true,
                      label: _audioState.isPlaying
                          ? (isRu ? 'Пауза' : 'Pauza')
                          : (isRu ? 'Слушать' : 'Tinglaş'),
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                        ),
                        tooltip: _audioState.isPlaying
                            ? (isRu ? 'Пауза' : 'Pauza')
                            : (isRu ? 'Слушать' : 'Tinglaş'),
                        onPressed: _audioState.isLoading
                            ? null
                            : _togglePlayPause,
                        icon: _audioState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _audioState.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 26,
                              ),
                      ),
                    );
                    final replayButton = Semantics(
                      button: true,
                      label: isRu ? 'Повторить' : 'Qayta tinglaş',
                      child: IconButton.outlined(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          side: BorderSide(
                            color: AppColors.borderColor(context),
                          ),
                        ),
                        tooltip: isRu ? 'Повторить' : 'Qayta tinglaş',
                        onPressed: _audioState.isLoading ? null : _replay,
                        icon: Icon(
                          Icons.replay_rounded,
                          color: AppColors.primaryAccentOnSurface(context),
                        ),
                      ),
                    );
                    final sliderControl = SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: posMs.toDouble(),
                        min: 0,
                        max: (totalMs > 0 ? totalMs : 1).toDouble(),
                        activeColor: AppColors.primaryAccentOnSurface(context),
                        inactiveColor: AppColors.borderColor(context),
                        onChanged: totalMs > 0
                            ? (value) => _controller?.seek(
                                Duration(milliseconds: value.round()),
                              )
                            : null,
                      ),
                    );
                    final timestampLabel = Text(
                      '${_formatDuration(_audioState.position)} / ${_formatDuration(totalDuration)}',
                      maxLines: isLargeText ? null : 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMutedColor(context),
                      ),
                    );
                    final speedButton = Semantics(
                      button: true,
                      label: isRu ? 'Скорость воспроизведения' : 'Tezlik',
                      child: InkWell(
                        onTap: _cycleSpeed,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.borderColor(context),
                              ),
                            ),
                            child: Text(
                              '${_audioState.speed}x',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    final errorIcon = Icon(
                      Icons.volume_off_rounded,
                      size: 18,
                      color: AppColors.errorTextOnTint(context),
                    );
                    final errorText = Text(
                      _audioState.localizedErrorMessage(locale) ??
                          (isRu
                              ? 'Не удалось воспроизвести аудио. Откройте текст ниже.'
                              : 'Audioni ijro etib bölmadi. Pastdagi matnli bayondan foydalaning.'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorTextOnTint(context),
                      ),
                    );
                    final retryButton = TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _loadCurrentMedia,
                      child: Text(
                        isRu ? 'Повторить' : 'Qayta uriniş',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.isDark(context)
                              ? const Color(0xFFE0E7FF)
                              : AppColors.primary,
                        ),
                      ),
                    );

                    return Column(
                      children: [
                        if (isLargeText) ...[
                          Row(
                            children: [
                              playButton,
                              const SizedBox(width: 8),
                              replayButton,
                              const Spacer(),
                              speedButton,
                            ],
                          ),
                          const SizedBox(height: 6),
                          sliderControl,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: timestampLabel,
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              playButton,
                              const SizedBox(width: 8),
                              replayButton,
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    sliderControl,
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: timestampLabel,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              speedButton,
                            ],
                          ),
                        if (_audioState.hasError) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorTint(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.35),
                              ),
                            ),
                            child: isLargeText
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          errorIcon,
                                          const SizedBox(width: 8),
                                          Expanded(child: errorText),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: retryButton,
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      errorIcon,
                                      const SizedBox(width: 8),
                                      Expanded(child: errorText),
                                      retryButton,
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],

            // Toggleable speaker-formatted transcript
            if ((widget.media.transcript ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Semantics(
                button: true,
                toggled: _transcriptExpanded,
                child: InkWell(
                  onTap: () => setState(
                    () => _transcriptExpanded = !_transcriptExpanded,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.subtleSurface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.borderColor(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.subtitles_outlined,
                            size: 18,
                            color: AppColors.primaryAccentOnSurface(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isRu ? 'Текст' : 'Matnli bayon',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                          ),
                          Icon(
                            _transcriptExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_transcriptExpanded) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor(context)),
                  ),
                  child: _SpeakerTranscriptBody(
                    transcript: widget.media.transcript!,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeakerTranscriptBody extends StatelessWidget {
  final String transcript;

  const _SpeakerTranscriptBody({required this.transcript});

  static final RegExp _speakerLineRegex = RegExp(
    r'^([^:\n]{1,32}):\s*(.+)$',
  );

  @override
  Widget build(BuildContext context) {
    final lines = transcript
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildLine(context, lines[i]),
        ],
      ],
    );
  }

  Widget _buildLine(BuildContext context, String line) {
    final match = _speakerLineRegex.firstMatch(line);
    if (match == null) {
      return Text(
        line,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          height: 1.45,
          color: AppColors.textPrimaryColor(context),
        ),
      );
    }
    final speaker = match.group(1)!;
    final utterance = match.group(2)!;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$speaker: ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryAccentOnSurface(context),
            ),
          ),
          TextSpan(
            text: utterance,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
