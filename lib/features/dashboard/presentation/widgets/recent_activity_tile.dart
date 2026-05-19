import 'package:flutter/material.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/features/analytics/domain/entities/analytics_entity.dart';


/// Renders a single row in the "Recent Activity" section.
/// Matches: [time] [title + subtitle] [due date] layout from the mockup.
class RecentActivityTile extends StatelessWidget {
  final RecentActivity activity;
  final bool showDivider;

  const RecentActivityTile({
    super.key,
    required this.activity,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time column
              SizedBox(
                width: 44,
                child: Text(
                  activity.time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              // Due date
              Text(
                activity.dueDate,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(color: AppTheme.divider, height: 1, thickness: 1),
      ],
    );
  }
}
