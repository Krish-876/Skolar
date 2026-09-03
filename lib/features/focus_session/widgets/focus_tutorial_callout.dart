import 'package:Skolar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

  const TutorialCallout({
    super.key,
    required this.instruction,
    this.onNext,
    this.pointsDown = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onNext,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!pointsDown) _buildArrow(isPointingUp: true),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1C2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentPurple.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPurple.withValues(alpha: 0.3),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              instruction,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.25,
              ),
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
