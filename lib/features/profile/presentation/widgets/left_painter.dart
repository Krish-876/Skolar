import 'package:flutter/material.dart';

class LeftHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 1.5;
    const radius = 42.0;
    const pinkShiftRight = 22.0; // 👈 increase to move entire pink line right

    // ── TOP HIGHLIGHT (pink/purple) ──
    final topRect = Rect.fromLTWH(0, 0, size.width, radius * 2);

    final topPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          const Color(0xFFB44FBF).withValues(alpha: 0.9),
          const Color(0xFFB44FBF).withValues(alpha: 0.9),
          Colors.transparent,
        ],
        stops: const [0.05, 0.15, 0.2, 1.0],
      ).createShader(topRect);

    final topPath = Path();
    topPath.moveTo(inset + pinkShiftRight, radius * 1.5);
    topPath.lineTo(inset + pinkShiftRight, radius);
    topPath.arcToPoint(
      Offset(radius + inset + pinkShiftRight, inset),
      radius: Radius.circular(radius - inset),
    );
    topPath.lineTo(size.width - radius - inset + pinkShiftRight, inset);
    topPath.arcToPoint(
      Offset(size.width - inset + pinkShiftRight, radius + inset),
      radius: Radius.circular(radius - inset),
    );
    topPath.lineTo(size.width - inset + pinkShiftRight, radius * 1.5);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(topPath, topPaint);
    canvas.restore();

    // ── RIGHT EDGE HIGHLIGHT (blue/purple) ──
    const blueMoveLeft = 24.0; // 👈 increase to move left

    final rightRect = Rect.fromLTWH(
      size.width - radius - blueMoveLeft,
      size.height * 0.1,
      radius,
      size.height * 0.8,
    );

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF3416E2).withValues(alpha: 0.5),
          const Color(0xFF3416E2).withValues(alpha: 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 0.6, 1.0],
      ).createShader(rightRect);

    final rightPath = Path();
    rightPath.moveTo(size.width - inset - blueMoveLeft, size.height * 0.15);
    rightPath.lineTo(size.width - inset - blueMoveLeft, size.height * 0.85);

    canvas.drawPath(rightPath, rightPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
