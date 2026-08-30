import 'package:flutter/material.dart';

/// Convex dome wipe: a full-width semicircular leading edge (radius =
/// screenWidth / 2, so it meets both screen edges with no seam) sweeping
/// vertically across the screen.
///
/// [domeUp] true sweeps a convex dome bottom-to-top, filling toward the top
/// (dome points up); false sweeps top-to-bottom, dome pointing down.
/// Renders no content of its own — it only computes the clip path. Callers
/// clip whatever they like with it (typically a full clone of the screen's
/// own body in a different palette).
class PhaseWipeClipper extends CustomClipper<Path> {
  final double progress;
  final bool domeUp;

  PhaseWipeClipper({required this.progress, required this.domeUp});

  @override
  Path getClip(Size size) {
    final double radius = size.width / 2;
    // Both directions travel the same distance: the apex starts flush with
    // the leading screen edge (a zero-area sliver) and reaches exactly full
    // screen coverage at progress == 1.
    final double travel = size.height + radius;

    final path = Path();

    if (domeUp) {
      // Filled region grows from the bottom, leading edge bulging upward.
      // centerY: height+radius (apex flush with bottom edge) -> 0 (full cover).
      final double centerY = (size.height + radius) - progress * travel;
      path.moveTo(0, size.height);
      path.lineTo(0, centerY);
      path.arcToPoint(
        Offset(size.width, centerY),
        radius: Radius.circular(radius),
        clockwise: true,
      );
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      // Filled region grows from the top, leading edge bulging downward.
      // centerY: -radius (apex flush with top edge) -> size.height (full cover).
      final double centerY = -radius + progress * travel;
      path.moveTo(0, 0);
      path.lineTo(0, centerY);
      path.arcToPoint(
        Offset(size.width, centerY),
        radius: Radius.circular(radius),
        clockwise: false,
      );
      path.lineTo(size.width, 0);
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant PhaseWipeClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.domeUp != domeUp;
  }
}
