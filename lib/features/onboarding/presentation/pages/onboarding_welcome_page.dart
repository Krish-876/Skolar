import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/auth_mode.dart';
import 'package:Skolar/features/auth/presentation/widgets/preview/rocket_carryover.dart';

class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final VideoPlayerController _controller;

  // Tracks whether this page is the topmost route, so an OS-level resume
  // (app switcher, home button) doesn't restart the video underneath
  // whatever's currently pushed on top of it.
  bool _isCurrentRoute = true;

  // Plays once, on tap, before navigating — buttons fade + slide down so
  // they don't just vanish when the route swaps.
  late final AnimationController _exitCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _buttonsExitOpacity = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
  late final Animation<Offset> _buttonsExitSlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0, 0.15),
  ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.asset('assets/animations/animation.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _controller.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // RouteAware — fires on in-app navigation, e.g. pushing/popping the auth
  // preview page. Generalizes beyond this one screen: any future route
  // pushed on top of this page pauses the video, and returning to it
  // (back button, or the pushed route popping itself) resumes it.
  @override
  void didPushNext() {
    _isCurrentRoute = false;
    if (_controller.value.isInitialized) {
      _controller.pause();
    }
  }

  @override
  void didPopNext() {
    _isCurrentRoute = true;
    if (_controller.value.isInitialized) {
      _controller.play();
    }
    // _exitCtrl stays at its forwarded (buttons-hidden) end state after the
    // tap that navigated away — nothing ever reversed it, so without this
    // the buttons would never come back on return. Animate them back in
    // rather than snapping, matching how they animated out.
    _exitCtrl.reverse();
  }

  // WidgetsBindingObserver — OS-level backgrounding (home button, app
  // switcher, incoming call), not just in-app navigation.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _controller.pause();
      case AppLifecycleState.resumed:
        if (_isCurrentRoute) _controller.play();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _goToAuthPreview(AuthMode mode) async {
    // Freeze on the exact frame the auth page's carried-over rocket shows,
    // then play the buttons out before the route actually swaps.
    _controller.pause();
    await _controller.seekTo(Duration.zero);
    await _exitCtrl.forward();
    if (!mounted) return;
    context.push(AppRoutes.authPreview, extra: mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RocketCarryover(),
          if (_controller.value.isInitialized)
            ClipRect(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _controller.value.isInitialized ? 1 : 0,
                  child: FadeTransition(
                    opacity: _buttonsExitOpacity,
                    child: SlideTransition(
                      position: _buttonsExitSlide,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.lg,
                          0,
                          AppTheme.lg,
                          40,
                        ),
                        child: Column(
                          children: [
                            _ChunkyButton(
                              label: 'Get started',
                              onTap: () => _goToAuthPreview(AuthMode.signup),
                              color: AppTheme.accentPurple,
                              shadow: AppTheme.chunkyButtonShadow,
                            ),
                            const SizedBox(height: AppTheme.smd),
                            _ChunkyButton(
                              label: 'I already have an account',
                              onTap: () => _goToAuthPreview(AuthMode.login),
                              color: AppTheme.background,
                              border: Border.all(
                                color: AppTheme.onboardingButtonBorder,
                                width: 2,
                              ),
                              shadow: AppTheme.chunkyButtonShadowOutline,
                              textColor: AppTheme.onSecondary,
                              fontWeight: FontWeight.normal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChunkyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final List<BoxShadow> shadow;
  final Color color;
  final Color textColor;
  final BoxBorder? border;
  final FontWeight fontWeight;

  const _ChunkyButton({
    required this.label,
    required this.onTap,
    required this.shadow,
    required this.color,
    this.textColor = AppTheme.onPrimary,
    this.border,
    this.fontWeight = FontWeight.bold,
  });

  @override
  State<_ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<_ChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: _pressed
            ? Matrix4.translationValues(0, 4, 0)
            : Matrix4.identity(),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: widget.color,
          border: widget.border,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: _pressed ? [] : widget.shadow,
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontFamily: 'GoogleSans',
            color: widget.textColor,
            fontWeight: widget.fontWeight,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
