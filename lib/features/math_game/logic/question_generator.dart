import 'dart:math';
import '../models/math_question.dart';

class QuestionGenerator {
  final Random _random;

  QuestionGenerator([Random? random]) : _random = random ?? Random();

  /// Calculates GCD / HCF using Euclidean algorithm
  static int gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  /// Calculates LCM
  static int lcm(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return (a * b) ~/ gcd(a, b);
  }

  /// Generates a question based on the question index and current streak.
  MathQuestion generate({
    required int questionIndex,
    required int currentStreak,
    MathQuestionType? forcedType,
  }) {
    // Difficulty level scales from 1 (easy) to 3 (moderate mental math)
    final difficulty = _determineDifficulty(questionIndex, currentStreak);

    // Pick a random question type among the 6 types (or forcedType for testing)
    final type =
        forcedType ??
        MathQuestionType.values[_random.nextInt(
          MathQuestionType.values.length,
        )];

    switch (type) {
      case MathQuestionType.addition:
        return _generateAddition(difficulty);
      case MathQuestionType.subtraction:
        return _generateSubtraction(difficulty);
      case MathQuestionType.multiplication:
        return _generateMultiplication(difficulty);
      case MathQuestionType.division:
        return _generateDivision(difficulty);
      case MathQuestionType.lcm:
        return _generateLcm(difficulty);
      case MathQuestionType.hcf:
        return _generateHcf(difficulty);
    }
  }

  int _determineDifficulty(int questionIndex, int currentStreak) {
    if (questionIndex < 4) return 1;
    if (questionIndex < 10 && currentStreak < 5) return 1;
    if (questionIndex < 18 || currentStreak < 8) return 2;
    return 3;
  }

  MathQuestion _generateAddition(int difficulty) {
    int a, b;
    switch (difficulty) {
      case 1:
        // Single and small double-digits
        a = _random.nextInt(15) + 6; // 6 - 20
        b = _random.nextInt(15) + 4; // 4 - 18
        break;
      case 2:
        // Classic two-digit addition (e.g., 24 + 37, 48 + 36)
        a = _random.nextInt(50) + 18; // 18 - 67
        b = _random.nextInt(40) + 15; // 15 - 54
        break;
      case 3:
      default:
        // Larger two-digit / small 3-digit (e.g., 78 + 59, 156 + 82)
        if (_random.nextBool()) {
          a = _random.nextInt(70) + 45; // 45 - 114
          b = _random.nextInt(60) + 38; // 38 - 97
        } else {
          a = _random.nextInt(90) + 110; // 110 - 199
          b = _random.nextInt(60) + 40; // 40 - 99
        }
        break;
    }

    return MathQuestion(
      displayText: '$a + $b',
      answer: a + b,
      type: MathQuestionType.addition,
      difficultyLevel: difficulty,
    );
  }

  MathQuestion _generateSubtraction(int difficulty) {
    int a, b;
    switch (difficulty) {
      case 1:
        // Simple subtraction with positive answers
        a = _random.nextInt(25) + 12; // 12 - 36
        b = _random.nextInt(a - 4) + 3; // 3 - (a-2)
        break;
      case 2:
        // Two-digit subtraction with regrouping (e.g. 73 - 28)
        a = _random.nextInt(60) + 35; // 35 - 94
        b = _random.nextInt(a - 15) + 12; // 12 - (a-4)
        break;
      case 3:
      default:
        // Three-digit or large two-digit subtraction (e.g. 145 - 67)
        if (_random.nextBool()) {
          a = _random.nextInt(80) + 120; // 120 - 199
          b = _random.nextInt(60) + 35; // 35 - 94
        } else {
          a = _random.nextInt(50) + 65; // 65 - 114
          b = _random.nextInt(a - 20) + 25;
        }
        break;
    }

    return MathQuestion(
      displayText: '$a − $b',
      answer: a - b,
      type: MathQuestionType.subtraction,
      difficultyLevel: difficulty,
    );
  }

  MathQuestion _generateMultiplication(int difficulty) {
    int a, b;
    switch (difficulty) {
      case 1:
        // Single digit multiplication (e.g., 7 × 8, 6 × 9)
        a = _random.nextInt(7) + 3; // 3 - 9
        b = _random.nextInt(7) + 3; // 3 - 9
        break;
      case 2:
        // 10-12 tables or single digit × 11-13 (e.g., 12 × 9, 11 × 8)
        if (_random.nextBool()) {
          a = _random.nextInt(3) + 11; // 11, 12, 13
          b = _random.nextInt(7) + 4; // 4 - 10
        } else {
          a = _random.nextInt(7) + 4;
          b = _random.nextInt(3) + 11;
        }
        break;
      case 3:
      default:
        // Friendly teen multiplication (e.g., 17 × 6, 14 × 8, 16 × 7)
        final teens = [13, 14, 15, 16, 17, 18, 19];
        a = teens[_random.nextInt(teens.length)];
        b = _random.nextInt(6) + 4; // 4 - 9
        break;
    }

    return MathQuestion(
      displayText: '$a × $b',
      answer: a * b,
      type: MathQuestionType.multiplication,
      difficultyLevel: difficulty,
    );
  }

  MathQuestion _generateDivision(int difficulty) {
    int divisor, quotient;
    switch (difficulty) {
      case 1:
        // Basic single-digit tables (e.g., 72 ÷ 8, 42 ÷ 6)
        divisor = _random.nextInt(7) + 3; // 3 - 9
        quotient = _random.nextInt(7) + 3; // 3 - 9
        break;
      case 2:
        // Larger dividends / 11-12 tables (e.g., 144 ÷ 12, 96 ÷ 6, 108 ÷ 9)
        if (_random.nextBool()) {
          divisor = _random.nextInt(4) + 6; // 6, 7, 8, 9
          quotient = _random.nextInt(6) + 11; // 11 - 16
        } else {
          divisor = 12;
          quotient = _random.nextInt(8) + 5; // 5 - 12
        }
        break;
      case 3:
      default:
        // Friendly 2-digit quotients (e.g., 135 ÷ 9, 150 ÷ 6, 96 ÷ 8)
        divisor = _random.nextInt(8) + 5; // 5 - 12
        quotient = _random.nextInt(10) + 12; // 12 - 21
        break;
    }

    final dividend = divisor * quotient;

    return MathQuestion(
      displayText: '$dividend ÷ $divisor',
      answer: quotient,
      type: MathQuestionType.division,
      difficultyLevel: difficulty,
    );
  }

  MathQuestion _generateLcm(int difficulty) {
    // Mental-friendly pairs curated for rapid solving
    const level1Pairs = [
      (4, 6),
      (6, 8),
      (3, 4),
      (2, 6),
      (3, 5),
      (4, 8),
      (2, 8),
      (5, 10),
    ];

    const level2Pairs = [
      (6, 9),
      (8, 12),
      (9, 12),
      (4, 10),
      (6, 10),
      (10, 15),
      (8, 10),
      (6, 12),
    ];

    const level3Pairs = [
      (12, 15),
      (10, 25),
      (9, 15),
      (12, 16),
      (15, 20),
      (12, 18),
      (14, 21),
    ];

    final List<(int, int)> list;
    switch (difficulty) {
      case 1:
        list = level1Pairs;
        break;
      case 2:
        list = level2Pairs;
        break;
      case 3:
      default:
        list = level3Pairs;
        break;
    }

    final pair = list[_random.nextInt(list.length)];
    final a = _random.nextBool() ? pair.$1 : pair.$2;
    final b = (a == pair.$1) ? pair.$2 : pair.$1;
    final answer = lcm(a, b);

    return MathQuestion(
      displayText: 'LCM($a, $b)',
      subtitleText: 'Least Common Multiple',
      answer: answer,
      type: MathQuestionType.lcm,
      difficultyLevel: difficulty,
    );
  }

  MathQuestion _generateHcf(int difficulty) {
    // Mental-friendly pairs with clean GCDs
    const level1Pairs = [
      (12, 18),
      (6, 9),
      (8, 12),
      (10, 15),
      (14, 21),
      (9, 15),
      (16, 20),
    ];

    const level2Pairs = [
      (16, 24),
      (18, 27),
      (20, 30),
      (18, 24),
      (15, 25),
      (24, 32),
      (21, 28),
      (20, 35),
    ];

    const level3Pairs = [
      (24, 36),
      (28, 42),
      (30, 45),
      (32, 48),
      (36, 48),
      (40, 60),
      (35, 50),
    ];

    final List<(int, int)> list;
    switch (difficulty) {
      case 1:
        list = level1Pairs;
        break;
      case 2:
        list = level2Pairs;
        break;
      case 3:
      default:
        list = level3Pairs;
        break;
    }

    final pair = list[_random.nextInt(list.length)];
    final a = _random.nextBool() ? pair.$1 : pair.$2;
    final b = (a == pair.$1) ? pair.$2 : pair.$1;
    final answer = gcd(a, b);

    return MathQuestion(
      displayText: 'HCF($a, $b)',
      subtitleText: 'Highest Common Factor',
      answer: answer,
      type: MathQuestionType.hcf,
      difficultyLevel: difficulty,
    );
  }
}
