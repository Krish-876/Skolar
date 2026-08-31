import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/auth/presentation/providers/auth_provider.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/auth_mode.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/auth_preview_sheet.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/drifting_circles.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/rocket_carryover.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/skolar_wordmark.dart';

export 'package:Skolar/features/auth/presentation/widgets/preview/auth_mode.dart'
    show AuthMode;

class AuthScreen extends ConsumerStatefulWidget {
  final AuthMode initialMode;

  const AuthScreen({super.key, this.initialMode = AuthMode.login});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  static const double _kHeroMinHeight = 160;
  static const double _kHeadlineTopReserve = 72;
  static const double _kSheetHardCapFraction = 0.68;

  late AuthMode _mode = widget.initialMode;
  String? _lastSubmittedEmail;
  bool _navigating = false;

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  late final AnimationController _ambientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  late final DriftProgress _circlesProgress = DriftProgress(
    entry: _entryCtrl,
    ambient: _ambientCtrl,
  );

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

  late final Animation<double> _wordmarkOpacity =
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.47, curve: Curves.easeOut),
        ),
      );

  late final Animation<double> _headlineOpacity =
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.23, 0.49, curve: Curves.easeOut),
        ),
      );

  late final Animation<Offset> _sheetSlide =
      Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.529, 1.0, curve: Curves.easeOutCubic),
        ),
      );

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

  void _onEmailSubmit(String email, String password) {
    _lastSubmittedEmail = email;
    // TODO: Switch to ref.read(authNotifierProvider.notifier).signIn / signUp when password auth is enabled
    ref.read(authNotifierProvider.notifier).sendMagicLink(email);
  }

  void _onGoogleTap() {
    ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  void _onForgotPassword(String initialEmail) {
    final emailCtrl = TextEditingController(text: initialEmail);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxxl),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppTheme.lg,
          AppTheme.lg,
          AppTheme.lg,
          MediaQuery.of(ctx).viewInsets.bottom + AppTheme.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Reset Password',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your college email and we will send you a password reset link.',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.onBackground2,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'you@bits-pilani.ac.in',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                prefixIcon: const Icon(
                  Icons.mail_outline,
                  color: AppTheme.accentPurple,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final email = emailCtrl.text.trim();
                  if (email.isNotEmpty) {
                    Navigator.pop(ctx);
                    ref
                        .read(authNotifierProvider.notifier)
                        .sendPasswordReset(email);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPurple,
                  foregroundColor: AppTheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  ),
                ),
                child: const Text(
                  'Send Reset Link',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onToggleMode(AuthMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
  }

  Future<bool> _isNewUser(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return true;
      final name = response['full_name'] as String?;
      return name == null || name.trim().isEmpty;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final safeTop = MediaQuery.paddingOf(context).top;
    final isLogin = _mode == AuthMode.login;
    final isSent = authState.status == AuthStatus.magicLinkSent;

    // Listen to error and success state
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(authNotifierProvider.notifier).reset();
      } else if (next.status == AuthStatus.passwordResetSent ||
          next.status == AuthStatus.authenticated) {
        if (next.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.successMessage!),
              backgroundColor: AppTheme.accentPurpleDark,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });

    // Listen to session stream and redirect
    ref.listen<AsyncValue<Session?>>(authSessionProvider, (_, next) {
      next.whenData((session) async {
        if (session == null || !mounted || _navigating) return;
        _navigating = true;
        final router = GoRouter.of(context);
        final isNew = await _isNewUser(session.user.id);
        if (!mounted) return;
        if (isNew) {
          router.go(AppRoutes.onboardingProfile);
        } else {
          router.go(AppRoutes.dashboard);
        }
      });
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          final heroMinHeight = _kHeroMinHeight + safeTop;
          final targetFraction = isSent ? 0.52 : (isLogin ? 0.55 : 0.65);
          final sheetMaxHeight = math.min(
            totalHeight * math.min(targetFraction, _kSheetHardCapFraction),
            math.max(totalHeight - heroMinHeight, 0.0),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              DriftingCircles(progress: _circlesProgress),
              IgnorePointer(
                child: FadeTransition(
                  opacity: _rocketOpacity,
                  child: ScaleTransition(
                    scale: _rocketScale,
                    child: const RocketCarryover(),
                  ),
                ),
              ),
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
                                  isSent
                                      ? "Check your\ninbox!"
                                      : (isLogin
                                          ? "Let's get you\nsigned in!"
                                          : 'Create your\naccount'),
                                  key: ValueKey('headline_${isSent}_$_mode'),
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
                        isLoading: authState.status == AuthStatus.loading,
                        isMagicLinkSent: isSent,
                        sentEmail: _lastSubmittedEmail,
                        onToggleMode: _onToggleMode,
                        onEmailSubmit: _onEmailSubmit,
                        onGoogleTap: _onGoogleTap,
                        onForgotPassword: _onForgotPassword,
                        onReset: () =>
                            ref.read(authNotifierProvider.notifier).reset(),
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
