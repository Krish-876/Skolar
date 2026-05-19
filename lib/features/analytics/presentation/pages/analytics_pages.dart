import 'package:flutter/material.dart';
import '../widgets/analytics_widgets.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: const [
          // TODO: replace with real data via provider
          AnalyticsCard(title: 'Sample item 1'),
          AnalyticsCard(title: 'Sample item 2'),
        ],
      ),
    );
  }
}
