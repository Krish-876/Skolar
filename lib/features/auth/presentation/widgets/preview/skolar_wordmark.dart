import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

/// The 'skolar' wordmark, pinned to a fixed offset from the top of the
/// screen via [Positioned] (requires a [Stack] ancestor).
///
/// Only rendered on the auth preview page. The onboarding welcome page
/// doesn't need its own copy — RocketCarryover's PNG already has a 'skolar'
/// wordmark baked into the artwork near this same position, so on the auth
/// page this widget starts invisible and crossfades in exactly as that
/// artwork fades out (see AuthPreviewPage._wordmarkOpacity). Rendering it on
/// the welcome page too would double it up on top of the baked-in one.
class SkolarWordmarkHeader extends StatelessWidget {
  const SkolarWordmarkHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: AppTheme.xl),
          child: Center(
            child: Text(
              'skolar',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.accentPurple,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
