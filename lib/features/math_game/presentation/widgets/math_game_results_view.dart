import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class MathGameResultsView extends StatefulWidget {
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

  @override
  State<MathGameResultsView> createState() => _MathGameResultsViewState();
}

class _MathGameResultsViewState extends State<MathGameResultsView> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    if (widget.totalCorrect > 3) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _getRankTitle() {
    final score = widget.finalScore;
    if (score >= 3000) return '🧠 Mental Math God';
    if (score >= 2200) return '⚡ Speed Demon';
    if (score >= 1500) return '🔥 Math Ninja';
    if (score >= 900) return '✨ Quick Thinker';
    if (score >= 400) return '🎯 Sharp Mind';
    return '🌱 Solid Effort';
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181724),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = widget.totalAnswered > 0
        ? ((widget.totalCorrect / widget.totalAnswered) * 100).round()
        : 0;
    final avgSpeed = widget.totalAnswered > 0
        ? (widget.elapsedSeconds / widget.totalAnswered).toStringAsFixed(1)
        : '0.0';

    return Stack(
      children: [
        // Confetti emitter
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,
            maxBlastForce: 6,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 25,
            gravity: 0.15,
            colors: const [
              Color(0xFF8C38E5),
              Color(0xFFB388FF),
              Color(0xFF34C759),
              Color(0xFFF5C518),
              Color(0xFFFF9500),
              Color(0xFF00E5FF),
            ],
          ),
        ),

        // Main results content
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8C38E5).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFB388FF).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'TIME’S UP!',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB388FF),
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Rank Title
                Text(
                  _getRankTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                // Final Score Big Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF261D3B), Color(0xFF161426)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF8C38E5).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8C38E5).withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'FINAL SCORE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA8C4FF),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.finalScore}',
                        style: const TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Stats Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard(
                      title: 'Correct / Total',
                      value: '${widget.totalCorrect} / ${widget.totalAnswered}',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF34C759),
                    ),
                    _buildStatCard(
                      title: 'Accuracy',
                      value: '$accuracy%',
                      icon: Icons.pie_chart_outline_rounded,
                      color: const Color(0xFF00E5FF),
                    ),
                    _buildStatCard(
                      title: 'Best Streak',
                      value: '${widget.highestStreak} 🔥',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFFF9500),
                    ),
                    _buildStatCard(
                      title: 'Avg Speed',
                      value: '${avgSpeed}s / Q',
                      icon: Icons.speed_rounded,
                      color: const Color(0xFFB388FF),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Play Again Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: widget.onPlayAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8C38E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: const Color(
                        0xFF8C38E5,
                      ).withValues(alpha: 0.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.replay_rounded, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'PLAY AGAIN',
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Exit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: widget.onExit,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Return to Dev Menu',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
