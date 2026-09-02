import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';
import 'package:Skolar/features/nova_chat/domain/entities/study_plan_entity.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_study_plan_card.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_thinking_indicator.dart';
import 'package:Skolar/shared/components/framed_avatar.dart';

class NovaChatBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final String? userAvatarSvg;

  const NovaChatBubble({
    super.key,
    required this.message,
    this.userAvatarSvg,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: isUser ? _buildUserRow(context) : _buildAssistantRow(context),
      ),
    );
  }

  Widget _buildUserRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(left: 48, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              // Solid lighter purple (no gradient) as requested
              color: const Color(0xFF8C5BE8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8C5BE8).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SelectableText(
              message.content,
              style: GoogleFonts.googleSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.normal,
                height: 1.4,
              ),
            ),
          ),
        ),

        // User SVG Avatar at the bottom-right
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _buildUserAvatar(),
        ),
      ],
    );
  }

  Widget _buildAssistantRow(BuildContext context) {
    final hasStructuredPlan = message.structuredData is StudyPlanEntity;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Nova Mascot Avatar on the bottom-left
        const Padding(
          padding: EdgeInsets.only(bottom: 2, right: 8),
          child: NovaMascotAvatar(size: 26),
        ),

        Flexible(
          child: Container(
            margin: const EdgeInsets.only(right: 24),
            padding: hasStructuredPlan
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              // Glassmorphic dark card matching screenshot
              color: const Color(0xFF1E1E26).withValues(alpha: 0.9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: hasStructuredPlan
                ? NovaStudyPlanCard(
                    plan: message.structuredData as StudyPlanEntity,
                  )
                : MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.googleSans(
                        color: const Color(0xFFF3F2F7),
                        fontSize: 15,
                        height: 1.45,
                      ),
                      strong: GoogleFonts.googleSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      em: GoogleFonts.googleSans(
                        color: const Color(0xFFA8C4FF),
                        fontStyle: FontStyle.italic,
                      ),
                      code: GoogleFonts.googleSans(
                        backgroundColor: const Color(0xFF14131A),
                        color: const Color(0xFFE2D6FF),
                        fontSize: 13.5,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF14131A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      listBullet: GoogleFonts.googleSans(
                        color: const Color(0xFF8C5BE8),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar() {
    if (userAvatarSvg != null && userAvatarSvg!.isNotEmpty) {
      return FramedAvatar(
        size: 26,
        svgString: userAvatarSvg!,
        backgroundColor: Colors.transparent,
      );
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2B36),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white70,
          size: 15,
        ),
      ),
    );
  }
}
