import 'package:Skolar/shared/providers/global_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_sort_option.dart';
import '../widgets/feed_post_card.dart';
import '../widgets/feed_sort_sheet.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final sortOption = ref.watch(feedSortProvider);
    final sorted = ref.watch(sortedFeedProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.accentPurple,
          backgroundColor: AppTheme.surface,
          onRefresh: () => ref.read(feedProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _TopBar()),
              SliverToBoxAdapter(child: _SortBar(sortOption: sortOption)),
              feedAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LoadingState(),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: e.toString(),
                    onRetry: () => ref.read(feedProvider.notifier).refresh(),
                  ),
                ),
                data: (_) {
                  if (sorted.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyFeedState(),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.only(bottom: 96),
                    sliver: SliverList(
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
                  );
                },
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
    final canPop = Navigator.canPop(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: AppTheme.onboardingButtonBorder,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.onBackground,
                  size: 16,
                ),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Feed',
                  style: GoogleFonts.googleSansFlex(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onBackground,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  college.isNotEmpty
                      ? college
                      : 'Peer questions & PYQ practice',
                  style: const TextStyle(
                    fontFamily: 'GoogleSans',
                    fontSize: 12,
                    color: AppTheme.onBackground2,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.onboardingButtonBorder,
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () => ref.read(feedProvider.notifier).refresh(),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: AppTheme.onBackground2,
              ),
              padding: EdgeInsets.zero,
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'EXPLORE QUESTIONS',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.onBackground2.withValues(alpha: 0.7),
            ),
          ),
          GestureDetector(
            onTap: () => FeedSortSheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: AppTheme.onboardingButtonBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sort_rounded,
                    size: 14,
                    color: AppTheme.accentPurple,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sortOption.label,
                    style: const TextStyle(
                      fontFamily: 'GoogleSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppTheme.onBackground2,
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
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (!_animated) {
      Future.delayed(Duration(milliseconds: 30 + widget.index * 60), () {
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

// ── Loading, error & empty states ─────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: AppTheme.accentPurple,
            strokeWidth: 2.5,
          ),
          SizedBox(height: 16),
          Text(
            'Loading questions...',
            style: TextStyle(
              fontFamily: 'GoogleSans',
              color: AppTheme.onBackground2,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.onboardingButtonBorder,
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.dynamic_feed_rounded,
                color: AppTheme.accentPurple,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No posts yet',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Practice questions shared by students will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.onBackground2,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.wishlist.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.wishlist.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppTheme.wishlist,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load feed',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'GoogleSans',
                color: AppTheme.onBackground2,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppTheme.accentPurple,
                size: 18,
              ),
              label: const Text(
                'Retry',
                style: TextStyle(
                  fontFamily: 'GoogleSans',
                  color: AppTheme.accentPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
