import 'package:flutter/material.dart';
import 'package:nova/core/widgets/glass_background.dart';
import 'package:nova/features/auth/presentation/widgets/space_background.dart';

class SpaceRecordPage extends StatelessWidget {
  const SpaceRecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GlassBackground(
        child: SpaceBackground(
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}