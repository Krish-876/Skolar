import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

class TestLoadingPage extends StatefulWidget {
  const TestLoadingPage({super.key});

  @override
  State<TestLoadingPage> createState() => _TestLoadingPageState();
}

class _TestLoadingPageState extends State<TestLoadingPage>
    with TickerProviderStateMixin {
  late GifController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GifController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Gif(
          image: const AssetImage('assets/animations/icon_animation.gif'),
          controller: _controller,
          autostart: Autostart.loop,
          fit: BoxFit.contain,
          width: 120,
          height: 120,
        ),
      ),
    );
  }
}
