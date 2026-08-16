import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
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
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic_rounded, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.speakerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Audio simulyatsiya (Native player)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                ),
                onPressed: _togglePlay,
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Simulated Audio Waveform Bars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(24, (idx) {
              final barProgress = idx / 24;
              final isPassed = barProgress <= _progress;
              final heights = [12.0, 24.0, 32.0, 16.0, 28.0, 40.0, 20.0, 30.0, 14.0, 36.0, 22.0, 18.0];
              final h = heights[idx % heights.length];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 6,
                height: _isPlaying ? (h * (0.6 + 0.4 * (idx % 3))) : h * 0.7,
                decoration: BoxDecoration(
                  color: isPassed ? AppColors.secondary : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Transcript Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              widget.transcript,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.textSecondary,
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
