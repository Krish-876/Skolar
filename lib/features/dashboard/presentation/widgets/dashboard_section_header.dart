import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';

class DashboardSectionHeader extends ConsumerWidget {
  final String title;
  final bool showRefresh;

  /// Overrides the default search/refresh icon row entirely when set — e.g.
  /// a "See Details" button for the radar section.
  final Widget? trailing;

  const DashboardSectionHeader({
    super.key,
    required this.title,
    this.showRefresh = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'GoogleSans',
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.search, color: AppTheme.textSecondary),
                    onPressed: () {},
                  ),
                  if (showRefresh)
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () =>
                          ref.read(dashboardPlanProvider.notifier).refresh(),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}
