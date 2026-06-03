import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_datasource.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_dto.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_provider.dart'
    show examPredictionDataSourceProvider;
import 'package:Skolar/shared/providers/global_providers.dart' show userProvider;

// ── Theme constants (mirrors mock_test_page) ──────────────────────────────────

const _surface = Color(0xFF2E2B3E);
const _textPrim = Color(0xFFFFFFFF);
const _textSec  = Color(0xFFA8C4FF);
const _correct  = Color(0xFF4CAF50);

// ── Per-file state ────────────────────────────────────────────────────────────

enum _FileStatus { pending, uploading, done, error }

class _FileItem {
  final String fileName;
  final String filePath;
  final _FileStatus status;
  final int questionsAdded;
  final String? error;

  const _FileItem({
    required this.fileName,
    required this.filePath,
    this.status = _FileStatus.pending,
    this.questionsAdded = 0,
    this.error,
  });

  _FileItem copyWith({
    _FileStatus? status,
    int? questionsAdded,
    String? error,
    bool clearError = false,
  }) =>
      _FileItem(
        fileName: fileName,
        filePath: filePath,
        status: status ?? this.status,
        questionsAdded: questionsAdded ?? this.questionsAdded,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Upload batch state ────────────────────────────────────────────────────────

class _UploadBatchState {
  final List<_FileItem> files;
  final bool isUploading;
  final bool isDone;

  const _UploadBatchState({
    this.files = const [],
    this.isUploading = false,
    this.isDone = false,
  });

  int get totalAdded => files.fold(0, (sum, f) => sum + f.questionsAdded);
  int get doneCount  => files.where((f) => f.status == _FileStatus.done).length;
  int get errorCount => files.where((f) => f.status == _FileStatus.error).length;

  _UploadBatchState copyWith({
    List<_FileItem>? files,
    bool? isUploading,
    bool? isDone,
  }) =>
      _UploadBatchState(
        files: files ?? this.files,
        isUploading: isUploading ?? this.isUploading,
        isDone: isDone ?? this.isDone,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class _UploadBatchNotifier extends Notifier<_UploadBatchState> {
  @override
  _UploadBatchState build() => const _UploadBatchState();

  void addFiles(List<PlatformFile> picked) {
    final existingNames = state.files.map((f) => f.fileName).toSet();
    final newItems = picked
        .where((p) => !existingNames.contains(p.name) && p.path != null)
        .map((p) => _FileItem(fileName: p.name, filePath: p.path!))
        .toList();
    if (newItems.isEmpty) return;
    state = state.copyWith(files: [...state.files, ...newItems]);
  }

  void removeFile(int index) {
    final updated = [...state.files]..removeAt(index);
    state = state.copyWith(files: updated);
  }

  void reset() => state = const _UploadBatchState();

  Future<void> uploadAll({
    required String subject,
    required int paperYear,
    required String examType,
    required String college,
    required ExamPredictionRemoteDataSource dataSource,
  }) async {
    if (state.isUploading) return;
    state = state.copyWith(isUploading: true, isDone: false);

    final reset = state.files
        .map((f) => f.status == _FileStatus.error
            ? f.copyWith(status: _FileStatus.pending, clearError: true)
            : f)
        .toList();
    state = state.copyWith(files: reset);

    for (int i = 0; i < state.files.length; i++) {
      if (state.files[i].status == _FileStatus.done) continue;

      final uploading = [...state.files];
      uploading[i] = uploading[i].copyWith(status: _FileStatus.uploading);
      state = state.copyWith(files: uploading);

      try {
        final UploadResultDto result = await dataSource.uploadPyq(
          filePath: state.files[i].filePath,
          subject: subject,
          paperYear: paperYear,      // was: year: year
          examType: examType,
          college: college,
        );
        final done = [...state.files];
        done[i] = done[i].copyWith(
          status: _FileStatus.done,
          questionsAdded: result.added,
          clearError: true,
        );
        state = state.copyWith(files: done);
      } catch (e) {
        final errored = [...state.files];
        errored[i] = errored[i].copyWith(
          status: _FileStatus.error,
          error: _friendlyError(e.toString()),
        );
        state = state.copyWith(files: errored);
      }
    }

    state = state.copyWith(isUploading: false, isDone: true);
  }

  String _friendlyError(String raw) {
    if (raw.contains('422')) return 'No questions found in PDF.';
    if (raw.contains('400')) return 'Invalid file or missing fields.';
    if (raw.contains('SocketException') || raw.contains('Connection')) {
      return 'Could not reach server. Check your connection.';
    }
    return 'Upload failed.';
  }
}

final _uploadBatchProvider =
    NotifierProvider<_UploadBatchNotifier, _UploadBatchState>(
  _UploadBatchNotifier.new,
);

// ── Page ──────────────────────────────────────────────────────────────────────

class PyqUploadPage extends ConsumerStatefulWidget {
  const PyqUploadPage({super.key});

  @override
  ConsumerState<PyqUploadPage> createState() => _PyqUploadPageState();
}

class _PyqUploadPageState extends ConsumerState<PyqUploadPage> {
  final _subjectController = TextEditingController();
  final _yearController =
      TextEditingController(text: DateTime.now().year.toString());
  String _selectedExamType = 'compre';

  static const _examTypes = ['quiz1', 'midsem', 'quiz2', 'compre', 'generated'];

  @override
  void dispose() {
    _subjectController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result != null) {
      ref.read(_uploadBatchProvider.notifier).addFiles(result.files);
    }
  }

  void _startUpload() {
    final subject = _subjectController.text.trim();
    final year = int.tryParse(_yearController.text.trim());

    if (subject.isEmpty) { _snack('Please enter a subject.'); return; }
    if (year == null || year < 1990 || year > DateTime.now().year + 1) {
      _snack('Please enter a valid year.'); return;
    }
    if (ref.read(_uploadBatchProvider).files.isEmpty) {
      _snack('Please select at least one PDF.'); return;
    }

    final college = ref.read(userProvider).college;
    final dataSource = ref.read(examPredictionDataSourceProvider);

    ref.read(_uploadBatchProvider.notifier).uploadAll(
      subject: subject,
      paperYear: year,
      examType: _selectedExamType,
      college: college,
      dataSource: dataSource,
    );
  }

  void _snack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: _textPrim)),
          backgroundColor: AppTheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(_uploadBatchProvider);
    final pendingCount = batch.files.where((f) => f.status != _FileStatus.done).length;
    final college = ref.watch(userProvider).college;
    final disabled = batch.isUploading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textSec, size: 18),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Upload PYQs',
                      style: GoogleFonts.googleSansFlex(
                          fontSize: 22, fontWeight: FontWeight.w700, color: _textPrim)),
                ),
                if (batch.files.isNotEmpty && !batch.isUploading)
                  GestureDetector(
                    onTap: () => ref.read(_uploadBatchProvider.notifier).reset(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_sweep_rounded, color: AppTheme.error, size: 14),
                        SizedBox(width: 5),
                        Text('Clear', style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text('Add previous year papers to the question bank',
                  style: GoogleFonts.googleSans(color: _textSec, fontSize: 13)),
            ),
            const SizedBox(height: 20),
      
            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  // College chip
                  _CollegeChip(college: college),
                  const SizedBox(height: 16),
      
                  // Subject field
                  _GlassField(
                    controller: _subjectController,
                    enabled: !disabled,
                    label: 'Subject',
                    hint: 'e.g. Artificial Intelligence',
                    icon: Icons.book_outlined,
                  ),
                  const SizedBox(height: 12),
      
                  // Year + Exam type row
                  Row(children: [
                    Expanded(
                      child: _GlassField(
                        controller: _yearController,
                        enabled: !disabled,
                        label: 'Year',
                        hint: '2024',
                        icon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _ExamTypeDropdown(
                      value: _selectedExamType,
                      items: _examTypes,
                      enabled: !disabled,
                      onChanged: (v) => setState(() => _selectedExamType = v!),
                    )),
                  ]),
                  const SizedBox(height: 20),
      
                  // Pick files button
                  _PickFilesButton(
                    isEmpty: batch.files.isEmpty,
                    disabled: disabled,
                    onTap: _pickFiles,
                  ),
      
                  // File list
                  if (batch.files.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Overall progress row
                    if (batch.isUploading || batch.isDone)
                      _ProgressHeader(batch: batch),
                    const SizedBox(height: 12),
                    ...batch.files.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileCard(
                        item: e.value,
                        index: e.key,
                        total: batch.files.length,
                        onRemove: disabled ? null
                            : () => ref.read(_uploadBatchProvider.notifier).removeFile(e.key),
                      ),
                    )),
                    const SizedBox(height: 8),
      
                    // Upload button
                    _UploadButton(
                      disabled: disabled,
                      pendingCount: pendingCount,
                      onTap: _startUpload,
                    ),
                  ],
      
                  // Summary
                  if (batch.isDone) ...[
                    const SizedBox(height: 20),
                    _SummaryCard(batch: batch),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── College chip ──────────────────────────────────────────────────────────────

class _CollegeChip extends StatelessWidget {
  final String college;
  const _CollegeChip({required this.college});

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.school_outlined, color: AppTheme.accent, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('College', style: TextStyle(color: _textSec, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(college, style: const TextStyle(color: _textPrim, fontSize: 13, fontWeight: FontWeight.w600)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _correct.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('Auto-filled', style: TextStyle(color: _correct, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Glass text field ──────────────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  const _GlassField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [
        Icon(icon, color: _textSec, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            style: const TextStyle(color: _textPrim, fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: const TextStyle(color: _textSec, fontSize: 12),
              hintStyle: TextStyle(color: _textSec.withOpacity(0.5), fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Exam type dropdown ────────────────────────────────────────────────────────

class _ExamTypeDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _ExamTypeDropdown({
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [
        const Icon(Icons.assignment_outlined, color: _textSec, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1B2E),
              style: const TextStyle(color: _textPrim, fontSize: 14, fontWeight: FontWeight.w500),
              iconEnabledColor: _textSec,
              iconDisabledColor: _textSec.withOpacity(0.3),
              hint: const Text('Exam Type', style: TextStyle(color: _textSec, fontSize: 12)),
              onChanged: enabled ? onChanged : null,
              items: items.map((t) => DropdownMenuItem(
                value: t,
                child: Text(t, style: const TextStyle(color: _textPrim)),
              )).toList(),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Pick files button ─────────────────────────────────────────────────────────

class _PickFilesButton extends StatelessWidget {
  final bool isEmpty;
  final bool disabled;
  final VoidCallback onTap;

  const _PickFilesButton({required this.isEmpty, required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(
            color: disabled ? _textSec.withOpacity(0.15) : AppTheme.accent.withOpacity(0.5),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.accent.withOpacity(disabled ? 0.02 : 0.05),
        ),
        child: Column(children: [
          Icon(
            isEmpty ? Icons.upload_file_rounded : Icons.add_rounded,
            color: disabled ? _textSec.withOpacity(0.3) : AppTheme.accent,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            isEmpty ? 'Select PDF files' : 'Add more PDFs',
            style: TextStyle(
              color: disabled ? _textSec.withOpacity(0.3) : AppTheme.accent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to browse your device',
            style: TextStyle(color: _textSec.withOpacity(0.5), fontSize: 11),
          ),
        ]),
      ),
    );
  }
}

// ── Progress header ───────────────────────────────────────────────────────────

class _ProgressHeader extends StatefulWidget {
  final _UploadBatchState batch;
  const _ProgressHeader({required this.batch});

  @override
  State<_ProgressHeader> createState() => _ProgressHeaderState();
}

class _ProgressHeaderState extends State<_ProgressHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _targetProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _targetProgress = _currentProgress;
    _anim = AlwaysStoppedAnimation(_targetProgress);
  }

  double get _currentProgress =>
      widget.batch.files.isEmpty ? 0.0 : widget.batch.doneCount / widget.batch.files.length;

  @override
  void didUpdateWidget(_ProgressHeader old) {
    super.didUpdateWidget(old);
    final newProgress = _currentProgress;
    if (newProgress == _targetProgress) return;

    final from = _anim.value;
    _targetProgress = newProgress;
    _anim = Tween<double>(begin: from, end: _targetProgress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              widget.batch.isUploading
                  ? 'Uploading ${widget.batch.doneCount + 1} of ${widget.batch.files.length}…'
                  : '${widget.batch.doneCount} of ${widget.batch.files.length} complete',
              style: const TextStyle(
                  color: _textPrim, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Text(
              '${(_anim.value * 100).round()}%',
              style: const TextStyle(
                  color: _textPrim, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LinearProgressIndicator(
              value: _anim.value,
              minHeight: 6,
              backgroundColor: _surface,
              valueColor: const AlwaysStoppedAnimation(_textPrim),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Shimmer painter ───────────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0, looping

  const _ShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final sweepWidth = size.width * 0.45;
    final x = -sweepWidth + (size.width + sweepWidth) * progress;

    final shader = LinearGradient(
      colors: const [
        Colors.transparent,
        Color(0x2263C8D4), // AppTheme.accent at ~13% opacity
        Color(0x3863C8D4), // AppTheme.accent at ~22% opacity
        Color(0x2263C8D4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    ).createShader(Rect.fromLTWH(x, 0, sweepWidth, size.height));

    canvas.drawRect(
      Rect.fromLTWH(x, 0, sweepWidth, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ── File card ─────────────────────────────────────────────────────────────────

class _FileCard extends StatefulWidget {
  final _FileItem item;
  final int index;
  final int total;
  final VoidCallback? onRemove;

  const _FileCard({
    required this.item,
    required this.index,
    required this.total,
    this.onRemove,
  });

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.item.status == _FileStatus.uploading) {
      _shimmerCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(_FileCard old) {
    super.didUpdateWidget(old);
    if (widget.item.status == _FileStatus.uploading) {
      if (!_shimmerCtrl.isAnimating) _shimmerCtrl.repeat();
    } else {
      _shimmerCtrl.stop();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Color get _statusColor => switch (widget.item.status) {
        _FileStatus.done      => _correct,
        _FileStatus.error     => AppTheme.error,
        _FileStatus.uploading => AppTheme.accent,
        _FileStatus.pending   => _textSec,
      };

  IconData get _statusIcon => switch (widget.item.status) {
        _FileStatus.done      => Icons.check_circle_rounded,
        _FileStatus.error     => Icons.error_rounded,
        _FileStatus.uploading => Icons.cloud_upload_rounded,
        _FileStatus.pending   => Icons.schedule_rounded,
      };

  String get _statusLabel => switch (widget.item.status) {
        _FileStatus.done  =>
          '+${widget.item.questionsAdded} question${widget.item.questionsAdded == 1 ? '' : 's'} added',
        _FileStatus.error     => widget.item.error ?? 'Upload failed',
        _FileStatus.uploading => 'Uploading…',
        _FileStatus.pending   => 'Waiting',
      };

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor;
    final isUploading = widget.item.status == _FileStatus.uploading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: sc.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sc.withOpacity(0.25), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // ── Shimmer layer (uploading only) ───────────────────────────
            if (isUploading)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _shimmerCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _ShimmerPainter(_shimmerCtrl.value),
                  ),
                ),
              ),

            // ── Card content ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.picture_as_pdf_rounded,
                        color: AppTheme.onBackground2, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _textPrim,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (isUploading)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppTheme.accent),
                          )
                        else
                          Icon(_statusIcon, color: sc, size: 12),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: sc,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

                // Remove / done badge
                if (widget.item.status == _FileStatus.pending &&
                    widget.onRemove != null)
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _textSec.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: _textSec, size: 14),
                    ),
                  )
                else if (widget.item.status == _FileStatus.done)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _correct.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${widget.item.questionsAdded}',
                      style: const TextStyle(
                          color: _correct,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upload button ─────────────────────────────────────────────────────────────

class _UploadButton extends StatelessWidget {
  final bool disabled;
  final int pendingCount;
  final VoidCallback onTap;

  const _UploadButton({required this.disabled, required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(colors: [AppTheme.primaryGradBegin, AppTheme.primaryGradEnd]),
          color: disabled ? _surface.withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: disabled ? [] : [
            BoxShadow(color: AppTheme.dropShadow.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (disabled)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            )
          else
            const Icon(Icons.cloud_upload_rounded, color: _textPrim, size: 18),
          const SizedBox(width: 10),
          Text(
            disabled ? 'Uploading…' : 'Upload $pendingCount file${pendingCount == 1 ? '' : 's'}',
            style: TextStyle(
              color: disabled ? _textSec : _textPrim,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final _UploadBatchState batch;
  const _SummaryCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final allOk = batch.errorCount == 0;
    final headerColor = allOk ? _correct : const Color(0xFFF5C518);

    return _GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: headerColor.withOpacity(0.08),
            border: Border(bottom: BorderSide(color: headerColor.withOpacity(0.2))),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: headerColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(allOk ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: headerColor, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              allOk ? 'All uploads complete' : 'Finished with errors',
              style: TextStyle(color: headerColor, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ]),
        ),

        // Stats row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _StatPill(icon: Icons.library_add_rounded, value: '${batch.totalAdded}', label: 'Questions added', color: AppTheme.accent),
            const SizedBox(width: 10),
            _StatPill(icon: Icons.check_rounded, value: '${batch.doneCount}/${batch.files.length}', label: 'Files done', color: _correct),
            if (batch.errorCount > 0) ...[
              const SizedBox(width: 10),
              _StatPill(icon: Icons.close_rounded, value: '${batch.errorCount}', label: 'Failed', color: AppTheme.error),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatPill({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Shared glass container ────────────────────────────────────────────────────

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _GlassContainer({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }
}