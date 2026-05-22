import 'package:flutter/material.dart';

/// Design tokens for an animated glassmorphism canvas.
/// 
/// Provides pure, fully saturated solid colors and duration constants
/// meant to feed into an animation loop, CustomPainter, or fragment shader.
class AppAnimatedMeshTheme {
  AppAnimatedMeshTheme._();

  /// Deep space canvas background color.
  static const Color canvasColor = Color(0xFF030306);

  /// Base solid Orchid Purple color token for motion paths.
  static const Color purpleOrbBase = Color(0xFF9333EA);

  /// Base solid Electric Cyan color token for motion paths.
  static const Color cyanOrbBase = Color(0xFF06B6D4);

  /// Base solid Golden Amber color token for motion paths.
  static const Color amberOrbBase = Color(0xFFFBBF24);

  /// Maximum target opacity threshold for the purple animation layer.
  static const double purpleMaxOpacity = 0.35;

  /// Maximum target opacity threshold for the cyan animation layer.
  static const double cyanMaxOpacity = 0.20;

  /// Maximum target opacity threshold for the amber animation layer.
  static const double amberMaxOpacity = 0.15;

  /// Global ambient animation cycle duration for slow, organic drift.
  static const Duration orbitDuration = Duration(seconds: 12);

  /// Secondary animation cycle duration for independent scale pulsing.
  static const Duration pulseDuration = Duration(seconds: 7);

}