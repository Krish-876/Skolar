import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_sort_option.dart';

class FeedSortSheet extends ConsumerWidget {
  const FeedSortSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxl),
        ),
      ),
      builder: (_) => const FeedSortSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(feedSortProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.onboardingButtonBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sort feed by',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),
            ...FeedSortOption.values.map(
              (option) => _SortOptionTile(
                option: option,
                selected: option == current,
                onTap: () {
                  ref.read(feedSortProvider.notifier).state = option;
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  final FeedSortOption option;
  final bool selected;
  final VoidCallback onTap;

  const _SortOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (option) {
      case FeedSortOption.upvotes:
        return Icons.arrow_upward_rounded;
      case FeedSortOption.mostAttempted:
        return Icons.group_outlined;
      case FeedSortOption.difficultyEasyFirst:
        return Icons.signal_cellular_alt_1_bar_rounded;
      case FeedSortOption.difficultyHardFirst:
        return Icons.local_fire_department_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accentPurple.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: selected
                  ? AppTheme.accentPurple
                  : AppTheme.onboardingButtonBorder,
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 18,
                color: selected ? AppTheme.accentPurple : AppTheme.onBackground2,
              ),
              const SizedBox(width: 12),
              Text(
                option.label,
                style: TextStyle(
                  fontFamily: 'GoogleSans',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppTheme.onBackground
                      : AppTheme.onBackground2,
                ),
              ),
              const Spacer(),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppTheme.accentPurple,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
