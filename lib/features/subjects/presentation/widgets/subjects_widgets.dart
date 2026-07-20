import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/subjects/domain/entities/subject_entity.dart';

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
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onBackground,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                target > 0 ? 'of $target cr' : 'credits',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onBackground2,
                  fontWeight: FontWeight.w400,
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
      ..color = AppTheme.surfaceLight.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final arcPaint = Paint()
      ..color = AppTheme.onBackground
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
  });

  @override
  Widget build(BuildContext context) {
    final hasHandout = subject.handoutUrl != null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        decoration: BoxDecoration(
          color: marked
              ? AppTheme.wishlist.withValues(alpha: 0.12)
              : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: marked
                ? AppTheme.wishlist.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.09),
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
                    size: 18,
                    color: marked
                        ? AppTheme.wishlist
                        : AppTheme.onBackground2.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: AppTheme.sm),
                ],
                Expanded(
                  child: Text(
                    subject.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: marked ? AppTheme.wishlist : AppTheme.onBackground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subject.shortName != null) ...[
                  const SizedBox(width: AppTheme.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      subject.shortName!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBackground2,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppTheme.md),
                Text(
                  subject.credits != null ? '${subject.credits} cr' : '— cr',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: marked ? AppTheme.wishlist : AppTheme.onBackground2,
                  ),
                ),
              ],
            ),
            if (!editMode) ...[
              const SizedBox(height: 10),
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
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppTheme.onBackground2.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Generating plan…',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.onBackground2.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    if (stagedFilename != null) {
      return GestureDetector(
        onTap: onUnstage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.wishlist.withValues(alpha: 0.12),
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
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '$stagedFilename (queued)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.wishlist.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(width: 5),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasHandout
              ? const Color(0xFFD4A5FF).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(
            color: hasHandout
                ? const Color(0xFFD4A5FF).withValues(alpha: 0.4)
                : AppTheme.onBackground2.withValues(alpha: 0.2),
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
              color: hasHandout
                  ? const Color(0xFFD4A5FF)
                  : AppTheme.onBackground2.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 5),
            Text(
              hasHandout
                  ? '${filename ?? 'Handout uploaded'}  ↺'
                  : 'Upload handout',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: hasHandout
                    ? const Color(0xFFD4A5FF)
                    : AppTheme.onBackground2.withValues(alpha: 0.6),
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
          color: AppTheme.bgGradBegin,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: AppTheme.onBackground2.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Credits this semester',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBackground,
              ),
            ),
            const SizedBox(height: AppTheme.xs),
            const Text(
              'How many total credits are you registered for?',
              style: TextStyle(fontSize: 13, color: AppTheme.onBackground2),
            ),
            const SizedBox(height: AppTheme.lg),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBackground,
              ),
              cursorColor: AppTheme.onBackground2,
              decoration: InputDecoration(
                hintText: '25',
                hintStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onBackground2.withValues(alpha: 0.3),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.onBackground2.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.onBackground2,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.only(bottom: AppTheme.sm),
              ),
            ),
            const SizedBox(height: AppTheme.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AnimatedOpacity(
                opacity: _valid ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  ),
                  child: ElevatedButton(
                    onPressed: _valid
                        ? () {
                            Navigator.pop(context);
                            widget.onConfirm(int.parse(_ctrl.text.trim()));
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: AppTheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                      ),
                    ),
                    child: const Text(
                      'Set',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
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
          color: AppTheme.bgGradBegin,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: AppTheme.onBackground2.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Add Subject',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBackground,
              ),
            ),
            if (widget.remainingCredits != null) ...[
              const SizedBox(height: AppTheme.xs),
              Text(
                widget.remainingCredits! > 0
                    ? '${widget.remainingCredits} credits remaining this semester'
                    : 'Credit limit reached',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.remainingCredits! > 0
                      ? AppTheme.onBackground2
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
            ),
            const SizedBox(height: AppTheme.md),
            SheetField(
              controller: _shortNameCtrl,
              label: 'Course Code',
              hint: 'e.g. CS F441',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppTheme.md),
            SheetField(
              controller: _creditsCtrl,
              label: 'Credits',
              hint: 'e.g. 3',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.sm),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.wishlist,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AnimatedOpacity(
                opacity: (_valid && !_submitting) ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  ),
                  child: ElevatedButton(
                    onPressed: (_valid && !_submitting) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: AppTheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.onPrimary,
                            ),
                          )
                        : const Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
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

  const SheetField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.onBackground2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: AppTheme.onBackground, fontSize: 15),
          cursorColor: AppTheme.onBackground2,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppTheme.onBackground2.withValues(alpha: 0.4),
              fontSize: 15,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.onBackground2.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.onBackground2, width: 1.8),
            ),
            contentPadding: const EdgeInsets.only(bottom: 6),
          ),
        ),
      ],
    );
  }
}
