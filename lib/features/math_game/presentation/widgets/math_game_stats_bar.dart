import 'package:flutter/material.dart';

class MathGameStatsBar extends StatelessWidget {
  final int score;
  final int currentStreak;
  final double remainingSeconds;
  final double totalSeconds;
  final VoidCallback onExit;

  const MathGameStatsBar({
    super.key,
    required this.score,
    required this.currentStreak,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onExit,
  });

  Color _getTimerColor() {
    if (remainingSeconds > 20) {
      return const Color(0xFF34C759); // Green
    } else if (remainingSeconds > 10) {
      return const Color(0xFFFF9500); // Amber
    } else {
      return const Color(0xFFFF3B30); // Crimson Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
    final timerColor = _getTimerColor();
    final isWarning = remainingSeconds <= 10 && remainingSeconds > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Exit button
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: 'Exit Game',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 12),

              // Score badge
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161522),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFFF5C518),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$score',
                        style: const TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Streak badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: currentStreak >= 3
                      ? const Color(0xFFFF9500).withValues(alpha: 0.18)
                      : const Color(0xFF161522),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: currentStreak >= 3
                        ? const Color(0xFFFF9500).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentStreak >= 5
                          ? '⚡'
                          : currentStreak >= 3
                          ? '🔥'
                          : '✨',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$currentStreak',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: currentStreak >= 3
                            ? const Color(0xFFFFB340)
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Timer Digital Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isWarning
                      ? const Color(0xFFFF3B30).withValues(alpha: 0.18)
                      : const Color(0xFF161522),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isWarning
                        ? const Color(0xFFFF3B30).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: timerColor),
                    const SizedBox(width: 6),
                    Text(
                      '${remainingSeconds.ceil()}s',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: timerColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Animated linear progress gauge
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
