/// lib/features/dashboard/presentation/widgets/bookshelf_banner.dart
///
/// Gradient pill banner that navigates to the BookShelf feature.
/// Pass [onTap] to wire navigation; defaults to a snackbar placeholder.
library;

import 'package:flutter/material.dart';

class BookShelfBanner extends StatefulWidget {
  final VoidCallback? onTap;

  const BookShelfBanner({super.key, this.onTap});

  @override
  State<BookShelfBanner> createState() => _BookShelfBannerState();
}

class _BookShelfBannerState extends State<BookShelfBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _hover;

  @override
  void initState() {
    super.initState();
    _hover = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BookShelf – coming soon')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hover.reverse(),
      onTapUp: (_) {
        _hover.forward();
        _handleTap();
      },
      onTapCancel: () => _hover.forward(),
      child: ScaleTransition(
        scale: _hover,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD0D8FF), Color(0xFF8B9FE8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFAA8FFF).withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Text(
                'Book Shelf',
                style: TextStyle(
                  color: Color(0xFF1A1A3E),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF1A1A3E),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}