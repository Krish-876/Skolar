import 'package:flutter/material.dart';

class MathGameResultsView extends StatelessWidget {
  final int finalScore;
  final int totalAnswered;
  final int totalCorrect;
  final double elapsedSeconds;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const MathGameResultsView({
    super.key,
    required this.finalScore,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.elapsedSeconds,
    required this.onPlayAgain,
    required this.onExit,
  });

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'GoogleSans',
              fontSize: 14,
              color: Color(0xFF8E8E9A),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'GoogleSans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEBEBF0),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = totalAnswered > 0
        ? ((totalCorrect / totalAnswered) * 100).round()
        : 0;
    final avgSpeed = totalAnswered > 0
        ? (elapsedSeconds / totalAnswered).toStringAsFixed(1)
        : '0.0';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SESSION COMPLETE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$finalScore',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const Text(
              'Final Score',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 14,
                color: Color(0xFF7A7A85),
              ),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  _buildStatRow('Questions Answered', '$totalAnswered'),
                  Divider(color: Colors.white.withValues(alpha: 0.06)),
                  _buildStatRow('Correct Answers', '$totalCorrect'),
                  Divider(color: Colors.white.withValues(alpha: 0.06)),
                  _buildStatRow('Accuracy', '$accuracy%'),
                  Divider(color: Colors.white.withValues(alpha: 0.06)),
                  _buildStatRow('Average Speed', '${avgSpeed}s / question'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Play Again Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onPlayAgain,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2B33),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Play Again',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Exit Button
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: onExit,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7A7A85),
                ),
                child: const Text(
                  'Exit',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
