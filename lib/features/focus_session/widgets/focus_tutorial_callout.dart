import 'dart:math';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum TutorialSwipeIndicator { none, up, down }

/// A Stack that allows children positioned outside its bounds to receive pointer events.
class OverflowHitTestStack extends Stack {
  const OverflowHitTestStack({
    super.key,
    super.alignment = AlignmentDirectional.topStart,
    super.textDirection,
    super.fit = StackFit.loose,
    super.clipBehavior = Clip.none,
    super.children = const <Widget>[],
  });

  @override
  RenderStack createRenderObject(BuildContext context) {
    return _OverflowHitTestRenderStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }
}

class _OverflowHitTestRenderStack extends RenderStack {
  _OverflowHitTestRenderStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      if (hitTestChildren(result, position: position) ||
          hitTestSelf(position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
      return false;
    }
    // Allow overflowing children outside stack bounds to receive clicks
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

class TutorialCallout extends StatelessWidget {
  final String instruction;
  final VoidCallback? onNext;
  final bool pointsDown;
  final TutorialSwipeIndicator swipeIndicator;

  const TutorialCallout({
    super.key,
    required this.instruction,
    this.onNext,
    this.pointsDown = false,
    this.swipeIndicator = TutorialSwipeIndicator.none,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = swipeIndicator == TutorialSwipeIndicator.up;
    final hasSwipe = swipeIndicator != TutorialSwipeIndicator.none;

    return GestureDetector(
      onTap: onNext,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!pointsDown) _buildArrow(isPointingUp: true),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSwipe) ...[
                  _AnimatedGestureIcon(isUp: isUp),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'GoogleSans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                      height: 1.25,
                    ),
                  ),
                ),
                if (hasSwipe) ...[
                  const SizedBox(width: 8),
                  _AnimatedSwipeGlyph(isUp: isUp),
                ],
              ],
            ),
          ),
          if (pointsDown) _buildArrow(isPointingUp: false),
        ],
      ),
    );
  }

  Widget _buildArrow({required bool isPointingUp}) {
    return Icon(
      isPointingUp
          ? Icons.arrow_drop_up_rounded
          : Icons.arrow_drop_down_rounded,
      color: AppTheme.accentPurple,
      size: 22,
    );
  }
}

class _AnimatedGestureIcon extends StatefulWidget {
  final bool isUp;

  const _AnimatedGestureIcon({required this.isUp});

  @override
  State<_AnimatedGestureIcon> createState() => _AnimatedGestureIconState();
}

class _AnimatedGestureIconState extends State<_AnimatedGestureIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = widget.isUp ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final offset = dir * (sin(t * pi) * 4.0);

        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Icon(
              widget.isUp ? Icons.swipe_up_rounded : Icons.swipe_down_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSwipeGlyph extends StatefulWidget {
  final bool isUp;

  const _AnimatedSwipeGlyph({required this.isUp});

  @override
  State<_AnimatedSwipeGlyph> createState() => _AnimatedSwipeGlyphState();
}

class _AnimatedSwipeGlyphState extends State<_AnimatedSwipeGlyph>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = widget.isUp ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final offset = dir * (sin(t * pi) * 5.0);
        final opacity = (0.55 + 0.45 * sin(t * pi)).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, offset),
          child: Opacity(
            opacity: opacity,
            child: Icon(
              widget.isUp
                  ? Icons.keyboard_double_arrow_up_rounded
                  : Icons.keyboard_double_arrow_down_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}
