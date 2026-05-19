import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_sort_option.dart';
import 'feed_colors.dart';

class FeedSortSheet extends ConsumerWidget {
  const FeedSortSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FeedColors.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const FeedSortSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(feedSortProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: FeedColors.sheetHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sort feed by',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FeedColors.textSecondary,
              fontFamily: 'DM Sans',
            ),
          ),
          const SizedBox(height: 8),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: FeedColors.sortOptBorder, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 16,
              color: selected ? FeedColors.sortSelText : FeedColors.textMuted,
            ),
            const SizedBox(width: 10),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? FeedColors.sortSelText : FeedColors.textSecondary,
                fontFamily: 'DM Sans',
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_rounded, size: 14, color: FeedColors.sortSelText),
          ],
        ),
      ),
    );
  }
}