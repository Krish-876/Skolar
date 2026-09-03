import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MathKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  const MathKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
  });

  Widget _buildButton({
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: const Color(0xFF2B2B33),
          borderRadius: BorderRadius.circular(10),
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
            borderRadius: BorderRadius.circular(10),
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Container(
              height: 58,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigit(String digit) {
    return _buildButton(
      onTap: () => onDigitPressed(digit),
      child: Text(
        digit,
        style: const TextStyle(
          fontFamily: 'GoogleSans',
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: Color(0xFFEBEBF0),
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
          Row(children: [_buildDigit('1'), _buildDigit('2'), _buildDigit('3')]),
          Row(children: [_buildDigit('4'), _buildDigit('5'), _buildDigit('6')]),
          Row(children: [_buildDigit('7'), _buildDigit('8'), _buildDigit('9')]),
          Row(
            children: [
              // Clear key
              _buildButton(
                onTap: onClear,
                child: const Text(
                  'C',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9E9EA8),
                  ),
                ),
              ),
              // 0
              _buildDigit('0'),
              // Backspace icon
              _buildButton(
                onTap: onBackspace,
                onLongPress: onClear,
                child: const Icon(
                  Icons.backspace_outlined,
                  size: 20,
                  color: Color(0xFFEBEBF0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
