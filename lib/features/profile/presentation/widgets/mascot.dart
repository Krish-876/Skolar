library;

import 'package:flutter/material.dart';

class MascotAvatar extends StatefulWidget {
  /// Path to the mascot image asset.
  /// If null, the built-in owl placeholder is rendered.
  final String? assetPath;

  /// Width and height of the avatar box (square).
  final double size;

  /// Whether to animate the glow pulse.
  final bool animated;

  const MascotAvatar({
    super.key,
    this.assetPath,
    this.size = 76,
    this.animated = true,
  });

  @override
  State<MascotAvatar> createState() => _MascotAvatarState();
}

class _MascotAvatarState extends State<MascotAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.animated) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MascotAvatar old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    if (!widget.animated && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final glow = _ctrl.value;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.size * 0.26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A3A8C), Color(0xFF2A1F5C)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF7B5EEF,
                ).withValues(alpha: 0.30 + glow * 0.25),
                blurRadius: 16 + glow * 10,
                spreadRadius: glow * 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.26),
        child: widget.assetPath != null
            ? Image.asset(widget.assetPath!, fit: BoxFit.cover)
            : _OwlPlaceholder(size: widget.size),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Built-in owl placeholder
// ─────────────────────────────────────────────
class _OwlPlaceholder extends StatelessWidget {
  final double size;
  const _OwlPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF6B4FCC), Color(0xFF2A1F5C)],
              radius: 0.85,
            ),
          ),
        ),
        CustomPaint(
          size: Size(size * 0.78, size * 0.78),
          painter: _OwlPainter(),
        ),
        // Camera icon badge
        Positioned(
          bottom: size * 0.05,
          right: size * 0.05,
          child: Container(
            width: size * 0.24,
            height: size * 0.24,
            decoration: BoxDecoration(
              color: const Color(0xFF7B5EEF),
              borderRadius: BorderRadius.circular(size * 0.07),
            ),
            child: Icon(
              Icons.add_a_photo_outlined,
              size: size * 0.13,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _OwlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final body = Paint()..color = const Color(0xFF7B5EEF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.06),
          width: size.width * 0.54,
          height: size.height * 0.56,
        ),
        Radius.circular(size.width * 0.23),
      ),
      body,
    );

    final ear = Paint()..color = const Color(0xFF6040BB);
    for (final dx in [-0.17, 0.17]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + dx * size.width, cy - size.height * 0.2),
            width: size.width * 0.17,
            height: size.height * 0.2,
          ),
          Radius.circular(size.width * 0.06),
        ),
        ear,
      );
    }

    final eyeWhite = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFF1A1040);
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.9);

    for (final dx in [-0.12, 0.12]) {
      final ex = cx + dx * size.width;
      const ey = 0.46;
      canvas.drawCircle(Offset(ex, cy * ey * 2), size.width * 0.11, eyeWhite);
      canvas.drawCircle(Offset(ex, cy * ey * 2), size.width * 0.06, pupil);
      canvas.drawCircle(
        Offset(ex + size.width * 0.025, cy * ey * 2 - size.height * 0.025),
        size.width * 0.02,
        shine,
      );
    }

    final beak = Paint()..color = const Color(0xFFFFB74D);
    final beakPath = Path()
      ..moveTo(cx, cy * 1.02)
      ..lineTo(cx - size.width * 0.05, cy * 0.94)
      ..lineTo(cx + size.width * 0.05, cy * 0.94)
      ..close();
    canvas.drawPath(beakPath, beak);
  }

  @override
  bool shouldRepaint(_OwlPainter old) => false;
}
