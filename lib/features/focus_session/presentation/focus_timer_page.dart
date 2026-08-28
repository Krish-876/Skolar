import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/focus_session/services/focus_sound_service.dart';
import 'package:Skolar/features/focus_session/widgets/glow_thumb_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/focus_timer_controller.dart';
import '../widgets/focus_background.dart';

class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});

  @override
  State<FocusTimerPage> createState() => FocusTimerPageState();
}

class FocusTimerPageState extends State<FocusTimerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final FocusTimerController _controller;
  late final AnimationController _transitionAnimController;
  bool _showGiveUpSheet = false;
  bool _showTransitionOverlay = false;
  String _transitionTitle = '';
  String _transitionSubtitle = '';

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
    _controller = FocusTimerController(vsync: this);
    _transitionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
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
    FocusSoundService.stop();
    _transitionAnimController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.syncWithSystemTime();
    } else if (state == AppLifecycleState.detached) {
      if (_controller.status == FocusTimerStatus.running) {
        _controller.reset();
        FocusSoundService.stop();
      }
    }
  }

  void _onPhaseChanged(FocusPhase newPhase) {
    if (newPhase == FocusPhase.breakTime) {
      FocusSoundService.playEnterBreak();
    } else {
      FocusSoundService.playExitBreak();
    }
  }

  void _onTimerComplete() {
    FocusSoundService.playSessionComplete();
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
                Icons.help_outline_rounded,
                color: AppTheme.accentPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'How it works',
              style: GoogleFonts.googleSans(
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
            _helpRow(
              'Set Duration',
              'Drag the slider or tap the time numbers to type your exact focus time.',
            ),
            const SizedBox(height: 14),
            _helpRow(
              'Pomodoro Mode',
              'Splits focus into 25-minute intervals with 5-minute restorative breaks.',
            ),
            const SizedBox(height: 14),
            _helpRow(
              'Lock-Screen Tracking',
              'Timer continues running accurately when your phone is locked.',
            ),
            const SizedBox(height: 14),
            _helpRow(
              'Break Switching',
              'During 5-minute break periods, you can switch apps without losing progress.',
            ),
            const SizedBox(height: 14),
            _helpRow(
              'Lock In & Give Up',
              'Swipe the capsule to lock in or cancel your active session.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentPurple,
            ),
            child: Text(
              'Got it',
              style: GoogleFonts.googleSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
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

  Widget _helpRow(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.googleSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: GoogleFonts.googleSans(
            color: Colors.white60,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  double _maxKnobOffset(BoxConstraints constraints) {
    return constraints.maxWidth - _knobSize - (_trackHorizontalPadding * 2);
  }

  void _springWaveBack() {
    final spring = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 180.0,
      ratio: 0.6,
    );
    final sim = SpringSimulation(
      spring,
      _controller.waveAnimationController.value,
      0.0,
      -0.5,
    );
    _controller.waveAnimationController.animateWith(sim);
  }

  void _springWaveForward() {
    final spring = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 300.0,
      ratio: 0.8,
    );
    final sim = SpringSimulation(
      spring,
      _controller.waveAnimationController.value,
      1.0,
      2.0,
    );
    _controller.waveAnimationController.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _controller.status == FocusTimerStatus.running;
    final canPop =
        _controller.status == FocusTimerStatus.idle ||
        _controller.status == FocusTimerStatus.complete;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isRunning) showGiveUpSheet();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _controller.waveAnimationController,
              builder: (context, _) {
                return FocusBackground(
                  slideProgress: _controller.slideProgress,
                );
              },
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(isRunning),
                  Expanded(flex: 44, child: _buildBonsaiHero(isRunning)),
                  Expanded(
                    flex: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (isRunning && _controller.isBreakPhase) ...[
                            _buildBreakPhaseHeader(),
                            const SizedBox(height: 12),
                          ],
                          _buildTimerReadout(isRunning),
                          if (isRunning) ...[
                            const SizedBox(height: 14),
                            _buildProgressIndicators(),
                          ],
                          const SizedBox(height: 20),
                          if (_controller.status == FocusTimerStatus.complete)
                            _buildRestartButton()
                          else
                            _buildInteractionZone(isIdle: !isRunning),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_showGiveUpSheet) _buildGiveUpOverlay(),
            if (_showTransitionOverlay) _buildTransitionOverlay(),
          ],
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
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
            const SizedBox(height: 14),
            Text(
              'Focus time',
              style: GoogleFonts.googleSans(
                color: Colors.white.withValues(alpha: isRunning ? 0.6 : 0.95),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakPhaseHeader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E676), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.coffee_rounded, size: 14, color: Color(0xFF00E676)),
          const SizedBox(width: 6),
          Text(
            '5 MIN BREAK',
            style: GoogleFonts.googleSans(
              color: const Color(0xFF00E676),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerReadout(bool isRunning) {
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
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    final displayTime = _controller.status == FocusTimerStatus.idle
        ? _controller.formattedTotalFocusTime
        : _controller.formattedTime;

    return GestureDetector(
      onTap: isRunning ? null : _showEditTimeDialog,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: isRunning ? '' : 'Tap to edit time',
        child: Text(
          displayTime,
          style: GoogleFonts.googleSans(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicators() {
    final intervalProgress = _controller.currentIntervalProgress;
    final breakSegments = _controller.breakSegments;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: SizedBox(
            height: 14,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Base track
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
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
                                color: AppTheme.accentPurple.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: AppTheme.background,
                                  width: 1.0,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                // Active interval progress fill
                FractionallySizedBox(
                  widthFactor: intervalProgress,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: _controller.isBreakPhase
                          ? const LinearGradient(
                              colors: [Color(0xFF00E676), Color(0xFF69F0AE)],
                            )
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: (_controller.isBreakPhase
                                  ? const Color(0xFF00E676)
                                  : AppTheme.primary)
                              .withValues(alpha: 0.35),
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
        const SizedBox(height: 10),

        // Upcoming break info / next session
        if (_controller.isPomodoroEnabled)
          Text(
            _controller.upcomingBreakInfo,
            style: GoogleFonts.googleSans(
              color: _controller.isBreakPhase
                  ? const Color(0xFF00E676).withValues(alpha: 0.95)
                  : AppTheme.accentPurple.withValues(alpha: 0.9),
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
          style: GoogleFonts.googleSans(color: Colors.white60, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            FocusSoundService.stop();
            _controller.reset();
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
                style: GoogleFonts.googleSans(
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

  Widget _buildInteractionZone({required bool isIdle}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          child: isIdle
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDurationSlider(),
                    const SizedBox(height: 10),
                    _buildPomodoroModeToggle(),
                    const SizedBox(height: 16),
                  ],
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
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1m',
                  style: GoogleFonts.googleSans(
                    color: Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '3h',
                  style: GoogleFonts.googleSans(
                    color: Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            _controller.setPomodoroEnabled(!enabled);
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.timelapse_rounded,
                size: 15,
                color: enabled ? AppTheme.accentPurple : Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                'Pomodoro mode',
                style: GoogleFonts.googleSans(
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
                axisAlignment: 0.0,
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
                      style: GoogleFonts.googleSans(
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
            final breakStr =
                _controller.isPomodoroEnabled &&
                        _controller.pomodoroBreakCount > 0
                    ? 'with ${_controller.breaksSubtitle}'
                    : '';
            setState(() {
              _knobOffset = maxOffset;
              _showTransitionOverlay = true;
              _transitionTitle =
                  'Focusing for ${_formatDurationText(_controller.totalSeconds)}';
              _transitionSubtitle = breakStr;
            });
            _springWaveForward();
            FocusSoundService.playStartFocus();
            _transitionAnimController.forward();

            // Once the full-screen overlay covers the screen (~400ms):
            Future.delayed(const Duration(milliseconds: 400), () {
              if (!mounted) return;
              // Assemble next running screen behind the overlay
              _controller.start();
              setState(() => _knobOffset = 0);

              // Hold the transition text for a moment, then fade away smoothly
              Future.delayed(const Duration(milliseconds: 750), () {
                if (!mounted) return;
                _transitionAnimController.reverse().then((_) {
                  if (!mounted) return;
                  setState(() => _showTransitionOverlay = false);
                });
              });
            });
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
              // Layer 0: base resting background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isRunning
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF3B1D6E), Color(0xFF20113D)],
                          )
                        : const LinearGradient(
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
                              colors: [Color(0xFF262433), Color(0xFF181622)],
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
                  style: GoogleFonts.googleSans(
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
                    color: isRunning ? Colors.white : AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isRunning
                            ? Colors.black38
                            : AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isRunning ? AppTheme.primary : Colors.white,
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

  String _formatDurationText(int seconds) {
    final mins = seconds ~/ 60;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '$h hour ${m} mins';
    if (h > 0) return '$h ${h == 1 ? 'hour' : 'hours'}';
    return '$mins mins';
  }

  Widget _buildTransitionOverlay() {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _transitionAnimController,
        child: Container(
          color: const Color(0xFF16161A), // full-screen deep obsidian
          child: Stack(
            children: [
              // Ambient subtle purple radial glow
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 10),
                        child: Image.asset(
                          'assets/images/bonsai.png',
                          width: 160,
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.spa_rounded,
                            size: 70,
                            color: Color(0xFF4DA83B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _transitionTitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.googleSans(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          height: 1.3,
                        ),
                      ),
                      if (_transitionSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _transitionSubtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.googleSans(
                            color: AppTheme.accentPurple.withValues(
                              alpha: 0.9,
                            ),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
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
              FocusSoundService.stop();
              _controller.reset();
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

    _hoursScrollCtrl = FixedExtentScrollController(
      initialItem: _selectedHours,
    );
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
        style: GoogleFonts.googleSans(
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
                    style: GoogleFonts.googleSans(
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
            style: GoogleFonts.googleSans(color: Colors.white54),
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
            style: GoogleFonts.googleSans(
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
                      style: GoogleFonts.googleSans(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unitLabel,
                      style: GoogleFonts.googleSans(
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
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Remaining focus duration: $timeRemaining',
            style: GoogleFonts.googleSans(color: Colors.white60, fontSize: 14),
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
                style: GoogleFonts.googleSans(
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
              style: GoogleFonts.googleSans(
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
