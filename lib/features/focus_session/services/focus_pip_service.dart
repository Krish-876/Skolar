import 'package:flutter/services.dart';

class FocusPipService {
  FocusPipService._();

  static const MethodChannel _channel = MethodChannel('skolar/pip');
  static void Function(bool isInPip)? onPipModeChanged;
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        final isInPip = call.arguments as bool? ?? false;
        onPipModeChanged?.call(isInPip);
      }
    });
    _initialized = true;
  }

  /// Enables or disables automatic Picture-in-Picture on user minimize
  static Future<void> setPipEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setPipEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  /// Manually triggers Picture-in-Picture mode
  static Future<bool> enterPip() async {
    try {
      final res = await _channel.invokeMethod<bool>('enterPip');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
