import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';

class DashboardSectionHeader extends ConsumerWidget {
  final String title;
  final bool showRefresh;

  const DashboardSectionHeader({
    super.key,
    required this.title,
    this.showRefresh = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.textPrimary),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.search, color: AppTheme.textSecondary),
                onPressed: () {},
              ),
              if (showRefresh)
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: AppTheme.textSecondary),
                  onPressed: () =>
                      ref.read(dashboardProvider.notifier).refresh(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}