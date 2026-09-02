import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/core/widgets/glass_background.dart';

/// A small motivational card sitting between the collapsible progress card
/// and the "All-Round Development" radar chart — just the looping CG-pull
/// Lottie behind a fixed caption, no interaction or state of its own.
class CgPullCard extends StatelessWidget {
  const CgPullCard({super.key});

  static const double _height = 140;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: GlassCard(
        borderRadius: 24,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DotLottieLoader.fromAsset(
              'assets/animations/CG_pull_bg.lottie',
              frameBuilder: (context, dotlottie) {
                if (dotlottie == null) return const SizedBox.shrink();
                return lottie.Lottie.memory(
                  dotlottie.animations.values.first,
                  fit: BoxFit.cover,
                  repeat: true,
                );
              },
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Text(
                'CG pull karna bhai utoooo',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'GoogleSans',
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
