import 'package:flutter/material.dart';

const String kRocketCarryoverAsset =
    'assets/animations/onboarding_first_frame.png';

/// The onboarding rocket's first-frame PNG, full-bleed, using the exact
/// widget structure the onboarding welcome page renders its background
/// with: ClipRect > SizedBox.expand > FittedBox(fit: BoxFit.fitHeight).
///
/// Shared verbatim (not re-implemented) between the welcome page and the
/// auth preview page so the image is pixel-identical at the instant the
/// two screens swap — same widget tree, not just matching code.
class RocketCarryover extends StatelessWidget {
  const RocketCarryover({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fitHeight,
          child: Image.asset(kRocketCarryoverAsset),
        ),
      ),
    );
  }
}
