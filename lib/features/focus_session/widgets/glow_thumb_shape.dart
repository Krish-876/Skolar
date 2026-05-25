import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

class GlowThumbShape extends SliderComponentShape {
  const GlowThumbShape();

  static const double _thumbRadius = 9.0;
  static const double _glowRadius = 14.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_glowRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    canvas.drawCircle(
      center,
      _glowRadius,
      Paint()
        ..color = AppTheme.primary.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      _thumbRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }
}