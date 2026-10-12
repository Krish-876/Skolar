import 'dart:async';
import 'dart:math';
import 'package:Skolar/core/services/activity_log_service.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:Skolar/features/focus_session/services/focus_haptic_service.dart';
import 'package:Skolar/features/focus_session/services/focus_notification_service.dart';
import 'package:Skolar/features/focus_session/services/focus_pip_service.dart';
import 'package:Skolar/features/focus_session/services/focus_sound_service.dart';
import 'package:Skolar/features/focus_session/services/focus_wakelock_service.dart';
import 'package:Skolar/features/focus_session/widgets/glow_thumb_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../controllers/focus_timer_controller.dart';
import '../services/focus_preferences_service.dart';
import '../widgets/focus_background.dart';
import '../widgets/phase_takeover.dart';
import '../widgets/analog_clock_painter.dart';
import '../widgets/focus_tutorial_callout.dart';

/// Colors that differ between the real (dark) body and its light-theme
/// break clone. Everything structural (layout, sizing, which widgets exist)
/// is identical between the two — only these leaf colors vary.
class _FocusPalette {
  final Color background;
  final Color onBackground;
  final Color muted;
  final Color accent;

  const _FocusPalette({
    required this.background,
    required this.onBackground,
    required this.muted,
    required this.accent,
  });
}

const _darkPalette = _FocusPalette(
  background: AppTheme.background,
  onBackground: Colors.white,
  muted: Colors.white70,
  accent: AppTheme.accentPurple,
);

const _lightPalette = _FocusPalette(
  background: AppTheme.focusBreakBackground,
  onBackground: AppTheme.focusBreakOnBackground,
  muted: AppTheme.focusBreakOnBackgroundMuted,
  accent: AppTheme.focusBreakAccent,
);

class FocusTimerPage extends ConsumerStatefulWidget {
  /// Pre-fills the duration slider/controller with this instead of the
  /// default 25 minutes — used when a task with its own timer duration is
  /// tapped from the dashboard's task list.
  final Duration? initialDuration;

  const FocusTimerPage({super.key, this.initialDuration});

  @override
  ConsumerState<FocusTimerPage> createState() => FocusTimerPageState();
}

class FocusTimerPageState extends ConsumerState<FocusTimerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final FocusTimerController _controller;
  late final AnimationController _zenAnimController;
  late final AnimationController _startRollController;

  // ANIMATION 1: phase takeover. Two independent wipes: entering break
  // sweeps a light clone of the screen in (dome up), then holds fully
  // revealed for the whole break; exiting break sweeps a dark clone back
  // over it (dome down). See _buildBody/_FocusPalette below.
  late final AnimationController _entryWipeController;
  late final AnimationController _exitWipeController;
  bool _showLightOverlay = false;
  bool _showDarkExitOverlay = false;

  bool _isInPipMode = false;

  bool _showGiveUpSheet = false;

  int _rollStartSeconds = 0;
  int _rollTargetSeconds = 0;

  int _appExitWarningCount = 0;
  Timer? _gracePeriodTimer;
  bool _wasCancelledDueToAppExit = false;
  bool _isAppInForeground = true;

  double _targetSliderMinutes = 25.0;
  double _animatedSliderMinutes = 25.0;
  double? _lastSnappedPoint;

  double _knobOffset = 0;
  bool _dragging = false;
  bool _showTutorial = false;
  int _tutorialStep = 0;

  /// UUID generated once per session start. Regenerated every time the
  /// user taps Start so retrying the same finished session is idempotent.
  String? _sessionClientId;
  bool _tutorialDontShowAgain = true;
  static const double _trackHorizontalPadding = 6.0;
  static const double _knobSize = 48.0;
  static const double _trackHeight = 62.0;
  static const double _triggerFraction = 0.82;

  @override
  void initState() {
    super.initState();
    FocusNotificationService.init();
    FocusPipService.init();
    FocusPipService.onPipModeChanged = (inPip) {
      if (mounted) {
        setState(() => _isInPipMode = inPip);
      }
    };
    _controller = FocusTimerController(vsync: this);
    _zenAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _zenAnimController.addListener(() => setState(() {}));
    _zenAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _updateAmoledWakelock(forceState: true);
      } else if (status == AnimationStatus.dismissed) {
        _updateAmoledWakelock(forceState: false);
      }
    });
    _startRollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _startRollController.addListener(() => setState(() {}));
    _entryWipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryWipeController.addListener(() => setState(() {}));
    _entryWipeController.addStatusListener(_onEntryWipeStatusChanged);
    _exitWipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _exitWipeController.addListener(() => setState(() {}));
    _exitWipeController.addStatusListener(_onExitWipeStatusChanged);

    final isTest = FocusTimerController.kTestMode;
    final presetDuration = widget.initialDuration;
    if (presetDuration != null && presetDuration.inSeconds > 0) {
      _controller.setDuration(presetDuration.inSeconds);
    }
    _targetSliderMinutes = isTest
        ? _controller.totalSeconds.toDouble().clamp(10.0, 180.0)
        : (_controller.totalSeconds / 60.0).clamp(1.0, 180.0);
    _animatedSliderMinutes = _targetSliderMinutes;
    _controller.addListener(() => setState(() {}));
    _controller.onComplete = _onTimerComplete;
    _controller.onPhaseChanged = _onPhaseChanged;

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shouldShow = await FocusPreferencesService.shouldShowTutorial();
      if (shouldShow &&
          mounted &&
          _controller.status == FocusTimerStatus.idle) {
        setState(() {
          _showTutorial = true;
          _tutorialStep = 0;
        });
      }
    });
  }

  void _dismissTutorial() async {
    if (_tutorialDontShowAgain) {
      await FocusPreferencesService.setTutorialSeen(true);
    }
    if (mounted) {
      setState(() => _showTutorial = false);
    }
  }

  void _updateAmoledWakelock({bool? forceState}) {
    final shouldKeepAwake =
        forceState ??
        (mounted &&
            _isAppInForeground &&
            _controller.status == FocusTimerStatus.running &&
            _zenAnimController.value >= 0.5);
    FocusWakelockService.setEnabled(shouldKeepAwake);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusWakelockService.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _gracePeriodTimer?.cancel();
    FocusPipService.setPipEnabled(false);
    FocusPipService.onPipModeChanged = null;
    FocusNotificationService.cancelAll();
    FocusSoundService.stop();
    _zenAnimController.dispose();
    _startRollController.dispose();
    _entryWipeController.dispose();
    _exitWipeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      _updateAmoledWakelock();
      _appExitWarningCount = 0;
      _gracePeriodTimer?.cancel();
      _gracePeriodTimer = null;
      FocusNotificationService.cancelAll();
      _controller.syncWithSystemTime();

      if (_wasCancelledDueToAppExit) {
        _wasCancelledDueToAppExit = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Focus session was cancelled because you left the app.',
                style: TextStyle(
                  fontFamily: 'GoogleSans',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppTheme.wishlist,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_isAppInForeground) {
        _isAppInForeground = false;
        FocusWakelockService.disable();

        if (_controller.status == FocusTimerStatus.running) {
          if (_controller.isBreakPhase) {
            // During break: enable native PiP
            FocusPipService.setPipEnabled(true);
          } else {
            // User minimized app during active focus session
            if (_appExitWarningCount == 0) {
              _appExitWarningCount = 1;
              FocusNotificationService.showExitWarningNotification();
              _gracePeriodTimer?.cancel();
              _gracePeriodTimer = Timer(const Duration(seconds: 10), () {
                if (!_isAppInForeground &&
                    _controller.status == FocusTimerStatus.running &&
                    !_controller.isBreakPhase) {
                  _cancelSessionDueToAppExit();
                }
              });
            } else {
              _cancelSessionDueToAppExit();
            }
          }
        }
      }
    } else if (state == AppLifecycleState.detached) {
      FocusWakelockService.disable();
      if (_controller.status == FocusTimerStatus.running) {
        _cancelSessionDueToAppExit();
      }
    }
  }

  void _cancelSessionDueToAppExit() {
    FocusWakelockService.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _zenAnimController.animateTo(0.0);
    _gracePeriodTimer?.cancel();
    _gracePeriodTimer = null;
    _wasCancelledDueToAppExit = true;
    _appExitWarningCount = 0;
    FocusPipService.setPipEnabled(false);
    _resetPhaseTakeoverState();
    _controller.reset();
    _springWaveBack();
    FocusSoundService.stop();
    FocusNotificationService.showSessionCancelledNotification();
  }

  void _onPhaseChanged(FocusPhase newPhase) {
    if (newPhase == FocusPhase.breakTime) {
      FocusSoundService.playEnterBreak();
      FocusPipService.setPipEnabled(true);
    } else {
      FocusPipService.setPipEnabled(false);
      FocusSoundService.playExitBreak();

      // If user is currently outside the app when break turns into focus:
      if (!_isAppInForeground &&
          _controller.status == FocusTimerStatus.running) {
        _appExitWarningCount = 1;
        FocusNotificationService.showExitWarningNotification();
        _gracePeriodTimer?.cancel();
        _gracePeriodTimer = Timer(const Duration(seconds: 10), () {
          if (!_isAppInForeground &&
              _controller.status == FocusTimerStatus.running &&
              !_controller.isBreakPhase) {
            _cancelSessionDueToAppExit();
          }
        });
      }
    }

    _handlePhaseTakeover(newPhase);
  }

  void _onTimerComplete() {
    FocusWakelockService.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _zenAnimController.animateTo(0.0);
    _resetPhaseTakeoverState();
    _springWaveBack();
    FocusSoundService.playSessionComplete();
    _logCompletedSession();
  }

  /// Inserts one activity_log row for this completed session, then
  /// invalidates progressStatsProvider so the dashboard heatmap and
  /// hours badges update without requiring a restart.
  ///
  /// Write failures surface as a SnackBar but do NOT block the
  /// completion UX — the timer still completes and the sound still plays.
  void _logCompletedSession() {
    // Focus-only seconds — _controller.totalSeconds never includes breaks.
    final focusSeconds = _controller.totalSeconds;
    final clientId = _sessionClientId;
    if (clientId == null || focusSeconds <= 0) return;

    final service = ref.read(activityLogServiceProvider);
    service
        .logFocusSession(
          durationSeconds: focusSeconds,
          clientId: clientId,
        )
        .then((_) {
          // Refresh dashboard stats so heatmap + hours update immediately.
          ref.invalidate(progressStatsProvider);
        })
        .catchError((Object e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not save focus session: $e',
                style: const TextStyle(
                  fontFamily: 'GoogleSans',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppTheme.wishlist,
              duration: const Duration(seconds: 4),
            ),
          );
        });
  }

  void _onEntryWipeStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _showLightOverlay = false;
      });
    }
  }

  void _onExitWipeStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      // Dark exit sweep finished covering the screen — the light break
      // layer beneath it is no longer needed either.
      _showDarkExitOverlay = false;
      _showLightOverlay = false;
    });
  }

  void _resetPhaseTakeoverState() {
    _entryWipeController.stop();
    _exitWipeController.stop();
    _startRollController.stop();
    _entryWipeController.value = 0.0;
    _exitWipeController.value = 0.0;
    _showLightOverlay = false;
    _showDarkExitOverlay = false;
  }

  /// Drives ANIMATION 1 (phase takeover) in response to a phase change.
  ///
  /// [newPhase] may reflect a transition that happened moments ago (normal
  /// tick) or minutes ago (resume via [FocusTimerController.syncWithSystemTime]).
  /// Only the former animates; the latter snaps straight to the target state.
  void _handlePhaseTakeover(FocusPhase newPhase) {
    final enteringBreak = newPhase == FocusPhase.breakTime;

    // Roll the readout from 0 up to the new phase's duration either way.
    _rollStartSeconds = 0;
    _rollTargetSeconds = _controller.currentPhaseTotalSeconds;

    final phaseStartedAt = _controller.phaseStartedAt;
    final isRecent =
        phaseStartedAt != null &&
        DateTime.now().difference(phaseStartedAt) < const Duration(seconds: 3);

    final canAnimate =
        mounted && !_isInPipMode && _isAppInForeground && isRecent;

    if (!canAnimate) {
      _startRollController.stop();
      _entryWipeController.stop();
      _exitWipeController.stop();
      setState(() {
        _showDarkExitOverlay = false;
        _showLightOverlay = false;
        _entryWipeController.value = 0.0;
        _exitWipeController.value = 0.0;
      });
      return;
    }

    final isAmoled = _zenAnimController.value >= 0.5;
    if (isAmoled) {
      // In AMOLED mode: play full-screen dome wipe between Black and White AMOLED
      _startPhaseWipe(enteringBreak);
    } else {
      // In Non-AMOLED mode: background shifts naturally, timer rolls, no wipe overlay
      _startRollController.forward(from: 0.0);
      setState(() {
        _showLightOverlay = false;
        _showDarkExitOverlay = false;
      });
    }
  }

  void _startPhaseWipe(bool enteringBreak) {
    if (!mounted) return;
    if (enteringBreak) {
      setState(() => _showLightOverlay = true);
      _startRollController.forward(from: 0.0);
      _entryWipeController.forward(from: 0.0);
    } else {
      setState(() => _showDarkExitOverlay = true);
      // _showLightOverlay stays true: the exit wipe needs the light clone
      // still visible beneath the dark dome as it sweeps down.
      _startRollController.forward(from: 0.0);
      _exitWipeController.forward(from: 0.0);
    }
  }

  void _skipActiveWipe() {
    if (_entryWipeController.isAnimating) {
      _entryWipeController.value = 1.0;
      setState(() => _showLightOverlay = false);
    } else if (_exitWipeController.isAnimating) {
      _exitWipeController.value = 1.0;
      setState(() {
        _showDarkExitOverlay = false;
        _showLightOverlay = false;
      });
    }
  }

  void showGiveUpSheet() {
    if (_controller.status == FocusTimerStatus.running) {
      setState(() => _showGiveUpSheet = true);
    }
  }

  void _showEditTimeDialog() {
    if (_controller.status != FocusTimerStatus.idle) return;

    showDialog(
      context: context,
      builder: (ctx) => _TimePickerDialog(
        initialSeconds: _controller.totalSeconds,
        onConfirm: (totalSeconds) {
          final mins = (totalSeconds / 60.0).clamp(1.0, 180.0);
          setState(() {
            _targetSliderMinutes = mins;
            _animatedSliderMinutes = mins;
            if (_showTutorial && _tutorialStep == 0) {
              _tutorialStep = 1;
            }
          });
          _controller.setDuration(totalSeconds);
        },
      ),
    );
  }

  double _maxKnobOffset(BoxConstraints constraints) {
    return constraints.maxWidth - _knobSize - (_trackHorizontalPadding * 2);
  }

  void _springWaveBack() {
    final spring = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 300.0,
      ratio: 0.8,
    );
    final sim = SpringSimulation(
      spring,
      _controller.waveAnimationController.value,
      0.0,
      -0.5,
    );
    _controller.waveAnimationController.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInPipMode) {
      return _buildPipMiniplayer();
    }
    return _buildMainScaffold();
  }

  Widget _buildPipMiniplayer() {
    final isBreak = _controller.isBreakPhase;
    final accentColor = AppTheme.accentPurple;

    return Scaffold(
      backgroundColor: AppTheme.secondary,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.secondary,
          border: Border.all(
            color: accentColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Center(
          child: isBreak
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.coffee_rounded, color: accentColor, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Break',
                          style: TextStyle(
                            fontFamily: 'GoogleSans',
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _controller.formattedTime,
                          style: TextStyle(
                            fontFamily: 'GoogleSans',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.2),
                      ),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Return to the app to continue focusing',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'GoogleSans',
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMainScaffold() {
    final isRunning = _controller.status == FocusTimerStatus.running;
    final canPop =
        _controller.status == FocusTimerStatus.idle ||
        _controller.status == FocusTimerStatus.complete;
    final zen = _zenAnimController.value;
    final slideProgress = isRunning
        ? 0.0
        : (_knobOffset / 180.0).clamp(0.0, 1.0);
    final isBreak = _controller.isBreakPhase;
    final targetBreakProgress = isBreak ? 1.0 : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: targetBreakProgress,
        end: targetBreakProgress,
      ),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      builder: (context, breakVal, _) {
        // Smoothly lightened Non-AMOLED base background
        final nonAmoledBg = Color.lerp(
          AppTheme.background,
          AppTheme.bgGradBegin,
          breakVal,
        )!;
        final isEntryWiping = _entryWipeController.isAnimating;
        final isExitWiping = _exitWipeController.isAnimating;

        // While the white wipe is sweeping UP during focus->break, the underlying
        // canvas remains black AMOLED so the white dome sweeps cleanly over black.
        // Once the wipe completes (or while in held break), the canvas is white AMOLED.
        final amoledBg = (isBreak && !isEntryWiping) || isExitWiping
            ? Colors.white
            : Colors.black;

        final scaffoldBg = Color.lerp(nonAmoledBg, amoledBg, zen)!;

        // In Non-AMOLED mode: text NEVER inverts (stays white/light).
        // In AMOLED mode: text inverts when screen is white AMOLED.
        final isAmoledWhite = ((isBreak && !isEntryWiping) || isExitWiping);
        final activePalette = isBreak
            ? _FocusPalette(
                background: scaffoldBg,
                onBackground: isAmoledWhite
                    ? Color.lerp(Colors.white, _lightPalette.onBackground, zen)!
                    : Colors.white,
                muted: isAmoledWhite
                    ? Color.lerp(Colors.white70, _lightPalette.muted, zen)!
                    : Colors.white70,
                accent: isAmoledWhite
                    ? Color.lerp(
                        AppTheme.accentPurple,
                        _lightPalette.accent,
                        zen,
                      )!
                    : AppTheme.accentPurple,
              )
            : _darkPalette;

        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && isRunning) showGiveUpSheet();
          },
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (isRunning) {
                final delta = details.primaryDelta ?? 0.0;
                // Dragging up (negative delta) increases zen progress towards 1.0
                // Dragging down (positive delta) decreases zen progress towards 0.0
                _zenAnimController.value =
                    (_zenAnimController.value - delta / 220.0).clamp(0.0, 1.0);
              }
            },
            onVerticalDragEnd: (details) {
              if (isRunning) {
                final velocity = details.primaryVelocity ?? 0.0;
                // Positive velocity means dragging DOWN (towards normal Non-AMOLED)
                // Negative velocity means dragging UP (towards AMOLED)
                if (velocity > 200) {
                  _zenAnimController.animateTo(0.0, curve: Curves.easeOutCubic);
                  _updateAmoledWakelock(forceState: false);
                  if (_showTutorial && _tutorialStep == 4) {
                    _dismissTutorial();
                  }
                } else if (velocity < -200) {
                  _zenAnimController.animateTo(1.0, curve: Curves.easeOutCubic);
                  _updateAmoledWakelock(forceState: true);
                  if (_showTutorial && _tutorialStep == 3) {
                    setState(() => _tutorialStep = 4);
                  }
                } else if (_zenAnimController.value > 0.5) {
                  _zenAnimController.animateTo(1.0, curve: Curves.easeOutCubic);
                  _updateAmoledWakelock(forceState: true);
                  if (_showTutorial && _tutorialStep == 3) {
                    setState(() => _tutorialStep = 4);
                  }
                } else {
                  _zenAnimController.animateTo(0.0, curve: Curves.easeOutCubic);
                  _updateAmoledWakelock(forceState: false);
                  if (_showTutorial && _tutorialStep == 4) {
                    _dismissTutorial();
                  }
                }
              }
            },
            behavior: HitTestBehavior.translucent,
            child: Scaffold(
              backgroundColor: scaffoldBg,
              body: Stack(
                children: [
                  // Dynamic normal background (smoothly expands ambient glow circle and lightens in break)
                  AnimatedBuilder(
                    animation: _controller.waveAnimationController,
                    builder: (context, _) {
                      return Opacity(
                        opacity: (1.0 - zen).clamp(0.0, 1.0),
                        child: FocusBackground(
                          slideProgress: _controller.slideProgress,
                          breakProgress: breakVal,
                        ),
                      );
                    },
                  ),

                  // AMOLED pure overlay (black in focus, pure white in break)
                  if (zen > 0.0)
                    Positioned.fill(
                      child: Container(color: amoledBg.withValues(alpha: zen)),
                    ),

                  // REAL, interactive body
                  _buildBody(
                    context,
                    activePalette,
                    isRunning: isRunning,
                    zen: zen,
                    slideProgress: slideProgress,
                  ),

                  // ANIMATION 1a: light-theme clone of the same body, revealed by
                  // a dome-up wipe on focus -> break and held fully open for the
                  // whole break (rendered at AMOLED zen = 1.0).
                  if (_showLightOverlay)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipPath(
                          clipper: PhaseWipeClipper(
                            progress: Curves.easeInOutCubic.transform(
                              _entryWipeController.value,
                            ),
                            domeUp: true,
                          ),
                          child: Container(
                            color: Colors.white,
                            child: _buildBody(
                              context,
                              _lightPalette,
                              isRunning: isRunning,
                              zen: 1.0,
                              slideProgress: slideProgress,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ANIMATION 1b: dark-theme clone sweeping back over the light
                  // layer on break -> focus (dome down, rendered at AMOLED zen = 1.0).
                  if (_showDarkExitOverlay)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipPath(
                          clipper: PhaseWipeClipper(
                            progress: Curves.easeInOutCubic.transform(
                              _exitWipeController.value,
                            ),
                            domeUp: false,
                          ),
                          child: Container(
                            color: Colors.black,
                            child: _buildBody(
                              context,
                              _darkPalette,
                              isRunning: isRunning,
                              zen: 1.0,
                              slideProgress: slideProgress,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Tap-to-skip: only intercepts while a wipe is actively
                  // animating, never during the multi-minute held break.
                  if (_entryWipeController.isAnimating ||
                      _exitWipeController.isAnimating)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _skipActiveWipe,
                      ),
                    ),

                  if (_showGiveUpSheet) _buildGiveUpOverlay(),
                  _buildTutorialBottomBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The entire visible content column — top bar, clock hero, phase label,
  /// timer readout, progress bar, and interaction zone — parameterized by
  /// [palette]. Called twice (dark = real, light = decorative clone) so the
  /// two are structurally identical by construction; only leaf colors that
  /// consume [palette] differ.
  Widget _buildBody(
    BuildContext context,
    _FocusPalette palette, {
    required bool isRunning,
    required double zen,
    required double slideProgress,
  }) {
    return SafeArea(
      child: Column(
        children: [
          // Top bar (fades out first or when sliding to lock in, dimmed during tutorial)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            opacity: _showTutorial ? 0.22 : 1.0,
            child: Opacity(
              opacity: isRunning
                  ? (1.0 - zen * 3.0).clamp(0.0, 1.0)
                  : (1.0 - slideProgress * 2.0).clamp(0.0, 1.0),
              child: _buildTopBar(isRunning),
            ),
          ),

          // Bonsai hero art (fades and moves up out of view, dimmed during tutorial)
          Expanded(
            flex: 44,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              opacity: _showTutorial ? 0.22 : 1.0,
              child: Transform.translate(
                offset: Offset(0, -60 * zen),
                child: Opacity(
                  opacity: (1.0 - zen * 2.5).clamp(0.0, 1.0),
                  child: _buildBonsaiHero(isRunning),
                ),
              ),
            ),
          ),

          // Main timer zone (centers and enlarges)
          Expanded(
            flex: 56,
            child: Transform.translate(
              offset: Offset(
                0,
                -MediaQuery.of(context).size.height * 0.22 * zen,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Phase title: "Focus" / "Break" (Always visible in AMOLED mode)
                    // Phase title: "Focus" / "Break" (Always visible in AMOLED mode)
                    if (isRunning) ...[
                      OverflowHitTestStack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Text(
                            _controller.isBreakPhase ? 'Break' : 'Focus',
                            style: TextStyle(
                              fontFamily: 'GoogleSans',
                              color: palette.onBackground.withValues(
                                alpha: (0.95 - (zen * 0.15)).clamp(0.75, 0.95),
                              ),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),

                          Positioned(
                            bottom: 28,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 48,
                              child: AnimatedOpacity(
                                opacity:
                                    (isRunning &&
                                        _showTutorial &&
                                        _tutorialStep == 3 &&
                                        zen < 0.5)
                                    ? 1.0
                                    : 0.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: IgnorePointer(
                                  ignoring:
                                      !(isRunning &&
                                          _showTutorial &&
                                          _tutorialStep == 3 &&
                                          zen < 0.5),
                                  child: const TutorialCallout(
                                    instruction: 'Swipe UP for AMOLED mode',
                                    pointsDown: true,
                                    swipeIndicator: TutorialSwipeIndicator.up,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: 28,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 48,
                              child: AnimatedOpacity(
                                opacity:
                                    (isRunning && _showTutorial && zen >= 0.5)
                                    ? 1.0
                                    : 0.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: IgnorePointer(
                                  ignoring:
                                      !(isRunning &&
                                          _showTutorial &&
                                          zen >= 0.5),
                                  child: TutorialCallout(
                                    instruction:
                                        'Swipe DOWN anytime to return. You are all set!',
                                    pointsDown: true,
                                    swipeIndicator: TutorialSwipeIndicator.down,
                                    onNext: _dismissTutorial,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Enlarging & centered timer readout
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      opacity:
                          (!isRunning && _showTutorial && _tutorialStep != 0)
                          ? 0.22
                          : 1.0,
                      child: Transform.scale(
                        scale: 1.0 + (zen * 0.40),
                        child: _buildTimerReadout(isRunning, palette),
                      ),
                    ),

                    // Progress indicators
                    if (isRunning) ...[
                      SizedBox(height: 14.0 - (4.0 * zen)),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        opacity: _showTutorial ? 0.22 : 1.0,
                        child: _buildProgressIndicators(palette, zen: zen),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Bottom slider & controls
                    Opacity(
                      opacity: (1.0 - zen * 3.0).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: zen > 0.1,
                        child: _controller.status == FocusTimerStatus.complete
                            ? _buildRestartButton()
                            : _buildInteractionZone(
                                isIdle: !isRunning,
                                slideProgress: slideProgress,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isRunning) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isRunning ? 0.0 : 1.0,
      child: IgnorePointer(
        ignoring: isRunning,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, right: 16),
          child: Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showTutorial = true;
                  _tutorialStep = 0;
                });
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBonsaiHero(bool isRunning) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Size relative to the slot instead of a fixed pixel size — a fixed
        // 300 could exceed the flex area's actual height on smaller screens
        // and get clipped/overlap the timer readout below it.
        final shortestSide = min(constraints.maxWidth, constraints.maxHeight);
        final clockSize = shortestSide.isFinite
            ? (shortestSide * 0.78).clamp(160.0, 260.0)
            : 220.0;

        return Center(
          child: Transform.translate(
            // Nudges just the clock down a little within its own slot —
            // doesn't affect the flex allocation or any other element's
            // position.
            offset: const Offset(0, -6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(top: isRunning ? 12 : 0),
              child: AnalogClock(
                size: clockSize,
                isIdle: !isRunning,
                elapsedSeconds:
                    (_controller.currentPhaseTotalSeconds -
                            _controller.currentPhaseSecondsLeft)
                        .toDouble(),
                progress: _controller.currentIntervalProgress,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatSecondsToTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildTimerReadout(bool isRunning, _FocusPalette palette) {
    final isComplete = _controller.status == FocusTimerStatus.complete;
    if (isComplete) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 40,
              color: AppTheme.accentPurple,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Session complete',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: palette.onBackground,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    String displayTime;
    if (_startRollController.isAnimating) {
      final t = Curves.easeInOutCubic.transform(_startRollController.value);
      final currentSec =
          (_rollStartSeconds + (_rollTargetSeconds - _rollStartSeconds) * t)
              .round();
      displayTime = _formatSecondsToTime(currentSec);
    } else if (_controller.status == FocusTimerStatus.idle) {
      displayTime = _controller.formattedTotalFocusTime;
    } else {
      displayTime = _controller.formattedTime;
    }

    return GestureDetector(
      onTap: isRunning ? null : _showEditTimeDialog,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: isRunning ? '' : 'Tap to edit time',
        child: Text(
          displayTime,
          style: TextStyle(
            fontFamily: 'GoogleSans',
            color: palette.onBackground,
            fontSize: 72,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicators(_FocusPalette palette, {double zen = 0.0}) {
    final overallProgress = _controller.sessionProgress;
    final breakSegments = _controller.breakSegments;

    return Column(
      children: [
        Opacity(
          opacity: (1.0 - zen * 2.2).clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SizedBox(
              height: 14.0 * (1.0 - zen),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Base track
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.onBackground.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Break intervals with visible duration thickness
                  if (_controller.isPomodoroEnabled && breakSegments.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        return Stack(
                          children: breakSegments.map((segment) {
                            final left = segment.startFraction * totalWidth;
                            final width = (segment.widthFraction * totalWidth)
                                .clamp(10.0, totalWidth);
                            return Positioned(
                              left: left,
                              width: width,
                              top: 3,
                              height: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: palette.accent.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: palette.background,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                  // Overall session progress fill
                  FractionallySizedBox(
                    widthFactor: overallProgress,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        // Solid accentPurple to match the "Slide to lock
                        // in" bar / "Keep focusing" button color.
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.accentPurple,
                            AppTheme.accentPurple,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentPurple.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 10.0 * (1.0 - zen)),

        // Upcoming break info / next session (Always visible in AMOLED mode)
        if (_controller.isPomodoroEnabled)
          Text(
            _controller.upcomingBreakInfo,
            style: TextStyle(
              fontFamily: 'GoogleSans',
              // Solid AppTheme.accentPurple — matches the "Slide to lock
              // in" / "Keep focusing" button exactly, in both themes.
              color: AppTheme.accentPurple,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildRestartButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Target completed. Ready for another session?',
          style: TextStyle(
            fontFamily: 'GoogleSans',
            color: Colors.white60,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            _appExitWarningCount = 0;
            _gracePeriodTimer?.cancel();
            _gracePeriodTimer = null;
            FocusNotificationService.cancelAll();
            FocusSoundService.stop();
            _resetPhaseTakeoverState();
            _controller.reset();
            _springWaveBack();
          },
          child: Container(
            height: _trackHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              // Solid accentPurple to match the "Slide to lock in" bar /
              // "Keep focusing" button color.
              gradient: const LinearGradient(
                colors: [AppTheme.accentPurple, AppTheme.accentPurple],
              ),
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPurple.withValues(alpha: 0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Start new session',
                style: TextStyle(
                  fontFamily: 'GoogleSans',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionZone({
    required bool isIdle,
    double slideProgress = 0.0,
  }) {
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          child: isIdle
              ? Opacity(
                  opacity: (1.0 - slideProgress * 1.8).clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        opacity: (_showTutorial && _tutorialStep != 0)
                            ? 0.22
                            : 1.0,
                        child: _buildDurationSlider(),
                      ),
                      const SizedBox(height: 10),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        opacity: (_showTutorial && _tutorialStep != 1)
                            ? 0.22
                            : 1.0,
                        child: _buildPomodoroModeToggle(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        LayoutBuilder(
          builder: (context, constraints) => AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            opacity: (_showTutorial && isIdle && _tutorialStep != 2)
                ? 0.22
                : 1.0,
            child: _buildSliderTrackBar(constraints),
          ),
        ),
      ],
    );

    return OverflowHitTestStack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Base layer: controls (slider, toggle, trackbar)
        controls,

        // Overlay layer: tutorial cards painted strictly on top of all controls
        Positioned(
          top: 36,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: (_showTutorial && _tutorialStep == 0 && isIdle)
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !(_showTutorial && _tutorialStep == 0 && isIdle),
              child: const TutorialCallout(
                instruction: 'Drag slider or tap digits to set focus time',
                pointsDown: false,
              ),
            ),
          ),
        ),

        Positioned(
          top: 78,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: (_showTutorial && _tutorialStep == 1 && isIdle)
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !(_showTutorial && _tutorialStep == 1 && isIdle),
              child: const TutorialCallout(
                instruction: 'Toggle Pomodoro for 25m focus + 5m breaks',
                pointsDown: false,
              ),
            ),
          ),
        ),

        Positioned(
          bottom: _trackHeight + 8,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: (_showTutorial && _tutorialStep == 2 && isIdle)
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !(_showTutorial && _tutorialStep == 2 && isIdle),
              child: const TutorialCallout(
                instruction: 'Slide knob to lock in & start',
                pointsDown: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSlider() {
    final isTestMode = FocusTimerController.kTestMode;
    const minVal = 1.0;
    const maxVal = 180.0;
    const snapPoints = [30.0, 60.0, 90.0, 120.0, 150.0];
    final snapThreshold = isTestMode ? 4.0 : 3.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: _animatedSliderMinutes,
              end: _targetSliderMinutes,
            ),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  trackShape: const RoundedRectSliderTrackShape(),
                  thumbShape: const GlowThumbShape(),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: AppTheme.accentPurple,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: val.clamp(minVal, maxVal),
                  min: minVal,
                  max: maxVal,
                  onChanged: (dragVal) {
                    double effectiveVal = dragVal;
                    double? currentSnap;

                    for (final point in snapPoints) {
                      if ((dragVal - point).abs() <= snapThreshold) {
                        effectiveVal = point;
                        currentSnap = point;
                        break;
                      }
                    }

                    if (currentSnap != null) {
                      if (_lastSnappedPoint != currentSnap) {
                        FocusHapticService.snap();
                        _lastSnappedPoint = currentSnap;
                      }
                    } else {
                      _lastSnappedPoint = null;
                    }

                    setState(() {
                      _targetSliderMinutes = effectiveVal;
                      _animatedSliderMinutes = effectiveVal;
                    });
                    final targetSeconds = isTestMode
                        ? effectiveVal.round()
                        : (effectiveVal.round() * 60);
                    _controller.setDuration(targetSeconds);
                  },
                  onChangeEnd: (finalVal) {
                    if (_showTutorial && _tutorialStep == 0) {
                      setState(() => _tutorialStep = 1);
                    }
                    double effectiveVal = finalVal;
                    for (final point in snapPoints) {
                      if ((finalVal - point).abs() <= snapThreshold) {
                        effectiveVal = point;
                        break;
                      }
                    }

                    final finalUnits = effectiveVal.round().clamp(
                      minVal.round(),
                      maxVal.round(),
                    );
                    setState(() {
                      _targetSliderMinutes = finalUnits.toDouble();
                      _animatedSliderMinutes = finalUnits.toDouble();
                    });
                    final targetSeconds = isTestMode
                        ? finalUnits
                        : (finalUnits * 60);
                    _controller.setDuration(targetSeconds);
                    _lastSnappedPoint = null;
                    FocusHapticService.snap();
                  },
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isTestMode ? '1s' : '1 min',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                Text(
                  isTestMode ? '3m' : '3 hours',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPomodoroModeToggle() {
    final enabled = _controller.isPomodoroEnabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (_showTutorial && _tutorialStep == 1) {
              setState(() => _tutorialStep = 2);
            }
            _controller.setPomodoroEnabled(!enabled);
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timelapse_rounded,
                size: 15,
                color: enabled ? AppTheme.accentPurple : Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                'Pomodoro mode',
                style: TextStyle(
                  fontFamily: 'GoogleSans',
                  color: enabled ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 38,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: enabled,
                    activeThumbColor: AppTheme.accentPurple,
                    activeTrackColor: AppTheme.accentPurple.withValues(
                      alpha: 0.4,
                    ),
                    inactiveThumbColor: Colors.white38,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                    onChanged: (val) {
                      if (_showTutorial && _tutorialStep == 1) {
                        setState(() => _tutorialStep = 2);
                      }
                      _controller.setPomodoroEnabled(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Easing break count subtitle placed directly below the Pomodoro toggle
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.center,
                child: child,
              ),
            );
          },
          child: enabled
              ? Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Center(
                    child: Text(
                      _controller.breaksSubtitle,
                      key: ValueKey(_controller.breaksSubtitle),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'GoogleSans',
                        color: AppTheme.accentPurple.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no_breaks_pomodoro_off')),
        ),
      ],
    );
  }

  Widget _buildSliderTrackBar(BoxConstraints constraints) {
    final isRunning = _controller.status == FocusTimerStatus.running;
    final maxOffset = _maxKnobOffset(constraints);

    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (details) {
        setState(() {
          _knobOffset = (_knobOffset + details.delta.dx).clamp(0.0, maxOffset);
        });
        if (!isRunning) {
          _controller.waveAnimationController.value = _knobOffset / maxOffset;
        }
      },
      onHorizontalDragEnd: (_) {
        final progressFraction = _knobOffset / maxOffset;

        if (progressFraction >= _triggerFraction) {
          setState(() => _dragging = false);
          if (!isRunning) {
            if (_showTutorial && _tutorialStep == 2) {
              setState(() => _tutorialStep = 3);
            }
            _appExitWarningCount = 0;
            _wasCancelledDueToAppExit = false;
            _gracePeriodTimer?.cancel();
            _gracePeriodTimer = null;
            FocusNotificationService.cancelAll();

            final startSec = _controller.totalSeconds;
            final targetSec = _controller.isPomodoroEnabled
                ? min(startSec, FocusTimerController.pomodoroFocusDuration)
                : startSec;

            _rollStartSeconds = startSec;
            _rollTargetSeconds = targetSec;

            // Generate a fresh idempotency key for this session.
            _sessionClientId = const Uuid().v4();

            _controller.start();
            _controller.waveAnimationController.value = 1.0;
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            FocusSoundService.playStartFocus();

            if (startSec != targetSec) {
              _startRollController.forward(from: 0.0);
            }

            setState(() => _knobOffset = 0);
          } else {
            setState(() => _knobOffset = 0);
            showGiveUpSheet();
          }
        } else {
          setState(() => _dragging = false);
          setState(() => _knobOffset = 0);
          if (!isRunning) {
            _springWaveBack();
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_trackHeight / 2),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: _trackHeight,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Layer 0: Base resting background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppTheme.surfaceGradBegin,
                        AppTheme.surfaceGradEnd,
                      ],
                    ),
                  ),
                ),
              ),

              // Layer 1: Convex sliding wipe
              Positioned.fill(
                child: ClipPath(
                  clipper: _KnobWipeClipper(
                    knobOffset: _knobOffset,
                    knobSize: _knobSize,
                    padding: _trackHorizontalPadding,
                    isDragging: _dragging,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isRunning
                          ? LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                AppTheme.wishlist.withValues(alpha: 0.75),
                                AppTheme.wishlist.withValues(alpha: 0.45),
                              ],
                            )
                          // Solid accentPurple to match the "Keep focusing"
                          // chunky button instead of the deeper primary
                          // gradient.
                          : const LinearGradient(
                              colors: [
                                AppTheme.accentPurple,
                                AppTheme.accentPurple,
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              // Layer 1.5: Floating border stroke
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_trackHeight / 2),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

              // Layer 2: Label text
              Center(
                child: Text(
                  isRunning ? 'Slide to give up' : 'Slide to lock in',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    color: Colors.white.withValues(
                      alpha: isRunning ? 0.7 : 0.5,
                    ),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Layer 3: Knob thumb
              AnimatedPositioned(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: _trackHorizontalPadding + _knobOffset,
                child: Container(
                  width: _knobSize,
                  height: _knobSize,
                  decoration: BoxDecoration(
                    color: isRunning
                        ? AppTheme.wishlist
                        : AppTheme.accentPurple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isRunning
                                    ? AppTheme.wishlist
                                    : AppTheme.accentPurple)
                                .withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiveUpOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showGiveUpSheet = false),
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _GiveUpSheetView(
            timeRemaining: _controller.formattedTime,
            onResume: () => setState(() => _showGiveUpSheet = false),
            onClear: () {
              setState(() => _showGiveUpSheet = false);
              FocusWakelockService.disable();
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              _zenAnimController.animateTo(0.0);
              _appExitWarningCount = 0;
              _gracePeriodTimer?.cancel();
              _gracePeriodTimer = null;
              FocusNotificationService.cancelAll();
              FocusSoundService.stop();
              _resetPhaseTakeoverState();
              _controller.reset();
              _springWaveBack();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: AnimatedOpacity(
        opacity: _showTutorial ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: !_showTutorial,
          child: SafeArea(
            top: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1926).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                        () => _tutorialDontShowAgain = !_tutorialDontShowAgain,
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _tutorialDontShowAgain
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 17,
                            color: _tutorialDontShowAgain
                                ? AppTheme.accentPurple
                                : Colors.white54,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Don't show again",
                            style: TextStyle(
                              fontFamily: 'GoogleSans',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 12,
                      width: 1,
                      color: Colors.white24,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    GestureDetector(
                      onTap: _dismissTutorial,
                      child: const Text(
                        'Skip Tutorial',
                        style: TextStyle(
                          fontFamily: 'GoogleSans',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Samsung Clock Style Rolling Wheel Time Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _TimePickerDialog extends StatefulWidget {
  final int initialSeconds;
  final ValueChanged<int> onConfirm;

  const _TimePickerDialog({
    required this.initialSeconds,
    required this.onConfirm,
  });

  @override
  State<_TimePickerDialog> createState() => _TimePickerDialogState();
}

class _TimePickerDialogState extends State<_TimePickerDialog> {
  late int _selectedHours;
  late int _selectedMinutes;

  late final FixedExtentScrollController _hoursScrollCtrl;
  late final FixedExtentScrollController _minsScrollCtrl;

  static const int maxHours = 3;
  static const int maxMinutes = 59;
  static const double itemHeight = 48.0;

  @override
  void initState() {
    super.initState();
    final totalMins = (widget.initialSeconds ~/ 60).clamp(1, 180);
    _selectedHours = (totalMins ~/ 60).clamp(0, maxHours);
    _selectedMinutes = (totalMins % 60).clamp(0, maxMinutes);

    _hoursScrollCtrl = FixedExtentScrollController(initialItem: _selectedHours);
    _minsScrollCtrl = FixedExtentScrollController(
      initialItem: _selectedMinutes,
    );
  }

  @override
  void dispose() {
    _hoursScrollCtrl.dispose();
    _minsScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      titlePadding: const EdgeInsets.only(top: 22, bottom: 6),
      title: Text(
        'Set duration',
        style: TextStyle(
          fontFamily: 'GoogleSans',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      content: SizedBox(
        width: 280,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center active selection glass indicator
            Container(
              height: itemHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accentPurple.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
            ),

            // The rolling wheel columns
            Row(
              children: [
                // Hours Wheel
                Expanded(
                  child: _buildWheel(
                    controller: _hoursScrollCtrl,
                    itemCount: maxHours + 1,
                    selectedItem: _selectedHours,
                    unitLabel: 'hr',
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedHours = index);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),

                // Colon divider
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontFamily: 'GoogleSans',
                      color: Colors.white54,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Minutes Wheel
                Expanded(
                  child: _buildWheel(
                    controller: _minsScrollCtrl,
                    itemCount: maxMinutes + 1,
                    selectedItem: _selectedMinutes,
                    unitLabel: 'min',
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedMinutes = index);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(fontFamily: 'GoogleSans', color: Colors.white54),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            var totalMinutes = _selectedHours * 60 + _selectedMinutes;
            if (totalMinutes == 0) totalMinutes = 1;
            widget.onConfirm(totalMinutes * 60);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'Set duration',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedItem,
    required String unitLabel,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemHeight,
      perspective: 0.003,
      diameterRatio: 1.25,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final isSelected = index == selectedItem;
          return Center(
            child: AnimatedScale(
              scale: isSelected ? 1.0 : 0.74,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontFamily: 'GoogleSans',
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unitLabel,
                      style: TextStyle(
                        fontFamily: 'GoogleSans',
                        color: isSelected
                            ? AppTheme.accentPurple
                            : Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Convex Wipe Path Geometry Clipper
// ─────────────────────────────────────────────────────────────────────────────
class _KnobWipeClipper extends CustomClipper<Path> {
  final double knobOffset;
  final double knobSize;
  final double padding;
  final bool isDragging;

  _KnobWipeClipper({
    required this.knobOffset,
    required this.knobSize,
    required this.padding,
    required this.isDragging,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    if (!isDragging) {
      return path;
    }

    final double knobCentreX = padding + knobOffset + (knobSize / 2);
    final double radius = knobSize / 2;

    path.moveTo(0, 0);
    path.lineTo(knobCentreX, 0);

    path.arcToPoint(
      Offset(knobCentreX, size.height),
      radius: Radius.circular(radius),
      clockwise: true,
    );

    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_KnobWipeClipper oldClipper) {
    return oldClipper.knobOffset != knobOffset ||
        oldClipper.knobSize != knobSize ||
        oldClipper.padding != padding ||
        oldClipper.isDragging != isDragging;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Give Up Bottom Overlay Sheet (Minimalist & Clean)
// ─────────────────────────────────────────────────────────────────────────────
class _GiveUpSheetView extends StatelessWidget {
  final String timeRemaining;
  final VoidCallback onResume;
  final VoidCallback onClear;

  const _GiveUpSheetView({
    required this.timeRemaining,
    required this.onResume,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Give up this session?',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Remaining focus duration: $timeRemaining',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          _ChunkyButton(label: 'Keep focusing', onTap: onResume),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.wishlist.withValues(alpha: 0.6)),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'End session',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.wishlist,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Matches `_ChunkyButton` in onboarding_welcome_page.dart / auth_preview_sheet.dart:
/// solid accent-purple fill, 4px translate down on press, shadow removed
/// while pressed — instead of a plain gradient button with no press feedback.
class _ChunkyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ChunkyButton({required this.label, required this.onTap});

  @override
  State<_ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<_ChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: _pressed
            ? Matrix4.translationValues(0, 4, 0)
            : Matrix4.identity(),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.accentPurple,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _pressed ? [] : AppTheme.chunkyButtonShadow,
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontFamily: 'GoogleSans',
            color: AppTheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
