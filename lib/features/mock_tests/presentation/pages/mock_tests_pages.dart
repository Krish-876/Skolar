import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova/core/theme/app_theme.dart';
import 'package:nova/features/mock_tests/presentation/providers/mock_tests_provider.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String subject;
  final int marks;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.subject,
    required this.marks,
  });
}

// _mockQuestions removed — questions are now fetched dynamically from
// POST /generate-batch via MockTestNotifier (see mock_test_provider.dart).

// ── Theme constants ───────────────────────────────────────────────────────────

const _bg         = Color(0xFF05061A);
const _primary    = Color(0xFF1E2A8A);
const _surface    = Color(0xFF2E2B3E);
const _surfaceLight = Color(0xFF3A3750);
const _accent     = Color(0xFF63C8D4);
const _textPrim   = Color(0xFFFFFFFF);
const _textSec    = Color(0xFFA8C4FF);
const _correct    = Color(0xFF4CAF50);
const _wrong      = Color(0xFFD0021B);
const _gradBegin  = Color(0xFF1E2A8A);
const _gradEnd    = Color(0xFF2E3DA0);
const _cardBg     = Color(0xFF0D1440);

// ── Entry point ───────────────────────────────────────────────────────────────

/// Subjects available in the mock test selector.
/// Extend this list as you add more subjects to the question bank.
const _kSubjects = [
  'Artificial Intelligence',
  'Computer Science',
  'Mathematics',
  'Physics',
  'Chemistry',
];

class MockTestPage extends ConsumerStatefulWidget {
  const MockTestPage({super.key});

  @override
  ConsumerState<MockTestPage> createState() => _MockTestPageState();
}

class _MockTestPageState extends ConsumerState<MockTestPage> {
  String _selectedSubject = _kSubjects.first;
  int _questionCount = 5;

  @override
  Widget build(BuildContext context) {
    final mockState = ref.watch(mockTestProvider);

    // ── Quiz in progress ──
    if (mockState.hasQuestions) {
      return _QuizFlow(questions: mockState.questions);
    }

    // ── Loading ──
    if (mockState.isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            const _GlowBlob(top: -180, left: -100, size: 400, color: Color(0x885E1B89)),
            const _GlowBlob(top: 100, right: -280, size: 480, color: Color(0x663416E2)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Generating your $_selectedSubject\nmock test…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textSec,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Analysing PYQs with DICL pipeline',
                    style: TextStyle(color: _textSec, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Error ──
    if (mockState.error != null) {
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
                  mockState.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textSec, fontSize: 13),
                ),
                const SizedBox(height: 24),
                _StartButton(
                  label: 'Retry',
                  onTap: () => _start(ref),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.read(mockTestProvider.notifier).reset(),
                  child: const Text('Change subject',
                      style: TextStyle(color: _textSec)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Setup screen (default) ──
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _GlowBlob(top: -180, left: -100, size: 400, color: Color(0x885E1B89)),
          const _GlowBlob(top: 100, right: -280, size: 480, color: Color(0x663416E2)),
          const _GlowBlob(bottom: -80, left: -60, size: 360, color: Color(0x4400D4FF)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _textSec, size: 18),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mock Test',
                    style: GoogleFonts.googleSansFlex(
                      fontSize: 35,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI-generated from your college PYQs',
                    style: GoogleFonts.googleSans(color: _textSec, fontSize: 14),
                  ),
                  const SizedBox(height: 36),

                  // Subject picker
                  Text('Subject',
                      style: GoogleFonts.googleSans(
                          color: _textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSubject,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1B2E),
                        style: const TextStyle(color: _textPrim, fontSize: 15),
                        iconEnabledColor: _textSec,
                        items: _kSubjects
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedSubject = v!),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Question count
                  Row(
                    children: [
                      Text('Questions',
                          style: GoogleFonts.googleSans(
                              color: _textSec,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                      const Spacer(),
                      _GlassChip(
                        child: Text(
                          '$_questionCount',
                          style: const TextStyle(
                              color: _textPrim,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
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
                      overlayColor: _accent.withOpacity(0.15),
                    ),
                    child: Slider(
                      min: 3,
                      max: 10,
                      divisions: 7,
                      value: _questionCount.toDouble(),
                      onChanged: (v) =>
                          setState(() => _questionCount = v.round()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('3', style: TextStyle(color: _textSec, fontSize: 11)),
                      Text('10', style: TextStyle(color: _textSec, fontSize: 11)),
                    ],
                  ),

                  const Spacer(),

                  _StartButton(
                    label: 'Start Test',
                    onTap: () => _start(ref),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Generation takes ~${_questionCount * 4}s',
                      style: const TextStyle(color: _textSec, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _start(WidgetRef ref) {
    ref.read(mockTestProvider.notifier).fetchQuestions(
          MockTestRequest(
            subject: _selectedSubject,
            count: _questionCount,
          ),
        );
  }
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
          gradient: const LinearGradient(colors: [AppTheme.primaryGradBegin,AppTheme.primaryGradEnd]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.4),
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

// ── Quiz flow state ───────────────────────────────────────────────────────────

class _QuizFlow extends ConsumerStatefulWidget {
  final List<QuizQuestion> questions;

  const _QuizFlow({required this.questions});

  @override
  ConsumerState<_QuizFlow> createState() => _QuizFlowState();
}

class _QuizFlowState extends ConsumerState<_QuizFlow> {
  int _current = 0;
  int _score   = 0;
  bool _done   = false;
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

  void _restart() {
    // Return to the setup screen so the user can generate a fresh test.
    ref.read(mockTestProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Glow blobs
          const _GlowBlob(top: -180, left: -100, size: 400,
              color: Color(0x885E1B89)),
          const _GlowBlob(top: 100, right: -280, size: 480,
              color: Color(0x663416E2)),
          const _GlowBlob(bottom: -80, left: -60, size: 360,
              color: Color(0x4400D4FF)),
          SafeArea(
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
                  ? _ResultScreen(
                      key: const ValueKey('result'),
                      score: _score,
                      total: widget.questions.fold(0, (s, q) => s + q.marks),
                      answers: _answers,
                      questions: widget.questions,
                      onRestart: _restart,
                    )
                  : _QuestionScreen(
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
        ],
      ),
    );
  }
}

// ── Question screen ───────────────────────────────────────────────────────────

class _QuestionScreen extends StatefulWidget {
  final QuizQuestion question;
  final int index;
  final int total;
  final int score;
  final int? picked;
  final ValueChanged<int> onAnswer;

  const _QuestionScreen({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.score,
    required this.picked,
    required this.onAnswer,
  });

  @override
  State<_QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<_QuestionScreen>
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
    final progress = (widget.index + 1) / widget.total;

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _textSec, size: 18),
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
                        value: progress,
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
              // Score chip
              _GlassChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Color(0xFFF5C518), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.score}',
                      style: const TextStyle(
                          color: _textPrim,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Timer ──
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) {
            final pulse = _seconds <= 7
                ? 1.0 + _pulseCtrl.value * 0.15
                : 1.0;
            return Transform.scale(
              scale: pulse,
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
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Question card ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TagChip(label: q.subject),
                    const SizedBox(width: 8),
                    _TagChip(label: '${q.marks}M'),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  q.question,
                  style: const TextStyle(
                    color: _textPrim,
                    fontSize: 16,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Options ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: q.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
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

// ── Option tile ───────────────────────────────────────────────────────────────

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatefulWidget {
  final String label;
  final String text;
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
    _scale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _borderColor {
    return switch (widget.state) {
      _OptionState.correct => _correct,
      _OptionState.wrong   => _wrong,
      _OptionState.idle    => Colors.white.withOpacity(0.08),
    };
  }

  Color get _bgColor {
    return switch (widget.state) {
      _OptionState.correct => _correct.withOpacity(0.15),
      _OptionState.wrong   => _wrong.withOpacity(0.12),
      _OptionState.idle    => Colors.white.withOpacity(0.03),
    };
  }

  Color get _labelColor {
    return switch (widget.state) {
      _OptionState.correct => _correct,
      _OptionState.wrong   => _wrong,
      _OptionState.idle    => _primary,
    };
  }

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
                  color: _labelColor.withOpacity(0.15),
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
                const Icon(Icons.check_circle_rounded,
                    color: _correct, size: 20),
              if (widget.state == _OptionState.wrong)
                const Icon(Icons.cancel_rounded, color: _wrong, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Result screen ─────────────────────────────────────────────────────────────

class _ResultScreen extends StatefulWidget {
  final int score;
  final int total;
  final List<int?> answers;
  final List<QuizQuestion> questions;
  final VoidCallback onRestart;

  const _ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.answers,
    required this.questions,
    required this.onRestart,
  });

  @override
  State<_ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<_ResultScreen>
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
    
    // Fire burst if score meets or exceeds 70% threshold
    if (widget.score / widget.total >= 0.7) {
      _confettiCtrl.play();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  String get _grade {
    final pct = widget.score / widget.total;
    if (pct >= 0.9) return 'Outstanding';
    if (pct >= 0.7) return 'Great Work';
    if (pct >= 0.5) return 'Keep Going';
    return 'Try Again';
  }

  Color get _gradeColor {
    final pct = widget.score / widget.total;
    if (pct >= 0.9) return _accent;
    if (pct >= 0.7) return const Color(0xFF5B6EF5);
    if (pct >= 0.5) return const Color(0xFFF5C518);
    return _wrong;
  }

  int get _correct => widget.answers
      .asMap()
      .entries
      .where((e) =>
          e.value != null &&
          e.value == widget.questions[e.key].correctIndex)
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
          colors: const [_accent, Color(0xFF5B6EF5), Color(0xFFF5C518), Colors.white],
          gravity: 0.2,
          numberOfParticles: 20,
          minimumSize: const Size(6, 6),
          maximumSize: const Size(10, 10),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Score ring
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
                                color: _textSec, fontSize: 13),
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
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '$_correct / ${widget.questions.length} correct',
                style: const TextStyle(color: _textSec, fontSize: 14),
              ),

              const SizedBox(height: 32),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_rounded,
                      iconColor: _correct_color,
                      label: 'Correct',
                      value: '$_correct',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.cancel_rounded,
                      iconColor: _wrong,
                      label: 'Wrong',
                      value:
                          '${widget.answers.where((a) => a != null).length - _correct}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.radio_button_unchecked,
                      iconColor: _textSec,
                      label: 'Skipped',
                      value:
                          '${widget.answers.where((a) => a == null).length}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Restart button
              GestureDetector(
                onTap: widget.onRestart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_gradBegin, _gradEnd],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, color: _textPrim, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'New Test',
                        style: TextStyle(
                          color: _textPrim,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _correct_color = _correct;

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
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
          Text(label,
              style: const TextStyle(color: _textSec, fontSize: 11)),
        ],
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

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    // Progress arc
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
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
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
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _primary.withOpacity(0.5),
          width: 1,
         ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _textSec,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final Color color;

  const _GlowBlob({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}