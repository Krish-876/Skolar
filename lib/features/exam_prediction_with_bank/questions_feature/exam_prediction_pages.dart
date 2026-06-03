import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_provider.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_widgets.dart';

class ExamPredictionPage extends ConsumerStatefulWidget {
  const ExamPredictionPage({super.key});

  @override
  ConsumerState<ExamPredictionPage> createState() =>
      _ExamPredictionPageState();
}

class _ExamPredictionPageState extends ConsumerState<ExamPredictionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statsProvider.notifier).refresh();
      ref.read(questionsProvider.notifier).filter();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Prediction'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Generate'),
            Tab(icon: Icon(Icons.upload_file), text: 'Upload PYQ'),
            Tab(icon: Icon(Icons.library_books), text: 'Question Bank'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GenerateTab(),
          _UploadTab(),
          _QuestionBankTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generate Tab
// ---------------------------------------------------------------------------

class _GenerateTab extends ConsumerStatefulWidget {
  const _GenerateTab();

  @override
  ConsumerState<_GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends ConsumerState<_GenerateTab> {
  final List<String> _subjects = [
    'Artificial Intelligence',
    'Computer Science',
    'Mathematics',
    'Physics',
    'Chemistry',
  ];

  String _selectedSubject = 'Artificial Intelligence';
  int _k = 5;
  final _yearFromController = TextEditingController();
  final _yearToController = TextEditingController();

  @override
  void dispose() {
    _yearFromController.dispose();
    _yearToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsProvider);
    final generateAsync = ref.watch(generateQuestionProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statsAsync.when(
          loading: () => const StatsLoadingCard(),
          error: (e, _) => ErrorCard(message: e.toString()),
          data: (stats) => stats != null
              ? StatsCard(stats: stats)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _selectedSubject,
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
          ),
          items: _subjects
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _selectedSubject = v!),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _yearFromController,
                decoration: const InputDecoration(
                  labelText: 'Year from (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _yearToController,
                decoration: const InputDecoration(
                  labelText: 'Year to (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Examples to use (k = $_k)',
                style: Theme.of(context).textTheme.bodyMedium),
            Slider(
              value: _k.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_k',
              onChanged: (v) => setState(() => _k = v.round()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate Question'),
          onPressed: generateAsync.isLoading
              ? null
              : () {
                  final yearFrom = int.tryParse(_yearFromController.text);
                  final yearTo = int.tryParse(_yearToController.text);
                  ref.read(generateQuestionProvider.notifier).generate(
                        subject: _selectedSubject,
                        k: _k,
                        yearFrom: yearFrom,
                        yearTo: yearTo,
                      );
                },
        ),
        const SizedBox(height: 24),
        generateAsync.when(
          loading: () => const GeneratingCard(),
          error: (e, _) => ErrorCard(message: e.toString()),
          data: (q) => q != null
              ? GeneratedQuestionCard(question: q)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Upload Tab
// ---------------------------------------------------------------------------

class _UploadTab extends ConsumerStatefulWidget {
  const _UploadTab();

  @override
  ConsumerState<_UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends ConsumerState<_UploadTab> {
  final _subjectController = TextEditingController();
  final _yearController = TextEditingController();
  final List<String> _examTypes = ['compre', 'midsem', 'endsem', 'unknown'];
  String _selectedExamType = 'compre';
  String? _pickedFilePath;
  String? _pickedFileName;

  @override
  void dispose() {
    _subjectController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFilePath = result.files.single.path;
        _pickedFileName = result.files.single.name;
      });
    }
  }

  void _upload() {
    final year = int.tryParse(_yearController.text.trim());
    if (_pickedFilePath == null ||
        _subjectController.text.isEmpty ||
        year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and select a PDF.')),
      );
      return;
    }
    ref.read(uploadPyqProvider.notifier).upload(
          filePath: _pickedFilePath!,
          subject: _subjectController.text.trim(),
          paperYear: year,
          examType: _selectedExamType,
        );
  }

  @override
  Widget build(BuildContext context) {
    final uploadAsync = ref.watch(uploadPyqProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: Text(_pickedFileName ?? 'Select PDF'),
          onPressed: _pickFile,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _subjectController,
          decoration: const InputDecoration(
            labelText: 'Subject (e.g. Artificial Intelligence)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _yearController,
          decoration: const InputDecoration(
            labelText: 'Year (e.g. 2025)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedExamType,
          decoration: const InputDecoration(
            labelText: 'Exam Type',
            border: OutlineInputBorder(),
          ),
          items: _examTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _selectedExamType = v!),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('Upload PYQ'),
          onPressed: uploadAsync.isLoading ? null : _upload,
        ),
        const SizedBox(height: 24),
        uploadAsync.when(
          loading: () => const UploadingCard(),
          error: (e, _) => ErrorCard(message: e.toString()),
          data: (result) => result != null
              ? UploadResultCard(result: result)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Question Bank Tab
// ---------------------------------------------------------------------------

class _QuestionBankTab extends ConsumerStatefulWidget {
  const _QuestionBankTab();

  @override
  ConsumerState<_QuestionBankTab> createState() => _QuestionBankTabState();
}

class _QuestionBankTabState extends ConsumerState<_QuestionBankTab> {
  final List<String> _examTypes = ['All', 'compre', 'midsem', 'endsem'];
  final List<String> _questionTypes = [
    'All',
    'mcq',
    'short_answer',
    'long_answer',
    'numerical'
  ];
  String _selectedExamType = 'All';
  String _selectedQuestionType = 'All';

  void _applyFilters() {
    ref.read(questionsProvider.notifier).filter(
          examType: _selectedExamType == 'All' ? null : _selectedExamType,
          questionType:
              _selectedQuestionType == 'All' ? null : _selectedQuestionType,
        );
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionsProvider);

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedExamType,
                  decoration: const InputDecoration(
                    labelText: 'Exam Type',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _examTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedExamType = v!);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedQuestionType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _questionTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedQuestionType = v!);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Question list
        Expanded(
          child: questionsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: ErrorCard(message: e.toString())),
            data: (response) {
              if (response == null || response.questions.isEmpty) {
                return const Center(
                  child: Text('No questions found.'),
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${response.total} questions',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: response.questions.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final q = response.questions[index];
                        return QuestionBankCard(question: q);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
