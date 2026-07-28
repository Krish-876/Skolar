import 'dart:async';
import 'package:flutter/material.dart';

/// Plays a pre-rendered PNG frame sequence (e.g. exported from a Lottie
/// animation via convert.js) as a lightweight, pixel-perfect alternative
/// to runtime Lottie rendering.
class FrameSequencePlayer extends StatefulWidget {
  final String folder;
  final int frameCount;
  final Duration frameDuration;
  final bool loop;
  final double width;
  final double height;
  final VoidCallback? onComplete;

  const FrameSequencePlayer({
    super.key,
    required this.folder,
    required this.frameCount,
    this.frameDuration = const Duration(milliseconds: 33),
    this.loop = false,
    this.width = 300,
    this.height = 300,
    this.onComplete,
  });

  @override
  State<FrameSequencePlayer> createState() => _FrameSequencePlayerState();
}

class _FrameSequencePlayerState extends State<FrameSequencePlayer> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.frameDuration, (t) {
      setState(() {
        if (_frame < widget.frameCount - 1) {
          _frame++;
        } else if (widget.loop) {
          _frame = 0;
        } else {
          t.cancel();
          widget.onComplete?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _frame.toString().padLeft(3, '0');
    return Image.asset(
      '${widget.folder}/frame_$n.png',
      width: widget.width,
      height: widget.height,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          'Missing frame: frame_$n.png\n$error',
          style: const TextStyle(color: Colors.red, fontSize: 10),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
