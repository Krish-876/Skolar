import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../logic/question_generator.dart';
import '../../models/math_question.dart';
import '../widgets/cg_pull_intro_overlay.dart';
import '../widgets/math_game_results_view.dart';
import '../widgets/math_game_stats_bar.dart';
import '../widgets/math_grid_painter.dart';
import '../widgets/math_keypad.dart';

class MathGamePage extends StatefulWidget {
  final bool showIntro;

  const MathGamePage({super.key, this.showIntro = true});

  @override
  State<MathGamePage> createState() => _MathGamePageState();
}

class _MathGamePageState extends State<MathGamePage>
    with SingleTickerProviderStateMixin {
  static const double _gameDurationSeconds = 60.0;

  final QuestionGenerator _generator = QuestionGenerator();
  final FocusNode _keyboardFocusNode = FocusNode();

  // Game state
  bool _showIntro = true;
  bool _isPlaying = false;
  bool _isGameOver = false;
  double _remainingSeconds = _gameDurationSeconds;
  Timer? _gameTimer;

  // Stats
  int _score = 0;
  int _totalAnswered = 0;
  int _totalCorrect = 0;

  // Current Question
  int _questionIndex = 0;
  late MathQuestion _currentQuestion;
  String _enteredInput = '';
  DateTime? _questionStartTime;

  // Feedback animation state
  bool? _lastAnswerCorrect; // null = idle, true = correct, false = wrong
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _showIntro = widget.showIntro;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _keyboardFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _initGame() {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = !_showIntro;
      _isGameOver = false;
      _remainingSeconds = _gameDurationSeconds;
      _score = 0;
      _totalAnswered = 0;
      _totalCorrect = 0;
      _questionIndex = 0;
      _enteredInput = '';
      _lastAnswerCorrect = null;
      _currentQuestion = _generator.generate(questionIndex: 0);
      _questionStartTime = DateTime.now();
    });

    if (!_showIntro) {
      _startTimer();
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = true;
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

  void _onIntroComplete() {
    setState(() {
      _showIntro = false;
    });
    _startTimer();
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
    if (!_isPlaying || _isGameOver || _lastAnswerCorrect != null) return;
    if (_enteredInput.length >= 6) return;

    final newInput = _enteredInput + digit;
    setState(() {
      _enteredInput = newInput;
    });

    // Auto-check if input matches the expected answer
    final parsed = int.tryParse(newInput);
    if (parsed != null && parsed == _currentQuestion.answer) {
      _evaluateAnswer(true, parsed);
    }
  }

  void _handleBackspace() {
    if (!_isPlaying || _isGameOver || _lastAnswerCorrect != null) return;
    if (_enteredInput.isNotEmpty) {
      setState(() {
        _enteredInput = _enteredInput.substring(0, _enteredInput.length - 1);
      });
    }
  }

  void _handleClear() {
    if (!_isPlaying || _isGameOver || _lastAnswerCorrect != null) return;
    setState(() {
      _enteredInput = '';
    });
  }

  void _handleSubmit() {
    if (!_isPlaying ||
        _isGameOver ||
        _enteredInput.isEmpty ||
        _lastAnswerCorrect != null) {
      return;
    }

    final parsed = int.tryParse(_enteredInput);
    if (parsed == null) return;

    final isCorrect = _currentQuestion.checkAnswer(parsed);
    _evaluateAnswer(isCorrect, parsed);
  }

  void _evaluateAnswer(bool isCorrect, int parsedAnswer) {
    final now = DateTime.now();
    final elapsedSec = _questionStartTime != null
        ? (now.difference(_questionStartTime!).inMilliseconds / 1000.0)
        : 2.0;

    _totalAnswered++;

    if (isCorrect) {
      HapticFeedback.lightImpact();
      _totalCorrect++;

      final basePoints = _currentQuestion.basePoints;
      final speedBonus =
          ((basePoints * 0.3) - (elapsedSec * (basePoints * 0.06)))
              .clamp(0.0, (basePoints * 0.3))
              .toInt();
      _score += basePoints + speedBonus;
      _lastAnswerCorrect = true;

      // Auto-advance quickly to next question
      Future.delayed(const Duration(milliseconds: 140), () {
        if (!mounted || !_isPlaying) return;
        setState(() {
          _questionIndex++;
          _enteredInput = '';
          _lastAnswerCorrect = null;
          _currentQuestion = _generator.generate(questionIndex: _questionIndex);
          _questionStartTime = DateTime.now();
        });
      });
    } else {
      HapticFeedback.vibrate();
      _lastAnswerCorrect = false;
      _shakeController.forward(from: 0.0);

      // Reset input for retry or advance quickly
      Future.delayed(const Duration(milliseconds: 220), () {
        if (!mounted || !_isPlaying) return;
        setState(() {
          _enteredInput = '';
          _lastAnswerCorrect = null;
        });
      });
    }

    setState(() {});
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _handleSubmit();
    } else if (key == LogicalKeyboardKey.backspace ||
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
    if (_isGameOver || _showIntro) {
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
        backgroundColor: const Color(0xFF1C1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Exit Game?',
          style: TextStyle(
            fontFamily: 'GoogleSans',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Your current progress will be lost.',
          style: TextStyle(fontFamily: 'GoogleSans', color: Color(0xFF9E9EA8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'GoogleSans',
                color: Color(0xFF9E9EA8),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Exit',
              style: TextStyle(fontFamily: 'GoogleSans'),
            ),
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

  Widget _buildMathBoard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _lastAnswerCorrect == true
              ? const Color(0xFF34C759).withValues(alpha: 0.8)
              : _lastAnswerCorrect == false
              ? const Color(0xFFFF3B30).withValues(alpha: 0.8)
              : const Color(0xFF22222B),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: CustomPaint(
          painter: const MathGridPainter(
            lineColor: Color(0xFF1C1C24),
            spacing: 48.0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child:
                  _currentQuestion.isVertical &&
                      _currentQuestion.topOperand != null &&
                      _currentQuestion.bottomOperand != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currentQuestion.topOperand!,
                          style: const TextStyle(
                            fontFamily: 'GoogleSans',
                            fontSize: 40,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF0F0F5),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${_currentQuestion.operatorSymbol ?? '+'} ',
                              style: const TextStyle(
                                fontFamily: 'GoogleSans',
                                fontSize: 34,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB0B0BD),
                              ),
                            ),
                            Text(
                              _currentQuestion.bottomOperand!,
                              style: const TextStyle(
                                fontFamily: 'GoogleSans',
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF0F0F5),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentQuestion.displayText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'GoogleSans',
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF0F0F5),
                          ),
                        ),
                        if (_currentQuestion.subtitleText != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _currentQuestion.subtitleText!,
                            style: const TextStyle(
                              fontFamily: 'GoogleSans',
                              fontSize: 12,
                              color: Color(0xFF7A7A85),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F13),
        body: SafeArea(
          child: Stack(
            children: [
              // Main Game View
              _isGameOver
                  ? MathGameResultsView(
                      finalScore: _score,
                      totalAnswered: _totalAnswered,
                      totalCorrect: _totalCorrect,
                      elapsedSeconds: _gameDurationSeconds - _remainingSeconds,
                      onPlayAgain: () {
                        setState(() {
                          _showIntro = false;
                        });
                        _initGame();
                      },
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
                        const SizedBox(height: 4),

                        // Sleek Minimal Top Stats Row
                        MathGameStatsBar(
                          score: _score,
                          solvedCount: _totalCorrect,
                          remainingSeconds: _remainingSeconds,
                          onExit: _confirmExit,
                        ),

                        const Spacer(),

                        // Central Question Math Board with subtle grid
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final sine = (_shakeController.value * 3 * 3.14159);
                            final offset =
                                (_shakeController.value > 0 &&
                                    _shakeController.value < 1)
                                ? (10.0 *
                                      (1 - _shakeController.value) *
                                      (sine).abs() *
                                      (_shakeController.value > 0.5 ? -1 : 1))
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(offset, 0),
                              child: child,
                            );
                          },
                          child: _buildMathBoard(),
                        ),

                        const SizedBox(height: 18),

                        // "TYPE OUT YOUR ANSWER" label
                        const Text(
                          'TYPE OUT YOUR ANSWER',
                          style: TextStyle(
                            fontFamily: 'GoogleSans',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Color(0xFF6E6E78),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Rounded Answer Input Field
                        Container(
                          height: 52,
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 48),
                          decoration: BoxDecoration(
                            color: const Color(0xFF23232A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _enteredInput.isNotEmpty
                                  ? const Color(0xFF4A4A58)
                                  : const Color(0xFF2C2C35),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _enteredInput.isEmpty
                              ? const Text(
                                  'Enter Answer',
                                  style: TextStyle(
                                    fontFamily: 'GoogleSans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF5A5A66),
                                  ),
                                )
                              : Text(
                                  _enteredInput,
                                  style: const TextStyle(
                                    fontFamily: 'GoogleSans',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFFFFFF),
                                    letterSpacing: 2,
                                  ),
                                ),
                        ),

                        const Spacer(),

                        // Minimal 3x4 Numeric Keypad
                        MathKeypad(
                          onDigitPressed: _handleDigitInput,
                          onBackspace: _handleBackspace,
                          onClear: _handleClear,
                          onSubmit: _handleSubmit,
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),

              // Expanding Lottie Intro Overlay
              if (_showIntro) CgPullIntroOverlay(onComplete: _onIntroComplete),
            ],
          ),
        ),
      ),
    );
  }
}
