import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/focus_session/data/models/focus_present.dart';
import 'package:Skolar/features/focus_session/widgets/present_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

import '../controllers/focus_timer_controller.dart';
import '../widgets/focus_background.dart';
import 'focus_setup_page.dart';

class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});

  @override
  State<FocusTimerPage> createState() => FocusTimerPageState();
}

class FocusTimerPageState extends State<FocusTimerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final FocusTimerController _controller;
  bool _showGiveUpSheet = false;

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
    _controller.addListener(() => setState(() {}));
    _controller.onComplete = _onTimerComplete;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ← add this
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_controller.status == FocusTimerStatus.running) {
        _controller.reset();
      }
    }
  }

  void _onTimerComplete() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FlutterRingtonePlayer().playAlarm(looping: true, asAlarm: true);
      // Explicit vibration pattern alongside — works on all Android versions
      Vibration.vibrate(
        pattern: [0, 800, 400, 800, 400, 800],
        repeat: 0, // repeat indefinitely until Vibration.cancel() is called
      );
    });
  }

  void showGiveUpSheet() {
    if (_controller.status == FocusTimerStatus.running) {
      setState(() => _showGiveUpSheet = true);
    }
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
      onPopInvoked: (didPop) {
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
                  Expanded(flex: 46, child: _buildBonsaiHero(isRunning)),
                  Expanded(
                    flex: 54,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildTimerReadout(),
                          const SizedBox(height: 40),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBonsaiHero(bool isRunning) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        padding: EdgeInsets.only(top: isRunning ? 40 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 10),
              child: Image.asset(
                'assets/images/bonsai.png',
                width: 260,
                height: 240,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.spa_rounded,
                  size: 80,
                  color: Color.fromARGB(255, 77, 168, 59),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Focus time',
              style: TextStyle(
                color: Colors.white.withValues(alpha: isRunning ? 0.5 : 0.9),
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerReadout() {
    final isComplete = _controller.status == FocusTimerStatus.complete;
    return Text(
      isComplete ? 'Done! 🎉' : _controller.formattedTime,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 76,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
      ),
    );
  }

  Widget _buildRestartButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Great session! Ready for another?',
          style: TextStyle(color: Colors.white60, fontSize: 15),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            FlutterRingtonePlayer().stop();
            Vibration.cancel();
            _controller.reset();
          },
          child: Container(
            height: _trackHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xCCFFFFFF), AppTheme.surfaceGrad2End],
                stops: [0.0, 0.81],
              ),
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              border: Border.all(color: AppTheme.background, width: 1.0),
            ),
            child: const Center(
              child: Text(
                'Start new session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: isIdle
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _buildPresetChipsRow(),
                )
              : const SizedBox.shrink(),
        ),
        LayoutBuilder(
          builder: (context, constraints) => _buildSliderTrackBar(constraints),
        ),
      ],
    );
  }

  Widget _buildPresetChipsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(FocusPreset.defaults.length, (i) {
          final p = FocusPreset.defaults[i];
          final isActive = _controller.totalSeconds == p.seconds;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: PresetChip(
              label: p.label,
              isActive: isActive,
              onTap: () => _controller.setDuration(p.seconds),
            ),
          );
        }),
        PresetChip(
          label: 'Custom',
          isActive: false,
          icon: Icons.tune_rounded,
          onTap: () => _navigateToCustomSetupPage(),
        ),
      ],
    );
  }

  void _navigateToCustomSetupPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusSetupPage(
          initialSeconds: _controller.totalSeconds,
          onConfirm: (seconds) {
            _controller.setDuration(seconds);
            Navigator.pop(context);
          },
        ),
      ),
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
          setState(() => _dragging = false); // Done dragging
          if (!isRunning) {
            setState(() => _knobOffset = maxOffset);
            _springWaveForward();
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!mounted) return;
              _controller.start();
              setState(() => _knobOffset = 0);
            });
          } else {
            setState(() => _knobOffset = 0);
            showGiveUpSheet();
          }
        } else {
          setState(() => _dragging = false); // Done dragging
          setState(() => _knobOffset = 0);
          if (!isRunning) {
            _springWaveBack();
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_trackHeight / 2),
        clipBehavior: Clip
            .antiAlias, // Forces the static capsule layout to be perfectly smooth
        child: SizedBox(
          height: _trackHeight,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Layer 0 (base): resting background gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isRunning
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppTheme.primaryGradEnd,
                              AppTheme.bgGradEnd,
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xCCFFFFFF),
                              AppTheme.surfaceGrad2End,
                            ],
                            stops: [0.0, 0.81],
                          ),
                  ),
                ),
              ),

              // Layer 1: Convex sliding wipe animation layer
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
                              colors: [
                                Color(0xCCFFFFFF),
                                AppTheme.surfaceGrad2End,
                              ],
                              stops: [0.0, 0.81],
                            )
                          : const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                AppTheme.primaryGradEnd,
                                AppTheme.bgGradEnd,
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              // Layer 1.5 (FIX): Floating border stroke overlay.
              // Placing this above the background gradients keeps the border anti-aliased and pristine.
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_trackHeight / 2),
                      border: Border.all(
                        color: AppTheme.background,
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

              // Layer 2: Label text string
              Center(
                child: Text(
                  isRunning ? 'Slide to give up' : 'Slide to lock in',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: isRunning ? 0.6 : 0.4),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Layer 3: The physical slider button thumb
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
                        ? AppTheme.onBackground
                        : AppTheme.background,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isRunning
                        ? AppTheme.background
                        : AppTheme.onBackground,
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
              _controller.reset();
            },
          ),
        ),
      ],
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
// Give Up Bottom Overlay Sheet
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
        color: Color(0xFF0D1440),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          const Text(
            'Give up this session?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Remaining focus duration: $timeRemaining',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onResume,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2A8A),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Keep focusing',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'End session',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
