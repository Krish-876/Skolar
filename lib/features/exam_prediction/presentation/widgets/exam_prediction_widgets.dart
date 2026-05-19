import 'package:flutter/material.dart';

/// Reusable card for a single Exam Prediction item.
class ExamPredictionCard extends StatelessWidget {
  final String title;
  const ExamPredictionCard({super.key, required this.title});

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
