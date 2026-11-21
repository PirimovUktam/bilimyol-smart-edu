import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';

class MathFunctionGraphWidget extends StatefulWidget {
  const MathFunctionGraphWidget({super.key});

  @override
  State<MathFunctionGraphWidget> createState() =>
      _MathFunctionGraphWidgetState();
}

class _MathFunctionGraphWidgetState extends State<MathFunctionGraphWidget> {
  double _currentX = 2.0;

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
    final yValue = 2 * _currentX + 3;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return AppCard(
      padding: const EdgeInsets.all(16),
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
                  s.interactiveGraphTitle,
                  style: AppTypography.ui(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.brandSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'f(${_currentX.toStringAsFixed(1)}) = ${yValue.toStringAsFixed(1)}',
                    style: AppTypography.mono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: c.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Custom Painted Coordinate System Canvas
          SizedBox(
            height: 170,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _GraphPainter(
                  currentX: _currentX,
                  currentY: yValue,
                  c: c,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Interactive X slider (responsive at 360dp @ 2.0x)
          LayoutBuilder(
            builder: (context, constraints) {
              final label = Text(
                'x = ${_currentX.toStringAsFixed(1)}',
                style: AppTypography.mono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.graphite,
                ),
              );
              final slider = Slider(
                value: _currentX,
                min: 0,
                max: 4,
                divisions: 8,
                activeColor: c.brand,
                inactiveColor: c.hairline,
                onChanged: (val) => setState(() => _currentX = val),
              );

              if (textScale >= 1.5 || constraints.maxWidth < 260) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    slider,
                  ],
                );
              }

              return Row(
                children: [
                  Flexible(flex: 0, child: label),
                  const SizedBox(width: 8),
                  Expanded(child: slider),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final double currentX;
  final double currentY;
  final AppSemanticColors c;

  _GraphPainter({
    required this.currentX,
    required this.currentY,
    required this.c,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = c.subtle;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = c.hairline
      ..strokeWidth = 1.0;

    const double originX = 32;
    final double originY = size.height - 22;
    final double scaleX = ((size.width - originX - 20) / 5.0).clamp(24.0, 56.0);
    final double scaleY = ((originY - 16) / 12.0).clamp(8.0, 12.0);

    // Draw grid lines
    for (double x = 0; x <= 5; x += 1) {
      final px = originX + x * scaleX;
      canvas.drawLine(Offset(px, 10), Offset(px, size.height - 10), gridPaint);
    }
    for (double y = 0; y <= 12; y += 3) {
      final py = originY - y * scaleY;
      canvas.drawLine(Offset(16, py), Offset(size.width - 16, py), gridPaint);
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = c.slatefine
      ..strokeWidth = 1.5;

    // X Axis
    canvas.drawLine(
      Offset(16, originY),
      Offset(size.width - 14, originY),
      axisPaint,
    );
    // Y Axis
    canvas.drawLine(
      Offset(originX, size.height - 12),
      Offset(originX, 12),
      axisPaint,
    );

    // Draw function line y = 2x + 3
    final linePaint = Paint()
      ..color = c.brand
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (double x = 0; x <= 4.5; x += 0.2) {
      final y = 2 * x + 3;
      final px = originX + x * scaleX;
      final py = originY - y * scaleY;
      if (x == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw current active point (originY - currentY * scaleY)
    final activePx = originX + currentX * scaleX;
    final activePy = originY - currentY * scaleY;

    final dotHaloPaint = Paint()..color = c.error.withValues(alpha: 0.2);
    canvas.drawCircle(Offset(activePx, activePy), 11, dotHaloPaint);

    final dotPaint = Paint()..color = c.error;
    canvas.drawCircle(Offset(activePx, activePy), 6, dotPaint);

    final dotRingPaint = Paint()
      ..color = c.paper
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(activePx, activePy), 6, dotRingPaint);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.currentX != currentX ||
        oldDelegate.currentY != currentY ||
        oldDelegate.c != c;
  }
}
