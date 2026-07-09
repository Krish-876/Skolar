import 'package:Skolar/shared/providers/global_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';
// import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/core/widgets/glass_background.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_sort_option.dart';
import '../widgets/feed_colors.dart';
import '../widgets/feed_post_card.dart';
import '../widgets/feed_sort_sheet.dart';
// import '../widgets/generate_sheet.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final sortOption = ref.watch(feedSortProvider);
    final sorted = ref.watch(
      sortedFeedProvider,
    ); // ← cached, no re-sort on rebuild

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: RefreshIndicator(
          color: FeedColors.purple,
          backgroundColor: FeedColors.surface,
          onRefresh: () => ref.read(feedProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _TopBar()),
              SliverToBoxAdapter(child: _SortBar(sortOption: sortOption)),
              feedAsync.when(
                loading: () =>
                    const SliverFillRemaining(child: _LoadingState()),
                error: (e, _) => SliverFillRemaining(
                  child: _ErrorState(message: e.toString()),
                ),
                data: (_) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _AnimatedCard(
                      index: index,
                      child: FeedPostCard(post: sorted[index], index: index),
                    ),
                    childCount: sorted.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final college = ref.watch(userProvider).college;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skolar',
                  style: GoogleFonts.googleSans(
                    fontSize: 35,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onBackground,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  college,
                  style: GoogleFonts.googleSans(
                    fontSize: 11,
                    color: AppTheme.textGradBegin.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.notifications_outlined,
            size: 21,
            color: FeedColors.textMuted,
          ),
          const SizedBox(width: 14),
          const Icon(
            Icons.search_rounded,
            size: 21,
            color: FeedColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ── Sort bar ──────────────────────────────────────────────────────────────────

class _SortBar extends StatelessWidget {
  final FeedSortOption sortOption;
  const _SortBar({required this.sortOption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'Sorted by',
            style: TextStyle(
              fontSize: 11,
              color: FeedColors.textHint,
              fontFamily: 'DM Sans',
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => FeedSortSheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FeedColors.border, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sort_rounded,
                    size: 13,
                    color: FeedColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    sortOption.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: FeedColors.textMuted,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 13,
                    color: FeedColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated card wrapper ─────────────────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final int index;
  const _AnimatedCard({required this.child, required this.index});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (!_animated) {
      Future.delayed(Duration(milliseconds: 40 + widget.index * 80), () {
        if (mounted) {
          _ctrl.forward();
          _animated = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Loading & error states ────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: FeedColors.purple,
        strokeWidth: 2,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Failed to load feed\n$message',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: FeedColors.textMuted,
          fontSize: 13,
          fontFamily: 'DM Sans',
        ),
      ),
    );
  }
}
