import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/streak_strip.dart';
import 'package:Skolar/shared/providers/global_providers.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DevMenuTrigger(
            // Greeting + name share one line now (baseline-aligned so the
            // small "Halo" and the large bold name sit on a common text
            // baseline despite their very different font sizes) — each
            // keeps its own original size/weight, just side by side instead
            // of stacked.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'Halo,',
                  style: TextStyle(
                    fontFamily: 'GoogleSans',
                    color: AppTheme.textSecondary,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'GoogleSans',
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Its own row, full-width, below the greeting — the month grid
          // needs real room (week-day labels + a month-label row + 7 rows of
          // blocks) that it never had squeezed into the greeting row. The
          // week/month view-mode toggle (the 3-dot menu) now lives inside
          // StreakStrip itself, not here — it's the heatmap's own control.
          const StreakStrip(),
        ],
      ),
    );
  }
}

/// Hidden triple-tap → dev menu, preserved from the previous header/app-bar.
class _DevMenuTrigger extends StatefulWidget {
  final Widget child;
  const _DevMenuTrigger({required this.child});

  @override
  State<_DevMenuTrigger> createState() => _DevMenuTriggerState();
}

class _DevMenuTriggerState extends State<_DevMenuTrigger> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!) > const Duration(milliseconds: 500)) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTap = now;

    if (_tapCount >= 3) {
      _tapCount = 0;
      context.push('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
