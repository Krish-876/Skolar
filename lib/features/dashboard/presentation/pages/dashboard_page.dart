import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/all_round_development_card.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:Skolar/features/dashboard/presentation/widgets/expandable_progress_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _cardAnchorKey = GlobalKey();
  final _expansionProgress = ValueNotifier<double>(0);
  final _scrollController = ScrollController();

  // Matches the collapsed card's actual content height: 20px padding (top
  // + bottom, see `_CollapsedContent`) around its tallest element, the ring
  // at its collapsed diameter (radius 38 * 2 = 76) — 20 + 76 + 20 = 116.
  // This box is a fixed-size overlay (`Positioned.fromRect`), not something
  // that sizes to its own content, so a taller-than-necessary value here
  // left visible dead space at the bottom of the card.
  static const double _collapsedCardHeight = 116;

  @override
  void dispose() {
    _expansionProgress.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Reloads every dashboard data source, then bumps
  // `dashboardRefreshSignalProvider` so the week strip pages itself back to
  // the current week — regardless of which week/month the user had swiped
  // to — instead of a reload leaving it stranded wherever it was.
  Future<void> _onRefresh() async {
    ref.invalidate(progressStatsProvider);
    ref.invalidate(developmentAxesProvider);
    await Future.wait([
      ref.read(dashboardPlanProvider.notifier).refresh(),
      ref.read(progressStatsProvider.future),
      ref.read(developmentAxesProvider.future),
    ]);
    // The widget (and this State's `ref`) can be disposed while the above
    // await is pending — e.g. the user navigates away mid-refresh — so `ref`
    // is no longer safe to touch once we come back from it without checking
    // first.
    if (!mounted) return;
    ref.read(dashboardRefreshSignalProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: AppTheme.pureBlack),
        Scaffold(
          backgroundColor: AppTheme.transparent,
          body: SafeArea(
            child: ValueListenableBuilder<double>(
              valueListenable: _expansionProgress,
              builder: (context, progress, child) => IgnorePointer(
                ignoring: progress > 0.05,
                child: Opacity(
                  opacity: (1 - progress * 1.6).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -16 * progress),
                    child: child,
                  ),
                ),
              ),
              child: _buildScaffoldContent(context),
            ),
          ),
        ),
        ExpandableProgressCard(
          anchorKey: _cardAnchorKey,
          expansionProgress: _expansionProgress,
          scrollController: _scrollController,
        ),
      ],
    );
  }

  Widget _buildScaffoldContent(BuildContext context) {
    // DashboardHeader (which contains the week/month StreakStrip toggle) used
    // to be a fixed, non-scrolling sibling above an `Expanded(CustomScrollView)`
    // — so when the month grid made the header taller, it squeezed the
    // Expanded's available height rather than just extending the scroll
    // content, and on a small enough screen that overflowed the outer Column
    // outright ("RenderFlex overflowed..."). It's now the CustomScrollView's
    // own first sliver: the anchor below it is guaranteed to sit immediately
    // below it by ordinary layout flow regardless of how tall the header
    // gets, and a taller header just extends scrollable content instead of
    // budging against a fixed remaining-space budget.
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      child: CustomScrollView(
        controller: _scrollController,
        // `AlwaysScrollableScrollPhysics` (not plain `BouncingScrollPhysics`)
        // so the pull-to-refresh gesture still triggers even on a screen
        // tall enough that this content doesn't overflow it — otherwise
        // there'd be no overscroll for `RefreshIndicator` to detect.
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: DashboardHeader()),
          // Anchor placeholder for the collapsed card's overlay geometry —
          // lives in the scrollable content so it scrolls away with the rest
          // of the page instead of leaving the overlay stuck in place. Extra
          // top padding (was 8) gives it a bit more breathing room below the
          // streak strip now that the date row (see `streak_strip.dart`)
          // makes that section taller — without it the card sat too close
          // underneath.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                key: _cardAnchorKey,
                width: double.infinity,
                height: _collapsedCardHeight,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              // Top padding (was 0) matches the same breathing-room bump
              // just given to the anchor above it — the collapsed card now
              // sits with more space below it too, so this card doesn't
              // crowd right up against it.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: const AllRoundDevelopmentCard(),
            ),
          ),
        ],
      ),
    );
  }
}