import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';

class MathFunctionGraphWidget extends StatefulWidget {
  const MathFunctionGraphWidget({super.key});

  @override
  State<MathFunctionGraphWidget> createState() => _MathFunctionGraphWidgetState();
}

class _MathFunctionGraphWidgetState extends State<MathFunctionGraphWidget> {
  double _currentX = 2.0;

  @override
  Widget build(BuildContext context) {
    final yValue = 2 * _currentX + 3;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Interaktiv Grafik: f(x) = 2x + 3',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'f(${_currentX.toStringAsFixed(1)}) = ${yValue.toStringAsFixed(1)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custom Painted Coordinate System Canvas
          SizedBox(
            height: 170,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _GraphPainter(currentX: _currentX, currentY: yValue),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Interactive X slider
          Row(
            children: [
              Text(
                'x = ${_currentX.toStringAsFixed(1)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _currentX,
                  min: 0,
                  max: 4,
                  divisions: 8,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _currentX = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final double currentX;
  final double currentY;

  _GraphPainter({required this.currentX, required this.currentY});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    const double originX = 40;
    final double originY = size.height - 25;
    const double scaleX = 50.0;
    const double scaleY = 11.0;

    // Draw grid lines
    for (double x = 0; x <= 5; x += 1) {
      final px = originX + x * scaleX;
      canvas.drawLine(Offset(px, 10), Offset(px, size.height - 10), gridPaint);
    }
    for (double y = 0; y <= 12; y += 3) {
      final py = originY - y * scaleY;
      canvas.drawLine(Offset(20, py), Offset(size.width - 20, py), gridPaint);
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1.5;

    // X Axis
    canvas.drawLine(Offset(20, originY), Offset(size.width - 15, originY), axisPaint);
    // Y Axis
    canvas.drawLine(Offset(originX, size.height - 15), Offset(originX, 15), axisPaint);

    // Draw function line y = 2x + 3
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (double x = 0; x <= 5; x += 0.2) {
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

    // Draw current active point
    final activePx = originX + currentX * scaleX;
    final activePy = originY + currentY * scaleY;

    final dotPaint = Paint()..color = AppColors.error;
    canvas.drawCircle(Offset(activePx, activePy), 6, dotPaint);

    final dotRingPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(activePx, activePy), 6, dotRingPaint);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.currentX != currentX || oldDelegate.currentY != currentY;
  }
}
