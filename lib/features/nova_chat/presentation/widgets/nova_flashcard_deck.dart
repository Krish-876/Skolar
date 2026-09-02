import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/features/nova_chat/domain/entities/chat_message_entity.dart';

import 'package:Skolar/features/nova_chat/presentation/widgets/nova_fullscreen_modal.dart';

class NovaFlashcardDeck extends StatefulWidget {
  final FlashcardEntity deck;
  final bool isFullScreen;

  const NovaFlashcardDeck({
    super.key,
    required this.deck,
    this.isFullScreen = false,
  });

  @override
  State<NovaFlashcardDeck> createState() => _NovaFlashcardDeckState();
}

class _NovaFlashcardDeckState extends State<NovaFlashcardDeck> {
  int _cardIndex = 0;
  bool _isFlipped = false;

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _nextCard() {
    if (_cardIndex < widget.deck.cards.length - 1) {
      setState(() {
        _cardIndex++;
        _isFlipped = false;
      });
    }
  }

  void _prevCard() {
    if (_cardIndex > 0) {
      setState(() {
        _cardIndex--;
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.deck.cards;
    if (cards.isEmpty) return const SizedBox.shrink();
    final currentCard = cards[_cardIndex];

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF29B6F6).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.style_rounded,
                        color: Color(0xFF29B6F6),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.deck.title,
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
              Text(
                '${_cardIndex + 1} / ${cards.length}',
                style: GoogleFonts.googleSans(
                  color: const Color(0xFFC0BCDA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!widget.isFullScreen) ...[
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Full screen',
                  onPressed: () {
                    NovaFullScreenModal.show(
                      context,
                      title: widget.deck.title,
                      subtitle: 'Flashcard Deck (${cards.length} cards)',
                      child: NovaFlashcardDeck(deck: widget.deck, isFullScreen: true),
                    );
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // 3D Flip Card Container
          GestureDetector(
            onTap: _flipCard,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                final isUnder = (val >= 90);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateY((val * pi) / 180),
                  child: isUnder
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: _buildBackCard(currentCard),
                        )
                      : _buildFrontCard(currentCard),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Navigation Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _cardIndex > 0 ? _prevCard : null,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                color: _cardIndex > 0 ? Colors.white70 : Colors.white24,
              ),
              Text(
                'Tap card to flip',
                style: GoogleFonts.googleSans(
                  color: const Color(0xFF8C5BE8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                onPressed: _cardIndex < cards.length - 1 ? _nextCard : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: _cardIndex < cards.length - 1
                    ? Colors.white70
                    : Colors.white24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFrontCard(FlashcardItemEntity card) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8C5BE8).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'CONCEPT / FORMULA',
            style: GoogleFonts.googleSans(
              color: const Color(0xFF8C5BE8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            card.front,
            textAlign: TextAlign.center,
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(FlashcardItemEntity card) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF191724),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF29B6F6).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'DEFINITION & DETAILS',
            style: GoogleFonts.googleSans(
              color: const Color(0xFF29B6F6),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            card.back,
            textAlign: TextAlign.center,
            style: GoogleFonts.googleSans(
              color: const Color(0xFFE8E4F3),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (card.keyTakeaway != null && card.keyTakeaway!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                'Tip: ${card.keyTakeaway!}',
                style: GoogleFonts.googleSans(
                  color: const Color(0xFFFFD54F),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
