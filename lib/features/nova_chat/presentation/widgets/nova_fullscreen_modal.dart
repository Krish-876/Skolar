import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaFullScreenModal extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const NovaFullScreenModal({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, anim, _) {
          return FadeTransition(
            opacity: anim,
            child: NovaFullScreenModal(
              title: title,
              subtitle: subtitle,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient Glow
          Positioned(
            top: 40,
            right: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF9153DE).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header with Close Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Close full screen',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.googleSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: GoogleFonts.googleSans(
                                  color: const Color(0xFFA5A3B8),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Color(0xFF22202E), height: 1),

                // Expanded Interactive Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
