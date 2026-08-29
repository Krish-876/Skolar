import 'package:Skolar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FocusBackground extends StatelessWidget {
  final double slideProgress;
  final double breakProgress;

  const FocusBackground({
    super.key,
    required this.slideProgress,
    this.breakProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FocusBackgroundPainter(
        slideProgress: slideProgress,
        breakProgress: breakProgress,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FocusBackgroundPainter extends CustomPainter {
  final double slideProgress;
  final double breakProgress;

  _FocusBackgroundPainter({
    required this.slideProgress,
    required this.breakProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Solid base (smoothly lightens during break)
    final bgColor = Color.lerp(
      AppTheme.background,
      const Color(0xFF1D162B),
      breakProgress,
    )!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // 2. Ambient glow (tasteful, subtle expansion and lightening during break)
    final cx = size.width * (0.20 + 0.06 * breakProgress);
    final cy = size.height * (0.50 - 0.02 * breakProgress);
    final glowCenter = Offset(cx, cy);
    final glowRadius = size.width * (1.10 + 0.15 * breakProgress);

    final glowCenterColor = Color.lerp(
      AppTheme.primary.withValues(alpha: 0.35),
      const Color(0xFFA78BFA).withValues(alpha: 0.48),
      breakProgress,
    )!;
    final glowMidColor = Color.lerp(
      AppTheme.primary.withValues(alpha: 0.08),
      const Color(0xFF8B5CF6).withValues(alpha: 0.18),
      breakProgress,
    )!;

    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowCenterColor,
            glowMidColor,
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    // 3. Surface panel
    _paintWave(canvas, size);
  }

  void _paintWave(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final double cornerY = h * 0.45 + (h * 0.55 * slideProgress);
    final double dip = w * 0.129;
    final double R = (w * w / 4.0 + dip * dip) / (2.0 * dip);
    final double cx = w / 2.0;
    final double cy = cornerY - (R - dip);

    final Rect arcOval = Rect.fromCircle(center: Offset(cx, cy), radius: R);
    final double startAngle = _angle(cx, cy, 0, cornerY);
    final double endAngle = _angle(cx, cy, w, cornerY);

    double sweepAngle = endAngle - startAngle;
    if (sweepAngle > 0) sweepAngle -= 2 * 3.141592653589793;

    final topWaveColor = Color.lerp(
      AppTheme.surfaceGrad2Begin,
      const Color(0xFF382A54),
      breakProgress,
    )!;
    final botWaveColor = Color.lerp(
      AppTheme.bgGradEnd,
      const Color(0xFF201633),
      breakProgress,
    )!;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topWaveColor, botWaveColor],
        stops: const [0.0, 0.85],
      ).createShader(Rect.fromLTWH(0, cornerY, w, h - cornerY));

    // Path: start at top-left corner, arc across the dipped top edge, straight sides + bottom
    final path = Path()
      ..moveTo(0, cornerY)
      ..arcTo(arcOval, startAngle, sweepAngle, false)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(path, paint);

    // Sheen along arc edge
    final sheenAccent = Color.lerp(
      AppTheme.accentPurple,
      const Color(0xFFC084FC),
      breakProgress,
    )!;

    canvas.drawPath(
      Path()
        ..moveTo(0, cornerY)
        ..arcTo(arcOval, startAngle, sweepAngle, false),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            sheenAccent.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.25 + 0.10 * breakProgress),
            sheenAccent.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, cornerY - 4, w, dip + 8))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  double _angle(double cx, double cy, double px, double py) =>
      (Offset(px, py) - Offset(cx, cy)).direction;

  @override
  bool shouldRepaint(covariant _FocusBackgroundPainter oldDelegate) =>
      oldDelegate.slideProgress != slideProgress ||
      oldDelegate.breakProgress != breakProgress;
}
