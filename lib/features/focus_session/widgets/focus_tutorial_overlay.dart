import 'package:Skolar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../services/focus_preferences_service.dart';

enum TutorialStep {
  setTime,
  pomodoro,
  normalMode,
  amoledMode,
}

class FocusTutorialOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback? onTogglePomodoro;
  final bool isPomodoroEnabled;

  const FocusTutorialOverlay({
    super.key,
    required this.onDismiss,
    this.onTogglePomodoro,
    this.isPomodoroEnabled = false,
  });

  @override
  State<FocusTutorialOverlay> createState() => _FocusTutorialOverlayState();
}

class _FocusTutorialOverlayState extends State<FocusTutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  bool _dontShowAgain = true;
  late final AnimationController _pulseController;

  static const _steps = [
    TutorialStep.setTime,
    TutorialStep.pomodoro,
    TutorialStep.normalMode,
    TutorialStep.amoledMode,
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _finishTutorial() async {
    if (_dontShowAgain) {
      await FocusPreferencesService.setTutorialSeen(true);
    }
    widget.onDismiss();
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() => _currentStepIndex++);
    } else {
      _finishTutorial();
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStepIndex];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent backdrop with click-through protection
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // Prevent taps falling through
              child: Container(
                color: Colors.black.withValues(alpha: 0.78),
              ),
            ),
          ),

          // Visual target pointers and animations based on step
          SafeArea(
            child: Stack(
              children: [
                _buildTargetVisual(step),

                // Top bar: Step counter & Skip button
                Positioned(
                  top: 12,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.accentPurple.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Step ${_currentStepIndex + 1} of ${_steps.length}',
                          style: const TextStyle(
                            fontFamily: 'GoogleSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentPurple,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _finishTutorial,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Skip',
                                style: TextStyle(
                                  fontFamily: 'GoogleSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Instructional Guide Card
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: step == TutorialStep.normalMode ? 140 : 28,
                  child: _buildGuideCard(step),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetVisual(TutorialStep step) {
    switch (step) {
      case TutorialStep.setTime:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final scale = 1.0 + (_pulseController.value * 0.05);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.accentPurple,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentPurple.withValues(
                              alpha: 0.4 * _pulseController.value,
                            ),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: AppTheme.accentPurple,
                            size: 26,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Tap or drag to set duration',
                            style: TextStyle(
                              fontFamily: 'GoogleSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 60),
            ],
          ),
        );

      case TutorialStep.pomodoro:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPurple.withValues(
                        alpha: 0.15 + (_pulseController.value * 0.15),
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.accentPurple,
                        width: 2,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timelapse_rounded,
                          color: AppTheme.accentPurple,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '25m Focus  •  5m Rest',
                          style: TextStyle(
                            fontFamily: 'GoogleSans',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        );

      case TutorialStep.normalMode:
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 60.0),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final offset = _pulseController.value * 18.0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Slide to start session',
                      style: TextStyle(
                        fontFamily: 'GoogleSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentPurple,
                        shadows: [
                          Shadow(
                            color: AppTheme.accentPurple.withValues(alpha: 0.8),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.translate(
                      offset: Offset(offset, 0),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.accentPurple,
                        size: 20,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );

      case TutorialStep.amoledMode:
        return Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final offset = -_pulseController.value * 28.0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: Offset(0, offset),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white38,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.swipe_up_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Icon(
                          Icons.keyboard_double_arrow_up_rounded,
                          size: 28,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Swipe UP to enter AMOLED Mode\nSwipe DOWN to exit anytime',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'GoogleSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        );
    }
  }

  Widget _buildGuideCard(TutorialStep step) {
    String title;
    String description;
    IconData icon;

    switch (step) {
      case TutorialStep.setTime:
        title = 'Setting Your Focus Time';
        description =
            'Drag the duration slider to adjust your focus target, or tap directly on the timer digits for an exact rolling picker.';
        icon = Icons.timer_outlined;
        break;
      case TutorialStep.pomodoro:
        title = 'Pomodoro Intervals';
        description =
            'Turn on Pomodoro mode to automatically alternate between 25-minute focus sprints and 5-minute restorative breaks.';
        icon = Icons.timelapse_rounded;
        break;
      case TutorialStep.normalMode:
        title = 'Real-Time Clock & Lock In';
        description =
            'The analog clock always shows current real wall-clock time. When you are ready, slide the bottom bar across to lock in and start!';
        icon = Icons.access_time_rounded;
        break;
      case TutorialStep.amoledMode:
        title = 'AMOLED Desk Clock Mode';
        description =
            'Once running, swipe up to activate true-black AMOLED mode. The screen automatically stays on without sleeping, perfect for your desk.';
        icon = Icons.dark_mode_rounded;
        break;
    }

    final isLastStep = _currentStepIndex == _steps.length - 1;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.accentPurple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'GoogleSans',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'GoogleSans',
              fontSize: 13.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),

          // "Don't show again" Checkbox
          GestureDetector(
            onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _dontShowAgain,
                    activeColor: AppTheme.accentPurple,
                    checkColor: Colors.white,
                    side: const BorderSide(color: Colors.white38, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (val) =>
                        setState(() => _dontShowAgain = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Don't show tutorial again",
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    fontSize: 12.5,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Navigation buttons (Back, Indicator dots, Next / Done)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStepIndex > 0)
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontFamily: 'GoogleSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 60),

              // Step indicator dots
              Row(
                children: List.generate(_steps.length, (idx) {
                  final active = idx == _currentStepIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: active ? 18 : 6,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.accentPurple : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),

              // Next / Got It button
              GestureDetector(
                onTap: _nextStep,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPurple.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    isLastStep ? 'Got it!' : 'Next',
                    style: const TextStyle(
                      fontFamily: 'GoogleSans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
