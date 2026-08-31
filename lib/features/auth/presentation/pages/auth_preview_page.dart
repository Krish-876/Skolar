import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/auth_mode.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/auth_preview_sheet.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/drifting_circles.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/rocket_carryover.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/skolar_wordmark.dart';

export 'package:Skolar/features/auth/presentation/widgets/preview/auth_mode.dart'
    show AuthMode;

/// UI-only preview of a redesigned auth screen. No backend, no provider
/// wiring — every submit/social action is a debugPrint + SnackBar no-op.
class AuthPreviewPage extends StatefulWidget {
  final AuthMode initialMode;

  const AuthPreviewPage({super.key, this.initialMode = AuthMode.login});

  @override
  State<AuthPreviewPage> createState() => _AuthPreviewPageState();
}

class _AuthPreviewPageState extends State<AuthPreviewPage>
    with TickerProviderStateMixin {
  // Wordmark + two-line headline always need at least this much room in the
  // dark area (plus the top safe-area inset), regardless of what the sheet
  // wants — reserved first so the headline can never be squeezed off screen.
  static const double _kHeroMinHeight = 160;
  // Space reserved above the headline for the wordmark (AppTheme.xl top
  // padding + its own text height + a small gap) so the headline's Center
  // never creeps up underneath it. Must stay in sync with
  // SkolarWordmarkHeader's own padding/font size.
  static const double _kHeadlineTopReserve = 72;
  // Absolute ceiling on the sheet regardless of mode, beyond the per-mode
  // targets below — the sheet scrolls internally past this instead of
  // growing further.
  static const double _kSheetHardCapFraction = 0.68;

  late AuthMode _mode = widget.initialMode;

  // Drives the one-shot ~850ms entry sequence via Interval curves, strictly
  // staged: rocket/wordmark/circles/headline all finish by ~430ms so the
  // dark screen sits still and alone for a beat, then the sheet — the only
  // thing still moving from 450ms on — rises over the remaining ~400ms. The
  // rocket fade is deliberately slow (~400ms) so it still reads as "the
  // same screen" carrying over rather than a hand-off that just happened —
  // everything else was stretched to match so it still finishes first.
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  // Keeps the background alive with slow continuous drift after entry.
  late final AnimationController _ambientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  late final DriftProgress _circlesProgress = DriftProgress(
    entry: _entryCtrl,
    ambient: _ambientCtrl,
  );

  // The rocket carries over full-screen from the onboarding page (pixel-
  // identical at t=0, see RocketCarryover), then fades away slowly (~400ms)
  // to reveal the real auth background — slow enough that it still reads
  // as the same screen, not a page that just arrived. Scale is subtle —
  // it's a full-bleed image, not a small centered flourish, so a big shrink
  // would be jarring.
  late final Animation<double> _rocketOpacity = Tween<double>(begin: 1, end: 0)
      .animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.47, curve: Curves.easeOut),
        ),
      );

  late final Animation<double> _rocketScale =
      Tween<double>(begin: 1.0, end: 1.04).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.47, curve: Curves.easeOut),
        ),
      );

  // The carried-over PNG has its own 'skolar' wordmark baked into the
  // artwork (same asset the onboarding page shows), so SkolarWordmarkHeader
  // starts invisible and crossfades in on exactly the rocket's fade-out
  // window — otherwise the two wordmarks render on top of each other.
  late final Animation<double> _wordmarkOpacity =
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.47, curve: Curves.easeOut),
        ),
      );

  // Invisible at t=0 (the welcome page has no headline) — fades in as the
  // rocket clears, finished well before the sheet starts (~450ms) so
  // nothing is still settling when the sheet becomes the only thing moving.
  late final Animation<double> _headlineOpacity =
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.23, 0.49, curve: Curves.easeOut),
        ),
      );

  // The sheet: fully below the screen (Offset(0, 1.0) — 100% of its own
  // height) until it starts, a pure translate with no fade (a fade reads as
  // "appeared"; a translate reads as "came from somewhere"), starting once
  // everything else above has settled (~450ms in) and taking the remaining
  // ~400ms to decelerate into place. No bounce — it's heavy, it settles.
  late final Animation<Offset> _sheetSlide =
      Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.529, 1.0, curve: Curves.easeOutCubic),
        ),
      );

  // Named no-op callbacks, trivial to swap for real usecases later.

  // SWAP: wire to AuthProvider (send-magic-link / sign-in-with-password usecase)
  void onEmailSubmit(String email, String password) =>
      _fireAction(_mode == AuthMode.login ? 'Log in' : 'Sign up');

  void onGoogleTap() => _fireAction('Continue with Google');

  void onForgotPassword(String email) => _fireAction('Forgot password');

  // SWAP: this stays local UI state even after real usecases are wired in —
  // it only flips which form is shown, no request involved.
  void onToggleMode(AuthMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
  }

  void _fireAction(String action) {
    debugPrint('[AuthPreview] $action tapped');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action tapped'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(kRocketCarryoverAsset), context);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _ambientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final safeTop = MediaQuery.paddingOf(context).top;
    final isLogin = _mode == AuthMode.login;

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          final heroMinHeight = _kHeroMinHeight + safeTop;
          // Target ~45% dark / 55% sheet in Log In, sheet may grow to ~65%
          // in Sign Up — but the hero reservation above always wins if the
          // two conflict, and the hard cap below is the final ceiling.
          final targetFraction = isLogin ? 0.55 : 0.65;
          final sheetMaxHeight = math.min(
            totalHeight * math.min(targetFraction, _kSheetHardCapFraction),
            math.max(totalHeight - heroMinHeight, 0.0),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              DriftingCircles(progress: _circlesProgress),
              // Pixel-identical carryover from the onboarding welcome page
              // (same widget, see RocketCarryover) — fades away to reveal
              // the real auth background once the swap has landed.
              IgnorePointer(
                child: FadeTransition(
                  opacity: _rocketOpacity,
                  child: ScaleTransition(
                    scale: _rocketScale,
                    child: const RocketCarryover(),
                  ),
                ),
              ),
              // Crossfades in as the rocket artwork's own baked-in wordmark
              // fades out (see _wordmarkOpacity above) — from here on it's
              // the permanent wordmark, at a fixed offset from the top.
              FadeTransition(
                opacity: _wordmarkOpacity,
                child: const SkolarWordmarkHeader(),
              ),
              Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: _kHeadlineTopReserve,
                          bottom: AppTheme.lg,
                        ),
                        child: Center(
                          child: FadeTransition(
                            opacity: _headlineOpacity,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'GoogleSans',
                                color: AppTheme.onBackground,
                                fontWeight: FontWeight.bold,
                                fontSize: keyboardOpen ? 18 : 24,
                                height: 1.25,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  isLogin
                                      ? "Let's get you\nsigned in!"
                                      : 'Create your\naccount',
                                  key: ValueKey(_mode),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: sheetMaxHeight),
                    child: SlideTransition(
                      position: _sheetSlide,
                      child: AuthPreviewSheet(
                        mode: _mode,
                        onToggleMode: onToggleMode,
                        onEmailSubmit: onEmailSubmit,
                        onGoogleTap: onGoogleTap,
                        onForgotPassword: onForgotPassword,
                        onReset: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
