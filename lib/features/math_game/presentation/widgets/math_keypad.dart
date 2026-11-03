import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _kKeyColor = Color(0xFF232326);

class MathKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const MathKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onClear,
  });

  Widget _buildKey({
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
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
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Ink(
              height: 60,
              decoration: BoxDecoration(
                color: _kKeyColor,
                borderRadius: BorderRadius.circular(18),
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
          fontFamily: 'GoogleSans',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
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
              _buildDigitKey('.'),
              _buildDigitKey('0'),
              _buildKey(
                onTap: onBackspace,
                onLongPress: onClear,
                child: const Icon(
                  Icons.backspace_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
