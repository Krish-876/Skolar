import 'package:Skolar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FocusBackground extends StatelessWidget {
  final double slideProgress;

  const FocusBackground({super.key, required this.slideProgress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FocusBackgroundPainter(slideProgress: slideProgress),
      child: const SizedBox.expand(),
    );
  }
}

class _FocusBackgroundPainter extends CustomPainter {
  final double slideProgress;

  _FocusBackgroundPainter({required this.slideProgress});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Solid base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppTheme.background,
    );

    // 2. Ambient glow
    final glowCenter = Offset(size.width * 0.2, size.height * 0.5);
    final glowRadius = size.width * 1.1;
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.35),
            AppTheme.primary.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    // 3. Surface panel
    _paintWave(canvas, size);
  }

  void _paintWave(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // From Figma: shape top-corners sit at Y=775.46 on a 1518px tall frame → 51.1%
    // slideProgress 0→1 pushes the panel off the bottom of the screen.
    final double cornerY = h * 0.45 + (h * 0.55 * slideProgress);

    // From Figma: arc dip = 88px on 681px wide frame → 12.9% of screen width.
    // This is how far the arc's LOWEST point sits BELOW the two top corners.
    // (The arc is convex-up: corners are the HIGH points, centre dips DOWN.)
    //
    // Wait — re-reading the Figma: the shape is a rectangle with a concave arc
    // CUT into the top. So the TOP CORNERS are at cornerY, and the arc dips
    // DOWN to (cornerY + dip) at the horizontal centre. The surface body is
    // BELOW the arc. This is concave-up from outside, convex-up from inside —
    // the arc curves DOWNWARD from corners to centre = the "bowl" cut at top.
    //
    // The spacing=-88 means the arc lowest point is 88px below the bounding box top.
    final double dip = w * 0.129; // 88/681 × screenWidth

    // Large-circle radius from 3 symmetric points:
    //   (0, cornerY), (w/2, cornerY + dip), (w, cornerY)
    // R = (w²/4 + dip²) / (2 × dip)
    final double R = (w * w / 4.0 + dip * dip) / (2.0 * dip);

    // Circle centre is ABOVE the arc corners (since arc dips downward):
    // centre Y = cornerY - (R - dip)
    final double cx = w / 2.0;
    final double cy = cornerY - (R - dip);

    final Rect arcOval = Rect.fromCircle(center: Offset(cx, cy), radius: R);

    // Angles from centre to the two corner points
    // Centre is far ABOVE screen. Left corner (0, cornerY) is below-left of centre.
    // startAngle ≈ π/2 + small angle (pointing down-left)
    // endAngle   ≈ π/2 - small angle (pointing down-right)
    // The arc from startAngle to endAngle CLOCKWISE passes through the bottom (the dip).
    final double startAngle = _angle(cx, cy, 0, cornerY);
    final double endAngle = _angle(cx, cy, w, cornerY);

    // Clockwise sweep from left corner → through dip bottom → right corner
    double sweepAngle = endAngle - startAngle;
    // Both angles are near π/2 (pointing downward from a centre high above).
    // startAngle < endAngle (left is more negative x → larger angle? let's force CW short arc)
    // The dip point (w/2, cornerY+dip) is directly below centre → angle = π/2 (straight down).
    // startAngle (to left corner) > π/2, endAngle (to right corner) < π/2.
    // CW sweep from startAngle to endAngle = negative (endAngle - startAngle) which is negative.
    // We want the SHORT clockwise arc, so ensure sweepAngle is negative and |sweep| < π.
    if (sweepAngle > 0) sweepAngle -= 2 * 3.141592653589793;
    // sweepAngle is now negative (CW). The short arc through the dip. ✓

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [AppTheme.surfaceGrad2Begin, AppTheme.bgGradEnd],
        stops: const [0.0, 0.85],
      ).createShader(Rect.fromLTWH(0, cornerY, w, h - cornerY));

    // Path: start at top-left corner, arc across the dipped top edge, straight sides + bottom
    final path = Path()
      ..moveTo(0, cornerY)
      ..arcTo(arcOval, startAngle, sweepAngle, false)
      // arcTo ends at (w, cornerY)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(path, paint);

    // Sheen along arc edge
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerY)
        ..arcTo(arcOval, startAngle, sweepAngle, false),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
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
      oldDelegate.slideProgress != slideProgress;
}
