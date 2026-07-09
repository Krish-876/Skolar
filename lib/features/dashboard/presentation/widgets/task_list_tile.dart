import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/analytics/domain/entities/analytics_entity.dart';

/// Renders a single task as a clean, independent sub-box.
/// Designed to live seamlessly inside a unified parent card structure.
class TaskListTile extends StatelessWidget {
  final TaskItem task;
  final bool showDivider; // Maintained for signature compatibility, unused here

  const TaskListTile({super.key, required this.task, this.showDivider = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Soft bottom margin to cleanly separate the sub-boxes
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // High-end subtle transparent tint to contrast against the parent card background
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _AvatarStack(avatars: task.assigneeAvatars),
              ],
            ),
          ),
          Text(
            task.dueDate,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Stacked avatar circles (overlapping, like the mockup).
class _AvatarStack extends StatelessWidget {
  final List<String> avatars;
  static const double _size = 26;
  static const double _overlap = 16;

  const _AvatarStack({required this.avatars});

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) return const SizedBox.shrink();
    final count = avatars.length.clamp(0, 4);
    final totalWidth = _size + (_overlap * (count - 1));

    return SizedBox(
      width: totalWidth,
      height: _size,
      child: Stack(
        children: List.generate(count, (i) {
          return Positioned(
            left: i * _overlap,
            child: _Avatar(label: avatars[i], index: i),
          );
        }),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  final int index;
  static const _size = 26.0;

  static const _colors = [
    Color(0xFF9333EA), // Orchid Purple
    Color(0xFF06B6D4), // Electric Cyan
    Color(0xFF3B82F6), // Digital Blue
    Color(0xFFFBBF24), // Amber Gold
  ];

  const _Avatar({required this.label, required this.index});

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final color = _colors[index % _colors.length];

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.cardBackground, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
