import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

/// Generic "no data yet" empty state — icon + short copy, muted text colour.
/// Kept as its own widget so a Lottie asset can later replace [icon] without
/// touching any caller.
class NoDataPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;

  const NoDataPlaceholder({
    super.key,
    required this.message,
    this.icon = Icons.insights_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
