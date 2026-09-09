import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/subjects/presentation/widgets/subjects_widgets.dart';

class MathGameResultsView extends StatelessWidget {
  final int finalScore;
  final int totalAnswered;
  final int totalCorrect;
  final int highestStreak;
  final double elapsedSeconds;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const MathGameResultsView({
    super.key,
    required this.finalScore,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.highestStreak,
    required this.elapsedSeconds,
    required this.onPlayAgain,
    required this.onExit,
  });

  Widget _buildStatBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: _buildPlainStat(label: label, value: value),
    );
  }

  Widget _buildPlainStat({required String label, required String value}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'GoogleSans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white54,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'GoogleSans',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avgSpeed = totalAnswered > 0
        ? (elapsedSeconds / totalAnswered).toStringAsFixed(1)
        : '0.0';

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Center heading
                  const Text(
                        'TIME’S UP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'GoogleSans',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 700.ms)
                      .moveY(
                        begin: 14,
                        end: 0,
                        duration: 700.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 10),

                  // Sub heading
                  const Text(
                        'Go back to your chair, you little procrastinator!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'GoogleSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white60,
                          height: 1.4,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 700.ms, delay: 200.ms)
                      .moveY(
                        begin: 14,
                        end: 0,
                        duration: 700.ms,
                        delay: 200.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 48),

                  // Questions attempted + avg speed — separate boxes,
                  // no fill color, just a light border
                  Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatBox(
                            label: 'ATTEMPTED',
                            value: '$totalAnswered',
                          ),
                          const SizedBox(width: 32),
                          _buildStatBox(
                            label: 'AVG SPEED',
                            value: '${avgSpeed}s / Q',
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 700.ms, delay: 550.ms)
                      .moveY(
                        begin: 14,
                        end: 0,
                        duration: 700.ms,
                        delay: 550.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 28),

                  // Final Score — plain, no box
                  Column(
                        children: [
                          const Text(
                            'FINAL SCORE',
                            style: TextStyle(
                              fontFamily: 'GoogleSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white54,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$finalScore',
                            style: const TextStyle(
                              fontFamily: 'GoogleSans',
                              fontSize: 72,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 700.ms, delay: 850.ms)
                      .moveY(
                        begin: 14,
                        end: 0,
                        duration: 700.ms,
                        delay: 850.ms,
                        curve: Curves.easeOut,
                      ),
                ],
              ),
            ),
          ),
        ),

        // Bottom-anchored actions
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              // Play More Button — shared app-wide 2.5D chunky button,
              // recolored for this page only (black body, old body color
              // as the shadow) — ChunkyButton itself is untouched.
              ChunkyButton(
                label: 'PLAY MORE',
                onTap: onPlayAgain,
                color: Colors.black,
                border: Border.all(color: AppTheme.accentPurple, width: 1),
                shadow: const [
                  BoxShadow(
                    color: AppTheme.accentPurple,
                    blurRadius: 0,
                    offset: Offset(0, 4),
                  ),
                ],
                height: 56,
              ),

              const SizedBox(height: 12),

              // Exit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: onExit,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(
                      fontFamily: 'GoogleSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
