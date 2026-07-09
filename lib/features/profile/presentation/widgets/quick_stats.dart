/// lib/features/dashboard/presentation/widgets/quick_stats_row.dart
///
/// Three circular stat buttons: watch time, uploads, friends.
/// Each fires an onTap callback – wire up navigation or sheets.
library;

import 'package:flutter/material.dart';

class QuickStatsRow extends StatelessWidget {
  final String totalWatchTime;
  final int totalUploads;
  final int friendCount;

  /// Optional tap callbacks – if null, a default bottom-sheet placeholder fires.
  final VoidCallback? onWatchTimeTap;
  final VoidCallback? onUploadsTap;
  final VoidCallback? onFriendsTap;

  const QuickStatsRow({
    super.key,
    this.totalWatchTime = '—',
    this.totalUploads = 0,
    this.friendCount = 0,
    this.onWatchTimeTap,
    this.onUploadsTap,
    this.onFriendsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCircle(
            icon: Icons.access_time_outlined,
            label: 'Total watch time',
            value: totalWatchTime,
            onTap: onWatchTimeTap ?? () => _sheet(context, 'Total Watch Time'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCircle(
            icon: Icons.send_outlined,
            label: 'Total upload works',
            value: '$totalUploads',
            onTap: onUploadsTap ?? () => _sheet(context, 'Upload Works'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCircle(
            icon: Icons.group_outlined,
            label: 'Friends',
            value: '$friendCount',
            onTap: onFriendsTap ?? () => _sheet(context, 'Friends'),
          ),
        ),
      ],
    );
  }

  void _sheet(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2D55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFEEF0FF),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Wire up your provider or navigation here.',
              style: TextStyle(color: Color(0xFF7A84AA)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Single circular stat button – also exported for custom layouts.
class StatCircle extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const StatCircle({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  State<StatCircle> createState() => _StatCircleState();
}

class _StatCircleState extends State<StatCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _scale;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scale.reverse(),
      onTapUp: (_) {
        _scale.forward();
        widget.onTap();
      },
      onTapCancel: () => _scale.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131B38).withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1F2D55)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B5EEF).withValues(alpha: 0.07),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: const Color(0xFF7A84AA), size: 22),
                if (widget.value.isNotEmpty &&
                    widget.value != '0' &&
                    widget.value != '—') ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.value,
                    style: const TextStyle(
                      color: Color(0xFFAA8FFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF7A84AA),
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
