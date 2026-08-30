import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

/// Combines a one-shot entry curve with a continuous ambient drift into a
/// single [Animation] so [DriftingCircles] only needs one constructor
/// parameter. `value` is the entry progress (0..1, settles once); `ambient`
/// is a free-running repeating phase used for the idle drift after entry.
class DriftProgress extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  DriftProgress({required this.entry, required this.ambient}) {
    entry.addListener(notifyListeners);
    entry.addStatusListener(notifyStatusListeners);
    ambient.addListener(notifyListeners);
  }

  final Animation<double> entry;
  final Animation<double> ambient;

  @override
  double get value => entry.value;

  @override
  AnimationStatus get status => entry.status;

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}
}

/// Soft drifting background circles, painted with a single [CustomPainter]
/// so any number of circles cost one repaint pass instead of N widgets.
///
/// Takes a plain `Animation<double>` so a future Lottie/Rive background can
/// drop in behind the same constructor without the sheet animation caring.
/// When given a [DriftProgress] specifically, it also picks up the ambient
/// drift; a bare entry-only animation still works, just without the idle
/// motion.
class DriftingCircles extends StatelessWidget {
  final Animation<double> progress;

  const DriftingCircles({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      // Belt-and-suspenders: guarantees nothing a circle computes can ever
      // paint past the screen bounds, regardless of position/radius math.
      child: ClipRect(
        child: CustomPaint(
          painter: _DriftingCirclesPainter(progress),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _CircleSpec {
  final bool fromLeft;
  final double radius;
  final double baseOpacity;
  final double restDx; // fraction of width
  final double restDy; // fraction of height
  final double entryDistance; // px travelled in from off-screen
  final double start; // entry-window start, 0..1
  final double end; // entry-window end, 0..1
  final Curve curve;
  final double ambientAmplitude; // px
  final double ambientSpeed; // cycles per ambient loop
  final double ambientPhase; // radians

  const _CircleSpec({
    required this.fromLeft,
    required this.radius,
    required this.baseOpacity,
    required this.restDx,
    required this.restDy,
    required this.entryDistance,
    required this.start,
    required this.end,
    required this.curve,
    required this.ambientAmplitude,
    required this.ambientSpeed,
    required this.ambientPhase,
  });
}

// Mostly small, at most two "large" (radius >= 60), scattered across the
// dark area without clustering in the corners. Every circle sits with
// enough margin from the edges that it's never more than half cropped —
// a big circle hugging an edge reads as a straight grey bar, not a circle.
//
// start/end are fractions of AuthPreviewPage's entry controller. All of
// them finish by ~0.51 (roughly 430ms of the 850ms total) — well before the
// sheet starts rising at 0.529 — so the circles are done settling before
// the sheet becomes the only thing still moving on screen.
const List<_CircleSpec> _specs = [
  _CircleSpec(
    fromLeft: true,
    radius: 24,
    baseOpacity: 0.20,
    restDx: 0.14,
    restDy: 0.26,
    entryDistance: 90,
    start: 0.076,
    end: 0.306,
    curve: Curves.easeOutBack,
    ambientAmplitude: 5,
    ambientSpeed: 0.8,
    ambientPhase: 0.3,
  ),
  _CircleSpec(
    fromLeft: true,
    radius: 34,
    baseOpacity: 0.14,
    restDx: 0.32,
    restDy: 0.12,
    entryDistance: 110,
    start: 0.122,
    end: 0.367,
    curve: Curves.easeOut,
    ambientAmplitude: 8,
    ambientSpeed: 0.5,
    ambientPhase: 1.4,
  ),
  _CircleSpec(
    fromLeft: false,
    radius: 80,
    baseOpacity: 0.12,
    restDx: 0.56,
    restDy: 0.40,
    entryDistance: 150,
    start: 0.046,
    end: 0.275,
    curve: Curves.easeOutBack,
    ambientAmplitude: 10,
    ambientSpeed: 0.4,
    ambientPhase: 2.1,
  ),
  _CircleSpec(
    fromLeft: false,
    radius: 22,
    baseOpacity: 0.22,
    restDx: 0.70,
    restDy: 0.18,
    entryDistance: 90,
    start: 0.184,
    end: 0.428,
    curve: Curves.easeOut,
    ambientAmplitude: 4,
    ambientSpeed: 1.1,
    ambientPhase: 3.0,
  ),
  _CircleSpec(
    fromLeft: false,
    radius: 46,
    baseOpacity: 0.16,
    restDx: 0.84,
    restDy: 0.46,
    entryDistance: 110,
    start: 0.229,
    end: 0.474,
    curve: Curves.easeOutBack,
    ambientAmplitude: 9,
    ambientSpeed: 0.6,
    ambientPhase: 0.7,
  ),
  _CircleSpec(
    fromLeft: true,
    radius: 30,
    baseOpacity: 0.20,
    restDx: 0.24,
    restDy: 0.52,
    entryDistance: 100,
    start: 0.092,
    end: 0.336,
    curve: Curves.easeOut,
    ambientAmplitude: 6,
    ambientSpeed: 0.9,
    ambientPhase: 4.2,
  ),
  _CircleSpec(
    fromLeft: false,
    radius: 62,
    baseOpacity: 0.10,
    restDx: 0.60,
    restDy: 0.56,
    entryDistance: 140,
    start: 0.275,
    end: 0.505,
    curve: Curves.easeOut,
    ambientAmplitude: 11,
    ambientSpeed: 0.35,
    ambientPhase: 5.0,
  ),
  _CircleSpec(
    fromLeft: true,
    radius: 26,
    baseOpacity: 0.18,
    restDx: 0.42,
    restDy: 0.22,
    entryDistance: 95,
    start: 0.153,
    end: 0.398,
    curve: Curves.easeOutBack,
    ambientAmplitude: 5,
    ambientSpeed: 1.0,
    ambientPhase: 1.9,
  ),
];

class _DriftingCirclesPainter extends CustomPainter {
  _DriftingCirclesPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final entryT = progress.value;
    final ambientT = progress is DriftProgress
        ? (progress as DriftProgress).ambient.value
        : 0.0;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final spec in _specs) {
      final localT = ((entryT - spec.start) / (spec.end - spec.start)).clamp(
        0.0,
        1.0,
      );
      final eased = spec.curve.transform(localT);

      final restX = spec.restDx * size.width;
      final restY = spec.restDy * size.height;
      final offscreenX = spec.fromLeft
          ? -spec.entryDistance
          : size.width + spec.entryDistance;
      final dx = restX + (1 - eased) * (offscreenX - restX);

      final ambientAngle =
          ambientT * 2 * math.pi * spec.ambientSpeed + spec.ambientPhase;
      final ambientOffset =
          math.sin(ambientAngle) * spec.ambientAmplitude * eased;

      final center = Offset(dx + ambientOffset, restY + ambientOffset * 0.6);
      final alpha = (spec.baseOpacity * eased).clamp(0.0, 1.0);

      // Radial gradient instead of a flat fill: fades to fully transparent
      // before the geometric edge, so there's no hard boundary — even a
      // circle partly cropped by the screen edge just fades out rather than
      // reading as a straight bar.
      paint.shader = ui.Gradient.radial(
        center,
        spec.radius,
        [
          AppTheme.accentPurple.withValues(alpha: alpha),
          AppTheme.accentPurple.withValues(alpha: 0),
        ],
        const [0.0, 1.0],
      );
      canvas.drawCircle(center, spec.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DriftingCirclesPainter oldDelegate) => false;
}
