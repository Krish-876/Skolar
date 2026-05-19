import 'package:flutter/material.dart';

/// Reusable card for a single Analytics item.
class AnalyticsCard extends StatelessWidget {
  final String title;
  const AnalyticsCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
