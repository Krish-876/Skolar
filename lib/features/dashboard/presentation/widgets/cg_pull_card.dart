import 'dart:ui' show ImageFilter;

import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';

/// A motivational card sitting between the collapsible progress card
/// and the "All-Round Development" radar chart. Tapping it expands into
/// the mental math game screen.
class CgPullCard extends StatefulWidget {
  const CgPullCard({super.key});

  @override
  State<CgPullCard> createState() => _CgPullCardState();
}

class _CgPullCardState extends State<CgPullCard>
    with SingleTickerProviderStateMixin {
  static const double _height = 165;
  late final AnimationController _controller;
  late Animation<double> _animation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    context.push(AppRoutes.mathGame);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: Material(
          color: AppTheme.transparent,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: _onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.white.withValues(alpha: 0.22),
                      width: 1.2,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 44,
                        bottom: 0,
                        child: DotLottieLoader.fromAsset(
                          'assets/animations/CG_pull_bg.lottie',
                          frameBuilder: (context, dotlottie) {
                            if (dotlottie == null)
                              return const SizedBox.shrink();
                            return lottie.Lottie.memory(
                              dotlottie.animations.values.first,
                              controller: _animation,
                              onLoaded: (composition) {
                                final totalMs =
                                    composition.duration.inMilliseconds;
                                const trimStartMs = 2000;
                                const trimEndMs = 5000;
                                final effectiveEndMs =
                                    totalMs > (trimStartMs + trimEndMs)
                                    ? totalMs - trimEndMs
                                    : totalMs;
                                final startProgress = totalMs > 0
                                    ? (trimStartMs / totalMs).clamp(0.0, 0.95)
                                    : 0.0;
                                final endProgress = totalMs > 0
                                    ? (effectiveEndMs / totalMs).clamp(
                                        startProgress + 0.01,
                                        1.0,
                                      )
                                    : 1.0;
                                final remainingDuration =
                                    totalMs > (trimStartMs + trimEndMs)
                                    ? Duration(
                                        milliseconds:
                                            totalMs - trimStartMs - trimEndMs,
                                      )
                                    : composition.duration;

                                setState(() {
                                  _animation =
                                      Tween<double>(
                                        begin: startProgress,
                                        end: endProgress,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _controller,
                                          curve: Curves.easeInOut,
                                        ),
                                      );
                                });

                                _controller.duration = remainingDuration;
                                _controller.repeat(reverse: true);
                              },
                              fit: BoxFit.cover,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 14,
                        child: Text(
                          'CG pull karna bhai utoooo',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontFamily: 'GoogleSans',
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
