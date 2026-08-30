import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/subjects/domain/entities/subject_entity.dart';

// ── 2.5D Chunky Button ───────────────────────────────────────────────────

class ChunkyButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;
  final Color color;
  final Color textColor;
  final BoxBorder? border;
  final FontWeight fontWeight;
  final IconData? icon;
  final bool enabled;
  final double height;

  const ChunkyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.shadow,
    this.color = AppTheme.accentPurple,
    this.textColor = AppTheme.onPrimary,
    this.border,
    this.fontWeight = FontWeight.bold,
    this.icon,
    this.enabled = true,
    this.height = 54,
  });

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveShadow = widget.shadow ?? AppTheme.chunkyButtonShadow;
    final isInteractive = widget.enabled && widget.onTap != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: widget.enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTapDown: isInteractive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: isInteractive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: isInteractive ? () => setState(() => _pressed = false) : null,
        onTap: isInteractive ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: _pressed
              ? Matrix4.translationValues(0, 4, 0)
              : Matrix4.identity(),
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color,
            border: widget.border,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: (_pressed || !widget.enabled) ? [] : effectiveShadow,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: widget.textColor),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'GoogleSans',
                  color: widget.textColor,
                  fontWeight: widget.fontWeight,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Credit ring ───────────────────────────────────────────────────────────

class CreditRing extends StatelessWidget {
  final int earned;
  final int target;
  const CreditRing({super.key, required this.earned, required this.target});

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (earned / target).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: RingPainter(progress: progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$earned',
                style: GoogleFonts.googleSans(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                target > 0 ? 'of $target cr' : 'credits',
                style: GoogleFonts.googleSans(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final double progress;
  RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 12.0;
    const startAngle = -pi / 2;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final arcPaint = Paint()
      ..color = AppTheme.accentPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(RingPainter old) => old.progress != progress;
}

// ── Subject row ───────────────────────────────────────────────────────────

class SubjectRow extends StatelessWidget {
  final SubjectEntity subject;
  final bool editMode;
  final bool marked;
  final bool uploading;
  final String? stagedFilename;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPickHandout;
  final VoidCallback? onUnstageHandout;
  final VoidCallback? onDelete;
  final int index;

  const SubjectRow({
    super.key,
    required this.subject,
    required this.editMode,
    required this.marked,
    required this.uploading,
    required this.onLongPress,
    this.stagedFilename,
    this.onTap,
    this.onPickHandout,
    this.onUnstageHandout,
    this.onDelete,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasHandout = subject.handoutUrl != null;

    final rowCard = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: marked
              ? AppTheme.wishlist.withValues(alpha: 0.14)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: marked
                ? AppTheme.wishlist.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: marked ? 1.5 : 1.0,
          ),
          boxShadow: marked
              ? [
                  BoxShadow(
                    color: AppTheme.wishlist.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (editMode) ...[
                  Icon(
                    marked
                        ? Icons.remove_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: marked
                        ? AppTheme.wishlist
                        : AppTheme.onBackground2.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: AppTheme.sm),
                ],
                Expanded(
                  child: Text(
                    subject.name,
                    style: GoogleFonts.googleSans(
                      fontSize: 15,
                      fontWeight: marked ? FontWeight.bold : FontWeight.w600,
                      color: marked ? AppTheme.wishlist : Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subject.shortName != null) ...[
                  const SizedBox(width: AppTheme.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      subject.shortName!,
                      style: GoogleFonts.googleSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentPurple,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppTheme.md),
                Text(
                  subject.credits != null ? '${subject.credits} cr' : '— cr',
                  style: GoogleFonts.googleSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: marked ? AppTheme.wishlist : Colors.white70,
                  ),
                ),
              ],
            ),
            if (!editMode) ...[
              const SizedBox(height: 12),
              HandoutChip(
                hasHandout: hasHandout,
                filename: subject.handoutFilename,
                uploading: uploading,
                stagedFilename: stagedFilename,
                onPick: onPickHandout,
                onUnstage: onUnstageHandout,
              ),
            ],
          ],
        ),
      ),
    );

    final animatedChild = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: rowCard,
    );

    if (editMode || onDelete == null) {
      return animatedChild;
    }

    return Dismissible(
      key: Key('subject_${subject.userSubjectId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete',
              style: GoogleFonts.googleSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete?.call();
      },
      child: animatedChild,
    );
  }
}

// ── Handout chip ──────────────────────────────────────────────────────────

class HandoutChip extends StatelessWidget {
  final bool hasHandout;
  final String? filename;
  final bool uploading;
  final String? stagedFilename;
  final VoidCallback? onPick;
  final VoidCallback? onUnstage;

  const HandoutChip({
    super.key,
    required this.hasHandout,
    required this.uploading,
    this.filename,
    this.stagedFilename,
    this.onPick,
    this.onUnstage,
  });

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white54,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Generating plan…',
            style: GoogleFonts.googleSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white60,
            ),
          ),
        ],
      );
    }

    if (stagedFilename != null) {
      return GestureDetector(
        onTap: onUnstage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.wishlist.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            border: Border.all(
              color: AppTheme.wishlist.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 13,
                color: AppTheme.wishlist.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$stagedFilename (queued)',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.googleSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.wishlist.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.close_rounded,
                size: 13,
                color: AppTheme.wishlist.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: hasHandout
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(
            color: hasHandout
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasHandout
                  ? Icons.description_rounded
                  : Icons.upload_file_rounded,
              size: 13,
              color: hasHandout ? AppTheme.accentPurple : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              hasHandout
                  ? '${filename ?? 'Handout uploaded'}  ↺'
                  : 'Upload handout',
              style: GoogleFonts.googleSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: hasHandout ? AppTheme.accentPurple : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Credit target sheet ───────────────────────────────────────────────────

class CreditTargetSheet extends StatefulWidget {
  final ValueChanged<int> onConfirm;
  const CreditTargetSheet({super.key, required this.onConfirm});

  @override
  State<CreditTargetSheet> createState() => _CreditTargetSheetState();
}

class _CreditTargetSheetState extends State<CreditTargetSheet> {
  final _ctrl = TextEditingController();
  bool get _valid =>
      int.tryParse(_ctrl.text.trim()) != null &&
      int.parse(_ctrl.text.trim()) > 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.lg,
          AppTheme.lg,
          AppTheme.lg,
          AppTheme.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppTheme.lg),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Credits this semester',
              style: GoogleFonts.googleSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How many total credits are you registered for?',
              style: GoogleFonts.googleSans(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: AppTheme.lg),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.googleSans(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              cursorColor: AppTheme.accentPurple,
              decoration: InputDecoration(
                hintText: '25',
                hintStyle: GoogleFonts.googleSans(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white24,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.only(bottom: AppTheme.sm),
              ),
            ),
            const SizedBox(height: AppTheme.xl),
            ChunkyButton(
              label: 'Set Target',
              enabled: _valid,
              onTap: _valid
                  ? () {
                      Navigator.pop(context);
                      widget.onConfirm(int.parse(_ctrl.text.trim()));
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add subject sheet ─────────────────────────────────────────────────────

class AddSubjectSheet extends StatefulWidget {
  final int? remainingCredits;
  final Future<String?> Function(String name, String courseCode, int credits)
  onConfirm;

  const AddSubjectSheet({
    super.key,
    required this.onConfirm,
    this.remainingCredits,
  });

  @override
  State<AddSubjectSheet> createState() => _AddSubjectSheetState();
}

class _AddSubjectSheetState extends State<AddSubjectSheet> {
  final _nameCtrl = TextEditingController();
  final _shortNameCtrl = TextEditingController();
  final _creditsCtrl = TextEditingController();

  String? _error;
  bool _submitting = false;

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _shortNameCtrl.text.trim().isNotEmpty &&
      int.tryParse(_creditsCtrl.text.trim()) != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortNameCtrl.dispose();
    _creditsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final credits = int.parse(_creditsCtrl.text.trim());

    if (widget.remainingCredits != null && credits > widget.remainingCredits!) {
      setState(
        () => _error =
            'Only ${widget.remainingCredits} credits remaining this semester',
      );
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final err = await widget.onConfirm(
      _nameCtrl.text.trim(),
      _shortNameCtrl.text.trim(),
      credits,
    );

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
        _submitting = false;
      });
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.lg,
          AppTheme.lg,
          AppTheme.lg,
          AppTheme.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppTheme.lg),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add Subject',
              style: GoogleFonts.googleSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.remainingCredits != null) ...[
              const SizedBox(height: AppTheme.xs),
              Text(
                widget.remainingCredits! > 0
                    ? '${widget.remainingCredits} credits remaining this semester'
                    : 'Credit limit reached',
                style: GoogleFonts.googleSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.remainingCredits! > 0
                      ? Colors.white54
                      : AppTheme.wishlist,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.lg),
            SheetField(
              controller: _nameCtrl,
              label: 'Subject Name',
              hint: 'e.g. Artificial Intelligence',
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppTheme.md),
            SheetField(
              controller: _shortNameCtrl,
              label: 'Course Code',
              hint: 'e.g. CS F441',
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: AppTheme.md),
            SheetField(
              controller: _creditsCtrl,
              label: 'Credits',
              hint: 'e.g. 3',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.none,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.sm),
              Text(
                _error!,
                style: GoogleFonts.googleSans(
                  fontSize: 12,
                  color: AppTheme.wishlist,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.xl),
            ChunkyButton(
              label: _submitting ? 'Adding...' : 'Add Subject',
              enabled: _valid && !_submitting,
              onTap: (_valid && !_submitting) ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared field widget ───────────────────────────────────────────────────

class SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String> onChanged;
  final TextCapitalization textCapitalization;

  const SheetField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
    required this.textCapitalization,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.googleSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.googleSans(color: Colors.white, fontSize: 15),
          cursorColor: AppTheme.accentPurple,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.googleSans(
              color: Colors.white24,
              fontSize: 15,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accentPurple, width: 1.8),
            ),
            contentPadding: const EdgeInsets.only(bottom: 6),
          ),
        ),
      ],
    );
  }
}
