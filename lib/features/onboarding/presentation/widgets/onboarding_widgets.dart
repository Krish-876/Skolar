import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:Skolar/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuestionStep — animated entrance wrapper for each onboarding question.
// Re-triggers animation whenever [key] changes (swap key on step change).
// ─────────────────────────────────────────────────────────────────────────────

class QuestionStep extends StatefulWidget {
  final String question;
  final String? hint;
  final Widget child;

  const QuestionStep({
    super.key,
    required this.question,
    this.hint,
    required this.child,
  });

  @override
  State<QuestionStep> createState() => _QuestionStepState();
}

class _QuestionStepState extends State<QuestionStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.question,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.onBackground,
                height: 1.3,
              ),
            ),
            if (widget.hint != null) ...[
              const SizedBox(height: AppTheme.xs),
              Text(
                widget.hint!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onBackground2,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.xl),
            widget.child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SelectableChip — pill with gradient glow when selected.
// ─────────────────────────────────────────────────────────────────────────────

class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withOpacity(0.12),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGradBegin.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.onPrimary : AppTheme.onBackground2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChipGrid — single-select Wrap of SelectableChips.
// ─────────────────────────────────────────────────────────────────────────────

class ChipGrid extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const ChipGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.sm,
      runSpacing: AppTheme.sm,
      children: options
          .map(
            (o) => SelectableChip(
              label: o,
              selected: selected == o,
              onTap: () => onSelected(o),
            ),
          )
          .toList(),
    );
  }
}
