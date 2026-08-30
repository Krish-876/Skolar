import 'package:flutter/services.dart';

class FocusHapticService {
  FocusHapticService._();

  static const MethodChannel _channel = MethodChannel('skolar/pip');

  /// Normal touch haptic click (system EFFECT_CLICK)
  static void snap() {
    try {
      _channel.invokeMethod('hapticSnap');
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Subtle touch feedback
  static void vibrate({int duration = 10, int amplitude = 50}) {
    try {
      _channel.invokeMethod('vibrate', {
        'duration': duration,
        'amplitude': amplitude,
      });
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
