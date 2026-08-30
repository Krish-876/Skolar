import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';

class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/animations/animation.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.fitHeight,
                child: Image.asset(
                  'assets/animations/onboarding_first_frame.png',
                ),
              ),
            ),
          ),
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
                          onTap: () => context.push(AppRoutes.auth),
                          color: AppTheme.accentPurple,
                          shadow: AppTheme.chunkyButtonShadow,
                        ),
                        const SizedBox(height: AppTheme.smd),
                        _ChunkyButton(
                          label: 'I already have an account',
                          onTap: () => context.push(AppRoutes.auth),
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
