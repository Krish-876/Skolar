/// Feature skeleton - Pages
import 'package:flutter/material.dart';
import '../widgets/exam_prediction_widgets.dart';

class ExamPredictionPage extends StatelessWidget {
  const ExamPredictionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Prediction'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: const [
          // TODO: replace with real data via provider
          ExamPredictionCard(title: 'Sample item 1'),
          ExamPredictionCard(title: 'Sample item 2'),
        ],
      ),
    );
  }
}
