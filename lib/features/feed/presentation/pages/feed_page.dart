import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/core/widgets/feed_gradient.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_sort_option.dart';
import '../widgets/feed_colors.dart';
import '../widgets/feed_post_card.dart';
import '../widgets/feed_sort_sheet.dart';
import '../widgets/generate_sheet.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final sortOption = ref.watch(feedSortProvider);
    final sorted = ref.watch(sortedFeedProvider); // ← cached, no re-sort on rebuild

    return GlassBackgroundFeed(
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
                error: (e, _) =>
                    SliverFillRemaining(child: _ErrorState(message: e.toString())),
                data: (_) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _AnimatedCard(
                      index: index,
                      child: FeedPostCard(
                        post: sorted[index],
                        index: index,
                      ),
                    ),
                    childCount: sorted.length,
                  ),
                ),
              ),
            ],
          ),
        ),
        // bottomNavigationBar: const _BottomNav(),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skolar',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.deepOrange,
                    fontFamily: 'DM Sans',
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'BITS Pilani · Hyderabad',
                  style: TextStyle(
                    fontSize: 11,
                    color: FeedColors.textHint,
                    fontFamily: 'DM Sans',
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.notifications_outlined,
              size: 21, color: FeedColors.textMuted),
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded,
              size: 21, color: FeedColors.textMuted),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FeedColors.border, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded,
                      size: 13, color: FeedColors.textMuted),
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
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 13, color: FeedColors.textMuted),
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

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatefulWidget {
  const _BottomNav();

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> {
  int _current = 1;

  final _items = const [
    _NavItem(icon: Icons.home_outlined, label: 'Home'),
    _NavItem(icon: Icons.view_list_rounded, label: 'Feed'),
    _NavItem(icon: null, label: 'Generate'),
    _NavItem(icon: Icons.emoji_events_outlined, label: 'Ranks'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  void _onTap(int index) {
    if (index == 2) {
      GenerateSheet.show(context);
      return;
    }
    setState(() => _current = index);
    // TODO: context.go(AppRoutes.xxx) for each index
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FeedColors.navBg,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              if (i == 2) return _GenerateNavItem(onTap: () => _onTap(2));
              return _NavItemWidget(
                item: _items[i],
                active: _current == i,
                onTap: () => _onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData? icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavItemWidget extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavItemWidget(
      {required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: active ? FeedColors.navActive : FeedColors.navInactive,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                color: active ? FeedColors.navActive : FeedColors.navInactive,
                fontFamily: 'DM Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateNavItem extends StatelessWidget {
  final VoidCallback onTap;
  const _GenerateNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: FeedColors.genRingBg,
                shape: BoxShape.circle,
                border:
                    Border.all(color: FeedColors.genRingBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: FeedColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Generate',
              style: TextStyle(
                fontSize: 10,
                color: FeedColors.navInactive,
                fontFamily: 'DM Sans',
              ),
            ),
          ],
        ),
      ),
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