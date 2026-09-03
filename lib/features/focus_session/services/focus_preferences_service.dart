import 'package:shared_preferences/shared_preferences.dart';

class FocusPreferencesService {
  FocusPreferencesService._();

  static const String _kTutorialSeenKey = 'has_seen_focus_timer_tutorial';

  /// Returns true if the first-time user tutorial should be shown.
  static Future<bool> shouldShowTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_kTutorialSeenKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Sets whether the user has completed or chosen not to see the tutorial again.
  static Future<void> setTutorialSeen(bool seen) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTutorialSeenKey, seen);
    } catch (_) {}
  }

  /// Resets the tutorial status so it will be shown again.
  static Future<void> resetTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kTutorialSeenKey);
    } catch (_) {}
  }
}
