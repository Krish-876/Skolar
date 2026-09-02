import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/features/mock_tests/domain/entities/mock_test_entity.dart';
import 'package:Skolar/features/mock_tests/presentation/pages/mock_tests_pages.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';

class NovaQuizCard extends StatefulWidget {
  final QuizEntity quiz;
  final bool isFullScreen;

  const NovaQuizCard({
    super.key,
    required this.quiz,
    this.isFullScreen = false,
  });

  @override
  State<NovaQuizCard> createState() => _NovaQuizCardState();
}

class _NovaQuizCardState extends State<NovaQuizCard> {
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _answered = false;
  int _score = 0;
  bool _quizFinished = false;

  void _handleOptionSelect(int index) {
    if (_answered) return;
    setState(() {
      _selectedOptionIndex = index;
      _answered = true;
      if (index == widget.quiz.questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.quiz.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _answered = false;
      });
    } else {
      setState(() {
        _quizFinished = true;
      });
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _selectedOptionIndex = null;
      _answered = false;
      _score = 0;
      _quizFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quiz.questions;
    if (questions.isEmpty) return const SizedBox.shrink();

    if (_quizFinished) {
      return _buildScoreSummary(context);
    }

    final currentQ = questions[_currentIndex];

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
          // Header Row: Quiz Badge, Title (No overflow), Stepper & Fullscreen Trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8C5BE8).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.quiz_rounded,
                        color: Color(0xFF8C5BE8),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.quiz.title,
                        style: GoogleFonts.googleSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${questions.length}',
                  style: GoogleFonts.googleSans(
                    color: const Color(0xFFC0BCDA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                  tooltip: 'Full screen test',
                  onPressed: () {
                    final quizQuestions = widget.quiz.questions.map((q) {
                      return QuizQuestion(
                        question: q.question,
                        options: q.options,
                        correctIndex: q.correctIndex,
                        subject: widget.quiz.title,
                        marks: 4,
                      );
                    }).toList();

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => McqQuizFlow(
                          questions: quizQuestions,
                          onRestart: () => Navigator.maybePop(context),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Question Prompt
          SelectableText(
            currentQ.question,
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          // Options List with 2.5D Tactile Buttons
          ...List.generate(currentQ.options.length, (optIndex) {
            final optionText = currentQ.options[optIndex];
            return _QuizOptionTile(
              label: optionText,
              index: optIndex,
              isSelected: _selectedOptionIndex == optIndex,
              isCorrect: currentQ.correctIndex == optIndex,
              answered: _answered,
              onTap: () => _handleOptionSelect(optIndex),
            );
          }),

          // Explanation Box (Appears after answer is selected)
          if (_answered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0D14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedOptionIndex == currentQ.correctIndex
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                      : const Color(0xFFFF5252).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedOptionIndex == currentQ.correctIndex
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        color: _selectedOptionIndex == currentQ.correctIndex
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFFAB40),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedOptionIndex == currentQ.correctIndex
                            ? "Correct!"
                            : "Explanation",
                        style: GoogleFonts.googleSans(
                          color: _selectedOptionIndex == currentQ.correctIndex
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFFAB40),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    currentQ.explanation,
                    style: GoogleFonts.googleSans(
                      color: const Color(0xFFD0CBDD),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Next / Finish Button
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _nextQuestion,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8C5BE8),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF5A2DA3),
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentIndex < questions.length - 1
                            ? 'Next Question'
                            : 'View Results',
                        style: GoogleFonts.googleSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreSummary(BuildContext context) {
    final total = widget.quiz.questions.length;
    final percentage = (total > 0) ? (_score / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16151D),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
        ),
        border: Border.all(
          color: const Color(0xFF8C5BE8).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8C5BE8).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFD54F),
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Quiz Completed!',
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You scored $_score out of $total ($percentage%)',
            style: GoogleFonts.googleSans(
              color: const Color(0xFFC5BFDB),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _restartQuiz,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF22202E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizOptionTile extends StatefulWidget {
  final String label;
  final int index;
  final bool isSelected;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  const _QuizOptionTile({
    required this.label,
    required this.index,
    required this.isSelected,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  @override
  State<_QuizOptionTile> createState() => _QuizOptionTileState();
}

class _QuizOptionTileState extends State<_QuizOptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFF0F0E16);
    Color border = Colors.white.withValues(alpha: 0.08);
    Color textColor = Colors.white;

    if (widget.answered) {
      if (widget.isCorrect) {
        bg = const Color(0xFF1E3A24);
        border = const Color(0xFF4CAF50);
        textColor = const Color(0xFFB9F6CA);
      } else if (widget.isSelected && !widget.isCorrect) {
        bg = const Color(0xFF3B1E22);
        border = const Color(0xFFFF5252);
        textColor = const Color(0xFFFFCDD2);
      }
    }

    final letter = String.fromCharCode(65 + widget.index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTapDown: widget.answered
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.answered
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: widget.answered
            ? null
            : () => setState(() => _pressed = false),
        onTap: widget.answered ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: _pressed
              ? Matrix4.translationValues(0, 2, 0)
              : Matrix4.identity(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.2),
            boxShadow: _pressed || widget.answered
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: GoogleFonts.googleSans(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.googleSans(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
