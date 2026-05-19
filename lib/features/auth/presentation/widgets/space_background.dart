
// ═════════════════════════════════════════════════════════════════════════════
// SPACE BACKGROUND
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────

import 'dart:math';

import 'package:flutter/material.dart';

class _Star {
  double x, y;
  final double size;
  final double baseOpacity;
  double twinklePhase;
  final double twinkleSpeed;
  final double driftX;
  final double driftY;
  final double depth; // 0 = far/slow, 1 = close/fast

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.baseOpacity,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.driftX,
    required this.driftY,
    required this.depth,
  });
}

class _ShootingStar {
  double x = 0, y = 0;
  double angle = 0;
  double speed = 0;
  double trailLength = 0;
  double progress = 0;
  double opacity = 0;
  bool active = false;

  _ShootingStar.inactive();

  void spawn(Random rng) {
    final fromTop = rng.nextBool();
    x = fromTop ? rng.nextDouble() * 0.8 : rng.nextDouble() * 0.1;
    y = fromTop ? rng.nextDouble() * 0.15 : rng.nextDouble() * 0.5;
    angle = -(0.26 + rng.nextDouble() * 0.44);
    speed = rng.nextDouble() * 0.28 + 0.22;
    trailLength = rng.nextDouble() * 0.12 + 0.14;
    opacity = rng.nextDouble() * 0.3 + 0.7;
    progress = 0;
    active = true;
  }
}

class _NebulaPulse {
  final Offset center;
  final double radius;
  final Color color;
  double phase;
  final double speed;

  _NebulaPulse({
    required this.center,
    required this.radius,
    required this.color,
    required this.phase,
    required this.speed,
  });
}

// ─────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────

class SpaceBackground extends StatefulWidget {
  final Widget child;
  const SpaceBackground({super.key, required this.child});

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();

  static const int _farCount  = 80;
  static const int _midCount  = 50;
  static const int _nearCount = 25;
  late final List<_Star> _stars;

  static const int _poolSize = 5;
  late final List<_ShootingStar> _pool;
  double _nextShoot = 0;
  static const double _minInterval = 1.2;
  static const double _maxInterval = 3.5;

  late final List<_NebulaPulse> _nebulae;
  double _prevTime = 0;

  @override
  void initState() {
    super.initState();

    _stars = [
      ..._makeStarLayer(_farCount,
          depthMin: 0.0,  depthMax: 0.30,
          sizeMin:  0.3,  sizeMax:  0.9,
          opMin:    0.20, opMax:    0.55,
          driftScale: 8),
      ..._makeStarLayer(_midCount,
          depthMin: 0.30, depthMax: 0.65,
          sizeMin:  0.8,  sizeMax:  1.6,
          opMin:    0.40, opMax:    0.75,
          driftScale: 18),
      ..._makeStarLayer(_nearCount,
          depthMin: 0.65, depthMax: 1.0,
          sizeMin:  1.5,  sizeMax:  2.8,
          opMin:    0.65, opMax:    1.0,
          driftScale: 34),
    ];

    _pool = List.generate(_poolSize, (_) => _ShootingStar.inactive());
    _nextShoot = _rng.nextDouble() * 1.5 + 0.5;

    _nebulae = [
      _NebulaPulse(center: const Offset(0.18, 0.14), radius: 0.58,
          color: const Color(0xFF1A0A6E), phase: 0,   speed: 0.40),
      _NebulaPulse(center: const Offset(0.78, 0.42), radius: 0.52,
          color: const Color(0xFF3D0B70), phase: 1.0, speed: 0.28),
      _NebulaPulse(center: const Offset(0.45, 0.88), radius: 0.48,
          color: const Color(0xFF0B1A55), phase: 2.2, speed: 0.35),
      _NebulaPulse(center: const Offset(0.88, 0.08), radius: 0.38,
          color: const Color(0xFF062040), phase: 3.5, speed: 0.50),
    ];

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..repeat();

    _ctrl.addListener(_onTick);
  }

  List<_Star> _makeStarLayer(
    int count, {
    required double depthMin, required double depthMax,
    required double sizeMin,  required double sizeMax,
    required double opMin,    required double opMax,
    required double driftScale,
  }) {
    return List.generate(count, (_) {
      final depth = depthMin + _rng.nextDouble() * (depthMax - depthMin);
      return _Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: sizeMin + _rng.nextDouble() * (sizeMax - sizeMin),
        baseOpacity: opMin + _rng.nextDouble() * (opMax - opMin),
        twinklePhase: _rng.nextDouble() * 2 * pi,
        twinkleSpeed: 0.4 + depth * 2.2,
        driftX: (_rng.nextDouble() - 0.5) * driftScale,
        driftY: (_rng.nextDouble() - 0.3) * driftScale * 0.6,
        depth: depth,
      );
    });
  }

  void _onTick() {
    final us = _ctrl.lastElapsedDuration?.inMicroseconds ?? 0;
    final elapsed = us / 1e6;
    final dt = (elapsed - _prevTime).clamp(0.0, 0.05);
    _prevTime = elapsed;
    if (dt <= 0) return;

    _nextShoot -= dt;
    if (_nextShoot <= 0) {
      _spawnShooter();
      _nextShoot = _minInterval + _rng.nextDouble() * (_maxInterval - _minInterval);
    }

    setState(() {
      for (final n in _nebulae) {
        n.phase += n.speed * dt;
      }
      for (final s in _stars) {
        s.twinklePhase += s.twinkleSpeed * dt;
        final speedMult = 0.3 + s.depth * 1.4;
        s.x += s.driftX * dt * speedMult / 400;
        s.y += s.driftY * dt * speedMult / 800;
        if (s.x > 1) s.x -= 1;
        if (s.x < 0) s.x += 1;
        if (s.y > 1) s.y -= 1;
        if (s.y < 0) s.y += 1;
      }
      for (final s in _pool) {
        if (!s.active) continue;
        s.progress += s.speed * dt;
        if (s.progress >= 1.3) s.active = false;
      }
    });
  }

  void _spawnShooter() {
    final burst = _rng.nextDouble() < 0.2 ? 2 : 1;
    var spawned = 0;
    for (final s in _pool) {
      if (!s.active && spawned < burst) {
        s.spawn(_rng);
        spawned++;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SpacePainter(
                stars: _stars,
                shooters: _pool,
                nebulae: _nebulae,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────

class _SpacePainter extends CustomPainter {
  final List<_Star> stars;
  final List<_ShootingStar> shooters;
  final List<_NebulaPulse> nebulae;

  _SpacePainter({
    required this.stars,
    required this.shooters,
    required this.nebulae,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    _drawNebulae(canvas, size);
    _drawStars(canvas, size);
    _drawShooters(canvas, size);
  }

  void _drawBg(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF04050E),
            Color(0xFF080920),
            Color(0xFF0E0B28),
            Color(0xFF060418),
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawNebulae(Canvas canvas, Size size) {
    for (final n in nebulae) {
      final breathe = sin(n.phase);
      final r = n.radius * size.width * (1.0 + breathe * 0.15);
      final baseAlpha = (n.color.a / 255.0);
      final alpha = (baseAlpha * (1.0 + breathe * 0.20)).clamp(0.0, 1.0);
      final center = Offset(n.center.dx * size.width, n.center.dy * size.height);

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              n.color.withValues(alpha: alpha),
              n.color.withValues(alpha: alpha * 0.4),
              n.color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r))
          ..blendMode = BlendMode.screen,
      );
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;

    for (final s in stars) {
      final twinkleAmp = 0.15 + s.depth * 0.30;
      final twinkle = sin(s.twinklePhase) * twinkleAmp;
      final op = (s.baseOpacity + twinkle).clamp(0.0, 1.0);
      final px = s.x * size.width;
      final py = s.y * size.height;

      // Near stars get a corona glow
      if (s.depth > 0.55) {
        canvas.drawCircle(
          Offset(px, py),
          s.size * 2.8,
          Paint()
            ..color = Colors.white.withValues(alpha: op * 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
        );
      }

      p.color = Colors.white.withValues(alpha: op);
      canvas.drawCircle(Offset(px, py), s.size, p);
    }
  }

  void _drawShooters(Canvas canvas, Size size) {
    for (final s in shooters) {
      if (!s.active) continue;

      final dist = size.width * 1.5;
      final hx = s.x * size.width  + cos(s.angle) * dist * s.progress;
      final hy = s.y * size.height + sin(s.angle) * dist * s.progress;
      final trailPx = size.width * s.trailLength;
      final tx = hx - cos(s.angle) * trailPx;
      final ty = hy - sin(s.angle) * trailPx;

      final fadeIn  = (s.progress * 6).clamp(0.0, 1.0);
      final fadeOut = (1.0 - (s.progress - 0.75) * 4).clamp(0.0, 1.0);
      final alpha   = fadeIn * fadeOut * s.opacity;
      if (alpha <= 0.01) continue;

      // Glow trail (soft, wide)
      canvas.drawLine(
        Offset(tx, ty),
        Offset(hx, hy),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: alpha * 0.25),
              Colors.white.withValues(alpha: alpha * 0.60),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromPoints(Offset(tx, ty), Offset(hx, hy)))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );

      // Sharp core trail
      canvas.drawLine(
        Offset(tx, ty),
        Offset(hx, hy),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: alpha * 0.85),
            ],
          ).createShader(Rect.fromPoints(Offset(tx, ty), Offset(hx, hy)))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );

      // Bright head flare
      canvas.drawCircle(
        Offset(hx, hy),
        2.8,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }

  @override
  bool shouldRepaint(_SpacePainter old) => true;
}

// ═════════════════════════════════════════════════════════════════════════════
// ONBOARDING PAGE
// ═════════════════════════════════════════════════════════════════════════════

class _StepData {
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;

  const _StepData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
  });
}

const _steps = [
  _StepData(
    eyebrow: 'Welcome to Nova',
    title: 'Learn better,\nRemember longer\nAchieve higher!',
    body:
        'Discover a next-gen platform that blends AI, gamification, and collaboration to make studying interactive, efficient, and fun.',
    icon: Icons.auto_awesome_rounded,
  ),
  _StepData(
    eyebrow: 'Our features',
    title: 'Only platform u need to gear up your study game!',
    body:
        'Upload notes · AI summaries · Flashcards & quizzes · Chat with notes · Audio lessons · Real-time study battles · Leaderboards',
    icon: Icons.rocket_launch_rounded,
  ),
  _StepData(
    eyebrow: 'Community',
    title: 'Making learning fun and competitive!',
    body:
        "Exes break your heart, Nova breaks down your notes… and actually shows up on time.",
    icon: Icons.emoji_events_rounded,
  ),
];

