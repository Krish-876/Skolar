import 'package:flutter/material.dart';

/// Custom app widgets and builders
class AppWidgets {
  /// Loading indicator
  static Widget buildLoadingIndicator({
    Color? color,
    double size = 50,
  }) =>
      SizedBox(
        height: size,
        width: size,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );

  /// Error widget
  static Widget buildErrorWidget({
    required String message,
    required VoidCallback onRetry,
  }) =>
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  /// Empty state widget
  static Widget buildEmptyWidget({
    required String title,
    String? subtitle,
    IconData icon = Icons.hourglass_empty,
  }) =>
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.grey)),
            ]
          ],
        ),
      );
}
