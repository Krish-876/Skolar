import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:Skolar/core/loading/test_page.dart';
import 'package:Skolar/core/widgets/animated_profile_gradient.dart';
import 'package:Skolar/features/focus_session/widgets/focus_background.dart';
import 'package:Skolar/features/mock_tests/domain/entities/mock_test_entity.dart';
import 'package:Skolar/features/subjects/presentation/providers/subjects_provider.dart';
import 'package:Skolar/shared/models/exam_type.dart';
// import 'package:Skolar/shared/providers/global_providers.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/mock_tests/presentation/providers/mock_tests_provider.dart';

const _bg = Color(0xFF05061A);
const _primary = Color(0xFF1E2A8A);
const _surface = Color(0xFF2E2B3E);
const _accent = Color(0xFF63C8D4);
const _textPrim = Color(0xFFFFFFFF);
const _textSec = Color(0xFFA8C4FF);
const _correct = Color(0xFF4CAF50);
const _wrong = Color(0xFFD0021B);

Color _marksColor(int marks) {
  if (marks <= 3) return const Color(0xFF4CAF50);
  if (marks <= 6) return const Color(0xFFF5C518);
  return const Color(0xFFFF6B6B);
}

final _gfm = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
);

MarkdownStyleSheet _answerMarkdownStyle() {
  return MarkdownStyleSheet(
    p: const TextStyle(
      color: _textPrim,
      fontSize: 14,
      height: 1.7,
      fontWeight: FontWeight.w400,
    ),
    h3: const TextStyle(
      color: _accent,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
    ),
    strong: const TextStyle(
      color: _textPrim,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
    em: const TextStyle(
      color: _textSec,
      fontStyle: FontStyle.italic,
      fontSize: 14,
    ),
    code: TextStyle(
      color: _accent,
      backgroundColor: _primary.withValues(alpha: 0.3),
      fontSize: 13,
      fontFamily: 'monospace',
    ),
    codeblockDecoration: BoxDecoration(
      color: _primary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _primary.withValues(alpha: 0.4)),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    listBullet: const TextStyle(color: _accent, fontSize: 14),
    listIndent: 18,
    blockSpacing: 10,
    tableHead: const TextStyle(
      color: _accent,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
    tableBody: const TextStyle(color: _textPrim, fontSize: 13, height: 1.5),
    tableBorder: TableBorder.all(
      color: _surface,
      width: 1,
      borderRadius: BorderRadius.circular(6),
    ),
    tableHeadAlign: TextAlign.center,
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    tableCellsDecoration: BoxDecoration(color: _primary.withValues(alpha: 0.4)),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: _surface, width: 1)),
    ),
  );
}

MarkdownStyleSheet _questionMarkdownStyle() {
  return MarkdownStyleSheet(
    p: const TextStyle(
      color: _textPrim,
      fontSize: 13,
      height: 1.65,
      fontWeight: FontWeight.w500,
    ),
    strong: const TextStyle(
      color: _textPrim,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
    em: const TextStyle(
      color: _textSec,
      fontStyle: FontStyle.italic,
      fontSize: 13,
    ),
    code: TextStyle(
      color: _accent,
      backgroundColor: _primary.withValues(alpha: 0.3),
      fontSize: 12,
      fontFamily: 'monospace',
    ),
    listBullet: const TextStyle(color: _textSec, fontSize: 13),
    listIndent: 16,
    blockSpacing: 8,
    tableHead: const TextStyle(
      color: _textSec,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    tableBody: const TextStyle(color: _textPrim, fontSize: 12, height: 1.5),
    tableBorder: TableBorder.all(
      color: _surface,
      width: 1,
      borderRadius: BorderRadius.circular(6),
    ),
    tableHeadAlign: TextAlign.center,
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    tableCellsDecoration: BoxDecoration(
      color: _primary.withValues(alpha: 0.35),
    ),
  );
}

// ── Exam type enum — in syllabus order: quiz1 ⊂ midsem ⊂ quiz2 ⊂ compre ─────

enum _ExamType { quiz1, midsem, quiz2, compreA, compreB }

extension _ExamTypeExt on _ExamType {
  String get label => switch (this) {
    _ExamType.quiz1 => 'Quiz 1',
    _ExamType.midsem => 'Midsem',
    _ExamType.quiz2 => 'Quiz 2',
    _ExamType.compreA => 'Compre Part A',
    _ExamType.compreB => 'Compre Part B',
  };

  ExamType get examType => switch (this) {
    _ExamType.quiz1 => ExamType.quiz1,
    _ExamType.midsem => ExamType.midsem,
    _ExamType.quiz2 => ExamType.quiz2,
    _ExamType.compreA => ExamType.compre,
    _ExamType.compreB => ExamType.compre,
  };

  ExamMode get mode => switch (this) {
    _ExamType.compreA => ExamMode.mcqBlitz,
    _ => ExamMode.writtenPractice,
  };

  int get defaultCount => switch (this) {
    _ExamType.quiz1 => 5,
    _ExamType.midsem => 6,
    _ExamType.quiz2 => 5,
    _ExamType.compreA => 8,
    _ExamType.compreB => 4,
  };

  int get maxCount => switch (this) {
    _ExamType.compreA => 15,
    _ => 10,
  };

  IconData get icon => switch (this) {
    _ExamType.quiz1 => Icons.quiz_outlined,
    _ExamType.midsem => Icons.description_outlined,
    _ExamType.quiz2 => Icons.quiz_outlined,
    _ExamType.compreA => Icons.flash_on_rounded,
    _ExamType.compreB => Icons.edit_note_rounded,
  };
}

// ── Entry point ───────────────────────────────────────────────────────────────

class MockTestPage extends ConsumerStatefulWidget {
  const MockTestPage({super.key});
  @override
  ConsumerState<MockTestPage> createState() => _MockTestPageState();
}

class _MockTestPageState extends ConsumerState<MockTestPage> {
  String? _selectedSubject;
  _ExamType _selectedExam = _ExamType.quiz1;
  int _questionCount = _ExamType.quiz1.defaultCount;

  /// Keeps `_selectedSubject` valid as the subjects list resolves or
  /// changes (e.g. user deleted the previously-selected subject in a
  /// past session). Only mutates when necessary — cheap to call every
  /// build.
  void _syncSelectedSubject(List<String> names) {
    if (names.isEmpty) return;
    if (_selectedSubject == null || !names.contains(_selectedSubject)) {
      _selectedSubject = names.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mockState = ref.watch(mockTestProvider);
    if (mockState.isLoading) return const TestLoadingPage();
    if (mockState.error != null) {
      return _ErrorScreen(
        error: mockState.error!,
        onRetry: _start,
        onBack: () => ref.read(mockTestProvider.notifier).reset(),
      );
    }
    if (mockState.hasQuestions) {
      return mockState.mode == ExamMode.mcqBlitz
          ? _McqQuizFlow(questions: mockState.mcqQuestions)
          : _WrittenPracticeFlow(questions: mockState.openQuestions);
    }

    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      loading: () => const TestLoadingPage(),
      error: (e, _) => _ErrorScreen(
        error: 'Could not load your subjects.\n$e',
        onRetry: () => ref.invalidate(subjectsProvider),
        onBack: () => Navigator.maybePop(context),
      ),
      data: (subjectsState) {
        // Dedup by name, preserve original order.
        final seen = <String>{};
        final subjectNames = <String>[
          for (final s in subjectsState.subjects)
            if (seen.add(s.name)) s.name,
        ];

        if (subjectNames.isEmpty) {
          // Defensive fallback. This page is normally only reachable
          // after the user has confirmed their subjects (CDCs are
          // auto-seeded on first load), so this shouldn't occur in
          // practice — but guard against it rather than crashing on
          // an empty dropdown / null selection.
          return _NoSubjectsScreen(
            onAddSubjects: () => Navigator.maybePop(context),
          );
        }

        _syncSelectedSubject(subjectNames);

        return _SetupScreen(
          subjects: subjectNames,
          selectedSubject: _selectedSubject!,
          selectedExam: _selectedExam,
          questionCount: _questionCount,
          onSubjectChanged: (s) => setState(() => _selectedSubject = s),
          onExamChanged: (e) => setState(() {
            _selectedExam = e;
            _questionCount = e.defaultCount;
          }),
          onCountChanged: (c) => setState(() => _questionCount = c),
          onStart: _start,
        );
      },
    );
  }

  void _start() {
    final subject = _selectedSubject;
    if (subject == null) return;
    ref
        .read(mockTestProvider.notifier)
        .fetchQuestions(
          MockTestRequest(
            subject: subject,
            mode: _selectedExam.mode,
            examType: _selectedExam.examType,
            count: _questionCount,
          ),
        );
  }
}

// ── No subjects screen (defensive fallback) ─────────────────────────────────

class _NoSubjectsScreen extends StatelessWidget {
  final VoidCallback onAddSubjects;
  const _NoSubjectsScreen({required this.onAddSubjects});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, color: _textSec, size: 48),
              const SizedBox(height: 16),
              const Text(
                'No subjects yet',
                style: TextStyle(
                  color: _textPrim,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your subjects first to generate a mock test.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSec, fontSize: 13),
              ),
              const SizedBox(height: 24),
              _StartButton(label: 'Go to Subjects', onTap: onAddSubjects),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Setup screen ──────────────────────────────────────────────────────────────

class _SetupScreen extends StatelessWidget {
  final List<String> subjects;
  final String selectedSubject;
  final _ExamType selectedExam;
  final int questionCount;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<_ExamType> onExamChanged;
  final ValueChanged<int> onCountChanged;
  final VoidCallback onStart;

  const _SetupScreen({
    required this.subjects,
    required this.selectedSubject,
    required this.selectedExam,
    required this.questionCount,
    required this.onSubjectChanged,
    required this.onExamChanged,
    required this.onCountChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _textSec,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Text(
                'Mock Test',
                style: GoogleFonts.googleSansFlex(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI-generated from your college PYQs',
                style: GoogleFonts.googleSans(color: _textSec, fontSize: 14),
              ),
              const SizedBox(height: 28),
              _SectionLabel('Exam Type'),
              const SizedBox(height: 10),
              _ExamTypeGrid(selected: selectedExam, onChanged: onExamChanged),
              const SizedBox(height: 24),
              _SectionLabel('Subject'),
              const SizedBox(height: 10),
              _GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSubject,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1B2E),
                    style: const TextStyle(color: _textPrim, fontSize: 15),
                    iconEnabledColor: _textSec,
                    items: subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => onSubjectChanged(v!),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _SectionLabel('Questions'),
                  const Spacer(),
                  _GlassChip(
                    child: Text(
                      '$questionCount',
                      style: const TextStyle(
                        color: _textPrim,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: _accent,
                  inactiveTrackColor: _surface,
                  thumbColor: _accent,
                  overlayColor: _accent.withValues(alpha: 0.15),
                ),
                child: Slider(
                  min: 3,
                  max: selectedExam.maxCount.toDouble(),
                  divisions: selectedExam.maxCount - 3,
                  value: questionCount
                      .clamp(3, selectedExam.maxCount)
                      .toDouble(),
                  onChanged: (v) => onCountChanged(v.round()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '3',
                    style: const TextStyle(color: _textSec, fontSize: 11),
                  ),
                  Text(
                    '${selectedExam.maxCount}',
                    style: const TextStyle(color: _textSec, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              _StartButton(label: 'Start Test', onTap: onStart),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  selectedExam.mode == ExamMode.mcqBlitz
                      ? 'Generation takes ~${questionCount * 4}s'
                      : 'Generation takes ~${questionCount * 8}s (questions + answers)',
                  style: const TextStyle(color: _textSec, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Exam type grid ────────────────────────────────────────────────────────────

class _ExamTypeGrid extends StatelessWidget {
  final _ExamType selected;
  final ValueChanged<_ExamType> onChanged;
  const _ExamTypeGrid({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: _ExamType.values.map((type) {
        final isSel = type == selected;
        return GestureDetector(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSel
                  ? _primary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? _accent : Colors.white.withValues(alpha: 0.08),
                width: isSel ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(type.icon, color: isSel ? _accent : _textSec, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      color: isSel ? _textPrim : _textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Error screen ──────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  const _ErrorScreen({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: _wrong, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Could not generate test',
                style: TextStyle(
                  color: _textPrim,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSec, fontSize: 13),
              ),
              const SizedBox(height: 24),
              _StartButton(label: 'Retry', onTap: onRetry),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onBack,
                child: const Text(
                  'Change subject',
                  style: TextStyle(color: _textSec),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// QUESTION CARD — shared between MCQ + written views
// ═════════════════════════════════════════════════════════════════════════════

class _QuestionCard extends StatelessWidget {
  final String question;
  final String subject;
  final int marks;
  final int? questionNumber;

  const _QuestionCard({
    required this.question,
    required this.subject,
    required this.marks,
    this.questionNumber,
  });

  ({String context, String ask}) _split() {
    final trimmed = question.trim();
    final doubleNewline = trimmed.lastIndexOf('\n\n');
    if (doubleNewline > 0 && doubleNewline > trimmed.length * 0.3) {
      return (
        context: trimmed.substring(0, doubleNewline).trim(),
        ask: trimmed.substring(doubleNewline + 2).trim(),
      );
    }
    final lastNewline = trimmed.lastIndexOf('\n');
    if (lastNewline > 0 && lastNewline > trimmed.length * 0.3) {
      return (
        context: trimmed.substring(0, lastNewline).trim(),
        ask: trimmed.substring(lastNewline + 1).trim(),
      );
    }
    return (context: '', ask: trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final parts = _split();
    final mc = _marksColor(marks);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    if (questionNumber != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$questionNumber',
                            style: const TextStyle(
                              color: _textPrim,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        subject,
                        style: const TextStyle(
                          color: _textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: mc.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: mc.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: mc, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            '$marks M',
                            style: TextStyle(
                              color: mc,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (parts.context.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: MarkdownBody(
                    data: parts.context,
                    styleSheet: _questionMarkdownStyle(),
                    softLineBreak: true,
                    extensionSet: _gfm,
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: parts.context.isNotEmpty
                    ? const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: _accent, width: 3),
                        ),
                      )
                    : null,
                child: MarkdownBody(
                  data: parts.ask,
                  styleSheet: parts.context.isNotEmpty
                      ? _questionMarkdownStyle().copyWith(
                          p: const TextStyle(
                            color: _textPrim,
                            fontSize: 13,
                            height: 1.65,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : _questionMarkdownStyle(),
                  softLineBreak: true,
                  extensionSet: _gfm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MODEL ANSWER CARD
// ═════════════════════════════════════════════════════════════════════════════

class _ModelAnswerCard extends StatelessWidget {
  final String modelAnswer;
  const _ModelAnswerCard({required this.modelAnswer});

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(
                  color: _accent.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_rounded,
                    color: _accent,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Model Answer',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _MarkdownWithAccentHeadings(
              data: modelAnswer,
              styleSheet: _answerMarkdownStyle(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownWithAccentHeadings extends StatelessWidget {
  final String data;
  final MarkdownStyleSheet styleSheet;
  const _MarkdownWithAccentHeadings({
    required this.data,
    required this.styleSheet,
  });

  @override
  Widget build(BuildContext context) {
    final segments = <({String text, bool isHeading})>[];
    final buffer = StringBuffer();

    for (final line in data.split('\n')) {
      if (line.startsWith('### ')) {
        if (buffer.isNotEmpty) {
          segments.add((text: buffer.toString().trim(), isHeading: false));
          buffer.clear();
        }
        segments.add((text: line.substring(4).trim(), isHeading: true));
      } else {
        buffer.writeln(line);
      }
    }
    if (buffer.isNotEmpty) {
      segments.add((text: buffer.toString().trim(), isHeading: false));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        if (seg.isHeading) {
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  seg.text.toUpperCase(),
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          );
        }
        if (seg.text.isEmpty) return const SizedBox.shrink();
        return MarkdownBody(
          data: seg.text,
          styleSheet: styleSheet,
          softLineBreak: true,
          extensionSet: _gfm,
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MCQ BLITZ FLOW
// ═════════════════════════════════════════════════════════════════════════════

class _McqQuizFlow extends ConsumerStatefulWidget {
  final List<QuizQuestion> questions;
  const _McqQuizFlow({required this.questions});
  @override
  ConsumerState<_McqQuizFlow> createState() => _McqQuizFlowState();
}

class _McqQuizFlowState extends ConsumerState<_McqQuizFlow> {
  int _current = 0;
  int _score = 0;
  bool _done = false;
  late final List<int?> _answers;

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.questions.length, null);
  }

  void _onAnswer(int picked) {
    if (_answers[_current] != null) return;
    final correct = widget.questions[_current].correctIndex == picked;
    setState(() {
      _answers[_current] = picked;
      if (correct) _score += widget.questions[_current].marks;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_current < widget.questions.length - 1) {
        setState(() => _current++);
      } else {
        setState(() => _done = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: GlassBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            ),
            child: _done
                ? _McqResultScreen(
                    key: const ValueKey('result'),
                    score: _score,
                    total: widget.questions.fold(0, (s, q) => s + q.marks),
                    answers: _answers,
                    questions: widget.questions,
                    onRestart: () =>
                        ref.read(mockTestProvider.notifier).reset(),
                  )
                : _McqQuestionScreen(
                    key: ValueKey(_current),
                    question: widget.questions[_current],
                    index: _current,
                    total: widget.questions.length,
                    score: _score,
                    picked: _answers[_current],
                    onAnswer: _onAnswer,
                  ),
          ),
        ),
      ),
    );
  }
}

class _McqQuestionScreen extends StatefulWidget {
  final QuizQuestion question;
  final int index, total, score;
  final int? picked;
  final ValueChanged<int> onAnswer;

  const _McqQuestionScreen({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.score,
    required this.picked,
    required this.onAnswer,
  });
  @override
  State<_McqQuestionScreen> createState() => _McqQuestionScreenState();
}

class _McqQuestionScreenState extends State<_McqQuestionScreen>
    with SingleTickerProviderStateMixin {
  late final Timer _timer;
  int _seconds = 30;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) {
          _seconds--;
        } else {
          _timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color get _timerColor {
    if (_seconds > 15) return _accent;
    if (_seconds > 7) return const Color(0xFFF5C518);
    return _wrong;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _textSec,
                  size: 18,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Question ${widget.index + 1} of ${widget.total}',
                      style: const TextStyle(color: _textSec, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (widget.index + 1) / widget.total,
                        minHeight: 5,
                        backgroundColor: _surface,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF5B6EF5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _GlassChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFF5C518),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.score}',
                      style: const TextStyle(
                        color: _textPrim,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, _) => Transform.scale(
            scale: _seconds <= 7 ? 1.0 + _pulseCtrl.value * 0.15 : 1.0,
            child: _GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, color: _timerColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${_seconds}s',
                    style: TextStyle(
                      color: _timerColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _QuestionCard(
            question: q.question,
            subject: q.subject,
            marks: q.marks,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: q.options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _OptionTile(
              label: String.fromCharCode(65 + i),
              text: q.options[i],
              state: widget.picked == null
                  ? _OptionState.idle
                  : i == q.correctIndex
                  ? _OptionState.correct
                  : i == widget.picked
                  ? _OptionState.wrong
                  : _OptionState.idle,
              onTap: widget.picked == null ? () => widget.onAnswer(i) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _McqResultScreen extends StatefulWidget {
  final int score, total;
  final List<int?> answers;
  final List<QuizQuestion> questions;
  final VoidCallback onRestart;

  const _McqResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.answers,
    required this.questions,
    required this.onRestart,
  });
  @override
  State<_McqResultScreen> createState() => _McqResultScreenState();
}

class _McqResultScreenState extends State<_McqResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scoreAnim;
  late final ConfettiController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _scoreAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.score / widget.total >= 0.7) _confettiCtrl.play();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  String get _grade {
    final p = widget.score / widget.total;
    if (p >= 0.9) return 'Outstanding';
    if (p >= 0.7) return 'Great Work';
    if (p >= 0.5) return 'Keep Going';
    return 'Try Again';
  }

  Color get _gradeColor {
    final p = widget.score / widget.total;
    if (p >= 0.9) return _accent;
    if (p >= 0.7) return const Color(0xFF5B6EF5);
    if (p >= 0.5) return const Color(0xFFF5C518);
    return _wrong;
  }

  int get _correctCount => widget.answers
      .asMap()
      .entries
      .where(
        (e) =>
            e.value != null && e.value == widget.questions[e.key].correctIndex,
      )
      .length;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ConfettiWidget(
          confettiController: _confettiCtrl,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            _accent,
            Color(0xFF5B6EF5),
            Color(0xFFF5C518),
            Colors.white,
          ],
          gravity: 0.2,
          numberOfParticles: 20,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scoreAnim,
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: widget.score / widget.total,
                      color: _gradeColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.score}',
                            style: const TextStyle(
                              color: _textPrim,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'of ${widget.total}',
                            style: const TextStyle(
                              color: _textSec,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _grade,
                style: TextStyle(
                  color: _gradeColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_correctCount / ${widget.questions.length} correct',
                style: const TextStyle(color: _textSec, fontSize: 14),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_rounded,
                      iconColor: _correct,
                      label: 'Correct',
                      value: '$_correctCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.cancel_rounded,
                      iconColor: _wrong,
                      label: 'Wrong',
                      value:
                          '${widget.answers.where((a) => a != null).length - _correctCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.radio_button_unchecked,
                      iconColor: _textSec,
                      label: 'Skipped',
                      value: '${widget.answers.where((a) => a == null).length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _StartButton(label: 'New Test', onTap: widget.onRestart),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WRITTEN PRACTICE FLOW
// ═════════════════════════════════════════════════════════════════════════════

class _WrittenPracticeFlow extends ConsumerStatefulWidget {
  final List<OpenQuestion> questions;
  const _WrittenPracticeFlow({required this.questions});
  @override
  ConsumerState<_WrittenPracticeFlow> createState() =>
      _WrittenPracticeFlowState();
}

class _WrittenPracticeFlowState extends ConsumerState<_WrittenPracticeFlow> {
  bool? _viewMode;
  @override
  Widget build(BuildContext context) {
    if (_viewMode == null) {
      return _ViewModeChooser(onChoose: (v) => setState(() => _viewMode = v));
    }
    if (_viewMode == true) {
      return _PaperView(
        questions: widget.questions,
        onDone: () => ref.read(mockTestProvider.notifier).reset(),
      );
    }
    return _FlashcardView(
      questions: widget.questions,
      onDone: () => ref.read(mockTestProvider.notifier).reset(),
    );
  }
}

class _ViewModeChooser extends StatelessWidget {
  final ValueChanged<bool> onChoose;
  const _ViewModeChooser({required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: GlassBackground(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: _accent, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Questions Ready',
                style: TextStyle(
                  color: _textPrim,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'How would you like to practice?',
                style: TextStyle(color: _textSec, fontSize: 14),
              ),
              const SizedBox(height: 40),
              _ModeCard(
                icon: Icons.view_agenda_outlined,
                title: 'One at a time',
                subtitle: 'Flashcard style — think then reveal answer',
                onTap: () => onChoose(false),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                icon: Icons.article_outlined,
                title: 'All at once',
                subtitle: 'Paper style — scroll through all questions',
                onTap: () => onChoose(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _textPrim,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _textSec,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _textSec,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flashcard view ────────────────────────────────────────────────────────────

class _FlashcardView extends StatefulWidget {
  final List<OpenQuestion> questions;
  final VoidCallback onDone;
  const _FlashcardView({required this.questions, required this.onDone});
  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView> {
  int _current = 0;
  bool _revealed = false;

  void _next() {
    if (_current < widget.questions.length - 1) {
      setState(() {
        _current++;
        _revealed = false;
      });
    } else {
      widget.onDone();
    }
  }

  void _onBackPressed(BuildContext context) {
    if (_current > 0) {
      setState(() {
        _current--;
        _revealed = false;
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_current];
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const FocusBackground(slideProgress: 1.0),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _onBackPressed(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _textSec,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (_current + 1) / widget.questions.length,
                            minHeight: 5,
                            backgroundColor: _surface,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF5B6EF5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_current + 1}/${widget.questions.length}',
                        style: const TextStyle(color: _textSec, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _QuestionCard(
                          question: q.question,
                          subject: q.subject,
                          marks: q.marks,
                        ),
                        const SizedBox(height: 16),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 350),
                          crossFadeState: _revealed
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: GestureDetector(
                            onTap: () => setState(() => _revealed = true),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _accent.withValues(alpha: 0.4),
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: _accent,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Reveal Model Answer',
                                    style: TextStyle(
                                      color: _accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          secondChild: _ModelAnswerCard(
                            modelAnswer: q.modelAnswer,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _StartButton(
                    label: _current == widget.questions.length - 1
                        ? '✓ Finish'
                        : 'Next Question →',
                    onTap: _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paper view ────────────────────────────────────────────────────────────────

class _PaperView extends StatefulWidget {
  final List<OpenQuestion> questions;
  final VoidCallback onDone;
  const _PaperView({required this.questions, required this.onDone});
  @override
  State<_PaperView> createState() => _PaperViewState();
}

class _PaperViewState extends State<_PaperView> {
  final Set<int> _revealed = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const FocusBackground(slideProgress: 1.0),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _textSec,
                          size: 18,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Practice Paper',
                          style: TextStyle(
                            color: _textPrim,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.questions.length} questions',
                        style: const TextStyle(color: _textSec, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: widget.questions.length,
                    itemBuilder: (_, i) {
                      final q = widget.questions[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _QuestionCard(
                              question: q.question,
                              subject: q.subject,
                              marks: q.marks,
                              questionNumber: i + 1,
                            ),
                            const SizedBox(height: 10),
                            if (!_revealed.contains(i))
                              GestureDetector(
                                onTap: () => setState(() => _revealed.add(i)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _accent.withValues(alpha: 0.4),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline_rounded,
                                        color: _accent,
                                        size: 15,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Show Answer',
                                        style: TextStyle(
                                          color: _accent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              _ModelAnswerCard(modelAnswer: q.modelAnswer),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bg.withValues(alpha: 0), _bg],
                ),
              ),
              child: _StartButton(
                label: '✦ Finish Session',
                onTap: widget.onDone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────────────────

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatefulWidget {
  final String label, text;
  final _OptionState state;
  final VoidCallback? onTap;
  const _OptionTile({
    required this.label,
    required this.text,
    required this.state,
    this.onTap,
  });
  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _borderColor => switch (widget.state) {
    _OptionState.correct => _correct,
    _OptionState.wrong => _wrong,
    _ => Colors.white.withValues(alpha: 0.08),
  };
  Color get _bgColor => switch (widget.state) {
    _OptionState.correct => _correct.withValues(alpha: 0.15),
    _OptionState.wrong => _wrong.withValues(alpha: 0.12),
    _ => Colors.white.withValues(alpha: 0.03),
  };
  Color get _labelColor => switch (widget.state) {
    _OptionState.correct => _correct,
    _OptionState.wrong => _wrong,
    _ => _primary,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _labelColor.withValues(alpha: 0.15),
                  border: Border.all(color: _labelColor, width: 1.2),
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: _labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.state == _OptionState.idle
                        ? _textPrim
                        : widget.state == _OptionState.correct
                        ? _correct
                        : _wrong,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.state == _OptionState.correct)
                const Icon(
                  Icons.check_circle_rounded,
                  color: _correct,
                  size: 20,
                ),
              if (widget.state == _OptionState.wrong)
                const Icon(Icons.cancel_rounded, color: _wrong, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Shared UI helpers ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.googleSans(
      color: _textSec,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
}

class _StartButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _StartButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryGradBegin, AppTheme.primaryGradEnd],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded, color: _textPrim, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: _textPrim,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => _GlassContainer(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: _textPrim,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSec, fontSize: 11)),
      ],
    ),
  );
}

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
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final Widget child;
  const _GlassChip({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
