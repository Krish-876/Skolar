import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../logic/question_generator.dart';
import '../../models/math_question.dart';
import '../../services/math_game_high_score_service.dart';
import '../widgets/math_game_results_view.dart';
import '../widgets/math_game_stats_bar.dart';
import '../widgets/math_grid_painter.dart';
import '../widgets/math_keypad.dart';

class MathGamePage extends StatefulWidget {
  const MathGamePage({super.key});

  @override
  State<MathGamePage> createState() => _MathGamePageState();
}

class _MathGamePageState extends State<MathGamePage> {
  static const double _gameDurationSeconds = 60.0;

  final QuestionGenerator _generator = QuestionGenerator();
  final FocusNode _keyboardFocusNode = FocusNode();

  // Game state
  bool _isPlaying = false;
  bool _isGameOver = false;
  double _remainingSeconds = _gameDurationSeconds;
  Timer? _gameTimer;

  // Stats
  int _score = 0;
  int _currentStreak = 0;
  int _highestStreak = 0;
  int _totalAnswered = 0;
  int _totalCorrect = 0;

  // Current Question
  int _questionIndex = 0;
  late MathQuestion _currentQuestion;
  String _enteredInput = '';
  DateTime? _questionStartTime;

  // Best score (persisted locally, shown in the header's right badge)
  int _bestScore = 0;

  @override
  void initState() {
    super.initState();
    _startNewGame();
    _loadBestScore();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    final best = await MathGameHighScoreService.getBestScore();
    if (mounted) {
      setState(() => _bestScore = best);
    }
  }

  void _startNewGame() {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _remainingSeconds = _gameDurationSeconds;
      _score = 0;
      _currentStreak = 0;
      _highestStreak = 0;
      _totalAnswered = 0;
      _totalCorrect = 0;
      _questionIndex = 0;
      _enteredInput = '';
      _currentQuestion = _generator.generate(
        questionIndex: 0,
        currentStreak: 0,
      );
      _questionStartTime = DateTime.now();
    });

    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds -= 0.1;
        if (_remainingSeconds <= 0.05) {
          _remainingSeconds = 0;
          _endGame();
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
    HapticFeedback.heavyImpact();
  }

  void _handleDigitInput(String digit) {
    if (!_isPlaying || _isGameOver) return;
    if (_enteredInput.length >= 6) return; // Prevent excessive input
    setState(() {
      _enteredInput += digit;
    });
    _maybeAutoAdvance();
  }

  void _handleBackspace() {
    if (!_isPlaying || _isGameOver) return;
    if (_enteredInput.isNotEmpty) {
      setState(() {
        _enteredInput = _enteredInput.substring(0, _enteredInput.length - 1);
      });
    }
  }

  void _handleClear() {
    if (!_isPlaying || _isGameOver) return;
    setState(() {
      _enteredInput = '';
    });
  }

  /// Checks the current input against the answer and, if it matches, scores
  /// the question and instantly jumps to the next one — no manual submit
  /// step, no delay, no intermediate feedback state.
  void _maybeAutoAdvance() {
    if (!_isPlaying || _isGameOver) return;
    if (_enteredInput != _currentQuestion.answer.toString()) return;

    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final elapsedSec = _questionStartTime != null
        ? (now.difference(_questionStartTime!).inMilliseconds / 1000.0)
        : 2.0;

    _totalAnswered++;
    _totalCorrect++;
    _currentStreak++;
    if (_currentStreak > _highestStreak) {
      _highestStreak = _currentStreak;
    }

    // Calculate speed and streak bonuses
    const basePoints = 100;
    final speedBonus = (50 - (elapsedSec * 12)).clamp(0, 50).toInt();
    final streakBonus = _currentStreak * 15;
    final gained = basePoints + speedBonus + streakBonus;

    _score += gained;
    if (_score > _bestScore) {
      _bestScore = _score;
    }
    MathGameHighScoreService.setBestScoreIfHigher(_score);

    _questionIndex++;
    setState(() {
      _enteredInput = '';
      _currentQuestion = _generator.generate(
        questionIndex: _questionIndex,
        currentStreak: _currentStreak,
      );
      _questionStartTime = DateTime.now();
    });
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _handleBackspace();
    } else if (key == LogicalKeyboardKey.escape) {
      _confirmExit();
    } else {
      final char = event.character;
      if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
        _handleDigitInput(char);
      }
    }
  }

  Future<void> _confirmExit() async {
    if (_isGameOver) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Quit Game?',
          style: TextStyle(
            fontFamily: 'GoogleSans',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Your current 60s session progress will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Keep Playing',
              style: TextStyle(color: Color(0xFFB388FF)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            child: const Text('Quit'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      _gameTimer?.cancel();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  Widget _buildQuestionCard() {
    final lines = _currentQuestion.stackedLines;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final line in lines)
              Text(
                line,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'GoogleSans',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
          ],
        ),

        const SizedBox(height: 32),

        const Text(
          'TYPE OUT YOUR ANSWER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 12),

        // Read-only answer display, driven entirely by the keypad
        Container(
          width: double.infinity,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Center(
            child: Text(
              _enteredInput.isEmpty ? 'Enter Answer' : _enteredInput,
              style: TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _enteredInput.isEmpty ? Colors.white38 : Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _isGameOver
              ? MathGameResultsView(
                  finalScore: _score,
                  totalAnswered: _totalAnswered,
                  totalCorrect: _totalCorrect,
                  highestStreak: _highestStreak,
                  elapsedSeconds: _gameDurationSeconds - _remainingSeconds,
                  onPlayAgain: _startNewGame,
                  onExit: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                )
              : Column(
                  children: [
                    // Top "VS" header & countdown pill
                    MathGameStatsBar(
                      score: _score,
                      bestScore: _bestScore,
                      remainingSeconds: _remainingSeconds,
                      totalSeconds: _gameDurationSeconds,
                      onExit: _confirmExit,
                    ),

                    const SizedBox(height: 24),

                    // Central stacked-equation display over a faint grid
                    Expanded(
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: CustomPaint(painter: MathGridPainter()),
                          ),
                          Center(child: _buildQuestionCard()),
                        ],
                      ),
                    ),

                    // Numeric keypad — no submit button, input auto-checks
                    MathKeypad(
                      onDigitPressed: _handleDigitInput,
                      onBackspace: _handleBackspace,
                      onClear: _handleClear,
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ),
    );
  }
}
