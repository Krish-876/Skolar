import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum FocusTimerStatus { idle, running, complete }

enum FocusPhase { focus, breakTime }

class BreakSegment {
  final double startFraction;
  final double widthFraction;
  const BreakSegment({required this.startFraction, required this.widthFraction});
}

class FocusTimerController extends ChangeNotifier {
  FocusTimerController({required TickerProvider vsync}) {
    _waveAnimation = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 700),
    );
  }

  // 25m focus + 5m break
  static const int pomodoroFocusDuration = 25; // 25 minutes
  static const int pomodoroBreakDuration = 5; // 5 minutes

  FocusTimerStatus _status = FocusTimerStatus.idle;
  FocusTimerStatus get status => _status;

  FocusPhase _currentPhase = FocusPhase.focus;
  FocusPhase get currentPhase => _currentPhase;
  bool get isBreakPhase => _currentPhase == FocusPhase.breakTime;

  bool _isPomodoroEnabled = true;
  bool get isPomodoroEnabled => _isPomodoroEnabled;

  int _totalSeconds = 25 * 60; // total focus seconds chosen by user
  int get totalSeconds => _totalSeconds;

  int _secondsLeft = 25 * 60; // total remaining wall-clock seconds
  int get secondsLeft => _secondsLeft;

  int _currentPhaseTotalSeconds = 25 * 60;
  int get currentPhaseTotalSeconds => _currentPhaseTotalSeconds;

  int _currentPhaseSecondsLeft = 25 * 60;
  int get currentPhaseSecondsLeft => _currentPhaseSecondsLeft;

  DateTime? _sessionEndTime;
  DateTime? _phaseEndTime;

  DateTime? _phaseStartedAt;
  DateTime? get phaseStartedAt => _phaseStartedAt;

  bool _completionNotified = false;

  Timer? _ticker;
  late final AnimationController _waveAnimation;

  AnimationController get waveAnimationController => _waveAnimation;
  double get slideProgress => _waveAnimation.value;

  /// Callbacks
  VoidCallback? onComplete;
  void Function(FocusPhase newPhase)? onPhaseChanged;

  int get pomodoroBreakCount {
    if (!_isPomodoroEnabled || _totalSeconds <= pomodoroFocusDuration) return 0;
    return ((_totalSeconds - 1) ~/ pomodoroFocusDuration);
  }

  int get totalSessionDurationWithBreaks {
    if (!_isPomodoroEnabled) return _totalSeconds;
    return _totalSeconds + (pomodoroBreakCount * pomodoroBreakDuration);
  }

  void setPomodoroEnabled(bool enabled) {
    if (_status != FocusTimerStatus.idle) return;
    _isPomodoroEnabled = enabled;
    _currentPhaseTotalSeconds = _isPomodoroEnabled
        ? min(_totalSeconds, pomodoroFocusDuration)
        : _totalSeconds;
    _currentPhaseSecondsLeft = _currentPhaseTotalSeconds;
    notifyListeners();
  }

  void setDuration(int seconds) {
    assert(
      _status == FocusTimerStatus.idle,
      'Cannot change duration while running',
    );
    _totalSeconds = seconds;
    _secondsLeft = totalSessionDurationWithBreaks;
    _currentPhase = FocusPhase.focus;
    _currentPhaseTotalSeconds = _isPomodoroEnabled
        ? min(seconds, pomodoroFocusDuration)
        : seconds;
    _currentPhaseSecondsLeft = _currentPhaseTotalSeconds;
    notifyListeners();
  }

  void start() {
    if (_status != FocusTimerStatus.idle) return;
    _status = FocusTimerStatus.running;
    _currentPhase = FocusPhase.focus;

    final totalDuration = totalSessionDurationWithBreaks;
    _secondsLeft = totalDuration;

    _currentPhaseTotalSeconds = _isPomodoroEnabled
        ? min(_totalSeconds, pomodoroFocusDuration)
        : _totalSeconds;
    _currentPhaseSecondsLeft = _currentPhaseTotalSeconds;

    final now = DateTime.now();
    _sessionEndTime = now.add(Duration(seconds: totalDuration));
    _phaseEndTime = now.add(Duration(seconds: _currentPhaseTotalSeconds));
    _phaseStartedAt = now;
    _completionNotified = false;

    _waveAnimation.forward();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), _onTick);
    notifyListeners();
  }

  /// Resets the timer back to idle.
  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _sessionEndTime = null;
    _phaseEndTime = null;
    _phaseStartedAt = null;
    _completionNotified = false;
    _status = FocusTimerStatus.idle;
    _currentPhase = FocusPhase.focus;
    _secondsLeft = totalSessionDurationWithBreaks;
    _currentPhaseTotalSeconds = _isPomodoroEnabled
        ? min(_totalSeconds, pomodoroFocusDuration)
        : _totalSeconds;
    _currentPhaseSecondsLeft = _currentPhaseTotalSeconds;
    _waveAnimation.reverse();
    notifyListeners();
  }

  /// Synchronize timer state with real-world timestamps when app resumes from lock screen / background.
  void syncWithSystemTime() {
    if (_status != FocusTimerStatus.running || _sessionEndTime == null) return;

    final now = DateTime.now();
    final sessionMs = _sessionEndTime!.difference(now).inMilliseconds;
    final remainingSessionSeconds = (sessionMs / 1000).ceil();

    if (remainingSessionSeconds <= 0) {
      _completeSession();
      return;
    }

    _secondsLeft = remainingSessionSeconds;

    if (_isPomodoroEnabled && _phaseEndTime != null) {
      final phaseMs = _phaseEndTime!.difference(now).inMilliseconds;
      final phaseRemaining = (phaseMs / 1000).ceil();
      if (phaseRemaining <= 0) {
        final previousPhaseEndTime = _phaseEndTime!;
        if (_currentPhase == FocusPhase.focus) {
          // Transition to break
          _currentPhase = FocusPhase.breakTime;
          _currentPhaseTotalSeconds = pomodoroBreakDuration;
          _currentPhaseSecondsLeft = _currentPhaseTotalSeconds;
          _phaseEndTime = now.add(Duration(seconds: _currentPhaseTotalSeconds));
          _phaseStartedAt = previousPhaseEndTime;
          onPhaseChanged?.call(FocusPhase.breakTime);
        } else {
          // Break time finished -> Transition directly into next focus session!
          _currentPhase = FocusPhase.focus;
          _currentPhaseTotalSeconds = min(_secondsLeft, pomodoroFocusDuration);
          _currentPhaseSecondsLeft = _currentPhaseTotalSeconds;
          _phaseEndTime = now.add(Duration(seconds: _currentPhaseTotalSeconds));
          _phaseStartedAt = previousPhaseEndTime;
          onPhaseChanged?.call(FocusPhase.focus);
        }
      } else {
        _currentPhaseSecondsLeft = phaseRemaining;
      }
    } else {
      _currentPhaseSecondsLeft = _secondsLeft;
    }

    notifyListeners();
  }

  /// Marks the session complete and fires [onComplete] exactly once.
  ///
  /// Both [_onTick] and [syncWithSystemTime] can independently observe the
  /// session has run out; this guard is what keeps a completion-triggered
  /// side effect (sound/haptics) from ever firing twice for one session.
  void _completeSession() {
    if (_completionNotified) return;
    _completionNotified = true;

    _ticker?.cancel();
    _ticker = null;
    _secondsLeft = 0;
    _currentPhaseSecondsLeft = 0;
    _status = FocusTimerStatus.complete;
    notifyListeners();
    onComplete?.call();
  }

  void _onTick(Timer t) {
    if (_sessionEndTime == null) return;

    final now = DateTime.now();
    final ms = _sessionEndTime!.difference(now).inMilliseconds;
    final totalRemaining = (ms / 1000).ceil();

    if (totalRemaining <= 0) {
      _completeSession();
      return;
    }

    // Resolved once below, then written to _currentPhaseSecondsLeft exactly
    // once — never both a stale pre-transition reading and the new phase's
    // duration in the same tick.
    final int phaseRemaining;

    if (_isPomodoroEnabled && _phaseEndTime != null) {
      final phaseMs = _phaseEndTime!.difference(now).inMilliseconds;
      final rawPhaseRemaining = (phaseMs / 1000).ceil();
      if (rawPhaseRemaining <= 0) {
        // Transition phase
        if (_currentPhase == FocusPhase.focus) {
          // Focus finished -> Enter break
          _currentPhase = FocusPhase.breakTime;
          _currentPhaseTotalSeconds = pomodoroBreakDuration;
          _phaseEndTime = now.add(Duration(seconds: _currentPhaseTotalSeconds));
          _phaseStartedAt = now;
          onPhaseChanged?.call(FocusPhase.breakTime);
        } else {
          // Break finished -> Enter next focus session immediately!
          _currentPhase = FocusPhase.focus;
          _currentPhaseTotalSeconds = min(totalRemaining, pomodoroFocusDuration);
          _phaseEndTime = now.add(Duration(seconds: _currentPhaseTotalSeconds));
          _phaseStartedAt = now;
          onPhaseChanged?.call(FocusPhase.focus);
        }
        phaseRemaining = _currentPhaseTotalSeconds;
      } else {
        phaseRemaining = rawPhaseRemaining;
      }
    } else {
      phaseRemaining = totalRemaining;
    }

    // Sampling at 200ms means most ticks land inside the same displayed
    // second; skip the rebuild when nothing visible actually changed. Phase
    // transitions and the completion path above always run first, so they
    // can never be suppressed by this.
    if (totalRemaining == _secondsLeft &&
        phaseRemaining == _currentPhaseSecondsLeft) {
      return;
    }

    _secondsLeft = totalRemaining;
    _currentPhaseSecondsLeft = phaseRemaining;

    notifyListeners();
  }

  /// Overall session progress from 0.0 to 1.0
  double get sessionProgress {
    final total = totalSessionDurationWithBreaks;
    if (total <= 0) return 0.0;
    return (1.0 - (_secondsLeft / total)).clamp(0.0, 1.0);
  }

  /// Current interval phase progress from 0.0 to 1.0 (for current interval)
  double get currentIntervalProgress {
    if (_currentPhaseTotalSeconds <= 0) return 0.0;
    return (1.0 - (_currentPhaseSecondsLeft / _currentPhaseTotalSeconds)).clamp(
      0.0,
      1.0,
    );
  }

  /// Clean string for break count subtitle (e.g. "1 break", "2 breaks")
  String get breaksSubtitle {
    if (!_isPomodoroEnabled) return '';
    final count = pomodoroBreakCount;
    if (count == 0) return 'no breaks';
    return '$count ${count == 1 ? 'break' : 'breaks'}';
  }

  /// Proportional break segments along the 0.0..1.0 timeline with thickness
  List<BreakSegment> get breakSegments {
    final segments = <BreakSegment>[];
    final totalDuration = totalSessionDurationWithBreaks;
    if (!_isPomodoroEnabled || totalDuration <= 0 || pomodoroBreakCount == 0) {
      return segments;
    }

    final breakWidth = pomodoroBreakDuration / totalDuration;
    int elapsed = 0;

    for (int i = 0; i < pomodoroBreakCount; i++) {
      elapsed += pomodoroFocusDuration;
      final start = elapsed / totalDuration;
      segments.add(BreakSegment(
        startFraction: start.clamp(0.0, 1.0 - breakWidth),
        widthFraction: breakWidth,
      ));
      elapsed += pomodoroBreakDuration;
    }
    return segments;
  }

  /// Formatted time readout for the current active countdown
  String get formattedTime {
    final s = _status == FocusTimerStatus.idle
        ? _totalSeconds
        : _currentPhaseSecondsLeft;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Formatted preview of total focus duration
  String get formattedTotalFocusTime {
    final s = _totalSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Formatted total session time remaining
  String get formattedTotalRemaining {
    final s = _secondsLeft;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Upcoming break info string as requested
  String get upcomingBreakInfo {
    if (!_isPomodoroEnabled) return '';
    if (_currentPhase == FocusPhase.focus) {
      return 'Next: 5m break';
    } else {
      return 'Next: 25m focus session';
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _waveAnimation.dispose();
    super.dispose();
  }
}
