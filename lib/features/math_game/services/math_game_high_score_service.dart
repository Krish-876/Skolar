import 'package:shared_preferences/shared_preferences.dart';

/// Persists the player's best-ever score for the math game locally.
class MathGameHighScoreService {
  MathGameHighScoreService._();

  static const String _kBestScoreKey = 'math_game_best_score';

  static Future<int> getBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kBestScoreKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Saves [score] as the new best if it beats the stored one. Returns the
  /// resulting best score.
  static Future<int> setBestScoreIfHigher(int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_kBestScoreKey) ?? 0;
      if (score > current) {
        await prefs.setInt(_kBestScoreKey, score);
        return score;
      }
      return current;
    } catch (_) {
      return score;
    }
  }
}
