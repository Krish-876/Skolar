import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
import 'loading_provider.dart';

class LoadingOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const LoadingOverlay({super.key, required this.child});

  @override
  ConsumerState<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends ConsumerState<LoadingOverlay> with TickerProviderStateMixin {
  late GifController _gifController;

  @override
void initState() {
  super.initState();
  _gifController = GifController(vsync: this);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startLoop();
  });
}

void _startLoop() async {
  if (!mounted) return;
  _gifController.reset();
  _gifController.forward(from: 0);
  _gifController.addStatusListener((status) {
    if (status == AnimationStatus.completed && mounted) {
      _gifController.reset();
      _gifController.forward(from: 0);
    }
  });
}

  @override
  void dispose() {
    _gifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(loadingProvider);

    return PopScope(
      canPop: !isLoading,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          widget.child,
          if (isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xAA000000),
                child: Center(
                  child: Gif(
                    image: const AssetImage('assets/animations/icon_animation.gif'),
                    controller: _gifController,
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}