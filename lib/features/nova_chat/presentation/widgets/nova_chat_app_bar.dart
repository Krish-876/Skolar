import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/auth/presentation/widgets/mascot_state.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_thinking_indicator.dart';

class NovaChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isBackendOnline;
  final bool isThinking;
  final VoidCallback onClearChat;
  final String title;
  final MascotState mascotState;

  const NovaChatAppBar({
    super.key,
    required this.isBackendOnline,
    required this.isThinking,
    required this.onClearChat,
    this.mascotState = MascotState.idle,
    this.title = 'skolar',
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final activeMascotState = isThinking
        ? MascotState.watchingEmail
        : mascotState;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            // High transparency glassmorphism so chat bubbles visibly leak through
            color: Colors.black.withValues(alpha: 0.35),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 2),

                  // Mascot Avatar Badge
                  NovaMascotAvatar(size: 36, state: activeMascotState),
                  const SizedBox(width: 12),

                  // Title in Google Sans, centered in the bar — "skolar."
                  // with the brand purple full stop, matching the period
                  // accent used on the onboarding welcome buttons.
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: GoogleFonts.googleSans(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            children: [
                              TextSpan(text: title),
                              const TextSpan(
                                text: '.',
                                style: TextStyle(color: AppTheme.accentPurple),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isThinking) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Thinking...',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.googleSans(
                              color: const Color(0xFF8C5BE8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 3-dots Menu Button
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    color: const Color(0xFF1E1E24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'clear') {
                        onClearChat();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cleaning_services_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Clear conversation',
                              style: GoogleFonts.googleSans(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
