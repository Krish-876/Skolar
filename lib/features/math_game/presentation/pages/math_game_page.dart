import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../logic/question_generator.dart';
import '../../models/math_question.dart';
import '../widgets/math_game_results_view.dart';
import '../widgets/math_game_stats_bar.dart';
import '../widgets/math_keypad.dart';

class MathGamePage extends StatefulWidget {
  const MathGamePage({super.key});

  @override
  State<MathGamePage> createState() => _MathGamePageState();
}

class _MathGamePageState extends State<MathGamePage>
    with SingleTickerProviderStateMixin {
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

  // Feedback animation state
  bool? _lastAnswerCorrect; // null = idle, true = correct, false = wrong
  int _lastScoreGained = 0;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _startNewGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _keyboardFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
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
      _lastAnswerCorrect = null;
      _lastScoreGained = 0;
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
    if (!_isPlaying || _isGameOver || _lastAnswerCorrect != null) return;
    if (_enteredInput.length >= 6) return; // Prevent excessive input
    setState(() {
      _enteredInput += digit;
    });
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
    final now = DateTime.now();
    final elapsedSec = _questionStartTime != null
        ? (now.difference(_questionStartTime!).inMilliseconds / 1000.0)
        : 2.0;

    _totalAnswered++;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
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
      _lastScoreGained = gained;
      _lastAnswerCorrect = true;

      // Advance to next question quickly
      Future.delayed(const Duration(milliseconds: 180), () {
        if (!mounted || !_isPlaying) return;
        setState(() {
          _questionIndex++;
          _enteredInput = '';
          _lastAnswerCorrect = null;
          _currentQuestion = _generator.generate(
            questionIndex: _questionIndex,
            currentStreak: _currentStreak,
          );
          _questionStartTime = DateTime.now();
        });
      });
    } else {
      HapticFeedback.vibrate();
      _currentStreak = 0;
      _lastScoreGained = 0;
      _lastAnswerCorrect = false;
      _shakeController.forward(from: 0.0);

      // Advance to next question
      Future.delayed(const Duration(milliseconds: 260), () {
        if (!mounted || !_isPlaying) return;
        setState(() {
          _questionIndex++;
          _enteredInput = '';
          _lastAnswerCorrect = null;
          _currentQuestion = _generator.generate(
            questionIndex: _questionIndex,
            currentStreak: _currentStreak,
          );
          _questionStartTime = DateTime.now();
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
            fontFamily: 'ClashDisplay',
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
    Color borderColor = Colors.white.withValues(alpha: 0.1);
    Color cardBg = const Color(0xFF141320);

    if (_lastAnswerCorrect == true) {
      borderColor = const Color(0xFF34C759);
      cardBg = const Color(0xFF0F2618);
    } else if (_lastAnswerCorrect == false) {
      borderColor = const Color(0xFFFF3B30);
      cardBg = const Color(0xFF2B1216);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          if (_lastAnswerCorrect == true)
            BoxShadow(
              color: const Color(0xFF34C759).withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            )
          else if (_lastAnswerCorrect == false)
            BoxShadow(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Question Type Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8C38E5).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFB388FF).withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _currentQuestion.type.displayName,
              style: const TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB388FF),
                letterSpacing: 1.5,
              ),
            ),
          ),

          if (_currentQuestion.subtitleText != null) ...[
            const SizedBox(height: 6),
            Text(
              _currentQuestion.subtitleText!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white54,
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Main Big Math Prompt
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
            child: Text(
              _currentQuestion.displayText,
              key: ValueKey(_currentQuestion.displayText),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Answer Input Display Box
          Container(
            height: 62,
            constraints: const BoxConstraints(minWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0B14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _enteredInput.isNotEmpty
                    ? const Color(0xFF8C38E5)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Center(
              child: _enteredInput.isEmpty
                  ? Text(
                      '?',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    )
                  : Text(
                      _enteredInput,
                      style: const TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ],
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
                    // Top stats header & 60s countdown bar
                    MathGameStatsBar(
                      score: _score,
                      currentStreak: _currentStreak,
                      remainingSeconds: _remainingSeconds,
                      totalSeconds: _gameDurationSeconds,
                      onExit: _confirmExit,
                    ),

                    const Spacer(flex: 1),

                    // Floating Score / Combo animation
                    if (_lastAnswerCorrect == true && _lastScoreGained > 0)
                      Text(
                            '+$_lastScoreGained',
                            style: const TextStyle(
                              fontFamily: 'ClashDisplay',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34C759),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 100.ms)
                          .moveY(begin: 10, end: -20, duration: 250.ms)
                          .fadeOut(delay: 150.ms, duration: 150.ms)
                    else
                      const SizedBox(height: 28),

                    // Central Question Card with shake animation on wrong answer
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final sine = (_shakeController.value * 3 * 3.14159);
                        final offset =
                            (_shakeController.value > 0 &&
                                _shakeController.value < 1)
                            ? (12.0 *
                                  (1 - _shakeController.value) *
                                  (sine).abs() *
                                  (_shakeController.value > 0.5 ? -1 : 1))
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: _buildQuestionCard(),
                    ),

                    const Spacer(flex: 2),

                    // Tactile 3x4 Keypad
                    MathKeypad(
                      onDigitPressed: _handleDigitInput,
                      onBackspace: _handleBackspace,
                      onClear: _handleClear,
                      onSubmit: _handleSubmit,
                      isSubmitEnabled:
                          _enteredInput.isNotEmpty &&
                          _lastAnswerCorrect == null,
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ),
    );
  }
}
