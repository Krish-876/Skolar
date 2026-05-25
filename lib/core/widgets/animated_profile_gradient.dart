import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_static_mesh_theme.dart';

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
              color: AppStaticMeshTheme.purple.withOpacity(0.55),
            ),
          ),

          // 2. Middle-Right Deep Indigo Glow
          Positioned(
            top: 80,
            right: -300,
            child: _GlowBlob(
              size: 500,
              color: AppStaticMeshTheme.deepBlue.withOpacity(0.4),
            ),
          ),

          // 3. Bottom-Center Teal/Cyan Glow
          Positioned(
            bottom: -100,
            left: -50,
            child: _GlowBlob(
              size: 400,
              color: AppStaticMeshTheme.lightblue.withOpacity(0.3),
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
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

/// A Glassmorphism card widget that blurs the background glows.
/// Matches the central element in your reference image.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 32,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}