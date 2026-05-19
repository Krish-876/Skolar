import 'package:flutter/material.dart';
import '../widgets/colleges_widgets.dart';

class CollegesPage extends StatelessWidget {
  const CollegesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Colleges'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: const [
          // TODO: replace with real data via provider
          CollegesCard(title: 'Sample item 1'),
          CollegesCard(title: 'Sample item 2'),
        ],
      ),
    );
  }
}
