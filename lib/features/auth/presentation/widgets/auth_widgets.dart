import 'package:flutter/material.dart';

export 'reg_widget.dart';
export 'signin_widget.dart';

/// Reusable card for a single Auth item.
class AuthCard extends StatelessWidget {
  final String title;
  const AuthCard({super.key, required this.title});

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