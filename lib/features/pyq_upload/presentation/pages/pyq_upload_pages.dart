import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_datasource.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_dto.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_provider.dart'
    show examPredictionDataSourceProvider;

import 'package:Skolar/shared/providers/global_providers.dart' show userProvider;

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

  int get totalAdded =>
      files.fold(0, (sum, f) => sum + f.questionsAdded);

  int get doneCount =>
      files.where((f) => f.status == _FileStatus.done).length;

  int get errorCount =>
      files.where((f) => f.status == _FileStatus.error).length;

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
    // Deduplicate by filename
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
    required int year,
    required String examType,
    required String college,
    required ExamPredictionRemoteDataSource dataSource,
  }) async {
    if (state.isUploading) return;
    state = state.copyWith(isUploading: true, isDone: false);

    // Only reset previously-errored files back to pending.
    // Done files are left untouched — they will be skipped below.
    final reset = state.files
        .map((f) => f.status == _FileStatus.error
            ? f.copyWith(status: _FileStatus.pending, clearError: true)
            : f)
        .toList();
    state = state.copyWith(files: reset);

    for (int i = 0; i < state.files.length; i++) {
      // Skip files that were already successfully uploaded
      if (state.files[i].status == _FileStatus.done) continue;

      // Mark current file as uploading
      final uploading = [...state.files];
      uploading[i] = uploading[i].copyWith(status: _FileStatus.uploading);
      state = state.copyWith(files: uploading);

      try {
        final UploadResultDto result = await dataSource.uploadPyq(
          filePath: state.files[i].filePath,
          subject: subject,
          year: year,
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

  static const _examTypes = ['compre', 'midsem', 'endsem', 'unknown'];

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

    if (subject.isEmpty) {
      _snack('Please enter a subject.');
      return;
    }
    if (year == null || year < 1990 || year > DateTime.now().year + 1) {
      _snack('Please enter a valid year.');
      return;
    }
    if (ref.read(_uploadBatchProvider).files.isEmpty) {
      _snack('Please select at least one PDF.');
      return;
    }

    final college = ref.read(userProvider).college;
    final dataSource = ref.read(examPredictionDataSourceProvider);

    ref.read(_uploadBatchProvider.notifier).uploadAll(
          subject: subject,
          year: year,
          examType: _selectedExamType,
          college: college,
          dataSource: dataSource,
        );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(_uploadBatchProvider);
    final pendingCount =
        batch.files.where((f) => f.status != _FileStatus.done).length;
    final college = ref.watch(userProvider).college;
    final theme = Theme.of(context);
    final disabled = batch.isUploading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload PYQs'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          if (batch.files.isNotEmpty && !batch.isUploading)
            TextButton.icon(
              onPressed: () =>
                  ref.read(_uploadBatchProvider.notifier).reset(),
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear all'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // College (auto-filled, read-only)
          _CollegeChip(college: college),
          const SizedBox(height: 16),

          // Subject
          TextField(
            controller: _subjectController,
            enabled: !disabled,
            decoration: const InputDecoration(
              labelText: 'Subject',
              hintText: 'e.g. Artificial Intelligence',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Year + Exam type
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _yearController,
                  enabled: !disabled,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedExamType,
                  decoration: const InputDecoration(
                    labelText: 'Exam Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _examTypes
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: disabled
                      ? null
                      : (v) => setState(() => _selectedExamType = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pick files button
          OutlinedButton.icon(
            onPressed: disabled ? null : _pickFiles,
            icon: const Icon(Icons.attach_file),
            label: Text(
              batch.files.isEmpty ? 'Select PDF files' : 'Add more PDFs',
            ),
          ),

          // File cards
          if (batch.files.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...batch.files.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FileCard(
                    item: e.value,
                    onRemove: disabled
                        ? null
                        : () => ref
                            .read(_uploadBatchProvider.notifier)
                            .removeFile(e.key),
                  ),
                )),
            const SizedBox(height: 8),

            // Upload button
            FilledButton.icon(
              onPressed: disabled ? null : _startUpload,
              icon: disabled
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload),
              label: Text(
                disabled
                    ? 'Uploading…'
                    : "Upload $pendingCount file${pendingCount == 1 ? '' : 's'}",
              ),
            ),
          ],

          // Summary
          if (batch.isDone) ...[
            const SizedBox(height: 20),
            _SummaryCard(batch: batch),
          ],

          const SizedBox(height: 32),
        ],
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.school_outlined,
              size: 18, color: theme.colorScheme.secondary),
          const SizedBox(width: 8),
          Text(college,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('Auto-filled',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

// ── File card ─────────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final _FileItem item;
  final VoidCallback? onRemove;

  const _FileCard({required this.item, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color border, Widget trailing, String subtitle) =
        switch (item.status) {
      _FileStatus.pending => (
          theme.colorScheme.outline,
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
          'Waiting',
        ),
      _FileStatus.uploading => (
          theme.colorScheme.primary,
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          'Uploading…',
        ),
      _FileStatus.done => (
          Colors.green,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+${item.questionsAdded}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, color: Colors.green, size: 22),
            ],
          ),
          '${item.questionsAdded} question${item.questionsAdded == 1 ? '' : 's'} added',
        ),
      _FileStatus.error => (
          Colors.red,
          const Icon(Icons.error_outline, color: Colors.red, size: 22),
          item.error ?? 'Upload failed',
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          Icons.picture_as_pdf,
          color: item.status == _FileStatus.error ? Colors.red : Colors.red[700],
        ),
        title: Text(
          item.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: item.status == _FileStatus.error ? Colors.red : null,
          ),
        ),
        trailing: trailing,
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
    final theme = Theme.of(context);
    final allOk = batch.errorCount == 0;

    return Card(
      color: allOk
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allOk ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: allOk ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  allOk ? 'All uploads complete' : 'Upload finished with errors',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _summaryRow(
              context,
              Icons.library_add,
              '${batch.totalAdded} questions added to question bank',
            ),
            _summaryRow(
              context,
              Icons.check,
              '${batch.doneCount} of ${batch.files.length} files succeeded',
            ),
            if (batch.errorCount > 0)
              _summaryRow(
                context,
                Icons.close,
                '${batch.errorCount} file${batch.errorCount == 1 ? '' : 's'} failed — see cards above',
                color: Colors.red,
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? theme.colorScheme.onSurface),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}