import 'dart:async';
import 'package:flutter/material.dart';

enum FocusTimerStatus {
  idle,
  running,
  paused,
  complete,
}

class FocusTimerController extends ChangeNotifier {
  FocusTimerController({required TickerProvider vsync}) {
    _waveAnimation = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 700),
    );
  }

  FocusTimerStatus _status = FocusTimerStatus.idle;
  FocusTimerStatus get status => _status;

  int _totalSeconds = 3600; 
  int get totalSeconds => _totalSeconds;

  int _secondsLeft = 3600;
  int get secondsLeft => _secondsLeft;

  Timer? _ticker;
  late final AnimationController _waveAnimation;

  AnimationController get waveAnimationController => _waveAnimation;
  double get slideProgress => _waveAnimation.value;

  void setDuration(int seconds) {
    assert(_status == FocusTimerStatus.idle, 'Cannot change duration while running');
    _totalSeconds = seconds;
    _secondsLeft = seconds;
    notifyListeners();
  }

  void start() {
    if (_status != FocusTimerStatus.idle) return;
    _status = FocusTimerStatus.running;
    _waveAnimation.forward();
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _secondsLeft = _totalSeconds;
    _status = FocusTimerStatus.idle;
    _waveAnimation.reverse();
    notifyListeners();
  }

  void resume() {
    notifyListeners();
  }

  String get formattedTime {
    final h = _secondsLeft ~/ 3600;
    final m = (_secondsLeft % 3600) ~/ 60;
    final s = _secondsLeft % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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