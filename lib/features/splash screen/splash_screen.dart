import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;

class SnapScrollPhysics extends ScrollPhysics {
  const SnapScrollPhysics({super.parent});

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      SnapScrollPhysics(parent: buildParent(ancestor));

  // After a drag ends, snap to nearest boundary
  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final max = position.maxScrollExtent;
    if (max <= 0) return null;

    final current = position.pixels;
    final progress = current / max;

    // Decide target: fling velocity overrides threshold
    double target;
    if (velocity < -500) {
      target = 0.0;       // fast fling upward → snap to top
    } else if (velocity > 500) {
      target = max;       // fast fling downward → snap to bottom
    } else if (progress >= 0.5) {
      target = max;       // past halfway → snap to bottom
    } else {
      target = 0.0;       // before halfway → snap back to top
    }

    if ((current - target).abs() < 0.5) return null; // already there

    return ScrollSpringSimulation(
      SpringDescription.withDampingRatio(
        mass: 1.0,
        stiffness: 120.0,
        ratio: 1.1, // slightly overdamped — no bounce
      ),
      current,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  // Prevent ballistic scroll from carrying past the edges
  @override
  bool get allowImplicitScrolling => false;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _arcMove;
  late Animation<double> _arcFade;
  late Animation<double> _contentFade;

  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _arcMove = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );

    _arcFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.28, curve: Curves.easeIn),
    );

    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.85, curve: Curves.easeOut),
    );

    _controller.forward();

    _scrollController.addListener(() {
      final max = _scrollController.position.maxScrollExtent;
      if (max > 0) {
        setState(() {
          _scrollProgress = (_scrollController.offset / max).clamp(0.0, 1.0);
          _scrollOffset = _scrollController.offset;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _snapToBottom() {
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      max,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ArcGlowPainter(
                      arcMove: _arcMove.value,
                      arcFade: _arcFade.value,
                      scrollProgress: _scrollProgress,
                      scrollOffset: _scrollOffset,
                    ),
                  ),
                ),
              ),

              SingleChildScrollView(
                controller: _scrollController,
                physics: const SnapScrollPhysics(),
                child: SizedBox(
                  height: h * 2.0,
                  child: SafeArea(
                    child: Opacity(
                      opacity: _contentFade.value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - _contentFade.value)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 72),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Color(0xFF6B8EFF),
                                            Color(0xFF2A50D9),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'AI Assistant',
                                      style: TextStyle(
                                        fontFamily: 'GoogleSans',
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: h * 0.2),

                              Text(
                                'AI Powered',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'GoogleSans',
                                  color: Colors.white.withOpacity(0.48),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.5,
                                  height: 1.15,
                                ),
                              ),
                              const Text(
                                'Habit Tracking\nSystem',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'GoogleSans',
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.0,
                                  height: 1.2,
                                ),
                              ),

                              const SizedBox(height: 20),

                              Text(
                                'AI Helps You Capture, Organize, And Retrieve\nNotes Quickly And Efficiently.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'GoogleSans',
                                  color: Colors.white.withOpacity(0.42),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  height: 1.65,
                                  letterSpacing: 0.1,
                                ),
                              ),

                              const SizedBox(height: 40),

                              GestureDetector(
                                onTap: _snapToBottom,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.20),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontFamily: 'GoogleSans',
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter — bitmap-cached arc glow, zero dome fill, no per-frame blur cost
// ---------------------------------------------------------------------------

class ArcGlowPainter extends CustomPainter {
  final double arcMove;
  final double arcFade;
  final double scrollProgress;
  final double scrollOffset;

  ArcGlowPainter({
    required this.arcMove,
    required this.arcFade,
    required this.scrollProgress,
    required this.scrollOffset,
  });

  // ── Shared bitmap cache ──────────────────────────────────────────────────
  static ui.Image? _bottomBitmap;
  static ui.Image? _topBitmap;
  static Size _bitmapSize = Size.zero;
  static bool _rasterizing = false;

  // The arc peak sits at this fixed Y inside the bitmap.
  // Enough headroom above (for upward glow) and below (for downward glow).
  static const double _peakInBitmap = 300.0;
  // Total bitmap height: 300 above peak + 300 below = 600 px tall strip.
  static const double _bitmapHeight = 600.0;

  static const _glowLayers = [
    (80.0, 40.0, Color(0xFF1A3BFF), 0.18),
    (48.0, 24.0, Color(0xFF3060FF), 0.35),
    (28.0, 14.0, Color(0xFF5585FF), 0.55),
    (12.0,  6.0, Color(0xFF88AAFF), 0.75),
    ( 4.0,  2.0, Color(0xFFCCDDFF), 0.90),
    ( 1.5,  0.0, Color(0xFFFFFFFF), 0.60),
  ];

  // ── Arc path (open curve, not filled) ────────────────────────────────────
  // [flipped=false] → normal arc, edges drop below peak (bottom arc).
  // [flipped=true]  → inverted arc, edges rise above peak (top arc).
  static Path _buildArcPath(double w, double screenH, bool flipped) {
    final double cx = w / 2;
    final double ax = w * 1.35;
    final double edgeDrop = screenH * 0.065;
    final double pull = w * 1.6;
    const double peakY = _peakInBitmap;

    final Path path = Path();
    if (!flipped) {
      path.moveTo(-ax, peakY + edgeDrop);
      path.cubicTo(-ax + pull, peakY + edgeDrop, cx - pull * 0.28, peakY, cx, peakY);
      path.cubicTo(cx + pull * 0.28, peakY, ax + w - pull, peakY + edgeDrop, ax + w, peakY + edgeDrop);
    } else {
      path.moveTo(-ax, peakY - edgeDrop);
      path.cubicTo(-ax + pull, peakY - edgeDrop, cx - pull * 0.28, peakY, cx, peakY);
      path.cubicTo(cx + pull * 0.28, peakY, ax + w - pull, peakY - edgeDrop, ax + w, peakY - edgeDrop);
    }
    return path;
  }

  // ── Rasterize a single arc + hotspot into a bitmap strip ─────────────────
  static Future<ui.Image> _rasterizeArc(Size screenSize, bool flipped) async {
    final double w = screenSize.width;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w, _bitmapHeight),
    );

    final arcPath = _buildArcPath(w, screenSize.height, flipped);
    const double peakY = _peakInBitmap;

    // Glow layers — all blur happens here, once, offline
    for (final (strokeW, blur, color, colOpacity) in _glowLayers) {
      final shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(colOpacity),
          color.withOpacity(colOpacity),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.18, 0.82, 1.0],
      ).createShader(Rect.fromLTWH(0, peakY - 80, w, 160));

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..shader = shader;

      if (blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      }

      canvas.drawPath(arcPath, paint);
    }

    // Hotspot bloom at peak center
    final cx = w / 2;
    final hotspotCenter = Offset(cx, peakY);
    final hotspotPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.25),
          const Color(0xFF5585FF).withOpacity(0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: hotspotCenter, radius: w * 0.35));
    canvas.drawCircle(hotspotCenter, w * 0.35, hotspotPaint);

    final picture = recorder.endRecording();
    return picture.toImage(w.ceil(), _bitmapHeight.ceil());
  }

  // ── Cache management ──────────────────────────────────────────────────────
  static void _ensureBitmaps(Size size, VoidCallback onReady) {
    if (_bitmapSize == size && _bottomBitmap != null && _topBitmap != null) {
      return;
    }
    if (_rasterizing) return;
    _rasterizing = true;

    Future.wait([
      _rasterizeArc(size, false), // bottom (normal)
      _rasterizeArc(size, true),  // top (flipped)
    ]).then((images) {
      _bottomBitmap = images[0];
      _topBitmap    = images[1];
      _bitmapSize   = size;
      _rasterizing  = false;
      onReady();
    });
  }

  // ── Paint ─────────────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    if (arcFade <= 0) return;

    _ensureBitmaps(size, () {
      SchedulerBinding.instance.scheduleFrame();
    });

    if (_bottomBitmap == null || _topBitmap == null) return;

    final double h = size.height;
    final double meetY  = h * 0.30;
    final double travel = h * 0.1;
    const double restGap = 0.1;
    final double bottomPeakY = (meetY + travel) - travel * arcMove + restGap - scrollOffset;
    final double topPeakY    = (meetY - travel) + travel * arcMove - restGap - scrollOffset;
    final double topOpacity  = (1.0 - scrollProgress * 5.0).clamp(0.0, 1.0);

    // Single GPU blit per arc — offset so bitmap's _peakInBitmap aligns with
    // the desired on-screen peakY. No blur, no shader, zero per-frame cost.
    canvas.drawImage(
      _bottomBitmap!,
      Offset(0, bottomPeakY - _peakInBitmap),
      Paint()..color = Colors.white.withOpacity(arcFade),
    );

    if (topOpacity > 0) {
      canvas.drawImage(
        _topBitmap!,
        Offset(0, topPeakY - _peakInBitmap),
        Paint()..color = Colors.white.withOpacity(arcFade * topOpacity),
      );
    }

    // Bottom fade-in light glow gradient — scrolls upward with the page
    final bottomGlowOpacity = arcFade;
    if (bottomGlowOpacity > 0) {
      // Shift the gradient top up as the user scrolls so it leads the
      // page-transition like a glowing edge moving to the top.
      final double glowTop = h * 0.75 - scrollOffset;
      // Grow the rect height so it always fills to the bottom of the screen
      final double glowHeight = h * 0.45 + scrollOffset;
      // Extend rect well past both edges to guarantee true edge-to-edge fill
      final bottomGlowRect = Rect.fromLTWH(-size.width, glowTop, size.width * 3, glowHeight);
      final bottomGlowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF1A3BFF).withOpacity(0.14 * bottomGlowOpacity),
            const Color(0xFF3060FF).withOpacity(0.28 * bottomGlowOpacity),
            const Color(0xFF5585FF).withOpacity(0.42 * bottomGlowOpacity),
          ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ).createShader(bottomGlowRect);
      canvas.drawRect(bottomGlowRect, bottomGlowPaint);
    }
  }

  @override
  bool shouldRepaint(ArcGlowPainter old) =>
      old.arcMove        != arcMove        ||
      old.arcFade        != arcFade        ||
      old.scrollProgress != scrollProgress ||
      old.scrollOffset   != scrollOffset;
}