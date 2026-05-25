import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_animated_mesh_theme.dart';
import 'package:Skolar/core/theme/app_theme.dart';

class AnimatedMeshBackground extends StatefulWidget {
  const AnimatedMeshBackground({super.key});

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final _MeshPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _MeshPainter();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // slower
    )..repeat();

    _controller.addListener(() {
      _painter._tick(_controller.value);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _painter,
        size: size,
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter() : super(repaint: _repaint);

  static final _repaint = ValueNotifier<double>(0);
  double _t = 0;

  void _tick(double value) {
    _t = value;
    _repaint.value = value;
  }

  static const List<List<double>> _blobs = [
    // xPhase, yPhase, xSpeed, ySpeed, xAmp,  yAmp,  radius
    [0.0,     2.0,    2.0,    3.0,    0.28,  0.22,  0.52],
    [2.1,     0.4,    3.0,    1.0,    0.22,  0.30,  0.50],
    [4.3,     3.1,    2.0,    4.0,    0.30,  0.20,  0.40],
  ];

  static const List<Color> _blobColors = [
    AppAnimatedMeshTheme.purpleOrbBase, // Deep orchid purple
    AppAnimatedMeshTheme.cyanOrbBase, // Electric cyan
    AppAnimatedMeshTheme.amberOrbBase // Golden amber
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppTheme.bgGradEnd, AppTheme.bgGradBegin],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Offset.zero & size, bgPaint);

    final tw = 2 * math.pi * _t;

    for (int i = 0; i < _blobs.length; i++) {
      final b = _blobs[i];
      final cx = size.width  * (0.5 + b[4] * math.sin(tw * b[2] + b[0]));
      final cy = size.height * (0.5 + b[5] * math.cos(tw * b[3] + b[1]));
      final r  = size.width  * b[6] * 0.9;
      final color = _blobColors[i];

      // Smooth gaussian-like falloff — many tightly packed stops following
      // an exponential curve. No flat sections, no visible transition edges.
      // Opacity follows: f(t) = peak * exp(-k * t^2) approximated with 8 stops.
      final paint = Paint()
  ..blendMode = BlendMode.screen
  ..shader = RadialGradient(
    colors: [
      color.withOpacity(0.30), // center
      color.withOpacity(0.20),
      color.withOpacity(0.10),
      color.withOpacity(0.03),
      color.withOpacity(0.00), // edge
    ],
    stops: const [0.00, 0.25, 0.55, 0.85, 1.00],
  ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) => (_t - old._t).abs() > 0.005;
}