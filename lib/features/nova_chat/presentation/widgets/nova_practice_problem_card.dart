import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';

import 'package:Skolar/features/nova_chat/presentation/widgets/nova_fullscreen_modal.dart';

class NovaPracticeProblemCard extends StatefulWidget {
  final PracticeProblemEntity problem;
  final bool isFullScreen;

  const NovaPracticeProblemCard({
    super.key,
    required this.problem,
    this.isFullScreen = false,
  });

  @override
  State<NovaPracticeProblemCard> createState() =>
      _NovaPracticeProblemCardState();
}

class _NovaPracticeProblemCardState extends State<NovaPracticeProblemCard> {
  int _revealedHintsCount = 0;
  bool _solutionRevealed = false;

  void _revealNextHint() {
    if (_revealedHintsCount < widget.problem.hints.length) {
      setState(() {
        _revealedHintsCount++;
      });
    }
  }

  void _toggleSolution() {
    setState(() {
      _solutionRevealed = !_solutionRevealed;
    });
  }

  Color _getDifficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':
        return const Color(0xFF66BB6A);
      case 'medium':
        return const Color(0xFFFFB74D);
      case 'hard':
      case 'advanced':
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFF8C5BE8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffColor = _getDifficultyColor(widget.problem.difficulty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16151D),
        borderRadius: widget.isFullScreen
            ? BorderRadius.circular(20)
            : const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calculate_rounded,
                  color: diffColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.problem.title,
                  style: GoogleFonts.googleSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: diffColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  widget.problem.difficulty,
                  style: GoogleFonts.googleSans(
                    color: diffColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!widget.isFullScreen) ...[
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Full screen',
                  onPressed: () {
                    NovaFullScreenModal.show(
                      context,
                      title: widget.problem.title,
                      subtitle:
                          '${widget.problem.topic} • ${widget.problem.difficulty}',
                      child: NovaPracticeProblemCard(
                        problem: widget.problem,
                        isFullScreen: true,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Problem Statement Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0D14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: SelectableText(
              widget.problem.problemStatement,
              style: GoogleFonts.googleSans(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Progressive Hints
          if (widget.problem.hints.isNotEmpty) ...[
            ...List.generate(_revealedHintsCount, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1926),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Color(0xFFFFB74D),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        'Hint ${index + 1}: ${widget.problem.hints[index]}',
                        style: GoogleFonts.googleSans(
                          color: const Color(0xFFFFE0B2),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (_revealedHintsCount < widget.problem.hints.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: _revealNextHint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reveal Hint (${_revealedHintsCount + 1}/${widget.problem.hints.length})',
                          style: GoogleFonts.googleSans(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],

          // Full Solution Toggle
          GestureDetector(
            onTap: _toggleSolution,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8C5BE8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8C5BE8).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _solutionRevealed ? 'Hide Solution' : 'View Full Solution',
                    style: GoogleFonts.googleSans(
                      color: const Color(0xFFD4C2FC),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _solutionRevealed
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFFD4C2FC),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          if (_solutionRevealed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF100F18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8C5BE8).withValues(alpha: 0.25),
                ),
              ),
              child: MarkdownBody(
                data: widget.problem.solution,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.googleSans(
                    color: const Color(0xFFE2DDF0),
                    fontSize: 14,
                    height: 1.45,
                  ),
                  strong: GoogleFonts.googleSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  code: GoogleFonts.googleSans(
                    backgroundColor: const Color(0xFF191824),
                    color: const Color(0xFFE2D6FF),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
