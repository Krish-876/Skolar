import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/core/widgets/glass_background.dart';
import 'package:Skolar/features/dashboard/domain/entities/dashboard_entity.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/dashboard_section_header.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/development_radar_chart.dart';

/// The "All-Round Development" section. "See Details" never navigates to a
/// new page — it reveals a per-axis breakdown under the radar chart (via
/// `AnimatedSize` below) and auto-scrolls the page down just enough to bring
/// that reveal into view, then collapses on a second tap.
class AllRoundDevelopmentCard extends ConsumerStatefulWidget {
  const AllRoundDevelopmentCard({super.key});

  @override
  ConsumerState<AllRoundDevelopmentCard> createState() =>
      _AllRoundDevelopmentCardState();
}

class _AllRoundDevelopmentCardState
    extends ConsumerState<AllRoundDevelopmentCard> {
  // Shared via `developmentDetailsOpenProvider` rather than local state so
  // `ExpandableProgressCard` (a sibling elsewhere in the tree, overlaying
  // this page) can `ref.listen` to this toggle and re-measure its anchor
  // across the AnimatedSize resize below — without that, collapsing this
  // card left the progress-card overlay stuck at its pre-toggle position
  // until some unrelated scroll happened to re-trigger a measure.

  // This card sits directly below `StreakStrip` in the dashboard's scroll
  // view — when its week/month toggle animates the header's height (see
  // `streak_strip.dart`'s `AnimatedSwitcher`/`SizeTransition`), this card's
  // on-screen position shifts every frame for that ~400ms. `GlassCard`'s
  // `BackdropFilter` has to re-blur whatever's behind it at the new position
  // on every one of those frames — real compositing cost for an effect
  // nobody can see clearly mid-motion anyway, and exactly what read as lag
  // in that transition. Suppressing it for the duration (falling back to
  // the same flat tint/border, no blur) and restoring it once the header
  // settles removes that cost without touching the transition itself.
  bool _suppressGlassBlur = false;

  void _suppressGlassBlurBriefly() {
    setState(() => _suppressGlassBlur = true);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _suppressGlassBlur = false);
    });
  }

  // How far to nudge the page down when the breakdown opens — a fixed,
  // "just a little" amount rather than a measured reveal height. Waiting to
  // measure the revealed content (e.g. via `Scrollable.ensureVisible` after
  // the `AnimatedSize` below finishes) meant the scroll only started once
  // the reveal had *already* finished growing — a visible dead gap between
  // the tap and any motion. Scrolling by a fixed delta needs no measurement,
  // so it can start on the same frame as the reveal.
  static const double _detailsRevealScrollDelta = 160;

  void _toggleDetails() {
    final notifier = ref.read(developmentDetailsOpenProvider.notifier);
    final opening = !notifier.state;
    notifier.state = opening;
    // Same duration/curve as the `AnimatedSize` reveal/collapse below,
    // started in the same call, so the scroll and the resize run
    // concurrently as one motion in either direction — scrolling down as it
    // opens, symmetrically back up as it closes — instead of one lagging
    // behind the other.
    final position = Scrollable.of(context).position;
    // Only the close direction gets clamped (against overscrolling past the
    // top) — clamping the open direction against `maxScrollExtent` breaks
    // it, since at the instant of the tap that extent is still the
    // pre-reveal (un-grown) value; it only grows over the next few frames as
    // `AnimatedSize` expands, in step with this same scroll.
    final target = opening
        ? position.pixels + _detailsRevealScrollDelta
        : (position.pixels - _detailsRevealScrollDelta)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailsOpen = ref.watch(developmentDetailsOpenProvider);
    ref.listen<StreakViewMode>(streakViewModeProvider, (previous, next) {
      if (previous != next) _suppressGlassBlurBriefly();
    });
    return GlassCard(
      borderRadius: 24,
      enableBlur: !_suppressGlassBlur,
      child: Column(
        children: [
          DashboardSectionHeader(
            title: 'All-Round Development',
            trailing: TextButton.icon(
              onPressed: _toggleDetails,
              icon: AnimatedRotation(
                turns: detailsOpen ? 0.25 : 0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Icon(Icons.arrow_forward_rounded, color: AppTheme.accent, size: 16),
              ),
              label: Text(
                detailsOpen ? 'Hide Details' : 'See Details',
                style: TextStyle(
                  fontFamily: 'GoogleSans',
                  color: AppTheme.accent,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Consumer(
              builder: (context, ref, _) {
                final axesAsync = ref.watch(developmentAxesProvider);
                return axesAsync.when(
                  data: (axes) => Column(
                    children: [
                      DevelopmentRadarChart(axes: axes),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: detailsOpen
                            ? _AxisBreakdownList(axes: axes)
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(
                    height: 260,
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisBreakdownList extends StatelessWidget {
  final List<DevelopmentAxis> axes;
  const _AxisBreakdownList({required this.axes});

  @override
  Widget build(BuildContext context) {
    if (axes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: axes.map((a) => _AxisRow(axis: a)).toList(),
      ),
    );
  }
}

class _AxisRow extends StatelessWidget {
  final DevelopmentAxis axis;
  const _AxisRow({required this.axis});

  @override
  Widget build(BuildContext context) {
    final delta = axis.now - axis.startOfSemester;
    final deltaColor = delta > 0.001
        ? AppTheme.chartInProgress
        : delta < -0.001
            ? AppTheme.error
            : AppTheme.textSecondary;
    final deltaLabel = delta.abs() < 0.001
        ? '—'
        : '${delta > 0 ? '+' : ''}${(delta * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              axis.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: axis.now.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppTheme.surface,
                valueColor: AlwaysStoppedAnimation(AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              deltaLabel,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: deltaColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
