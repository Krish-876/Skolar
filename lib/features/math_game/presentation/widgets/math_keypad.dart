import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MathKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final bool isSubmitEnabled;

  const MathKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
    this.isSubmitEnabled = true,
  });

  Widget _buildKey({
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color? backgroundColor,
    Color? borderColor,
    Color? splashColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            onLongPress: onLongPress != null
                ? () {
                    HapticFeedback.mediumImpact();
                    onLongPress();
                  }
                : null,
            borderRadius: BorderRadius.circular(16),
            splashColor: splashColor ?? Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: Ink(
              height: 64,
              decoration: BoxDecoration(
                color: backgroundColor ?? const Color(0xFF181724),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor ?? Colors.white.withValues(alpha: 0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitKey(String digit) {
    return _buildKey(
      onTap: () => onDigitPressed(digit),
      child: Text(
        digit,
        style: const TextStyle(
          fontFamily: 'ClashDisplay',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildDigitKey('1'),
              _buildDigitKey('2'),
              _buildDigitKey('3'),
            ],
          ),
          Row(
            children: [
              _buildDigitKey('4'),
              _buildDigitKey('5'),
              _buildDigitKey('6'),
            ],
          ),
          Row(
            children: [
              _buildDigitKey('7'),
              _buildDigitKey('8'),
              _buildDigitKey('9'),
            ],
          ),
          Row(
            children: [
              // Backspace / Clear key
              _buildKey(
                onTap: onBackspace,
                onLongPress: onClear,
                backgroundColor: const Color(0xFF221F33),
                borderColor: Colors.white.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.backspace_outlined,
                  color: Color(0xFFE2D6FF),
                  size: 24,
                ),
              ),
              // 0 Digit
              _buildDigitKey('0'),
              // Submit key
              _buildKey(
                onTap: isSubmitEnabled ? onSubmit : () {},
                backgroundColor: isSubmitEnabled
                    ? const Color(0xFF8C38E5)
                    : const Color(0xFF2C243B),
                borderColor: isSubmitEnabled
                    ? const Color(0xFFB388FF).withValues(alpha: 0.5)
                    : Colors.transparent,
                splashColor: const Color(0xFFB388FF).withValues(alpha: 0.3),
                child: AnimatedScale(
                  scale: isSubmitEnabled ? 1.05 : 0.95,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.check_rounded,
                    color: isSubmitEnabled
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
