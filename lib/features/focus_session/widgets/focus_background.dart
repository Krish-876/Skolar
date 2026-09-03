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

/// One scattered purple orb in the ambient background — mirrors the auth
/// screen's `DriftingCircles` (a soft `accentPurple` radial gradient fading
/// to transparent), scaled to fractions of the canvas instead of DP so it
/// composes at any screen size.
class _AmbientOrb {
  final double dx; // fraction of width
  final double dy; // fraction of height
  final double radiusFraction; // fraction of width
  final double baseOpacity;

  const _AmbientOrb({
    required this.dx,
    required this.dy,
    required this.radiusFraction,
    required this.baseOpacity,
  });
}

// Scattered soft purple orbs across the black canvas — the same visual
// language as the auth screen's black hero + DriftingCircles, in place of
// one large diffuse wash.
const List<_AmbientOrb> _ambientOrbs = [
  _AmbientOrb(dx: 0.14, dy: 0.10, radiusFraction: 0.09, baseOpacity: 0.20),
  _AmbientOrb(dx: 0.78, dy: 0.16, radiusFraction: 0.07, baseOpacity: 0.16),
  _AmbientOrb(dx: 0.32, dy: 0.24, radiusFraction: 0.05, baseOpacity: 0.22),
  _AmbientOrb(dx: 0.62, dy: 0.30, radiusFraction: 0.11, baseOpacity: 0.14),
  _AmbientOrb(dx: 0.20, dy: 0.42, radiusFraction: 0.06, baseOpacity: 0.18),
  _AmbientOrb(dx: 0.85, dy: 0.46, radiusFraction: 0.08, baseOpacity: 0.15),
  _AmbientOrb(dx: 0.50, dy: 0.58, radiusFraction: 0.15, baseOpacity: 0.17),
  _AmbientOrb(dx: 0.40, dy: 0.14, radiusFraction: 0.045, baseOpacity: 0.24),
];

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
      AppTheme.bgGradBegin,
      breakProgress,
    )!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // 2. Ambient glow — scattered soft purple orbs (matching the auth
    // screen's DriftingCircles), brightening slightly during break.
    final orbAlphaBoost = 1.0 + breakProgress * 0.4;
    for (final orb in _ambientOrbs) {
      final center = Offset(orb.dx * size.width, orb.dy * size.height);
      final radius = orb.radiusFraction * size.width;
      final alpha = (orb.baseOpacity * orbAlphaBoost).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppTheme.accentPurple.withValues(alpha: alpha),
              AppTheme.accentPurple.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

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
      Color.lerp(AppTheme.surfaceGrad2Begin, AppTheme.accentPurple, 0.3),
      breakProgress,
    )!;
    final botWaveColor = Color.lerp(
      AppTheme.bgGradEnd,
      Color.lerp(AppTheme.bgGradEnd, AppTheme.accentPurple, 0.25),
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
    final sheenAccent = AppTheme.accentPurple;

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
