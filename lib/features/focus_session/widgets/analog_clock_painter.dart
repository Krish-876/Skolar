import 'dart:async';
import 'dart:math';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Minimalist analog clock for the focus timer's hero slot: transparent
/// face (no background disc), four cardinal tick marks, two flat-edged
/// hands, and a thin accent second hand with a colored pivot dot. All
/// colors come from [AppTheme].
///
/// Has two drive modes, switched by [isIdle]:
/// - Idle (no session started): hands show the real wall-clock time,
///   ticking off a local per-second [Timer] the widget owns.
/// - Active (session running/paused/complete): hands are driven entirely
///   by the focus session's own clock, matching the numeric readout —
///   - [elapsedSeconds] is seconds elapsed within the *current phase*
///     (`currentPhaseTotalSeconds - currentPhaseSecondsLeft` on
///     [FocusTimerController]) and drives the minute/second hands the way
///     a real clock's hands are driven by elapsed time.
///   - [progress] is the current phase's completion fraction (0..1, i.e.
///     [FocusTimerController.currentIntervalProgress]) and drives the hour
///     hand as a single lap spanning the whole phase — a plain progress
///     indicator rather than a wall-clock hour reading, since a 25-minute
///     session would barely move a real hour hand.
class AnalogClock extends StatefulWidget {
  final bool isIdle;
  final double elapsedSeconds;
  final double progress;
  final double size;

  const AnalogClock({
    super.key,
    required this.isIdle,
    required this.elapsedSeconds,
    required this.progress,
    this.size = 220,
  });

  @override
  State<AnalogClock> createState() => _AnalogClockState();
}

class _AnalogClockState extends State<AnalogClock> {
  Timer? _wallClockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startWallClockTimer();
  }

  void _startWallClockTimer() {
    _wallClockTimer?.cancel();
    _wallClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _wallClockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = AnalogClockPainter.wallClock(now: _now);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(painter: painter),
    );
  }
}

class AnalogClockPainter extends CustomPainter {
  final double hourFraction;
  final double minuteFraction;
  final double secondFraction;

  const AnalogClockPainter._({
    required this.hourFraction,
    required this.minuteFraction,
    required this.secondFraction,
  });

  factory AnalogClockPainter.session({
    required double elapsedSeconds,
    required double progress,
  }) {
    return AnalogClockPainter._(
      hourFraction: progress.clamp(0.0, 1.0),
      minuteFraction: (elapsedSeconds % 3600) / 3600,
      secondFraction: (elapsedSeconds % 60) / 60,
    );
  }

  factory AnalogClockPainter.wallClock({required DateTime now}) {
    final hour12 = now.hour % 12;
    return AnalogClockPainter._(
      hourFraction: (hour12 + now.minute / 60.0) / 12.0,
      minuteFraction: (now.minute + now.second / 60.0) / 60.0,
      secondFraction: (now.second + now.millisecond / 1000.0) / 60.0,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    _paintCardinalTicks(canvas, center, radius);
    _paintHands(canvas, center, radius);
    _paintPivot(canvas, center);
  }

  void _paintCardinalTicks(Canvas canvas, Offset center, double radius) {
    // Exactly 4 marks (12/3/6/9), small dots detached just outside the
    // face — not the full 12-mark ring the reference doesn't use.
    final paint = Paint()..color = AppTheme.onBackground.withValues(alpha: 0.3);

    for (int i = 0; i < 4; i++) {
      final angle = (pi / 2) * i;
      final dir = Offset(sin(angle), -cos(angle));
      final dotCenter = center + dir * radius * 1.04;
      canvas.drawCircle(dotCenter, 2.4, paint);
    }
  }

  void _paintHands(Canvas canvas, Offset center, double radius) {
    final hourAngle = hourFraction * 2 * pi;
    _drawHand(
      canvas,
      center,
      hourAngle,
      length: radius * 0.42,
      width: 5.0,
      color: AppTheme.onBackground,
    );

    final minuteAngle = minuteFraction * 2 * pi;
    _drawHand(
      canvas,
      center,
      minuteAngle,
      length: radius * 0.64,
      width: 3.2,
      color: AppTheme.onBackground.withValues(alpha: 0.9),
    );

    final secondAngle = secondFraction * 2 * pi;
    _drawHand(
      canvas,
      center,
      secondAngle,
      length: radius * 0.8,
      width: 1.4,
      color: AppTheme.accentPurple,
    );
  }

  void _drawHand(
    Canvas canvas,
    Offset center,
    double angle, {
    required double length,
    required double width,
    required Color color,
  }) {
    final dir = Offset(sin(angle), -cos(angle));
    final paint = Paint()
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt
      ..color = color;
    canvas.drawLine(center, center + dir * length, paint);
  }

  void _paintPivot(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 4.0, Paint()..color = AppTheme.accentPurple);
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) =>
      oldDelegate.hourFraction != hourFraction ||
      oldDelegate.minuteFraction != minuteFraction ||
      oldDelegate.secondFraction != secondFraction;
}
