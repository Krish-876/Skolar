import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Swipeable + auto-rotating background.
/// - Auto-rotates slowly forever
/// - User can swipe to spin; auto-rotation resumes immediately after
/// - No cursor
///
/// Tweak these two constants to taste:
///   _speed      : degrees per second (negative = clockwise)
///   _saturation : 1.0 = original, 2.0 = vivid, 2.5 = very vivid

class KnowledgeTreeBackground extends StatefulWidget {
  final String modelPath;
  const KnowledgeTreeBackground({
    super.key,
    this.modelPath = 'assets/models/knowledge_tree.glb',
  });

  @override
  State<KnowledgeTreeBackground> createState() =>
      _KnowledgeTreeBackgroundState();
}

class _KnowledgeTreeBackgroundState extends State<KnowledgeTreeBackground> {
  static const double _speed = -4; // deg/sec — change speed here
  static const double _saturation = 80; // change saturation here

  String get _js =>
      '''
    (function() {
      // Inject a global style that hides cursor on model-viewer + its shadow DOM
      // This survives hot restart because it targets the document, not the element
      const style = document.createElement('style');
      style.textContent = `
        model-viewer { cursor: none !important; }
        model-viewer * { cursor: none !important; }
      `;
      document.head.appendChild(style);

      const applyToMv = (mv) => {
        mv.style.cursor = 'none';

        // Inject into shadow root too
        const shadowStyle = document.createElement('style');
        shadowStyle.textContent = `* { cursor: none !important; }`;
        mv.shadowRoot?.appendChild(shadowStyle);

        // Saturation on canvas
        const applyCanvas = () => {
          const canvas = mv.shadowRoot?.querySelector('canvas');
          if (canvas) {
            canvas.style.filter = 'saturate($_saturation) contrast(1.05)';
            canvas.style.cursor = 'none';
          }
        };

        if (mv.loaded) {
          applyCanvas();
        } else {
          mv.addEventListener('load', applyCanvas);
        }

        // Lock phi — vertical axis lock
        const observer = new MutationObserver(() => {
          const orbit = mv.getCameraOrbit();
          if (orbit && Math.abs(orbit.phi - Math.PI/2) > 0.01) {
            mv.cameraOrbit = orbit.theta + 'rad ' + (Math.PI/2) + 'rad ' + orbit.radius + 'm';
          }
        });
        observer.observe(mv, { attributes: true, attributeFilter: ['camera-orbit'] });
      };

      const mv = document.querySelector('model-viewer');
      if (mv) {
        applyToMv(mv);
      } else {
        // Fallback: wait for it to appear
        const domObserver = new MutationObserver((_, obs) => {
          const el = document.querySelector('model-viewer');
          if (el) { obs.disconnect(); applyToMv(el); }
        });
        domObserver.observe(document.body, { childList: true, subtree: true });
      }
    })();
  ''';

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ModelViewer(
        src: widget.modelPath,
        alt: '',

        // Controls ON so swipe works; cursor hidden via JS + CSS
        cameraControls: true,

        // Lock vertical
        cameraOrbit: '0deg 90deg 3m',
        minCameraOrbit: 'auto 90deg auto',
        maxCameraOrbit: 'auto 90deg auto',

        // Auto-rotate
        autoRotate: true,
        autoRotateDelay: 0, // resume instantly after swipe
        rotationPerSecond: '${_speed}deg',

        exposure: 1.4,
        backgroundColor: Colors.transparent,
        ar: false,
        arModes: const [],
        shadowIntensity: 0.3,

        onWebViewCreated: (controller) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            controller.runJavaScript(_js);
          });
        },
      ),
    );
  }
}
