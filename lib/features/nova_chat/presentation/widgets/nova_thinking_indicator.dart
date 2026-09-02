import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/auth/presentation/widgets/mascot_state.dart';
import 'package:Skolar/features/auth/presentation/widgets/nova_mascot.dart';

class NovaMascotAvatar extends StatelessWidget {
  final double size;
  final MascotState state;

  const NovaMascotAvatar({
    super.key,
    this.size = 28,
    this.state = MascotState.idle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B28),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF8C5BE8).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: ClipOval(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 150,
            height: 150,
            child: NovaMascot(state: state),
          ),
        ),
      ),
    );
  }
}

class NovaThinkingIndicator extends StatefulWidget {
  const NovaThinkingIndicator({super.key});

  @override
  State<NovaThinkingIndicator> createState() => _NovaThinkingIndicatorState();
}

class _NovaThinkingIndicatorState extends State<NovaThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const NovaMascotAvatar(size: 26, state: MascotState.watchingEmail),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (index) {
                    final delay = index * 0.18;
                    final progress = (_animCtrl.value - delay) % 1.0;
                    final scale =
                        0.5 + (0.5 * (1 - (progress - 0.5).abs() * 2));
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.25 + (scale * 0.75),
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
