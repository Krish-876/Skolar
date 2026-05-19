import 'package:flutter/material.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/features/analytics/domain/entities/analytics_entity.dart';


/// Renders a single task row: title, stacked avatar circles, due date.
class TaskListTile extends StatelessWidget {
  final TaskItem task;
  final bool showDivider;

  const TaskListTile({
    super.key,
    required this.task,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                    const SizedBox(height: 8),
                    _AvatarStack(avatars: task.assigneeAvatars),
                  ],
                ),
              ),
              Text(
                task.dueDate,
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

/// Stacked avatar circles (overlapping, like the mockup).
class _AvatarStack extends StatelessWidget {
  final List<String> avatars;
  static const double _size = 28;
  static const double _overlap = 10;

  const _AvatarStack({required this.avatars});

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) return const SizedBox.shrink();
    final count = avatars.length.clamp(0, 4); // max 4 shown
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
  static const _size = 28.0;

  // Cycling colors for variety, matching the dark mockup aesthetic
  static const _colors = [
    Color(0xFF4A90D9),
    Color(0xFF7B68EE),
    Color(0xFF50C878),
    Color(0xFFFF8C69),
  ];

  const _Avatar({required this.label, required this.index});

  @override
  Widget build(BuildContext context) {
    // label can be an initial like "A" or a full name — show first char
    final initial =
        label.isNotEmpty ? label[0].toUpperCase() : '?';
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
