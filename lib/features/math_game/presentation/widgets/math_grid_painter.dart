import 'package:flutter/material.dart';

class MathGridPainter extends CustomPainter {
  final Color lineColor;
  final double spacing;

  const MathGridPainter({
    this.lineColor = const Color(0xFF1E1E26),
    this.spacing = 52.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    // Draw vertical lines
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant MathGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.spacing != spacing;
}
