import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';

class AudioSimWaveWidget extends StatefulWidget {
  final String transcript;
  final String speakerName;

  const AudioSimWaveWidget({
    super.key,
    required this.transcript,
    required this.speakerName,
  });

  @override
  State<AudioSimWaveWidget> createState() => _AudioSimWaveWidgetState();
}

class _AudioSimWaveWidgetState extends State<AudioSimWaveWidget> {
  bool _isPlaying = false;
  double _progress = 0.0;
  Timer? _timer;

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);

    if (_isPlaying) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _progress += 0.02;
          if (_progress >= 1.0) {
            _progress = 0.0;
            _isPlaying = false;
            _timer?.cancel();
          }
        });
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static AppStrings _resolveStrings(BuildContext context) {
    final registered = Localizations.of<AppStrings>(context, AppStrings);
    if (registered != null) return registered;
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    return isRu ? AppStrings.ru : AppStrings.uz;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: c.pathSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.mic_rounded, color: c.path, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.speakerName,
                      style: AppTypography.ui(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      s.audioPlayerLabel,
                      style: AppTypography.ui(
                        fontSize: 11.5,
                        color: c.slatefine,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: s.audioPlayerLabel,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                style: IconButton.styleFrom(
                  backgroundColor: c.path,
                  foregroundColor: c.isDark ? c.canvas : Colors.white,
                ),
                onPressed: _togglePlay,
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: c.isDark ? c.canvas : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Simulated Audio Waveform Bars (responsive across widths)
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(24, (idx) {
                final barProgress = idx / 24;
                final isPassed = barProgress <= _progress;
                const heights = [
                  12.0,
                  24.0,
                  32.0,
                  16.0,
                  28.0,
                  40.0,
                  20.0,
                  30.0,
                  14.0,
                  36.0,
                  22.0,
                  18.0,
                ];
                final h = heights[idx % heights.length];
                final targetH = (_isPlaying && !disableAnimations)
                    ? (h * (0.6 + 0.4 * (idx % 3))).clamp(10.0, 46.0)
                    : h * 0.7;

                return Flexible(
                  child: AnimatedContainer(
                    duration: disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    width: 5,
                    height: targetH,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isPassed ? c.path : c.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Transcript Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.subtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.hairline),
            ),
            child: Text(
              widget.transcript,
              style: AppTypography.ui(
                fontSize: 12.5,
                color: c.graphite,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
