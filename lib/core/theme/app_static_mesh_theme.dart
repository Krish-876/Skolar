import 'package:flutter/material.dart';

/// Design tokens for a static glassmorphism UI layout.
///
/// Contains pre-blended opacities perfectly balanced for layered static
/// background blobs against a deep dark canvas.
class AppStaticMeshTheme {
  AppStaticMeshTheme._();

  /// Base canvas background — ultra dark slate-indigo.
  static const Color background = Color(0xFF030306);

  /// Top-Left glow color — Orchid Purple at 35% opacity.
  static const Color topLeftGlow = Color(0x599333EA); // 0x59 = 35% Opacity

  /// Middle-Right glow color — Electric Cyan at 20% opacity.
  static const Color middleRightGlow = Color(0x3306B6D4); // 0x33 = 20% Opacity

  /// Bottom-Center glow color — Golden Amber at 15% opacity.
  static const Color bottomCenterGlow = Color(0x26FBBF24); // 0x26 = 15% Opacity

  /// High-contrast text, primary buttons, or crisp borders.
  static const Color onBackground = Color(0xFFFFFFFF);

  /// Dimmed text, secondary icons, and disabled states.
  static const Color onBackgroundDimmed = Color(0x99FFFFFF); // 60% Opacity

  /// Glass container fill color — subtle white tint.
  static const Color glassSurface = Color(0x08FFFFFF); // 3% Opacity

  /// Crisp, sharp glass container perimeter line.
  static const Color glassBorder = Color(0x14FFFFFF); // 8% Opacity

  /// Standard glass blur strength for the backdrop filter.
  static const double glassBlurSigma = 25.0;

  /// Semantic UI shortcuts
  static const Color deepBlue = Color(0xFF3416E2);
  static const Color purple = Color(0xFF5E1B89);
  static const Color lightblue = Color(0xFF00D4FF);
}
