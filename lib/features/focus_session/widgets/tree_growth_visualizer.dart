import 'dart:math' as math;
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Interactive circular gauge containing a procedurally growing bonsai tree
/// that matures dynamically as focus session time progresses.
class TreeGrowthVisualizer extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final bool isRunning;
  final bool isBreak;
  final double size;
  final double previewScale; // 0.0 to 1.0 (based on chosen duration during idle)

  const TreeGrowthVisualizer({
    super.key,
    required this.progress,
    required this.isRunning,
    this.isBreak = false,
    this.size = 210,
    this.previewScale = 0.5,
  });

  @override
  State<TreeGrowthVisualizer> createState() => _TreeGrowthVisualizerState();
}

class _TreeGrowthVisualizerState extends State<TreeGrowthVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swayController;
  final List<_FireflyParticle> _particles = [];
  final math.Random _random = math.Random(42);

  @override
  void initState() {
    super.initState();
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    // Initialize ambient firefly particles
    for (int i = 0; i < 18; i++) {
      _particles.add(
        _FireflyParticle(
          x: _random.nextDouble() * 2 - 1,
          y: _random.nextDouble() * 2 - 1,
          speed: 0.2 + _random.nextDouble() * 0.5,
          radius: 1.0 + _random.nextDouble() * 2.0,
          opacity: 0.15 + _random.nextDouble() * 0.6,
          phase: _random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void dispose() {
    _swayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveProgress = widget.isRunning
        ? widget.progress.clamp(0.0, 1.0)
        : (0.15 + (widget.previewScale * 0.7)).clamp(0.15, 0.85);

    return AnimatedBuilder(
      animation: _swayController,
      builder: (context, _) {
        final sway = math.sin(_swayController.value * math.pi * 2) * 0.04;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Ambient Circular Progress Gauge
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CircularGaugePainter(
                  progress: widget.isRunning ? widget.progress : 1.0,
                  isRunning: widget.isRunning,
                  isBreak: widget.isBreak,
                  accentColor: widget.isBreak
                      ? const Color(0xFFE5A93C)
                      : AppTheme.primary,
                ),
              ),

              // 2. Procedural Tree & Soil Canvas
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: CustomPaint(
                  size: Size(widget.size - 36, widget.size - 36),
                  painter: _TreeGrowthPainter(
                    growth: effectiveProgress,
                    sway: sway,
                    isBreak: widget.isBreak,
                    particles: _particles,
                    animValue: _swayController.value,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circular Progress Gauge Painter
// ─────────────────────────────────────────────────────────────────────────────
class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final bool isRunning;
  final bool isBreak;
  final Color accentColor;

  _CircularGaugePainter({
    required this.progress,
    required this.isRunning,
    required this.isBreak,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;

    // Track Paint
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: isRunning ? 0.08 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawCircle(center, radius, trackPaint);

    if (isRunning && progress > 0.001) {
      // Glow underlay
      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final sweepAngle = math.pi * 2 * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );

      // Active Gradient Arc
      final activePaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [
            accentColor.withValues(alpha: 0.6),
            accentColor,
            AppTheme.accentPurple,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );

      // Leading Head Particle
      final headAngle = -math.pi / 2 + sweepAngle;
      final headX = center.dx + radius * math.cos(headAngle);
      final headY = center.dy + radius * math.sin(headAngle);

      final headPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), 3.5, headPaint);
    } else if (!isRunning) {
      // Idle Notched / Dashed Aesthetic Track
      final tickPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      const tickCount = 24;
      for (int i = 0; i < tickCount; i++) {
        final angle = (i / tickCount) * math.pi * 2;
        final innerR = radius - 3.0;
        final outerR = radius + 3.0;

        final p1 = Offset(
          center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle),
        );
        final p2 = Offset(
          center.dx + outerR * math.cos(angle),
          center.dy + outerR * math.sin(angle),
        );

        canvas.drawLine(p1, p2, tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircularGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isRunning != isRunning ||
      oldDelegate.isBreak != isBreak ||
      oldDelegate.accentColor != accentColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tree Growth & Organic Foliage Painter
// ─────────────────────────────────────────────────────────────────────────────
class _TreeGrowthPainter extends CustomPainter {
  final double growth; // 0.0 to 1.0
  final double sway;
  final bool isBreak;
  final List<_FireflyParticle> particles;
  final double animValue;

  _TreeGrowthPainter({
    required this.growth,
    required this.sway,
    required this.isBreak,
    required this.particles,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseY = h * 0.86;
    final centerX = w * 0.5;

    // 1. Draw Bonsai Pot & Soil Mound
    _drawPotAndSoil(canvas, centerX, baseY, w, h);

    // 2. Draw Floating Spores / Fireflies (Active during break or high growth)
    if (isBreak || growth > 0.6) {
      _drawFireflies(canvas, centerX, baseY, w, h);
    }

    // 3. Draw Tree Trunk & Foliage based on growth level
    if (growth < 0.22) {
      // STAGE 1: Fresh Sprout
      _drawSprout(canvas, centerX, baseY, growth / 0.22);
    } else if (growth < 0.52) {
      // STAGE 2: Young Sapling
      final t = (growth - 0.22) / 0.30;
      _drawSapling(canvas, centerX, baseY, t);
    } else if (growth < 0.82) {
      // STAGE 3: Growing Bonsai
      final t = (growth - 0.52) / 0.30;
      _drawYoungBonsai(canvas, centerX, baseY, t);
    } else {
      // STAGE 4: Ancient Flourishing Bonsai
      final t = (growth - 0.82) / 0.18;
      _drawAncientBonsai(canvas, centerX, baseY, t);
    }
  }

  void _drawPotAndSoil(Canvas canvas, double cx, double cy, double w, double h) {
    // Ceramic Pot Base
    final potRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + 9),
        width: w * 0.46,
        height: 14,
      ),
      const Radius.circular(5),
    );

    final potPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF2D1D45),
          const Color(0xFF1E1230),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(potRect.outerRect);

    final potBorder = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(potRect, potPaint);
    canvas.drawRRect(potRect, potBorder);

    // Soil Mound
    final soilPath = Path()
      ..moveTo(cx - (w * 0.20), cy + 2)
      ..quadraticBezierTo(cx, cy - 6, cx + (w * 0.20), cy + 2)
      ..close();

    final soilPaint = Paint()
      ..color = const Color(0xFF34204D)
      ..style = PaintingStyle.fill;
    canvas.drawPath(soilPath, soilPaint);

    // Glowing amethyst flora highlights
    final mossPaint = Paint()
      ..color = const Color(0xFFA855F7).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 10, cy - 2), 4, mossPaint);
    canvas.drawCircle(Offset(cx + 8, cy - 1), 3.5, mossPaint);
  }

  void _drawFireflies(Canvas canvas, double cx, double cy, double w, double h) {
    for (final p in particles) {
      final floatY = math.sin(animValue * math.pi * 2 + p.phase) * 8.0;
      final px = cx + (p.x * w * 0.38);
      final py = (cy - (h * 0.4)) + (p.y * h * 0.35) + floatY;

      final pPaint = Paint()
        ..color = (isBreak ? const Color(0xFFFFD270) : const Color(0xFFD8B4FE))
            .withValues(alpha: p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(px, py), p.radius, pPaint);
    }
  }

  // Stage 1: Sprout
  void _drawSprout(Canvas canvas, double cx, double cy, double t) {
    final stemH = 22.0 * t;
    final topX = cx + (sway * 30);
    final topY = cy - stemH;

    final stemPaint = Paint()
      ..color = const Color(0xFFA78BFA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(cx, cy)
      ..quadraticBezierTo(cx + (sway * 15), cy - (stemH * 0.5), topX, topY);
    canvas.drawPath(stemPath, stemPaint);

    if (t > 0.3) {
      final leafScale = (t - 0.3) / 0.7;
      _drawLeaf(canvas, topX, topY, -0.6 + sway, 10 * leafScale);
      _drawLeaf(canvas, topX, topY, 0.6 + sway, 10 * leafScale);
    }
  }

  // Stage 2: Sapling
  void _drawSapling(Canvas canvas, double cx, double cy, double t) {
    final trunkH = 24.0 + (18.0 * t);
    final topX = cx + (sway * 45);
    final topY = cy - trunkH;

    final trunkPaint = Paint()
      ..color = const Color(0xFF4A2B75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final trunkPath = Path()
      ..moveTo(cx, cy)
      ..cubicTo(
        cx - 3,
        cy - (trunkH * 0.4),
        cx + 5 + (sway * 20),
        cy - (trunkH * 0.7),
        topX,
        topY,
      );
    canvas.drawPath(trunkPath, trunkPaint);

    // Left branch
    final bLeftX = cx - 14 + (sway * 30);
    final bLeftY = cy - (trunkH * 0.65);
    canvas.drawLine(
      Offset(cx, cy - (trunkH * 0.5)),
      Offset(bLeftX, bLeftY),
      trunkPaint..strokeWidth = 2.8,
    );

    // Foliage puffs
    _drawFoliageCloud(canvas, bLeftX, bLeftY, 12 + (6 * t));
    _drawFoliageCloud(canvas, topX + 6, topY + 2, 14 + (8 * t));
    _drawFoliageCloud(canvas, topX - 4, topY - 6, 16 + (8 * t));
  }

  // Stage 3: Young Bonsai
  void _drawYoungBonsai(Canvas canvas, double cx, double cy, double t) {
    final trunkH = 46.0 + (12.0 * t);
    final topX = cx + 6 + (sway * 55);
    final topY = cy - trunkH;

    final trunkPaint = Paint()
      ..color = const Color(0xFF3F2366)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final trunkPath = Path()
      ..moveTo(cx, cy)
      ..cubicTo(
        cx - 8,
        cy - (trunkH * 0.35),
        cx + 12 + (sway * 25),
        cy - (trunkH * 0.7),
        topX,
        topY,
      );
    canvas.drawPath(trunkPath, trunkPaint);

    // Branches
    final b1X = cx - 24 + (sway * 35);
    final b1Y = cy - (trunkH * 0.55);
    canvas.drawLine(
      Offset(cx - 2, cy - (trunkH * 0.45)),
      Offset(b1X, b1Y),
      trunkPaint..strokeWidth = 3.8,
    );

    final b2X = cx + 26 + (sway * 45);
    final b2Y = cy - (trunkH * 0.68);
    canvas.drawLine(
      Offset(cx + 6, cy - (trunkH * 0.60)),
      Offset(b2X, b2Y),
      trunkPaint..strokeWidth = 3.2,
    );

    // Lush foliage clouds
    _drawFoliageCloud(canvas, b1X, b1Y, 18 + (6 * t));
    _drawFoliageCloud(canvas, b2X, b2Y, 16 + (6 * t));
    _drawFoliageCloud(canvas, topX - 10, topY, 22 + (8 * t));
    _drawFoliageCloud(canvas, topX + 8, topY - 8, 20 + (8 * t));
  }

  // Stage 4: Ancient Flourishing Bonsai
  void _drawAncientBonsai(Canvas canvas, double cx, double cy, double t) {
    final trunkH = 58.0;
    final topX = cx + 8 + (sway * 65);
    final topY = cy - trunkH;

    // Gnarled, textured warm plum trunk
    final trunkPaint = Paint()
      ..color = const Color(0xFF381B5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round;

    final trunkPath = Path()
      ..moveTo(cx, cy)
      ..cubicTo(
        cx - 12,
        cy - (trunkH * 0.3),
        cx + 16 + (sway * 30),
        cy - (trunkH * 0.65),
        topX,
        topY,
      );
    canvas.drawPath(trunkPath, trunkPaint);

    // Primary branches
    final b1X = cx - 34 + (sway * 45);
    final b1Y = cy - (trunkH * 0.50);
    canvas.drawLine(
      Offset(cx - 4, cy - (trunkH * 0.40)),
      Offset(b1X, b1Y),
      trunkPaint..strokeWidth = 4.5,
    );

    final b2X = cx + 36 + (sway * 55);
    final b2Y = cy - (trunkH * 0.62);
    canvas.drawLine(
      Offset(cx + 8, cy - (trunkH * 0.55)),
      Offset(b2X, b2Y),
      trunkPaint..strokeWidth = 4.0,
    );

    final b3X = topX - 18;
    final b3Y = topY - 10;

    // Master Foliage Canopies with vibrant royal purple and luminous lilac highlights
    _drawFoliageCloud(canvas, b1X, b1Y, 24 + (4 * t), isMajestic: true);
    _drawFoliageCloud(canvas, b2X, b2Y, 22 + (4 * t), isMajestic: true);
    _drawFoliageCloud(canvas, b3X, b3Y, 26 + (4 * t), isMajestic: true);
    _drawFoliageCloud(canvas, topX + 12, topY - 14, 28 + (6 * t), isMajestic: true);
    _drawFoliageCloud(canvas, topX - 4, topY - 20, 30 + (6 * t), isMajestic: true);

    // Glowing Sakura / Violet Blossom Accents
    _drawBlossom(canvas, b1X + 4, b1Y - 6);
    _drawBlossom(canvas, b2X - 6, b2Y - 4);
    _drawBlossom(canvas, topX + 8, topY - 18);
    _drawBlossom(canvas, topX - 12, topY - 12);
  }

  void _drawLeaf(Canvas canvas, double x, double y, double angle, double size) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size * 0.5, -size * 0.4, size, 0)
      ..quadraticBezierTo(size * 0.5, size * 0.4, 0, 0)
      ..close();

    final leafPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFC084FC), Color(0xFF7C3AED)],
      ).createShader(Rect.fromLTWH(0, -size * 0.4, size, size * 0.8));

    canvas.drawPath(leafPath, leafPaint);
    canvas.restore();
  }

  void _drawFoliageCloud(
    Canvas canvas,
    double cx,
    double cy,
    double radius, {
    bool isMajestic = false,
  }) {
    // Underlay Shadow / Medium-Dark Violet
    final deepPaint = Paint()
      ..color = const Color(0xFF281342).withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy + 2), radius, deepPaint);

    // Vibrant Luminous Purple Main Body
    final mainPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          isMajestic ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
          const Color(0xFF4C1D95),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    canvas.drawCircle(Offset(cx - 2, cy - 2), radius * 0.9, mainPaint);

    // Radiant Lilac Crown Highlight
    final highlightPaint = Paint()
      ..color = (isBreak
              ? const Color(0xFFFFE082)
              : (isMajestic ? const Color(0xFFE9D5FF) : const Color(0xFFC084FC)))
          .withValues(alpha: 0.52);
    canvas.drawCircle(Offset(cx - 4, cy - 5), radius * 0.45, highlightPaint);
  }

  void _drawBlossom(Canvas canvas, double x, double y) {
    final blossomPaint = Paint()
      ..color = const Color(0xFFE879F9).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(Offset(x, y), 2.8, blossomPaint);

    final corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(x, y), 1.2, corePaint);
  }

  @override
  bool shouldRepaint(covariant _TreeGrowthPainter oldDelegate) =>
      oldDelegate.growth != growth ||
      oldDelegate.sway != sway ||
      oldDelegate.isBreak != isBreak ||
      oldDelegate.animValue != animValue;
}

class _FireflyParticle {
  double x;
  double y;
  double speed;
  double radius;
  double opacity;
  double phase;

  _FireflyParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.opacity,
    required this.phase,
  });
}
