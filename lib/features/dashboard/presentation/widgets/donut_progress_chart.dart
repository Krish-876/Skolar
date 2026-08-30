import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

/// One ring's worth of arc data — a track (full circle) plus a progress arc,
/// both drawn at the same stroke width. Multiple of these, stepped inward
/// from a shared outer radius, are what let [DonutProgressChart] draw
/// concentric rings (e.g. a legend against several metrics in the expanded
/// dashboard card) instead of just one.
class DonutRingData {
  /// Raw 0..1 sweep — capping (if any) is the caller's job; this class
  /// draws exactly what it's given.
  final double percent;
  final Color progressColor;
  final Color backgroundColor;
  final double lineWidth;

  const DonutRingData({
    required this.percent,
    required this.progressColor,
    required this.backgroundColor,
    required this.lineWidth,
  });
}

/// A concentric progress ring (track + arc, same center), drawn directly
/// with a [CustomPainter] instead of the `percent_indicator` package.
///
/// That package computes its own pixel diameter once and wraps everything
/// in a `Column` sized off of it — with `radius`/`lineWidth` animating every
/// frame here (the dashboard progress card's expand/collapse drag), that
/// internal `Column` ended up a fraction of a pixel short of the content it
/// was handed on almost every frame, regardless of how the content passed
/// into it was sized (the mismatch was in the package's own layout, not
/// anything on our side — see the git history on this file for the exhausted
/// attempts to constrain around it). Drawing the arc ourselves sidesteps
/// that entirely: there's no intermediate `Column`/`Material` for a
/// sub-pixel size mismatch to hide in, just a `CustomPaint` sized exactly to
/// `radius * 2` and a plain centered child.
///
/// The ring is capped below 100% so it can never visually close — there is
/// no "complete" state or celebration variant anywhere on this surface.
class DonutProgressChart extends StatelessWidget {
  static const double _maxVisualPercent = 0.92;

  /// Raw 0..1 completion ratio — capping to [_maxVisualPercent] happens here,
  /// same as it always did.
  final double percent;
  final double radius;
  final double lineWidth;
  final Widget? center;

  /// Additional rings drawn inside the primary one, each stepped inward by
  /// its own [DonutRingData.lineWidth] plus a small gap — for a legend
  /// against multiple metrics. Empty by default; existing single-ring
  /// callers (today, every one of them) are completely unaffected.
  final List<DonutRingData> innerRings;

  const DonutProgressChart({
    super.key,
    required this.percent,
    this.radius = 55,
    this.lineWidth = 10,
    this.center,
    this.innerRings = const [],
  });

  @override
  Widget build(BuildContext context) {
    final capped = percent.clamp(0.0, 1.0) * _maxVisualPercent;
    final rings = [
      DonutRingData(
        percent: capped,
        progressColor: AppTheme.accent,
        backgroundColor: AppTheme.surface.withValues(alpha: 0.4),
        lineWidth: lineWidth,
      ),
      ...innerRings,
    ];
    final diameter = radius * 2;

    return SizedBox(
      width: diameter,
      height: diameter,
      // Plain child of a Stack, centered — no Column, no Material, no
      // AnimatedPhysicalModel between the arc and whatever `center` is, so
      // there's nothing here with its own opinion about layout that the
      // caller's animating content could ever fractionally overflow.
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(diameter, diameter),
            painter: _DonutRingsPainter(rings: rings, outerRadius: radius),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _DonutRingsPainter extends CustomPainter {
  final List<DonutRingData> rings;
  final double outerRadius;

  // Breathing room between concentric rings so adjacent strokes don't touch.
  static const double _ringGap = 4;

  _DonutRingsPainter({required this.rings, required this.outerRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    var currentOuter = outerRadius;

    for (final ring in rings) {
      // Inset by half the stroke width so the *outer edge* of the stroke
      // sits at `currentOuter` — matches the proportions the previous
      // percent_indicator-based ring drew at the same radius/lineWidth.
      final ringRadius = currentOuter - ring.lineWidth / 2;
      if (ringRadius > 0) {
        final rect = Rect.fromCircle(center: center, radius: ringRadius);

        final backgroundPaint = Paint()
          ..color = ring.backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring.lineWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawCircle(center, ringRadius, backgroundPaint);

        if (ring.percent > 0) {
          final progressPaint = Paint()
            ..color = ring.progressColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = ring.lineWidth
            ..strokeCap = StrokeCap.round;
          // Starts at the top (-90°) and sweeps clockwise, same convention
          // percent_indicator used with its default `startAngle`/`reverse`.
          const startAngle = -math.pi / 2;
          final sweepAngle = 2 * math.pi * ring.percent;
          canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
        }
      }

      currentOuter -= ring.lineWidth + _ringGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutRingsPainter oldDelegate) {
    if (rings.length != oldDelegate.rings.length) return true;
    for (var i = 0; i < rings.length; i++) {
      final a = rings[i];
      final b = oldDelegate.rings[i];
      if (a.percent != b.percent ||
          a.progressColor != b.progressColor ||
          a.backgroundColor != b.backgroundColor ||
          a.lineWidth != b.lineWidth) {
        return true;
      }
    }
    return false;
  }
}
