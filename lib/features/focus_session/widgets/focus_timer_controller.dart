import 'dart:async';
import 'package:flutter/material.dart';

/// All possible states the focus timer can be in.
enum FocusTimerStatus {
  idle,       // Not started. Wave visible. Preset picker visible.
  running,    // Countdown active. Wave slid off. "Slide to give up" shown.
  paused,     // Reserved for future use (e.g. notification-triggered pause).
  complete,   // Timer reached zero.
}

/// Central controller for the Focus Timer feature.
///
/// Consumed by [FocusTimerPage] via [ChangeNotifierProvider] (or however
/// the app wires Riverpod / Provider — swap as needed).
///
/// Exposes:
/// - [status]          current phase
/// - [totalSeconds]    chosen duration
/// - [secondsLeft]     live countdown value
/// - [waveAnimation]   AnimationController driving the wave slide
/// - [slideProgress]   0.0→1.0 for [FocusWaveDivider]
/// - [formattedTime]   "H:MM:SS" or "MM:SS" string
///
/// Flow:
///   idle  ──start()──▶  running  ──giveUp()──▶  idle
///                               └──complete()──▶  complete
class FocusTimerController extends ChangeNotifier {
  FocusTimerController({required TickerProvider vsync}) {
    _waveAnimation = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 700),
    );
  }

  // ── State ──────────────────────────────────────────────────────────────────

  FocusTimerStatus _status = FocusTimerStatus.idle;
  FocusTimerStatus get status => _status;

  int _totalSeconds = 3600; // default 60 min
  int get totalSeconds => _totalSeconds;

  int _secondsLeft = 3600;
  int get secondsLeft => _secondsLeft;

  Timer? _ticker;

  // ── Wave animation ─────────────────────────────────────────────────────────

  late final AnimationController _waveAnimation;
  AnimationController get waveAnimationController => _waveAnimation;

  /// 0.0 = wave fully visible (idle), 1.0 = wave off screen (running).
  double get slideProgress => _waveAnimation.value;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Set the chosen duration before starting.
  void setDuration(int seconds) {
    assert(_status == FocusTimerStatus.idle, 'Cannot change duration while running');
    _totalSeconds = seconds;
    _secondsLeft = seconds;
    notifyListeners();
  }

  /// Called when the user completes the slide gesture to start.
  void start() {
    if (_status != FocusTimerStatus.idle) return;
    _status = FocusTimerStatus.running;

    // Slide the wave off screen.
    _waveAnimation.forward();

    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    notifyListeners();
  }

  /// Called from the "Give up" popup — End session button.
  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _secondsLeft = _totalSeconds;
    _status = FocusTimerStatus.idle;

    // Slide the wave back in.
    _waveAnimation.reverse();
    notifyListeners();
  }

  /// Called from the "Give up" popup — Keep focusing button.
  void resume() {
    // Status stays running — nothing to change except notify UI to close popup.
    notifyListeners();
  }

  // ── Formatted display string ───────────────────────────────────────────────

  String get formattedTime {
    final h = _secondsLeft ~/ 3600;
    final m = (_secondsLeft % 3600) ~/ 60;
    final s = _secondsLeft % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _onTick(Timer t) {
    if (_secondsLeft <= 0) {
      t.cancel();
      _status = FocusTimerStatus.complete;
      notifyListeners();
      return;
    }
    _secondsLeft--;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _waveAnimation.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preset model
// ─────────────────────────────────────────────────────────────────────────────

class FocusPreset {
  final String label;
  final int seconds;

  const FocusPreset({required this.label, required this.seconds});

  static const List<FocusPreset> defaults = [
    FocusPreset(label: 'Pomodoro', seconds: 25 * 60),
    FocusPreset(label: '45 min',   seconds: 45 * 60),
    FocusPreset(label: '1 hr',     seconds: 60 * 60),
  ];
}