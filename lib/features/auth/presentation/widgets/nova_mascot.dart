import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'mascot_state.dart';

class NovaMascot extends StatefulWidget {
  final MascotState state;
  const NovaMascot({super.key, required this.state});

  @override
  State<NovaMascot> createState() => _NovaMascotState();
}

class _NovaMascotState extends State<NovaMascot> with TickerProviderStateMixin {
  // ── Pupil + blush controller (lerp-based) ────────────────────────────────
  late final AnimationController _pupilCtrl;

  Offset _leftPupil = Offset.zero;
  Offset _rightPupil = Offset.zero;
  double _blush = 0;

  Offset _fromLeft = Offset.zero;
  Offset _fromRight = Offset.zero;
  double _fromBlush = 0;

  Offset _toLeft = Offset.zero;
  Offset _toRight = Offset.zero;
  double _toBlush = 0;

  // ── Eyelid controller (0 = fully open, 1 = fully closed) ─────────────────
  late final AnimationController _lidCtrl;
  double _lidAmount = 0;

  // ── Eye-scale controller (surprise wide / squint narrow) ─────────────────
  late final AnimationController _scaleCtrl;
  double _eyeScale = 1.0;
  double _scaleAmount = 0; // set before forwarding

  // ── Pupil-size pulse (breathing while watching email) ─────────────────────
  late final AnimationController _pulseCtrl;
  double _pupilScale = 1.0;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _glanceTimer;
  Timer? _snapBackTimer;
  Timer? _blinkTimer;

  static const double _maxR = 7.0;
  final _rng = Random();

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pupilCtrl = AnimationController(vsync: this)..addListener(_onPupilTick);

    _lidCtrl = AnimationController(vsync: this)
      ..addListener(() => setState(() => _lidAmount = _lidCtrl.value));

    _scaleCtrl = AnimationController(vsync: this, value: 0)
      ..addListener(() {
        setState(
          () => _eyeScale =
              1.0 + _scaleCtrl.value * _scaleCtrl.value * _scaleAmount,
        );
      });

    _pulseCtrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addListener(() {
          setState(() => _pupilScale = 1.0 + sin(_pulseCtrl.value * pi) * 0.12);
        });

    _scheduleNextBlink();
  }

  void _onPupilTick() {
    final t = CurvedAnimation(
      parent: _pupilCtrl,
      curve: Curves.easeInOut,
    ).value;
    setState(() {
      _leftPupil = Offset.lerp(_fromLeft, _toLeft, t)!;
      _rightPupil = Offset.lerp(_fromRight, _toRight, t)!;
      _blush = _fromBlush + (_toBlush - _fromBlush) * t;
    });
  }

  void _movePupils({
    required Offset left,
    required Offset right,
    required double blush,
    Duration duration = const Duration(milliseconds: 280),
  }) {
    _fromLeft = _leftPupil;
    _fromRight = _rightPupil;
    _fromBlush = _blush;
    _toLeft = left;
    _toRight = right;
    _toBlush = blush;
    _pupilCtrl.duration = duration;
    _pupilCtrl.forward(from: 0);
  }

  // ── Blink ─────────────────────────────────────────────────────────────────

  void _scheduleNextBlink() {
    final delay = Duration(milliseconds: 600 + _rng.nextInt(2100));
    _blinkTimer = Timer(delay, _blink);
  }

  Future<void> _blink({bool isDouble = false}) async {
    if (!mounted) return;
    // Close
    _lidCtrl.duration = const Duration(milliseconds: 80);
    await _lidCtrl.forward(from: 0);
    if (!mounted) return;
    // Open
    _lidCtrl.duration = const Duration(milliseconds: 90);
    await _lidCtrl.reverse();
    if (!mounted) return;

    // 30 % chance of a double-blink
    if (!isDouble && _rng.nextDouble() < 0.3) {
      await Future.delayed(const Duration(milliseconds: 5));
      if (mounted) await _blink(isDouble: true);
    } else {
      _scheduleNextBlink();
    }
  }

  // ── Eye-scale helpers ─────────────────────────────────────────────────────

  void _wideEyes({
    double amount = 0.18,
    Duration duration = const Duration(milliseconds: 120),
  }) {
    _scaleAmount = amount;
    _scaleCtrl.duration = duration;
    _scaleCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      _scaleCtrl.duration = const Duration(milliseconds: 350);
      _scaleCtrl.reverse();
    });
  }

  void _squintEyes({double amount = -0.22}) {
    _scaleAmount = amount; // negative → scale < 1
    _scaleCtrl.duration = const Duration(milliseconds: 200);
    _scaleCtrl.forward(from: 0);
  }

  void _normalEyes() {
    _scaleCtrl.duration = const Duration(milliseconds: 200);
    _scaleCtrl.reverse();
  }

  // ── State machine ─────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(NovaMascot old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _applyState(widget.state);
  }

  void _applyState(MascotState state) {
    _glanceTimer?.cancel();
    _snapBackTimer?.cancel();

    switch (state) {
      case MascotState.idle:
        _movePupils(left: Offset.zero, right: Offset.zero, blush: 0);
        _normalEyes();
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;
        setState(() => _pupilScale = 1.0);

      case MascotState.watchingEmail:
        // STOP the pulsing/pumping movement
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;

        setState(() {
          _pupilScale = 1.0; // Force it to stay at base size
          _eyeScale = 1.0; // Ensure eye white doesn't grow/shrink
        });

        _movePupils(
          left: const Offset(-1, _maxR),
          right: const Offset(1, _maxR),
          blush: 0,
          duration: const Duration(milliseconds: 200),
        );
        _normalEyes();
      case MascotState.lookingAway:
      case MascotState.guiltyGlance:
        _pulseCtrl.stop();
        setState(() => _pupilScale = 1.0);
        _normalEyes(); // CRITICAL: Forces eyeScale back to 1.0

        // Define multiple "I'm not looking!" spots
        final shiftySpots = [
          Offset(-_maxR, -_maxR * 0.8), // Top Left
          Offset(_maxR, -_maxR * 0.9), // Top Right
          Offset(-_maxR * 0.7, -2), // Mid Left
          Offset(_maxR * 0.5, -_maxR), // High Center
        ];

        final targetSpot = shiftySpots[_rng.nextInt(shiftySpots.length)];

        _movePupils(
          left: targetSpot,
          right: targetSpot,
          blush: 0.4,
          duration: const Duration(milliseconds: 250),
        );

        // Continue shifting eyes every 700-1500ms while in this state
        _glanceTimer = Timer(
          Duration(milliseconds: 600 + _rng.nextInt(100)),
          () {
            if (!mounted) return;
            if (widget.state == MascotState.lookingAway) {
              _applyState(MascotState.lookingAway);
            }
          },
        );

      case MascotState.caught:
        _pulseCtrl.stop();
        setState(() => _pupilScale = 1.0);
        // Wide shocked eyes + deep blush
        _wideEyes(amount: 0.28, duration: const Duration(milliseconds: 80));
        _movePupils(
          left: const Offset(-1, _maxR * 0.4),
          right: const Offset(1, _maxR * 0.4),
          blush: 1.0,
          duration: const Duration(milliseconds: 90),
        );
        // Rapid surprised double-blink, then settle guiltily
        _snapBackTimer = Timer(const Duration(milliseconds: 350), () async {
          if (!mounted) return;
          await _blink(isDouble: true);
          if (!mounted) return;
          _movePupils(
            left: const Offset(-_maxR, -3),
            right: const Offset(-_maxR, -3),
            blush: 0.6,
            duration: const Duration(milliseconds: 300),
          );
          _squintEyes(amount: -0.18);
        });
    }
  }

  @override
  void dispose() {
    _glanceTimer?.cancel();
    _snapBackTimer?.cancel();
    _blinkTimer?.cancel();
    _pupilCtrl.dispose();
    _lidCtrl.dispose();
    _scaleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: _MascotPainter(
          leftPupilOffset: _leftPupil,
          rightPupilOffset: _rightPupil,
          blushOpacity: _blush,
          lidAmount: _lidAmount,
          eyeScale: _eyeScale,
          pupilScale: _pupilScale,
          // Minor additions for better color control
          bodyColor: const Color(0xFF6B3FBF),
          highlightColor: const Color(0xFFB189EF),
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _MascotPainter extends CustomPainter {
  final Offset leftPupilOffset;
  final Offset rightPupilOffset;
  final double blushOpacity;
  final double lidAmount; // 0 open → 1 closed
  final double eyeScale; // 1 normal, >1 wide, <1 squint
  final double pupilScale; // subtle pulse radius multiplier

  const _MascotPainter({
    required this.leftPupilOffset,
    required this.rightPupilOffset,
    required this.blushOpacity,
    required this.lidAmount,
    required this.eyeScale,
    required this.pupilScale,
    required Color bodyColor,
    required Color highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.96),
        width: w * 0.55,
        height: h * 0.06,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── Ears ──────────────────────────────────────────────────────────────────
    // ── Ears ──────────────────────────────────────────────────────────────────
    final earPaint = Paint()..color = const Color(0xFF8B5ED4);

    void drawEar(double x, double y, double rotation) {
      canvas.save();
      canvas.translate(w * x, h * y);
      canvas.rotate(rotation);
      // Using a slightly more "conical" shape
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: w * 0.14,
            height: h * 0.22,
          ),
          Radius.circular(w * 0.07),
        ),
        earPaint,
      );
      canvas.restore();
    }

    drawEar(0.26, 0.22, -0.3); // Left ear
    drawEar(0.74, 0.22, 0.3); // Right ear
    // ── Body ──────────────────────────────────────────────────────────────────
    // ── Body (Pear-Shaped 3D Form) ──────────────────────────────────────────
    final bodyPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.58),
            width: w * 0.85,
            height: h * 0.75,
          ),
          topLeft: Radius.circular(w * 0.4),
          topRight: Radius.circular(w * 0.4),
          bottomLeft: Radius.circular(w * 0.3),
          bottomRight: Radius.circular(w * 0.3),
        ),
      );

    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          radius: 1.0,
          colors: const [
            Color(0xFFA678E8), // Top highlight
            Color(0xFF6B3FBF), // Core violet
            Color(0xFF3B1F71), // Deep bottom shadow
          ],
          stops: const [0.1, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── Feet ──────────────────────────────────────────────────────────────────
    // ── Legs & Feet ───────────────────────────────────────────────────────────
    // ── Integrated Legs ──────────────────────────────────────────────────────
    final legPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF5A2DA3), // Darker violet where it meets the body
          const Color(0xFF3B1F71), // Deepest shadow at the floor
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.8, w, h * 0.15));

    // ── Integrated Legs ──────────────────────────────────────────────────────
    void drawStumpyLeg(double xPos) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          // Moved from h * 0.88 to h * 0.94 to sit lower
          Rect.fromCenter(
            center: Offset(w * xPos, h * 0.94),
            width: w * 0.18,
            height: h * 0.12,
          ),
          Radius.circular(w * 0.06),
        ),
        legPaint,
      );
    }

    drawStumpyLeg(0.33); // Positioned under the left eye
    drawStumpyLeg(0.67); // Positioned under the right eye
    // ── Eyes ──────────────────────────────────────────────────────────────────
    final leftEyeCenter = Offset(w * 0.35, h * 0.46);
    final rightEyeCenter = Offset(w * 0.65, h * 0.46);
    final eyeRadius = w * 0.165 * eyeScale.clamp(0.6, 1.4);
    final pupilRadius = eyeRadius * 0.58 * pupilScale.clamp(0.7, 1.3);

    // ── Eye Whites (Spherical 3D Look) ────────────────────────────────────────
    Paint eyeWhite(Offset center) => Paint()
      ..shader = RadialGradient(
        // Move the "glow" to the top-left to make it look like a rounded ball
        center: const Alignment(-0.4, -0.4),
        radius: 0.8,
        colors: const [
          Color(0xFFFFFFFF), // Pure white highlight
          Color(0xFFF0F0F0), // Main white surface
          Color(0xFFDED2FF), // Subtle violet-tinted shadow at the edges
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: eyeRadius));
    canvas.drawCircle(leftEyeCenter, eyeRadius, eyeWhite(leftEyeCenter));
    canvas.drawCircle(rightEyeCenter, eyeRadius, eyeWhite(rightEyeCenter));

    // ── Pupils ────────────────────────────────────────────────────────────────
    void drawPupil(Offset eyeCenter, Offset offset) {
      final pupilCenter = eyeCenter + offset;
      canvas.save();
      canvas.clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: eyeCenter, radius: eyeRadius - 1)),
      );

      // 1. Deep Iris Glow (The magic touch)
      canvas.drawCircle(
        pupilCenter,
        pupilRadius,
        Paint()..color = const Color(0xFF1A1A1A),
      );
      canvas.drawCircle(
        pupilCenter,
        pupilRadius * 0.85,
        Paint()
          ..color = const Color(
            0xFF8B5ED4,
          ).withValues(alpha: 0.25), // Subtle violet glow
      );

      // 2. Primary Sharp Shine
      canvas.drawCircle(
        pupilCenter + Offset(pupilRadius * 0.35, -pupilRadius * 0.35),
        pupilRadius * 0.3, // Slightly larger for that "cute" look
        Paint()..color = Colors.white,
      );

      // 3. Tiny Reflection
      canvas.drawCircle(
        pupilCenter + Offset(-pupilRadius * 0.25, pupilRadius * 0.3),
        pupilRadius * 0.1,
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
      canvas.restore();
    }

    drawPupil(leftEyeCenter, leftPupilOffset);
    drawPupil(rightEyeCenter, rightPupilOffset);

    // ── Eyelids ───────────────────────────────────────────────────────────────
    if (lidAmount > 0) {
      _drawEyelid(canvas, leftEyeCenter, eyeRadius, lidAmount);
      _drawEyelid(canvas, rightEyeCenter, eyeRadius, lidAmount);
    }

    // ── Blush ─────────────────────────────────────────────────────────────────
    if (blushOpacity > 0) {
      final blushPaint = Paint()
        ..color = const Color(0xFFD475A8).withValues(alpha: blushOpacity * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.24, h * 0.57),
          width: w * 0.18,
          height: h * 0.10,
        ),
        blushPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.76, h * 0.57),
          width: w * 0.18,
          height: h * 0.10,
        ),
        blushPaint,
      );
    }
  }

  /// Fills the eye with a lid colour from the top down.
  /// [amount] 0 = nothing, 1 = fully covered.
  void _drawEyelid(
    Canvas canvas,
    Offset eyeCenter,
    double eyeRadius,
    double amount,
  ) {
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: eyeCenter, radius: eyeRadius + 0.5)),
    );

    final coverHeight = eyeRadius * 2 * amount;

    // Solid lid fill
    canvas.drawRect(
      Rect.fromLTWH(
        eyeCenter.dx - eyeRadius - 1,
        eyeCenter.dy - eyeRadius - 1,
        eyeRadius * 2 + 2,
        coverHeight + 1,
      ),
      Paint()..color = const Color(0xFF9060D8),
    );

    // Soft rounded leading edge
    if (amount > 0.05) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(eyeCenter.dx, eyeCenter.dy - eyeRadius + coverHeight),
          width: eyeRadius * 2.1,
          height: eyeRadius * 0.35,
        ),
        Paint()
          ..color = const Color(0xFF7A48C0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.leftPupilOffset != leftPupilOffset ||
      old.rightPupilOffset != rightPupilOffset ||
      old.blushOpacity != blushOpacity ||
      old.lidAmount != lidAmount ||
      old.eyeScale != eyeScale ||
      old.pupilScale != pupilScale;
}
