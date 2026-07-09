/// lib/features/dashboard/presentation/widgets/streak_card.dart
///
/// Standalone streak/progress card.
/// Usage:
///   StreakCard(
///     streakDays: 15,
///     targetDays: 90,
///     weekProgress: [true, true, true, false, null, null, null],
///   )
library;

import 'package:flutter/material.dart';

class StreakCard extends StatelessWidget {
  final int streakDays;
  final int targetDays;

  /// 7 entries – true=done, false=missed, null=future
  final List<bool?> weekProgress;
  final List<String> weekLabels;

  const StreakCard({
    super.key,
    required this.streakDays,
    required this.targetDays,
    required this.weekProgress,
    this.weekLabels = const ['Mon', 'Tue', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'],
  }) : assert(weekProgress.length == 7);

  @override
  Widget build(BuildContext context) {
    final progress = streakDays / targetDays;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131B38).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2D55), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _FlameBox(streakDays: streakDays),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FractionRow(streakDays: streakDays, targetDays: targetDays),
                const SizedBox(height: 10),
                _ProgressBar(value: progress),
                const SizedBox(height: 12),
                _WeekRow(weekProgress: weekProgress, weekLabels: weekLabels),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlameBox extends StatefulWidget {
  final int streakDays;
  const _FlameBox({required this.streakDays});

  @override
  State<_FlameBox> createState() => _FlameBoxState();
}

class _FlameBoxState extends State<_FlameBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: 1.0 + _ctrl.value * 0.04,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0xFF3D1F1A), Color(0xFF1A0D0D)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(b),
                child: const Icon(
                  Icons.local_fire_department,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.streakDays} days',
                style: const TextStyle(
                  color: Color(0xFFEEF0FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Skill streak',
                style: TextStyle(color: Color(0xFF7A84AA), fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FractionRow extends StatelessWidget {
  final int streakDays, targetDays;
  const _FractionRow({required this.streakDays, required this.targetDays});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$streakDays',
          style: const TextStyle(
            color: Color(0xFFEEF0FF),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        Text(
          '/$targetDays',
          style: const TextStyle(
            color: Color(0xFF7A84AA),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Target days',
          style: TextStyle(color: Color(0xFF3D4A72), fontSize: 11),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: const Color(0xFF0D1230),
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEEF0FF)),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final List<bool?> weekProgress;
  final List<String> weekLabels;
  const _WeekRow({required this.weekProgress, required this.weekLabels});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(weekLabels.length, (i) {
        return _WeekDot(label: weekLabels[i], status: weekProgress[i]);
      }),
    );
  }
}

class _WeekDot extends StatelessWidget {
  final String label;
  final bool? status;
  const _WeekDot({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Widget icon;

    if (status == true) {
      bg = const Color(0xFF4CAF50);
      icon = const Icon(Icons.check, size: 10, color: Colors.white);
    } else if (status == false) {
      bg = const Color(0xFFE53935);
      icon = const Icon(Icons.close, size: 10, color: Colors.white);
    } else {
      bg = const Color(0xFF0D1230);
      icon = const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: status == null
                  ? const Color(0xFF1F2D55)
                  : Colors.transparent,
            ),
          ),
          child: Center(child: icon),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: status == null
                ? const Color(0xFF3D4A72)
                : const Color(0xFF7A84AA),
            fontSize: 8.5,
          ),
        ),
      ],
    );
  }
}
