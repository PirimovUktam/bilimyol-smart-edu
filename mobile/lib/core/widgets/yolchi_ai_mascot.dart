import 'package:flutter/material.dart';

enum YolchiMood { happy, waving, explaining, celebrating, thinking }

class YolchiAIMascot extends StatelessWidget {
  final double size;
  final YolchiMood mood;

  const YolchiAIMascot({
    super.key,
    this.size = 56,
    this.mood = YolchiMood.happy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _YolchiPainter(mood: mood),
      ),
    );
  }
}

class _YolchiPainter extends CustomPainter {
  final YolchiMood mood;

  _YolchiPainter({required this.mood});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Hover jet glow
    final jetPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.8),
          const Color(0xFF6366F1).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.94), radius: w * 0.25));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.94), width: w * 0.4, height: h * 0.12), jetPaint);

    // Antenna
    final antennaPaint = Paint()
      ..color = const Color(0xFF818CF8)
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.22), Offset(w * 0.5, h * 0.08), antennaPaint);

    final tipPaint = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawCircle(Offset(w * 0.5, h * 0.07), w * 0.06, tipPaint);
    final tipCenterPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.5, h * 0.07), w * 0.03, tipCenterPaint);

    // Headset Pods
    final earPaint = Paint()..color = const Color(0xFF4F46E5);
    final earCyan = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.1, h * 0.24), const Radius.circular(4)),
      earPaint,
    );
    canvas.drawCircle(Offset(w * 0.13, h * 0.5), w * 0.03, earCyan);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.82, h * 0.38, w * 0.1, h * 0.24), const Radius.circular(4)),
      earPaint,
    );
    canvas.drawCircle(Offset(w * 0.87, h * 0.5), w * 0.03, earCyan);

    // Head Shell (White-Indigo gradient)
    final headPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(w * 0.15, h * 0.2, w * 0.7, h * 0.6))
      ..style = PaintingStyle.fill;
    final headBorder = Paint()
      ..color = const Color(0xFFA5B4FC)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final headRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.2, w * 0.68, h * 0.58),
      Radius.circular(w * 0.25),
    );
    canvas.drawRRect(headRRect, headPaint);
    canvas.drawRRect(headRRect, headBorder);

    // Visor Screen (Dark Navy/Slate gradient)
    final visorPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.24, h * 0.28, w * 0.52, h * 0.4))
      ..style = PaintingStyle.fill;

    final visorRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.28, w * 0.52, h * 0.4),
      Radius.circular(w * 0.16),
    );
    canvas.drawRRect(visorRRect, visorPaint);

    // Glowing Eyes & Mouth
    final eyePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;

    final blushPaint = Paint()..color = const Color(0xFFF43F5E).withValues(alpha: 0.6);

    if (mood == YolchiMood.happy || mood == YolchiMood.waving) {
      // Happy arcs
      final leftEyePath = Path()
        ..moveTo(w * 0.34, h * 0.49)
        ..quadraticBezierTo(w * 0.40, h * 0.41, w * 0.46, h * 0.49);
      final rightEyePath = Path()
        ..moveTo(w * 0.54, h * 0.49)
        ..quadraticBezierTo(w * 0.60, h * 0.41, w * 0.66, h * 0.49);
      canvas.drawPath(leftEyePath, eyePaint);
      canvas.drawPath(rightEyePath, eyePaint);

      // Blushes
      canvas.drawCircle(Offset(w * 0.32, h * 0.55), w * 0.03, blushPaint);
      canvas.drawCircle(Offset(w * 0.68, h * 0.55), w * 0.03, blushPaint);

      // Smile
      final smilePaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final smilePath = Path()
        ..moveTo(w * 0.46, h * 0.56)
        ..quadraticBezierTo(w * 0.5, h * 0.61, w * 0.54, h * 0.56);
      canvas.drawPath(smilePath, smilePaint);
    } else {
      // Rounded glowing dots
      final fillEye = Paint()..color = const Color(0xFF38BDF8);
      canvas.drawCircle(Offset(w * 0.4, h * 0.46), w * 0.05, fillEye);
      canvas.drawCircle(Offset(w * 0.6, h * 0.46), w * 0.05, fillEye);
      canvas.drawCircle(Offset(w * 0.41, h * 0.44), w * 0.02, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(w * 0.61, h * 0.44), w * 0.02, Paint()..color = Colors.white);

      final mouthPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.46, h * 0.57), Offset(w * 0.54, h * 0.57), mouthPaint);
    }

    // Floating body & core
    final bodyPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.34, h * 0.76, w * 0.32, h * 0.16), const Radius.circular(8)),
      bodyPaint,
    );
    final corePaint = Paint()..color = const Color(0xFF06B6D4);
    canvas.drawCircle(Offset(w * 0.5, h * 0.84), w * 0.04, corePaint);
  }

  @override
  bool shouldRepaint(covariant _YolchiPainter oldDelegate) => oldDelegate.mood != mood;
}
