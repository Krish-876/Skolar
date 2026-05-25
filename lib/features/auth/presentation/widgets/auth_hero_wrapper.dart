import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/core/widgets/animated_profile_gradient.dart';
import 'package:Skolar/features/auth/presentation/pages/auth_pages.dart';

/// Destination of the Hero flight from [OnboardingPage].
///
/// The [Hero] here expands the glass card to fill the screen.
/// Once the hero lands, [AuthScreen]'s content fades in on top.
class AuthHeroWrapper extends StatelessWidget {
  const AuthHeroWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── GIF background (same as onboarding, continuous playback) ──
        GlassBackground(
          child: Image.asset(
            'assets/images/space_bg.gif',
            fit: BoxFit.cover,
          ),
        ),

        // ── Hero card: expands from the onboarding card to full screen ──
        Hero(
          tag: 'auth_card',
          flightShuttleBuilder: _shuttleBuilder,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                // radiusXl so the shuttle tween ends cleanly
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
            ),
          ),
        ),

        // ── Auth content sits on top; AuthScreen manages its own fade-in ──
        const AuthScreen(),
      ],
    );
  }

  Widget _shuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final radiusTween = BorderRadiusTween(
      begin: BorderRadius.circular(40),
      end: BorderRadius.circular(AppTheme.radiusXl),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: radiusTween.evaluate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
          ),
        ),
      ),
    );
  }
}