import 'package:flutter/material.dart';

class MathGameStatsBar extends StatelessWidget {
  final int score;
  final int solvedCount;
  final double remainingSeconds;
  final VoidCallback onExit;

  const MathGameStatsBar({
    super.key,
    required this.score,
    required this.solvedCount,
    required this.remainingSeconds,
    required this.onExit,
  });

  String _formatTime(double seconds) {
    final s = seconds.ceil();
    final mins = s ~/ 60;
    final remSecs = s % 60;
    return '${mins.toString().padLeft(1, '0')}:${remSecs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = remainingSeconds <= 10 && remainingSeconds > 0;
    final timeStr = _formatTime(remainingSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Exit Button & Score
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onExit,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF9E9EA8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$score',
                  style: const TextStyle(
                    fontFamily: 'GoogleSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEBEBF0),
                  ),
                ),
              ),
            ],
          ),

          // Center: Cyan Timer Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isWarning
                  ? const Color(0xFFFF3B30).withValues(alpha: 0.15)
                  : const Color(0xFF16252B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isWarning
                    ? const Color(0xFFFF3B30).withValues(alpha: 0.4)
                    : const Color(0xFF00E5FF).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isWarning
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isWarning
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF00E5FF),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Right: Solved Count pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Solved $solvedCount',
              style: const TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB0B0BD),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
