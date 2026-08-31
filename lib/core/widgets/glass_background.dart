import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_static_mesh_theme.dart';
import 'package:Skolar/core/theme/app_theme.dart';

/// A reusable background widget that creates a moody, mesh-gradient effect
/// with purple and teal glows as seen in the reference image.
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStaticMeshTheme.background, // Base dark background
      body: Stack(
        children: [
          // 1. Top-Left Purple Glow
          Positioned(
            top: -200,
            left: -120,
            child: _GlowBlob(
              size: 450,
              color: AppStaticMeshTheme.purple.withValues(alpha: 0.55),
            ),
          ),

          // 2. Middle-Right Deep Indigo Glow
          Positioned(
            top: 80,
            right: -300,
            child: _GlowBlob(
              size: 500,
              color: AppStaticMeshTheme.deepBlue.withValues(alpha: 0.4),
            ),
          ),

          // 3. Bottom-Center Teal/Cyan Glow
          Positioned(
            bottom: -100,
            left: -50,
            child: _GlowBlob(
              size: 400,
              color: AppStaticMeshTheme.lightblue.withValues(alpha: 0.3),
            ),
          ),

          // 4. The Content (passed as child)
          SafeArea(child: child),
        ],
      ),
    );
  }
}

/// Helper widget to create soft, circular light leaks
class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}

/// A Glassmorphism card widget that blurs the background glows.
/// Matches the central element in your reference image.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  /// `BackdropFilter` re-samples and re-blurs whatever's behind this card on
  /// every single frame its on-screen position changes — not because the
  /// card's own content changed, but because the blur is a function of the
  /// pixels currently behind it, which are different at a new position. A
  /// card sitting directly below something whose *height* is animating
  /// (e.g. a header growing/shrinking above it in the same scroll view)
  /// therefore repositions and re-blurs every frame of that animation, which
  /// is real, measurable compositing cost for a purely cosmetic effect
  /// nobody can appreciate mid-motion anyway. Callers in exactly that
  /// situation can set this to `false` for the animation's duration to skip
  /// the blur (falling back to the same flat tint/border, no
  /// `BackdropFilter`) and restore it once things settle.
  final bool enableBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 32,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: enableBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: content,
            )
          : content,
    );
  }
}
