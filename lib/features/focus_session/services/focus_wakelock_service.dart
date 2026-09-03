import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class FocusWakelockService {
  FocusWakelockService._();

  static bool _isEnabled = false;

  /// Whether wakelock is currently enabled.
  static bool get isEnabled => _isEnabled;

  /// Enables the wakelock to keep the screen turned on.
  static Future<void> enable() async {
    if (_isEnabled) return;
    try {
      await WakelockPlus.enable();
      _isEnabled = true;
      debugPrint('[FocusWakelockService] Screen wakelock enabled');
    } catch (e) {
      debugPrint('[FocusWakelockService] Failed to enable wakelock: $e');
    }
  }

  /// Disables the wakelock to let the screen sleep normally.
  static Future<void> disable() async {
    if (!_isEnabled) return;
    try {
      await WakelockPlus.disable();
      _isEnabled = false;
      debugPrint('[FocusWakelockService] Screen wakelock disabled');
    } catch (e) {
      debugPrint('[FocusWakelockService] Failed to disable wakelock: $e');
    }
  }

  /// Sets wakelock state to [enabled].
  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await enable();
    } else {
      await disable();
    }
  }
}
