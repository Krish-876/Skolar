import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/gestures.dart' show VelocityTracker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:go_router/go_router.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/core/widgets/glass_background.dart';
import 'package:Skolar/features/dashboard/domain/entities/dashboard_entity.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/donut_progress_chart.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/task_list_tile.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/weekly_bar_chart.dart';

/// Consecutive most-recent active days, most-recent day last (per
/// [DailyCompletion]'s doc). Real, derived data — not a guess — used to give
/// the collapsed/expanded card a second stat badge alongside hours logged.
int _currentStreak(List<DailyCompletion> days) {
  var streak = 0;
  for (final d in days.reversed) {
    if (!d.isActiveDay) break;
    streak++;
  }
  return streak;
}

/// The collapsed progress card that expands in place to a full-screen view.
/// This is the one hand-rolled-animation exception in the dashboard rework:
/// an [AnimationController] driven directly by a [GestureDetector], so the
/// ring can interpolate continuously with the drag instead of only snapping
/// on release.
class ExpandableProgressCard extends ConsumerStatefulWidget {
  /// Key on the fixed placeholder box in the page layout — its measured
  /// on-screen rect is the card's collapsed geometry.
  final GlobalKey anchorKey;

  /// Notified every frame with the 0..1 expansion progress so the rest of
  /// the page can fade/offset around the card.
  final ValueNotifier<double> expansionProgress;

  /// The scroll controller for the list the anchor placeholder now lives in.
  /// The collapsed card is an overlay positioned from the anchor's measured
  /// global rect, not an actual child of that scrollable — without this, its
  /// rect was only ever measured once (plus on the heatmap week/month
  /// toggle), so scrolling the page left the overlay stuck in place while
  /// the anchor it was supposed to track scrolled away underneath it.
  final ScrollController? scrollController;

  const ExpandableProgressCard({
    super.key,
    required this.anchorKey,
    required this.expansionProgress,
    this.scrollController,
  });

  @override
  ConsumerState<ExpandableProgressCard> createState() =>
      _ExpandableProgressCardState();
}

class _CardAnchors {
  final Rect? collapsedRing;
  final Rect? expandedRing;
  final Rect? collapsedStreak;
  final Rect? expandedStreak;
  final Rect? collapsedHours;
  final Rect? expandedHours;

  const _CardAnchors({
    this.collapsedRing,
    this.expandedRing,
    this.collapsedStreak,
    this.expandedStreak,
    this.collapsedHours,
    this.expandedHours,
  });
}

class _ExpandableProgressCardState extends ConsumerState<ExpandableProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..addListener(() => widget.expansionProgress.value = _controller.value);

  // Holds the page-level anchor's measured rect without going through
  // State.setState. This rect only ever feeds this overlay's own
  // `Positioned.fromRect` below — it's never read by `_CardSurface` — but
  // routing its updates through setState forced the *entire* card (including
  // the off-screen expanded task list, shimmer, and Lottie animations) to
  // rebuild on every scroll tick and on every frame of the header's
  // week/month-toggle remeasure burst, which is exactly the "lag in the
  // week-month transition" this was causing. A ValueNotifier lets only the
  // cheap positioning wrapper in `build()` react to it.
  final ValueNotifier<Rect?> _collapsedRectNotifier = ValueNotifier(null);

  // Holds the measured anchor rects for the ring and stat badges. Held in a
  // ValueNotifier so `cardSurface`'s AnimatedBuilder can rebuild immediately
  // once the anchors are measured after first mount, rather than staying null
  // until the user touches/drags the card to tick `_controller`.
  final ValueNotifier<_CardAnchors> _ringAnchorsNotifier = ValueNotifier(
    const _CardAnchors(),
  );

  // How many more animation frames to keep re-measuring the anchor for
  // after the header's week/month toggle. The heatmap's AnimatedSwitcher
  // (see StreakStrip) animates its height over ~400ms, which pushes this
  // card's anchor to a new Y position frame-by-frame — a single one-shot
  // measure (as done in initState) would leave the collapsed card frozen
  // at its pre-toggle position while everything below actually moved.
  int _remeasureFramesLeft = 0;

  // The ring is one continuous widget floated above both the collapsed and
  // expanded layouts (see `_CardSurface`) instead of being a separate
  // instance embedded in each — the previous per-layout version tore the
  // ring down and remounted a fresh one the moment the content swapped,
  // which read as the progress animation cutting and starting over. Both
  // layouts stay mounted at all times (invisible, not unmounted) purely so
  // these two anchor points can be measured; the ring then interpolates
  // between them every frame, the same way the whole card interpolates
  // between `_collapsedRect` and the full-screen rect below.
  final _surfaceKey = GlobalKey();
  final _collapsedRingAnchorKey = GlobalKey();
  final _expandedRingAnchorKey = GlobalKey();

  // The expanded view's own content (bar chart, ring, task list) scrolls in
  // its own SingleChildScrollView once it's taller than the screen. That
  // scroll never touches `_controller` (the card is already fully expanded,
  // sitting still), so without an explicit listener here the floating ring
  // above stayed frozen at wherever it last measured while the actual page
  // content — including the anchor it's supposed to track — scrolled right
  // out from under it.
  final _expandedScrollController = ScrollController();

  // Same floating-anchor technique as the ring, applied to the two stat
  // badges ("day streak" / "this semester"): they used to be two entirely
  // separate widget instances (a vertical pair beside the collapsed ring, a
  // horizontal pair at the top of the expanded view), hard-swapped by the
  // same Visibility toggle as the rest of the content — so, like the ring
  // before this fix, they visually cut and restarted at the progress=0.5
  // boundary instead of sliding into their new spot. Floating one real copy
  // of each badge between its two measured anchors makes them glide there
  // continuously, same as the ring already does.
  final _collapsedStreakAnchorKey = GlobalKey();
  final _expandedStreakAnchorKey = GlobalKey();
  final _collapsedHoursAnchorKey = GlobalKey();
  final _expandedHoursAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measure();
      _measureRingAnchors();
    });
    // The anchor now scrolls with the page, so its global rect changes on
    // every scroll tick — re-measure continuously rather than only once.
    widget.scrollController?.addListener(_measure);
    // Same reasoning as `scrollController` above, but for the expanded
    // view's own internal scroll (see `_expandedScrollController`'s doc).
    _expandedScrollController.addListener(_measureRingAnchors);
  }

  void _measureRingAnchors() {
    if (!mounted) return;
    final surfaceBox =
        _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (surfaceBox == null || !surfaceBox.hasSize) return;

    Rect? readAnchor(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return box.localToGlobal(Offset.zero, ancestor: surfaceBox) & box.size;
    }

    final collapsedRing = readAnchor(_collapsedRingAnchorKey);
    final expandedRing = readAnchor(_expandedRingAnchorKey);
    final collapsedStreak = readAnchor(_collapsedStreakAnchorKey);
    final expandedStreak = readAnchor(_expandedStreakAnchorKey);
    final collapsedHours = readAnchor(_collapsedHoursAnchorKey);
    final expandedHours = readAnchor(_expandedHoursAnchorKey);

    final current = _ringAnchorsNotifier.value;
    bool differs(Rect? next, Rect? cur) => next != null && next != cur;
    final changed =
        differs(collapsedRing, current.collapsedRing) ||
        differs(expandedRing, current.expandedRing) ||
        differs(collapsedStreak, current.collapsedStreak) ||
        differs(expandedStreak, current.expandedStreak) ||
        differs(collapsedHours, current.collapsedHours) ||
        differs(expandedHours, current.expandedHours);
    if (!changed) return;

    _ringAnchorsNotifier.value = _CardAnchors(
      collapsedRing: collapsedRing ?? current.collapsedRing,
      expandedRing: expandedRing ?? current.expandedRing,
      collapsedStreak: collapsedStreak ?? current.collapsedStreak,
      expandedStreak: expandedStreak ?? current.expandedStreak,
      collapsedHours: collapsedHours ?? current.collapsedHours,
      expandedHours: expandedHours ?? current.expandedHours,
    );
  }

  void _measure() {
    final box =
        widget.anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect != _collapsedRectNotifier.value) {
      _collapsedRectNotifier.value = rect;
    }
  }

  void _scheduleRemeasureBurst() {
    // ~30 frames at 60fps covers the header's ~400ms resize with margin.
    _remeasureFramesLeft = 30;
    _remeasureNextFrame();
  }

  void _remeasureNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      _measureRingAnchors();
      _remeasureFramesLeft--;
      if (_remeasureFramesLeft > 0) _remeasureNextFrame();
    });
  }

  @override
  void didUpdateWidget(ExpandableProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_measure);
      widget.scrollController?.addListener(_measure);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_measure);
    _expandedScrollController.dispose();
    _collapsedRectNotifier.dispose();
    _ringAnchorsNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Same divisor regardless of drag direction — the whole point is that
  // the controller value follows the finger identically whichever way it
  // moves, so opening and closing feel like the exact same gesture played
  // in reverse rather than two differently-tuned interactions.
  void _onDragUpdate(DragUpdateDetails details, double screenHeight) {
    final collapsedTop = _collapsedRectNotifier.value?.top ?? screenHeight;
    final dragExtent = collapsedTop.clamp(1.0, screenHeight);
    _controller.value = (_controller.value - details.delta.dy / dragExtent)
        .clamp(0.0, 1.0);
  }

  // A flat release duration made a release at progress 0.95 (a hair from
  // done) take exactly as long to settle as one at 0.05 (barely started) —
  // same wall-clock time over very different remaining distances reads as
  // inconsistent speed, not smooth. Scaling duration by how far there still
  // is to travel keeps the *perceived* velocity roughly constant instead:
  // a near-finished release settles almost immediately, a barely-started
  // one still takes a full, deliberate glide. The clamps exist so a
  // vanishingly small remaining distance doesn't collapse to a 0ms jump-cut,
  // and a very slow release doesn't crawl.
  Duration _settleDuration(
    double distance, {
    required double progressPerSecond,
  }) {
    final ms = (distance / progressPerSecond * 1000).clamp(120.0, 340.0);
    return Duration(milliseconds: ms.round());
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final target = velocity < -250
        ? 1.0
        : velocity > 250
        ? 0.0
        : (_controller.value > 0.5 ? 1.0 : 0.0);
    final distance = (target - _controller.value).abs();

    // Convert the release fling speed (px/s) into the same normalized
    // progress-per-second unit `_onDragUpdate` implicitly uses (a drag delta
    // divided by the collapsed anchor's distance from the top of the
    // screen), so a fast fling settles fast and a slow release settles at a
    // matching, gentler pace — rather than every release, regardless of how
    // it was thrown, taking the same generic duration.
    final collapsedTop =
        _collapsedRectNotifier.value?.top ?? MediaQuery.sizeOf(context).height;
    final dragExtent = collapsedTop.clamp(1.0, double.infinity);
    final progressPerSecond = (velocity.abs() / dragExtent).clamp(1.0, 8.0);

    _controller.animateTo(
      target,
      // Always `easeOutCubic` (fast-start, decelerating into the target),
      // never `.flipped`, regardless of direction. `.flipped` mirrors the
      // open motion exactly — which sounds right on paper, but for a
      // release-triggered settle it means the closing animation starts
      // *slow* right when the finger lifts, before accelerating — reading
      // as a beat of lag/unresponsiveness at the exact moment the user let
      // go. A settle should always feel like it leaves immediately and
      // eases into rest, whichever direction it's headed.
      curve: Curves.easeOutCubic,
      duration: _settleDuration(distance, progressPerSecond: progressPerSecond),
    );
  }

  // No measured drag/fling speed to key off for these two (a button tap and
  // a system-back both fire this with the card already settled at 1.0) — a
  // fixed baseline of 3 progress-units/sec (a full traverse in ~330ms) still
  // gets the "cover however far is left at a consistent pace" benefit for
  // any partial-progress edge case, without needing a velocity input.
  static const double _defaultProgressPerSecond = 3.0;

  void _collapse() {
    final distance = _controller.value;
    _controller.animateTo(
      0.0,
      // Same `easeOutCubic` as `_expand` — see the note in `_onDragEnd` on
      // why this is never `.flipped`.
      curve: Curves.easeOutCubic,
      duration: _settleDuration(
        distance,
        progressPerSecond: _defaultProgressPerSecond,
      ),
    );
  }

  void _expand() {
    final distance = 1.0 - _controller.value;
    _controller.animateTo(
      1.0,
      curve: Curves.easeOutCubic,
      duration: _settleDuration(
        distance,
        progressPerSecond: _defaultProgressPerSecond,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The heatmap's week/month toggle resizes the header above this card's
    // anchor, so its collapsed position needs re-measuring across that
    // transition, not just once at mount.
    ref.listen<StreakViewMode>(streakViewModeProvider, (previous, next) {
      if (previous != next) _scheduleRemeasureBurst();
    });
    // Same reasoning, for the "All-Round Development" card's details
    // AnimatedSize toggle: that resize can shift the anchor's on-screen
    // position (e.g. via the scrollable correcting its offset once the
    // content below shrinks), but only once, or at a moment the scroll
    // listener's single `_measure()` catches a stale mid-animation frame —
    // not continuously across the whole ~380ms resize the way a drag does.
    // Without this, toggling "Hide Details" left the collapsed card frozen
    // at its pre-toggle position until an unrelated scroll gesture forced a
    // fresh measure.
    ref.listen<bool>(developmentDetailsOpenProvider, (previous, next) {
      if (previous != next) _scheduleRemeasureBurst();
    });
    // `StreakStrip` shows a short `SizedBox(height: 28)` placeholder while
    // `progressStatsProvider` is still loading, then swaps in the real,
    // much-taller week/month view once it resolves — growing the header by
    // the same "resize after the anchor's one-shot initState measure" class
    // of bug the two listeners above already guard against. Without this,
    // the very first `_measure()` (scheduled once in `initState`, before this
    // provider's artificial network delay resolves) permanently captured the
    // anchor's *loading-placeholder* position, leaving the collapsed card's
    // overlay stuck overlapping the header's real content for the entire
    // session unless some unrelated scroll/toggle happened to fix it.
    ref.listen<AsyncValue<ProgressStats>>(progressStatsProvider, (
      previous,
      next,
    ) {
      if (previous != next) _scheduleRemeasureBurst();
    });

    final screenSize = MediaQuery.sizeOf(context);
    final fullRect = Offset.zero & screenSize;
    // Shared with the expanded view's own scroll, below — a pull-down past
    // the top of that scroll (see `_ExpandedContent`'s `NotificationListener`)
    // drives the exact same collapse physics as the drag handle does.
    void dragUpdate(DragUpdateDetails d) => _onDragUpdate(d, screenSize.height);

    // `_CardSurface` depends only on `_controller` (drag/expand progress)
    // and the ring/streak/hours anchor rects it already takes as its own
    // constructor args — never on the page-level anchor rect held in
    // `_collapsedRectNotifier`. Building it inside its own `AnimatedBuilder`
    // that listens to `_controller` directly means it keeps rebuilding on
    // every real progress tick, but stops rebuilding on every scroll tick
    // and on every frame of the header's week/month-toggle remeasure burst
    // — both of which only ever move this whole overlay, never redraw its
    // content. Previously everything lived inside one `AnimatedBuilder`
    // whose surrounding `build()` reran on every one of those position-only
    // changes too, forcing a full rebuild of the entire card — including
    // the off-screen expanded task list, shimmer, and Lottie animations —
    // which is what read as lag during the week/month transition.
    final cardSurface = AnimatedBuilder(
      animation: Listenable.merge([_controller, _ringAnchorsNotifier]),
      builder: (context, _) {
        final anchors = _ringAnchorsNotifier.value;
        // Scheduled every controller tick so the ring/streak/hours anchors
        // stay current through the whole drag/expand animation, exactly
        // like `radius`/`lineWidth` already are — a plain drag mutates
        // `_controller.value` directly, so this `AnimatedBuilder`'s own
        // listener is what keeps this running, independent of whether the
        // state surrounding it ever rebuilds.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureRingAnchors(),
        );
        return _CardSurface(
          progress: _controller.value,
          expandedScrollController: _expandedScrollController,
          onPullToCollapseUpdate: dragUpdate,
          onPullToCollapseEnd: _onDragEnd,
          onCollapseTap: _collapse,
          surfaceKey: _surfaceKey,
          collapsedRingAnchorKey: _collapsedRingAnchorKey,
          expandedRingAnchorKey: _expandedRingAnchorKey,
          collapsedRingRect: anchors.collapsedRing,
          expandedRingRect: anchors.expandedRing,
          collapsedStreakAnchorKey: _collapsedStreakAnchorKey,
          expandedStreakAnchorKey: _expandedStreakAnchorKey,
          collapsedStreakRect: anchors.collapsedStreak,
          expandedStreakRect: anchors.expandedStreak,
          collapsedHoursAnchorKey: _collapsedHoursAnchorKey,
          expandedHoursAnchorKey: _expandedHoursAnchorKey,
          collapsedHoursRect: anchors.collapsedHours,
          expandedHoursRect: anchors.expandedHours,
        );
      },
    );

    // Outer wrapper: reacts to `_controller` (for the position lerp) and to
    // `_collapsedRectNotifier` (the page-level anchor moving under scroll or
    // the header's week/month resize) — but its own builder only touches
    // the cheap positioning/gesture wrapper, reusing the same `cardSurface`
    // instance above (via `AnimatedBuilder.child`) across every one of
    // those anchor-only updates instead of reconstructing it.
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _collapsedRectNotifier]),
      child: cardSurface,
      builder: (context, child) {
        final collapsedRect = _collapsedRectNotifier.value;
        if (collapsedRect == null) return const SizedBox.shrink();
        final rect = Rect.lerp(collapsedRect, fullRect, _controller.value)!;
        return Positioned.fromRect(
          rect: rect,
          child: PopScope(
            // While the card is expanded it covers the whole screen, so the
            // system/hardware back gesture must collapse it first — without
            // this the only way back was the vertical drag, with no
            // fallback for a user who doesn't discover that gesture (the
            // focus timer screen's AMOLED view has the same expanded-over-
            // the-dashboard shape and handles its own back button the same
            // way, via its own PopScope).
            canPop: _controller.value == 0.0,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _collapse();
            },
            child: GestureDetector(
              // Claims vertical drags whenever the card isn't fully
              // expanded — regardless of the underlying page's scroll
              // position. This overlay and the page's `CustomScrollView`
              // are siblings (see `dashboard_page.dart`'s `Stack`), not
              // ancestor/descendant, and this card paints on top of it —
              // Flutter's hit-testing walks a `Stack`'s children topmost
              // first and stops at whichever one claims the hit, so with
              // `HitTestBehavior.opaque` here, a touch inside the card's
              // (collapsed) bounds never even reaches the scroll view
              // underneath. There's no gesture-arena race to win; the card
              // simply is the only thing hit-tested at that point, so its
              // drag always takes priority there, however far the page has
              // been scrolled. A touch outside the card's small collapsed
              // rect was never part of this hit-test region to begin with,
              // so the page scrolls completely normally everywhere else.
              //
              // A previous version of this gated the *start* of a drag on
              // the page already being scrolled to the top, specifically so
              // a scroll gesture that happened to start over the collapsed
              // card could fall through to the page instead of popping the
              // card open. That's an intentional trade-off this reverses:
              // a touch that starts on the card now always controls the
              // card, never the page underneath it, at any scroll position.
              //
              // Once fully expanded (`_controller.value == 1.0`) this still
              // defers entirely so the expanded view's own scroll view is
              // reachable (collapsing from there goes through
              // `_ExpandedContent`'s own pull-to-collapse `Listener`
              // instead — see that class).
              behavior: _controller.value < 1.0
                  ? HitTestBehavior.opaque
                  : HitTestBehavior.deferToChild,
              onVerticalDragUpdate: _controller.value < 1.0
                  ? (d) => _onDragUpdate(d, screenSize.height)
                  : null,
              onVerticalDragEnd: _controller.value < 1.0 ? _onDragEnd : null,
              onTap: _controller.value == 0.0 ? _expand : null,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _CardSurface extends ConsumerWidget {
  final double progress;
  final ScrollController expandedScrollController;
  final GestureDragUpdateCallback onPullToCollapseUpdate;
  final GestureDragEndCallback onPullToCollapseEnd;
  final VoidCallback onCollapseTap;
  final GlobalKey surfaceKey;
  final GlobalKey collapsedRingAnchorKey;
  final GlobalKey expandedRingAnchorKey;
  final Rect? collapsedRingRect;
  final Rect? expandedRingRect;
  final GlobalKey collapsedStreakAnchorKey;
  final GlobalKey expandedStreakAnchorKey;
  final Rect? collapsedStreakRect;
  final Rect? expandedStreakRect;
  final GlobalKey collapsedHoursAnchorKey;
  final GlobalKey expandedHoursAnchorKey;
  final Rect? collapsedHoursRect;
  final Rect? expandedHoursRect;

  const _CardSurface({
    required this.progress,
    required this.expandedScrollController,
    required this.onPullToCollapseUpdate,
    required this.onPullToCollapseEnd,
    required this.onCollapseTap,
    required this.surfaceKey,
    required this.collapsedRingAnchorKey,
    required this.expandedRingAnchorKey,
    required this.collapsedRingRect,
    required this.expandedRingRect,
    required this.collapsedStreakAnchorKey,
    required this.expandedStreakAnchorKey,
    required this.collapsedStreakRect,
    required this.expandedStreakRect,
    required this.collapsedHoursAnchorKey,
    required this.expandedHoursAnchorKey,
    required this.collapsedHoursRect,
    required this.expandedHoursRect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(progressStatsProvider);
    final radius = lerpDouble(38, 108, progress)!;
    final lineWidth = lerpDouble(8, 14, progress)!;
    final cornerRadius = lerpDouble(20, 0, progress)!;
    final ringRect = Rect.lerp(collapsedRingRect, expandedRingRect, progress);
    final streakRect = Rect.lerp(
      collapsedStreakRect,
      expandedStreakRect,
      progress,
    );
    final hoursRect = Rect.lerp(
      collapsedHoursRect,
      expandedHoursRect,
      progress,
    );

    // Glassmorphic only while the card is fully at rest, collapsed (same
    // blurred, whitish-translucent-edge treatment as `GlassCard` elsewhere on
    // this dashboard) — the instant any motion starts (dragging open,
    // mid-expand/collapse, or fully expanded) it's the flat opaque
    // `AppTheme.pureBlack` surface this card always had. Lerping the two
    // continuously across `progress` read as a smeared, flickering blur
    // during the drag instead of a clean static-vs-moving state change.
    final isStatic = progress <= 0.0;
    final glassColor = isStatic
        ? AppTheme.white.withValues(alpha: 0.06)
        : AppTheme.pureBlack;

    // `BackdropFilter` forces a compositing saveLayer every frame it's in
    // the tree, even with a 0-sigma filter — this widget rebuilds on every
    // tick of the expand/collapse drag (see `AnimatedBuilder` above), so
    // leaving it in unconditionally paid that cost on every one of those
    // frames for a blur nobody sees outside the static, collapsed state.
    // Only mounting it when `isStatic` skips that layer entirely everywhere
    // else — dragging, mid-transition, fully expanded.
    final surfaceContent = Container(
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: isStatic
            ? Border.all(
                color: AppTheme.white.withValues(alpha: 0.14),
                width: 1.2,
              )
            : null,
      ),
      child: statsAsync.when(
        data: (stats) => Stack(
          children: [
            // Both variants stay mounted and laid out at all times — only
            // paint visibility toggles, with no fade — so the ring's two
            // anchor points can be measured continuously even while the
            // other one is hidden. That's what lets the floating ring
            // below track them without ever needing to unmount/remount.
            //
            // The swap threshold sits right near the collapsed end
            // (0.06), not the midpoint — `_ExpandedContent`'s own
            // content now fades out via a staggered per-element
            // opacity that only starts late in the shrink (see its
            // `progress` param), so by the time this structural swap
            // happens that content has already reached zero opacity.
            // Swapping at the old 0.5 midpoint cut expanded content
            // away while the container was still half the screen —
            // very obviously before it had "reached its collapsed
            // size".
            Visibility(
              visible: progress < 0.06,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: _CollapsedContent(
                stats: stats,
                radius: radius,
                ringAnchorKey: collapsedRingAnchorKey,
                streakAnchorKey: collapsedStreakAnchorKey,
                hoursAnchorKey: collapsedHoursAnchorKey,
              ),
            ),
            Visibility(
              visible: progress >= 0.06,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: _ExpandedContent(
                stats: stats,
                radius: radius,
                progress: progress,
                ringAnchorKey: expandedRingAnchorKey,
                streakAnchorKey: expandedStreakAnchorKey,
                hoursAnchorKey: expandedHoursAnchorKey,
                scrollController: expandedScrollController,
                onPullToCollapseUpdate: onPullToCollapseUpdate,
                onPullToCollapseEnd: onPullToCollapseEnd,
                onCollapseTap: onCollapseTap,
              ),
            ),
            // The one true ring — floats above both variants and moves
            // continuously between their anchor points instead of being
            // torn down and rebuilt when the content swaps.
            //
            // Sized from `radius` directly rather than from `ringRect`'s
            // own (measured) width/height: `ringRect` comes from
            // interpolating two independently-measured anchor rects, whose
            // reported `RenderBox.size` can be a fraction of a pixel off
            // from the pure `radius * 2` value `DonutProgressChart` uses
            // internally for its own layout. Only `ringRect`'s *center* is
            // used for position, which is unaffected by that mismatch.
            if (ringRect != null)
              Positioned(
                left: ringRect.center.dx - radius,
                top: ringRect.center.dy - radius,
                width: radius * 2,
                height: radius * 2,
                child: IgnorePointer(
                  child: DonutProgressChart(
                    percent: stats.weeklyCompletionRatio,
                    radius: radius,
                    lineWidth: lineWidth,
                    // At the collapsed radius (~38px) the ring's inner
                    // space is only ~44px across once its own padding and
                    // stroke are accounted for — two lines of text forced
                    // to fit there via FittedBox read as cramped, and
                    // combined with the two stat badges crowding the rest
                    // of the collapsed row, made the whole card feel
                    // overcrowded. Fading this in only once the ring has
                    // grown past roughly a third of the way to full
                    // expansion keeps the collapsed ring clean; by then
                    // there's real room for it.
                    // `DonutProgressChart` now draws the ring itself with a
                    // `CustomPainter` (see that file) instead of the
                    // `percent_indicator` package — no more intermediate
                    // `Column`/`Material` for a sub-pixel size mismatch to
                    // hide in, so the fixed-size wrapper below is no longer
                    // load-bearing for overflow the way it was against the
                    // old package. Left in place anyway: it's still the
                    // right way to size a `FittedBox`-scaled label that must
                    // never change size mid-animation, sized once for the
                    // ring's *largest* state so the `FittedBox` only ever
                    // scales down, never up.
                    // Enlarged (was 140x48) to actually fit the larger text
                    // below at something close to its full specified size —
                    // undersized here is what was forcing the two lines to
                    // fight over one shared `FittedBox` scale factor:
                    // growing one line's font grew the `Column`'s natural
                    // size, which shrank *both* lines more to still fit this
                    // box, so bigger text on one line read as smaller text
                    // on the other.
                    center: SizedBox(
                      width: 170,
                      height: 78,
                      child: Opacity(
                        opacity: ((progress - 0.15) / 0.35).clamp(0.0, 1.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${stats.tasksCompletedThisWeek}/${stats.tasksPlannedThisWeek}',
                                  style: TextStyle(
                                    fontFamily: 'GoogleSans',
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    // A fixed size here just left growing
                                    // empty space around the text as the
                                    // ring itself grew toward its expanded
                                    // diameter — `BoxFit.scaleDown` on the
                                    // surrounding `FittedBox` never scales
                                    // *up* past a child's natural size, only
                                    // down. Growing the font size in step
                                    // with `progress` is what actually makes
                                    // this readout bigger once the card is
                                    // fully expanded.
                                    fontSize: lerpDouble(18, 46, progress),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'this week',
                                  style: TextStyle(
                                    fontFamily: 'GoogleSans',
                                    color: AppTheme.textSecondary,
                                    fontSize: lerpDouble(10, 18, progress),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // The two stat badges — same floating technique as the ring
            // just above: one real instance each, gliding between its
            // collapsed and expanded anchor points instead of being torn
            // down and remounted at the progress=0.5 content swap.
            if (streakRect != null)
              Positioned.fromRect(
                rect: streakRect,
                child: IgnorePointer(
                  child: _StatBadge(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: AppTheme.accent,
                    value: '${_currentStreak(stats.dailyCompletions)}',
                    label: 'day streak',
                  ),
                ),
              ),
            if (hoursRect != null)
              Positioned.fromRect(
                rect: hoursRect,
                child: IgnorePointer(
                  child: _StatBadge(
                    icon: Icons.schedule_rounded,
                    iconColor: AppTheme.chartInProgress,
                    value:
                        '${stats.cumulativeHoursThisSemester.toStringAsFixed(1)}h',
                    label: 'this semester',
                    showIcon: false,
                  ),
                ),
              ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (_, _) => const Center(
          child: Icon(Icons.error_outline, color: AppTheme.error),
        ),
      ),
    );

    return Material(
      color: AppTheme.transparent,
      child: Container(
        key: surfaceKey,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: isStatic
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: surfaceContent,
              )
            : surfaceContent,
      ),
    );
  }
}

class _CollapsedContent extends StatelessWidget {
  final ProgressStats stats;
  final double radius;
  final Key ringAnchorKey;
  final Key streakAnchorKey;
  final Key hoursAnchorKey;

  const _CollapsedContent({
    required this.stats,
    required this.radius,
    required this.ringAnchorKey,
    required this.streakAnchorKey,
    required this.hoursAnchorKey,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Reserves the ring's footprint in this layout — the real ring is
          // drawn once, by `_CardSurface`, floating above both layouts, now
          // carrying its own centered readout (see `_CardSurface`) instead
          // of duplicating that number in this text column.
          SizedBox(key: ringAnchorKey, width: diameter, height: diameter),
          const SizedBox(width: 16),
          // Side-by-side, matching `_ExpandedContent`'s own badge pair —
          // was a vertical Column stacking both badges into half of the
          // collapsed ring's 76px height each, which is why they read as
          // small: a fixed-size badge squeezed to fit a half-height budget
          // looks equally small once expanded too, since its *position*
          // changes but its *intrinsic size* never did. Laid out
          // side-by-side instead, each badge gets the row's full height to
          // size itself against — see `_StatBadge` for the bigger layout
          // that room now allows.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // These reserve the badges' footprint only — the real
                // badges are drawn once, by `_CardSurface`, floating above
                // both layouts (see the streak/hours anchor comment on
                // `_ExpandableProgressCardState`).
                Expanded(
                  child: Opacity(
                    key: streakAnchorKey,
                    opacity: 0,
                    child: _StatBadge(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppTheme.accent,
                      value: '${_currentStreak(stats.dailyCompletions)}',
                      label: 'day streak',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    key: hoursAnchorKey,
                    opacity: 0,
                    child: _StatBadge(
                      icon: Icons.schedule_rounded,
                      iconColor: AppTheme.chartInProgress,
                      value:
                          '${stats.cumulativeHoursThisSemester.toStringAsFixed(1)}h',
                      label: 'this semester',
                      showIcon: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedContent extends StatefulWidget {
  final ProgressStats stats;
  final double radius;
  // Same shared value that drives the whole card's expand/collapse — used
  // here only to (a) gate when a fresh touch may start a pull-to-collapse
  // (see `_ExpandedContentState._onPointerDown`) and (b) drive the staggered
  // per-element reveal/hide below. Since it's the one continuous value both
  // directions already share, every opacity computed from it is
  // automatically an exact mirror on the way back — same intervals, same
  // curve, same total duration — with no separate "reverse" animation to
  // keep in sync.
  final double progress;
  final Key ringAnchorKey;
  final Key streakAnchorKey;
  final Key hoursAnchorKey;
  final ScrollController scrollController;
  // Wired to the same drag physics the collapsed card's swipe-up-to-expand
  // handle uses (`_ExpandableProgressCardState._onDragUpdate`/`_onDragEnd`)
  // — this view never re-implements the interpolation, it only decides
  // *when* to feed it (see `_ExpandedContentState`'s pull-to-collapse
  // gesture handling below).
  final GestureDragUpdateCallback onPullToCollapseUpdate;
  final GestureDragEndCallback onPullToCollapseEnd;
  // Explicit fallback for collapsing this view — the drag/pull gesture and
  // the system back gesture already cover it, but neither is discoverable
  // without trying it first; a visible arrow in the corner is.
  final VoidCallback onCollapseTap;

  const _ExpandedContent({
    required this.stats,
    required this.radius,
    required this.progress,
    required this.ringAnchorKey,
    required this.streakAnchorKey,
    required this.hoursAnchorKey,
    required this.scrollController,
    required this.onPullToCollapseUpdate,
    required this.onPullToCollapseEnd,
    required this.onCollapseTap,
  });

  @override
  State<_ExpandedContent> createState() => _ExpandedContentState();
}

class _ExpandedContentState extends State<_ExpandedContent> {
  // Raw pointer tracking rather than a `GestureDetector`/`NotificationListener`
  // pair: an ancestor `GestureDetector`'s vertical-drag recognizer and this
  // view's own `Scrollable` are both members of the same recognizer family
  // competing in the same gesture arena, and the `Scrollable` generally wins
  // that race regardless of scroll position — so a plain `GestureDetector`
  // here would silently never fire, and `NotificationListener<ScrollNotification>`
  // only reports back what the `Scrollable` decided to do with the drag,
  // which — with `ClampingScrollPhysics` and the scroll already pinned at
  // its boundary — is "nothing", so it stops emitting useful `dragDetails`
  // almost immediately once the pull begins. A raw `Listener` doesn't
  // participate in arena resolution at all; it observes every pointer event
  // that passes through it regardless of what the `Scrollable` does with the
  // same event, so it can drive the collapse independently instead of
  // fighting (or silently losing to) the list's own gesture handling.
  bool _pullGestureRelevant = false;
  bool _pullToCollapseActive = false;
  VelocityTracker? _velocityTracker;

  bool get _scrollAtTop {
    if (!widget.scrollController.hasClients) return true;
    final position = widget.scrollController.position;
    return position.pixels <= position.minScrollExtent + 0.5;
  }

  void _onPointerDown(PointerDownEvent event) {
    // Only a touch that starts while fully expanded is ever eligible to
    // become a pull-to-collapse — `Visibility`'s default
    // `maintainInteractivity: false` already keeps this whole subtree out of
    // hit-testing while collapsed (progress < 0.06), but for the
    // 0.06 <= progress < 1.0 mid-transition band the *outer* card overlay's
    // own drag handler (`_ExpandableProgressCardState.build`) is still the
    // active one; without this gate the same physical gesture would drive
    // `_controller` twice.
    _pullGestureRelevant = widget.progress == 1.0;
    _pullToCollapseActive = false;
    if (!_pullGestureRelevant) return;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pullGestureRelevant) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    if (!_pullToCollapseActive) {
      // Only start when the list has nowhere further to scroll and the
      // finger is moving down — any other movement is left alone so the
      // list scrolls normally.
      if (!_scrollAtTop || event.delta.dy <= 0) return;
      _pullToCollapseActive = true;
    }
    // Once armed, every subsequent move for this same pointer drives the
    // collapse — including a brief upward wobble — rather than re-checking
    // scroll position and possibly handing the gesture back to the list
    // mid-drag.
    widget.onPullToCollapseUpdate(
      DragUpdateDetails(globalPosition: event.position, delta: event.delta),
    );
  }

  void _onPointerEnd(PointerEvent event) {
    if (_pullGestureRelevant && _pullToCollapseActive) {
      final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
      widget.onPullToCollapseEnd(DragEndDetails(velocity: velocity));
    }
    _pullGestureRelevant = false;
    _pullToCollapseActive = false;
    _velocityTracker = null;
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;
    final stats = widget.stats;
    final progress = widget.progress;

    // Staggered reveal/hide for the three content blocks unique to this
    // view (the ring and the two stat badges are floated independently by
    // `_CardSurface` and aren't affected by this) — confined to a narrow
    // window right at the collapsed end so nothing fades away until the
    // container is almost fully shrunk, then a top-to-bottom cascade on the
    // way open (bottom-to-top teardown on the way closed, for free, since
    // it's the same formula read backwards as `progress` decreases).
    double reveal(double start, double end) => Curves.easeOut.transform(
      ((progress - start) / (end - start)).clamp(0.0, 1.0),
    );
    final headerReveal = reveal(0.06, 0.16);
    final chartReveal = reveal(0.10, 0.20);
    final tasksReveal = reveal(0.14, 0.24);

    // This view sits inside the card's shrinking overlay box (interpolated
    // every frame between the collapsed rect and the full screen — see
    // `_ExpandableProgressCardState.build`), which — until now — handed
    // this whole subtree the *current, shrinking* size as its own layout
    // constraints. That forced a real relayout of everything below on every
    // drag frame, and the shrink rate (tied to the outer rect) doesn't match
    // any single child's own natural size change — nothing here overflowed
    // on its own, but content laid out for a much bigger box was being
    // squeezed into a smaller one node-by-node every frame, faster than it
    // could gracefully re-flow, and something downstream would occasionally
    // lose the race and overflow mid-shrink (never at the endpoints, where
    // the box size and content settle together).
    //
    // Fix: give this content a *fixed* box — the true full screen size,
    // independent of the shrinking overlay's current constraints — via
    // `OverflowBox`, so it lays out exactly once for its natural (expanded)
    // size and never has to re-flow as the card shrinks. The ancestor
    // `Container`'s existing `clipBehavior: Clip.antiAlias` (see
    // `_CardSurface`) does the rest: whatever falls outside the shrinking
    // box is simply clipped away, so the content is *revealed/hidden* by
    // the shrink instead of being *re-laid-out* by it. Top-aligned so the
    // header stays pinned to the box's current top edge while the bottom
    // (chart, tasks) is what gets progressively clipped away — matching the
    // top-to-bottom staggered reveal above. At progress == 1.0 the box is
    // already the full screen, so this changes nothing about the expand
    // animation itself.
    final screenSize = MediaQuery.sizeOf(context);
    return OverflowBox(
      alignment: Alignment.topCenter,
      minWidth: 0,
      maxWidth: screenSize.width,
      minHeight: 0,
      maxHeight: screenSize.height,
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: SafeArea(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: SingleChildScrollView(
              controller: widget.scrollController,
              // Without an explicit physics override, this inherits the
              // platform default — `BouncingScrollPhysics` on iOS — which
              // rubber-bands the content itself on an over-the-top pull and then
              // plays its own ballistic spring-back once released. That fights
              // visually with the pull-to-collapse shrink this view already
              // drives via the `Listener` above (the content sliding/bouncing
              // independently of, and at a different rate than, the whole card
              // shrinking around it), which is what read as "not smooth".
              // Clamping removes that competing motion — the content just stays
              // put at the top while a pull-down is read purely as the collapse
              // gesture instead.
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgnorePointer(
                    ignoring: headerReveal <= 0.0,
                    child: Opacity(
                      opacity: headerReveal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The drag handle dash doubles as an explicit tap
                          // target for collapsing — the drag/pull gesture
                          // and the system back gesture already do it too,
                          // but neither is discoverable without trying it
                          // first, and this dash already reads as "the
                          // handle" without needing a separate icon.
                          Center(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onCollapseTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppTheme.textSecondary.withValues(
                                      alpha: 0.4,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Kept, not dropped — moved up from below the ring to
                          // this top corner so it reads as a header readout
                          // instead of adding to the stack of content below the
                          // ring (which was contributing to that view's bottom
                          // overflow). These reserve the badges' footprint only
                          // — the real badges are drawn once, by `_CardSurface`,
                          // floating above both layouts.
                          Row(
                            children: [
                              // Expanded rather than an unconstrained slot:
                              // without it each badge reports its own full
                              // natural width regardless of how little room is
                              // actually available, and on a narrow screen the
                              // pair (plus the 24px gap) overflows the Row — the
                              // badges' own internal Flexible+ellipsis text only
                              // ever gets a chance to shrink once it's actually
                              // given a bound.
                              Expanded(
                                child: Opacity(
                                  key: widget.streakAnchorKey,
                                  opacity: 0,
                                  child: _StatBadge(
                                    icon: Icons.local_fire_department_rounded,
                                    iconColor: AppTheme.accent,
                                    value:
                                        '${_currentStreak(stats.dailyCompletions)}',
                                    label: 'day streak',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Opacity(
                                  key: widget.hoursAnchorKey,
                                  opacity: 0,
                                  child: _StatBadge(
                                    icon: Icons.schedule_rounded,
                                    iconColor: AppTheme.chartInProgress,
                                    value:
                                        '${stats.cumulativeHoursThisSemester.toStringAsFixed(1)}h',
                                    label: 'this semester',
                                    showIcon: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // "Today's Tasks" and "Weekly Progress" swapped places —
                  // still keyed to `chartReveal`/`tasksReveal` respectively
                  // (not renamed) so the top-to-bottom stagger cascade (see
                  // those variables' doc above) still reveals whichever
                  // block is now on top first.
                  IgnorePointer(
                    ignoring: chartReveal <= 0.0,
                    child: Opacity(
                      opacity: chartReveal,
                      // Glassmorphic card — same treatment as `WeeklyBarChart` —
                      // wraps the header and `_TodaysTasks` together so the
                      // empty state's Lottie and the real task list both render
                      // inside this one container instead of swapping
                      // containers.
                      child: GlassCard(
                        borderRadius: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's Tasks",
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontFamily: 'GoogleSans',
                                      color: AppTheme.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              const _TodaysTasks(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Reserves the ring's footprint here too — the real ring is
                  // drawn once, by `_CardSurface`, floating above both layouts.
                  Center(
                    child: SizedBox(
                      key: widget.ringAnchorKey,
                      width: diameter,
                      height: diameter,
                    ),
                  ),
                  const SizedBox(height: 28),
                  IgnorePointer(
                    ignoring: tasksReveal <= 0.0,
                    child: Opacity(
                      opacity: tasksReveal,
                      // Reads the memoized bucketing instead of recomputing it
                      // here — this whole view rebuilds on every frame of the
                      // card's expand/collapse drag (see `weeklyChartDataProvider`'s
                      // doc for why that made the inline version real,
                      // avoidable per-frame work).
                      child: Consumer(
                        builder: (context, ref, _) => WeeklyBarChart(
                          dataByRange: ref.watch(weeklyChartDataProvider),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Real (non-debug) list of today's remaining tasks. When there are none,
/// shows the `empty_tasks` Lottie animation instead of just an empty area —
/// that animation's entire purpose is to read as "no tasks are there", not
/// as a loading or error state.
class _TodaysTasks extends ConsumerWidget {
  const _TodaysTasks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(dashboardPlanProvider);
    return planAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (plan) {
        final remaining = plan.remainingTasks;
        if (remaining.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 240,
                  width: 240,
                  child: DotLottieLoader.fromAsset(
                    'assets/animations/empty_tasks.lottie',
                    frameBuilder: (context, dotlottie) {
                      if (dotlottie == null) return const SizedBox.shrink();
                      return lottie.Lottie.memory(
                        dotlottie.animations.values.single,
                        fit: BoxFit.contain,
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
                Text(
                  'Yay! No tasks left',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'GoogleSans',
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.novaChat),
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppTheme.accentPurple,
                  ),
                  label: const Text(
                    'Edit with Nova',
                    style: TextStyle(
                      fontFamily: 'GoogleSans',
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surface.withValues(alpha: 0.6),
                    side: BorderSide(
                      color: AppTheme.white.withValues(alpha: 0.12),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: remaining
              .map(
                (t) => TaskListTile(
                  task: t,
                  onToggle: (id) =>
                      ref.read(dashboardPlanProvider.notifier).toggleTask(id),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// Compact stat pair, e.g. "🔥 3  day streak" — used beside the ring in both
/// the collapsed and expanded layouts. The icon+value row is what overflowed
/// for "this semester": that value ("132.5h") is longer than the streak's
/// bare number, and the 36px icon circle plus its gap ate into the same
/// narrow half-width slot a longer string already needed. [showIcon] drops
/// the icon entirely and centers the value on its own line (label centered
/// beneath it) instead, freeing that width rather than shrinking the text
/// further via ellipsis.
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool showIcon;

  const _StatBadge({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    // This badge is floated by `_CardSurface` via `Positioned.fromRect`,
    // sized to whatever its anchor placeholder measured — so its own
    // intrinsic size (not just its position) is what determines how big it
    // actually renders. Now that `_CollapsedContent` lays its two badges out
    // side-by-side instead of stacked (see that widget's doc), each one gets
    // the collapsed row's full ~76px height to size against instead of half
    // of it — icon/value/label are sized up accordingly so it actually reads
    // at a glance instead of disappearing next to the ring.
    final valueText = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: showIcon ? TextAlign.start : TextAlign.center,
      style: TextStyle(
        fontFamily: 'GoogleSans',
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
    );
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: showIcon ? TextAlign.start : TextAlign.center,
      style: TextStyle(
        fontFamily: 'GoogleSans',
        color: AppTheme.textSecondary,
        fontSize: 12,
      ),
    );

    return MediaQuery.withClampedTextScaling(
      // Even with the bigger layout below, this is still floated into a
      // fixed-height anchor box — capping at 1.0x keeps a large accessibility
      // text-scale setting from pushing it past that box's height, while a
      // "smaller text" setting can still shrink it.
      maxScaleFactor: 1.0,
      child: Column(
        crossAxisAlignment: showIcon
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: showIcon
            ? [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Flexible(child: valueText),
                  ],
                ),
                const SizedBox(height: 4),
                labelText,
              ]
            : [valueText, const SizedBox(height: 4), labelText],
      ),
    );
  }
}
