import 'dart:async';
import 'dart:math';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/focus_session/services/focus_notification_service.dart';
import 'package:Skolar/features/focus_session/services/focus_pip_service.dart';
import 'package:Skolar/features/focus_session/services/focus_sound_service.dart';
import 'package:Skolar/features/focus_session/widgets/glow_thumb_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../controllers/focus_timer_controller.dart';
import '../widgets/focus_background.dart';
import '../widgets/phase_takeover.dart';

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

class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});

  @override
  State<FocusTimerPage> createState() => FocusTimerPageState();
}

class FocusTimerPageState extends State<FocusTimerPage>
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

  double _knobOffset = 0;
  bool _dragging = false;
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
    _exitWipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _exitWipeController.addListener(() => setState(() {}));
    _exitWipeController.addStatusListener(_onExitWipeStatusChanged);

    _targetSliderMinutes = (_controller.totalSeconds / 60.0).clamp(1.0, 180.0);
    _animatedSliderMinutes = _targetSliderMinutes;
    _controller.addListener(() => setState(() {}));
    _controller.onComplete = _onTimerComplete;
    _controller.onPhaseChanged = _onPhaseChanged;

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
                style: TextStyle(fontFamily: 'GoogleSans',
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
      if (_controller.status == FocusTimerStatus.running) {
        _cancelSessionDueToAppExit();
      }
    }
  }

  void _cancelSessionDueToAppExit() {
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _zenAnimController.animateTo(0.0);
    _resetPhaseTakeoverState();
    _springWaveBack();
    FocusSoundService.playSessionComplete();
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
    final isRecent = phaseStartedAt != null &&
        DateTime.now().difference(phaseStartedAt) < const Duration(seconds: 3);

    final canAnimate =
        mounted && !_isInPipMode && _isAppInForeground && isRecent;

    if (!canAnimate) {
      _startRollController.stop();
      _entryWipeController.stop();
      _exitWipeController.stop();
      setState(() {
        _showDarkExitOverlay = false;
        _showLightOverlay = enteringBreak;
        _entryWipeController.value = enteringBreak ? 1.0 : 0.0;
        _exitWipeController.value = 0.0;
      });
      return;
    }

    // Zen/AMOLED is the primary case here, not an exception: a phase change
    // is hardest to notice exactly when the user is deep in zen. The wipe
    // always plays, and both stacked bodies always render at zen == 1.0
    // geometry during it — same timer position/scale/visible elements as
    // the AMOLED screen, so nothing moves during the wipe itself. If the
    // user isn't already in zen, settle into zen FIRST, then start the
    // wipe — the layout shift and the wipe must never overlap. Zen is not
    // forced back afterward; the session simply continues in zen from here.
    if (_zenAnimController.value >= 1.0) {
      _startPhaseWipe(enteringBreak);
    } else {
      _zenAnimController
          .animateTo(1.0, curve: Curves.easeOutCubic)
          .whenComplete(() => _startPhaseWipe(enteringBreak));
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
    } else if (_exitWipeController.isAnimating) {
      _exitWipeController.value = 1.0;
    }
  }

  void showGiveUpSheet() {
    if (_controller.status == FocusTimerStatus.running) {
      setState(() => _showGiveUpSheet = true);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.spa_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Deep Focus Mode',
              style: TextStyle(fontFamily: 'GoogleSans',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              Icons.notifications_active_rounded,
              'Stay within the app while focusing. Leaving the app will issue a warning and automatically cancel after 10 seconds.',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              Icons.coffee_rounded,
              'During breaks, you can freely exit the app or use Picture-in-Picture mode.',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              Icons.lock_clock_rounded,
              'Your timer continues accurately even if your device screen turns off.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Got it',
              style: TextStyle(fontFamily: 'GoogleSans',
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.accentPurple),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontFamily: 'GoogleSans',
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
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
      backgroundColor: const Color(0xFF13131A),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
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
                          style: TextStyle(fontFamily: 'GoogleSans',
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _controller.formattedTime,
                          style: TextStyle(fontFamily: 'GoogleSans',
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
                      style: TextStyle(fontFamily: 'GoogleSans',
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
    final slideProgress =
        isRunning ? 0.0 : (_knobOffset / 180.0).clamp(0.0, 1.0);

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
            _zenAnimController.value =
                (_zenAnimController.value - delta / 260.0).clamp(0.0, 1.0);
          }
        },
        onVerticalDragEnd: (details) {
          if (isRunning) {
            final velocity = details.primaryVelocity ?? 0.0;
            if (velocity < -300 || _zenAnimController.value > 0.45) {
              _zenAnimController.animateTo(1.0, curve: Curves.easeOutCubic);
            } else {
              _zenAnimController.animateTo(0.0, curve: Curves.easeOutCubic);
            }
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: Color.lerp(AppTheme.background, Colors.black, zen),
          body: Stack(
            children: [
              // Dynamic normal background (fades out as AMOLED zen increases)
              AnimatedBuilder(
                animation: _controller.waveAnimationController,
                builder: (context, _) {
                  return Opacity(
                    opacity: (1.0 - zen).clamp(0.0, 1.0),
                    child: FocusBackground(
                      slideProgress: _controller.slideProgress,
                    ),
                  );
                },
              ),

              // AMOLED pure black overlay
              if (zen > 0.0)
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: zen)),
                ),

              // REAL, interactive body — unchanged in every way.
              _buildBody(
                context,
                _darkPalette,
                isRunning: isRunning,
                zen: zen,
                slideProgress: slideProgress,
              ),

              // ANIMATION 1a: light-theme clone of the same body, revealed by
              // a dome-up wipe on focus -> break and held fully open for the
              // whole break. Purely decorative: IgnorePointer lets every
              // gesture pass through to the real body above.
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
                        color: _lightPalette.background,
                        child: _buildBody(
                          context,
                          _lightPalette,
                          isRunning: isRunning,
                          zen: zen,
                          slideProgress: slideProgress,
                        ),
                      ),
                    ),
                  ),
                ),

              // ANIMATION 1b: dark-theme clone sweeping back over the light
              // layer on break -> focus (dome down). Also decorative.
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
                        color: _darkPalette.background,
                        child: _buildBody(
                          context,
                          _darkPalette,
                          isRunning: isRunning,
                          zen: zen,
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
            ],
          ),
        ),
      ),
    );
  }

  /// The entire visible content column — top bar, bonsai hero, phase label,
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
          // Top bar (fades out first or when sliding to lock in)
          Opacity(
            opacity: isRunning
                ? (1.0 - zen * 3.0).clamp(0.0, 1.0)
                : (1.0 - slideProgress * 2.0).clamp(0.0, 1.0),
            child: _buildTopBar(isRunning),
          ),

          // Bonsai hero art (fades and moves up out of view)
          Expanded(
            flex: 44,
            child: Transform.translate(
              offset: Offset(0, -60 * zen),
              child: Opacity(
                opacity: (1.0 - zen * 2.5).clamp(0.0, 1.0),
                child: _buildBonsaiHero(isRunning),
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
                    if (isRunning) ...[
                      Text(
                        _controller.isBreakPhase ? 'Break' : 'Focus',
                        style: TextStyle(fontFamily: 'GoogleSans',
                          color: palette.onBackground.withValues(
                            alpha: (0.95 - (zen * 0.15)).clamp(0.75, 0.95),
                          ),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Enlarging & centered timer readout
                    Transform.scale(
                      scale: 1.0 + (zen * 0.40),
                      child: _buildTimerReadout(isRunning, palette),
                    ),

                    // Progress indicators
                    if (isRunning) ...[
                      SizedBox(height: 14.0 - (4.0 * zen)),
                      _buildProgressIndicators(palette, zen: zen),
                    ],

                    const SizedBox(height: 20),

                    // Bottom slider & controls
                    Opacity(
                      opacity: (1.0 - zen * 3.0).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: zen > 0.1,
                        child:
                            _controller.status == FocusTimerStatus.complete
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
              onTap: _showHelpDialog,
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
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        padding: EdgeInsets.only(top: isRunning ? 20 : 0),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 10),
          child: Image.asset(
            'assets/images/bonsai.png',
            width: 230,
            height: 210,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.spa_rounded,
              size: 80,
              color: Color(0xFF4DA83B),
            ),
          ),
        ),
      ),
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
              color: AppTheme.primary.withValues(alpha: 0.18),
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
            style: TextStyle(fontFamily: 'GoogleSans',
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
          style: TextStyle(fontFamily: 'GoogleSans',
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
                                  color: palette.accent.withValues(
                                    alpha: 0.6,
                                  ),
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
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
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
            style: TextStyle(fontFamily: 'GoogleSans',
              color: palette.accent.withValues(
                alpha: (0.95 - (zen * 0.15)).clamp(0.75, 0.95),
              ),
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
          style: TextStyle(fontFamily: 'GoogleSans',color: Colors.white60, fontSize: 14),
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
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Start new session',
                style: TextStyle(fontFamily: 'GoogleSans',
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
    return Column(
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
                      _buildDurationSlider(),
                      const SizedBox(height: 10),
                      _buildPomodoroModeToggle(),
                      const SizedBox(height: 16),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        LayoutBuilder(
          builder: (context, constraints) => _buildSliderTrackBar(constraints),
        ),
      ],
    );
  }

  Widget _buildDurationSlider() {
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
                  thumbShape: const GlowThumbShape(),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: AppTheme.primary,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: val.clamp(1.0, 180.0),
                  min: 1,
                  max: 180,
                  onChanged: (dragVal) {
                    setState(() {
                      _targetSliderMinutes = dragVal;
                      _animatedSliderMinutes = dragVal;
                    });
                    _controller.setDuration(dragVal.round() * 60);
                  },
                  onChangeEnd: (finalVal) {
                    final snapped = ((finalVal / 5.0).round() * 5).clamp(
                      1,
                      180,
                    );
                    setState(() {
                      _targetSliderMinutes = snapped.toDouble();
                      _animatedSliderMinutes = snapped.toDouble();
                    });
                    _controller.setDuration(snapped * 60);
                    HapticFeedback.selectionClick();
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
                  '1 min',
                  style: TextStyle(fontFamily: 'GoogleSans',
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '1 hour',
                  style: TextStyle(fontFamily: 'GoogleSans',
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '3 hours',
                  style: TextStyle(fontFamily: 'GoogleSans',
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
          onTap: () => _controller.setPomodoroEnabled(!enabled),
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
                style: TextStyle(fontFamily: 'GoogleSans',
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
                    activeThumbColor: AppTheme.primary,
                    activeTrackColor: AppTheme.primary.withValues(alpha: 0.4),
                    inactiveThumbColor: Colors.white38,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                    onChanged: (val) => _controller.setPomodoroEnabled(val),
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
                      style: TextStyle(fontFamily: 'GoogleSans',
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
                      colors: [Color(0xFF262433), Color(0xFF181622)],
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
                          ? const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFF521C2B), Color(0xFF2B0E17)],
                            )
                          : AppTheme.primaryGradient,
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
                  style: TextStyle(fontFamily: 'GoogleSans',
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
                        ? const Color(0xFFE53935)
                        : AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isRunning
                                ? const Color(0xFFE53935)
                                : AppTheme.primary)
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
        style: TextStyle(fontFamily: 'GoogleSans',
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
                color: AppTheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.4),
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
                    style: TextStyle(fontFamily: 'GoogleSans',
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
            style: TextStyle(fontFamily: 'GoogleSans',color: Colors.white54),
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
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'Set duration',
            style: TextStyle(fontFamily: 'GoogleSans',
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
                      style: TextStyle(fontFamily: 'GoogleSans',
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unitLabel,
                      style: TextStyle(fontFamily: 'GoogleSans',
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
            style: TextStyle(fontFamily: 'GoogleSans',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Remaining focus duration: $timeRemaining',
            style: TextStyle(fontFamily: 'GoogleSans',color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onResume,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'Keep focusing',
                style: TextStyle(fontFamily: 'GoogleSans',
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
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
              style: TextStyle(fontFamily: 'GoogleSans',
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
