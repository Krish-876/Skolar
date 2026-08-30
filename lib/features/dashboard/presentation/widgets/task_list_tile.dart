import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/dashboard/domain/entities/dashboard_entity.dart';

/// Renders a single remaining task: circle checkbox, title, subject, and the
/// timer duration attached to it.
class TaskListTile extends StatelessWidget {
  final DashboardTask task;
  final ValueChanged<String>? onToggle;
  final bool showDivider; // kept for signature compatibility, unused here

  const TaskListTile({
    super.key,
    required this.task,
    this.onToggle,
    this.showDivider = false,
  });

  String get _formattedDuration {
    final d = task.timerDuration;
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      return mins == 0 ? '${d.inHours}h' : '${d.inHours}h ${mins}m';
    }
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleCheckbox(
            checked: task.completed,
            onTap: onToggle == null ? null : () => onToggle!(task.id),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'GoogleSans',
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    decoration: task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.subject,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'GoogleSans',
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(
              AppRoutes.focusSession,
              extra: task.timerDuration,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _formattedDuration,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'GoogleSans',
                    color: AppTheme.textSecondary,
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

class _CircleCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback? onTap;

  const _CircleCheckbox({required this.checked, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? AppTheme.accent : AppTheme.transparent,
            border: Border.all(
              color: checked ? AppTheme.accent : AppTheme.textSecondary,
              width: 1.5,
            ),
          ),
          child: checked
              ? const Icon(Icons.check, size: 14, color: AppTheme.onPrimary)
              : null,
        ),
      ),
    );
  }
}
