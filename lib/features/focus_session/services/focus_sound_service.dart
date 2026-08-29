import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Studio-grade glassy sound and haptic feedback service for focus sessions.
class FocusSoundService {
  FocusSoundService._();

  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  /// Crisp glassy crystal chime when focus begins.
  static Future<void> playStartFocus() async {
    try {
      await HapticFeedback.mediumImpact();
      await _player.stop();
      await _player.setVolume(0.85);
      await _player.play(AssetSource('sounds/focus_start.wav'));
    } catch (_) {}
  }

  /// Serene, warm singing bowl tone when entering a break.
  static Future<void> playEnterBreak() async {
    try {
      await HapticFeedback.lightImpact();
      await _player.stop();
      await _player.setVolume(0.9);
      await _player.play(AssetSource('sounds/break_start.wav'));
    } catch (_) {}
  }

  /// Crisp upward glass chime when exiting a break and returning to focus.
  static Future<void> playExitBreak() async {
    try {
      await HapticFeedback.mediumImpact();
      await _player.stop();
      await _player.setVolume(0.9);
      await _player.play(AssetSource('sounds/break_end.wav'));
    } catch (_) {}
  }

  /// Peaceful, resonant glass harmonic chord when session completes.
  static Future<void> playSessionComplete() async {
    try {
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/session_complete.wav'));

      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // No `repeat`: in this package repeat is a loop-back pattern index,
        // not a count, and 0 means "loop forever from the start" — omitting
        // it (default -1) is what makes this a one-shot buzz.
        await Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400]);
      }
    } catch (_) {}
  }

  /// Stop active sounds and vibration. Independent try/catch per call so a
  /// failure stopping audio can never leave haptics (e.g. a runaway
  /// vibration pattern) uncancelled, and vice versa.
  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
  }
}
