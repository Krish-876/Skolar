import 'dart:ui' show ImageFilter;
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:Skolar/core/theme/app_theme.dart';

class CgPullIntroOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const CgPullIntroOverlay({super.key, required this.onComplete});

  @override
  State<CgPullIntroOverlay> createState() => _CgPullIntroOverlayState();
}

class _CgPullIntroOverlayState extends State<CgPullIntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Wait for the hero expansion to complete (~450ms) + brief centered pause (~400ms),
    // then fade out smoothly to reveal the math game
    Future.delayed(const Duration(milliseconds: 850), () {
      if (!mounted || _isCompleted) return;
      _fadeController.forward().then((_) {
        if (!mounted || _isCompleted) return;
        _isCompleted = true;
        widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _skip() {
    if (_isCompleted || !mounted) return;
    _isCompleted = true;
    _fadeController.stop();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(opacity: _fadeAnimation.value, child: child);
        },
        child: Hero(
          tag: 'cg_pull_card_hero',
          child: Material(
            color: Colors.transparent,
            child: Container(
              color: const Color(0xFF0F0F13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Frosted glass layer matching the collapsed card
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.75),
                    ),
                  ),

                  // Centered Lottie animation and caption
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          height: 240,
                          child: DotLottieLoader.fromAsset(
                            'assets/animations/CG_pull_bg.lottie',
                            frameBuilder: (context, dotlottie) {
                              if (dotlottie == null) {
                                return const SizedBox.shrink();
                              }
                              return lottie.Lottie.memory(
                                dotlottie.animations.values.first,
                                fit: BoxFit.contain,
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CG pull karna bhai utoooo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'GoogleSans',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
