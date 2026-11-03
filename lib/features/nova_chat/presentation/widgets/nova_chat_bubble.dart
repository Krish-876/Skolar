import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';
import 'package:Skolar/features/nova_chat/domain/entities/study_plan_entity.dart';
import 'package:Skolar/features/nova_chat/presentation/providers/nova_chat_provider.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_flashcard_deck.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_practice_problem_card.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_proposal_card.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_quiz_card.dart';
import 'package:Skolar/features/nova_chat/presentation/widgets/nova_study_plan_card.dart';

class NovaChatBubble extends ConsumerWidget {
  final ChatMessageEntity message;
  final String? userAvatarSvg;

  const NovaChatBubble({super.key, required this.message, this.userAvatarSvg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: isUser
            ? _buildUserRow(context)
            : _buildAssistantRow(context, ref),
      ),
    );
  }

  Widget _buildUserRow(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8, left: 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF221F2D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: SelectableText(
          message.content,
          style: GoogleFonts.googleSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantRow(BuildContext context, WidgetRef ref) {
    final turnId = message.proposalTurnId;
    final proposals = message.pendingProposals;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolymorphicContent(context),
          if (turnId != null && proposals.isNotEmpty)
            NovaProposalCard(
              turnId: turnId,
              proposals: proposals,
              status: ref.watch(
                novaChatProvider.select((s) => s.statusForTurn(turnId)),
              ),
              onConfirm: () => ref
                  .read(novaChatProvider.notifier)
                  .resolveProposalTurn(turnId, confirm: true),
              onReject: () => ref
                  .read(novaChatProvider.notifier)
                  .resolveProposalTurn(turnId, confirm: false),
            ),
        ],
      ),
    );
  }

  Widget _buildPolymorphicContent(BuildContext context) {
    switch (message.responseType) {
      case NovaResponseType.quiz:
        if (message.structuredData is QuizEntity) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.content.isNotEmpty) ...[
                _buildStandardMessageBubble(message.content),
                const SizedBox(height: 12),
              ],
              NovaQuizCard(quiz: message.structuredData as QuizEntity),
            ],
          );
        }
        break;

      case NovaResponseType.plan:
        if (message.structuredData is StudyPlanEntity) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.content.isNotEmpty &&
                  !message.content.startsWith('**Here is your')) ...[
                _buildStandardMessageBubble(message.content),
                const SizedBox(height: 12),
              ],
              NovaStudyPlanCard(
                plan: message.structuredData as StudyPlanEntity,
              ),
            ],
          );
        }
        break;

      case NovaResponseType.flashcard:
        if (message.structuredData is FlashcardEntity) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.content.isNotEmpty) ...[
                _buildStandardMessageBubble(message.content),
                const SizedBox(height: 12),
              ],
              NovaFlashcardDeck(
                deck: message.structuredData as FlashcardEntity,
              ),
            ],
          );
        }
        break;

      case NovaResponseType.practiceProblem:
        if (message.structuredData is PracticeProblemEntity) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.content.isNotEmpty) ...[
                _buildStandardMessageBubble(message.content),
                const SizedBox(height: 12),
              ],
              NovaPracticeProblemCard(
                problem: message.structuredData as PracticeProblemEntity,
              ),
            ],
          );
        }
        break;

      case NovaResponseType.chat:
        break;
    }

    return _buildStandardMessageBubble(message.content);
  }

  Widget _buildStandardMessageBubble(String content) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.googleSans(
          color: const Color(0xFFECEBEE),
          fontSize: 15.5,
          height: 1.55,
        ),
        strong: GoogleFonts.googleSans(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        em: GoogleFonts.googleSans(
          color: const Color(0xFFA8C4FF),
          fontStyle: FontStyle.italic,
        ),
        h1: GoogleFonts.googleSans(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h2: GoogleFonts.googleSans(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h3: GoogleFonts.googleSans(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        code: GoogleFonts.googleSans(
          backgroundColor: const Color(0xFF181720),
          color: const Color(0xFFE2D6FF),
          fontSize: 13.5,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF181720),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        listBullet: GoogleFonts.googleSans(
          color: const Color(0xFFB388FF),
          fontSize: 15,
        ),
        listBulletPadding: const EdgeInsets.only(right: 6),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0xFF1C1A24),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: Color(0xFFB388FF), width: 3),
          ),
        ),
      ),
    );
  }
}
