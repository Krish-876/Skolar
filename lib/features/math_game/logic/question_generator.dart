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

  /// Determines question type following the progressive difficulty sequence:
  /// Addition -> Subtraction -> Multiplication -> Division -> LCM -> HCF
  MathQuestionType determineType(int questionIndex) {
    if (questionIndex < 4) {
      return MathQuestionType.addition;
    } else if (questionIndex < 8) {
      return MathQuestionType.subtraction;
    } else if (questionIndex < 13) {
      return MathQuestionType.multiplication;
    } else if (questionIndex < 18) {
      return MathQuestionType.division;
    } else if (questionIndex < 24) {
      return MathQuestionType.lcm;
    } else {
      // For question 25+, alternate between high-tier LCM & HCF
      return (questionIndex % 2 == 0)
          ? MathQuestionType.hcf
          : MathQuestionType.lcm;
    }
  }

  /// Generates a question based on the question index.
  MathQuestion generate({
    required int questionIndex,
    MathQuestionType? forcedType,
  }) {
    final type = forcedType ?? determineType(questionIndex);
    final difficulty = _determineDifficulty(questionIndex, type);

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

  int _determineDifficulty(int questionIndex, MathQuestionType type) {
    // Within each category, progressively ramp up from difficulty 1 to 3
    int offset = 0;
    switch (type) {
      case MathQuestionType.addition:
        offset = questionIndex;
        break;
      case MathQuestionType.subtraction:
        offset = questionIndex - 4;
        break;
      case MathQuestionType.multiplication:
        offset = questionIndex - 8;
        break;
      case MathQuestionType.division:
        offset = questionIndex - 13;
        break;
      case MathQuestionType.lcm:
        offset = questionIndex - 18;
        break;
      case MathQuestionType.hcf:
        offset = questionIndex - 24;
        break;
    }

    if (offset <= 1) return 1;
    if (offset <= 3) return 2;
    return 3;
  }

  int _calculateBasePoints(MathQuestionType type, int difficulty) {
    return type.baseDifficultyWeight + ((difficulty - 1) * 30);
  }

  MathQuestion _generateAddition(int difficulty) {
    int a, b;
    switch (difficulty) {
      case 1:
        a = _random.nextInt(15) + 6; // 6 - 20
        b = _random.nextInt(15) + 4; // 4 - 18
        break;
      case 2:
        a = _random.nextInt(50) + 18; // 18 - 67
        b = _random.nextInt(40) + 15; // 15 - 54
        break;
      case 3:
      default:
        if (_random.nextBool()) {
          a = _random.nextInt(70) + 45; // 45 - 114
          b = _random.nextInt(60) + 38; // 38 - 97
        } else {
          a = _random.nextInt(90) + 110; // 110 - 199
          b = _random.nextInt(60) + 40; // 40 - 99
        }
        break;
    }

    final points = _calculateBasePoints(MathQuestionType.addition, difficulty);

    return MathQuestion(
      topOperand: '$a',
      bottomOperand: '$b',
      operatorSymbol: '+',
      displayText: '$a + $b',
      answer: a + b,
      type: MathQuestionType.addition,
      difficultyLevel: difficulty,
      basePoints: points,
      isVertical: true,
    );
  }

  MathQuestion _generateSubtraction(int difficulty) {
    int a, b;
    switch (difficulty) {
      case 1:
        a = _random.nextInt(25) + 12; // 12 - 36
        b = _random.nextInt(a - 6) + 3; // 3 to a-4
        break;
      case 2:
        a = _random.nextInt(60) + 35; // 35 - 94
        b = _random.nextInt(a - 20) + 15; // 15 to a-6
        break;
      case 3:
      default:
        if (_random.nextBool()) {
          a = _random.nextInt(80) + 120; // 120 - 199
          b = _random.nextInt(65) + 35; // 35 - 99
        } else {
          a = _random.nextInt(40) + 75; // 75 - 114
          b = _random.nextInt(a - 30) + 25; // 25 to a-6
        }
        break;
    }

    final points = _calculateBasePoints(
      MathQuestionType.subtraction,
      difficulty,
    );

    return MathQuestion(
      topOperand: '$a',
      bottomOperand: '$b',
      operatorSymbol: '−',
      displayText: '$a − $b',
      answer: a - b,
      type: MathQuestionType.subtraction,
      difficultyLevel: difficulty,
      basePoints: points,
      isVertical: true,
    );
  }

  MathQuestion _generateMultiplication(int difficulty) {
    int a, b;
    switch (difficulty) {
      case 1:
        a = _random.nextInt(7) + 3; // 3 - 9
        b = _random.nextInt(7) + 3; // 3 - 9
        break;
      case 2:
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
        final teens = [13, 14, 15, 16, 17, 18, 19];
        a = teens[_random.nextInt(teens.length)];
        b = _random.nextInt(6) + 4; // 4 - 9
        break;
    }

    final points = _calculateBasePoints(
      MathQuestionType.multiplication,
      difficulty,
    );

    return MathQuestion(
      topOperand: '$a',
      bottomOperand: '$b',
      operatorSymbol: '×',
      displayText: '$a × $b',
      answer: a * b,
      type: MathQuestionType.multiplication,
      difficultyLevel: difficulty,
      basePoints: points,
      isVertical: true,
    );
  }

  MathQuestion _generateDivision(int difficulty) {
    int divisor, quotient;
    switch (difficulty) {
      case 1:
        divisor = _random.nextInt(7) + 3; // 3 - 9
        quotient = _random.nextInt(7) + 3; // 3 - 9
        break;
      case 2:
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
        divisor = _random.nextInt(8) + 5; // 5 - 12
        quotient = _random.nextInt(10) + 12; // 12 - 21
        break;
    }

    final dividend = divisor * quotient;
    final points = _calculateBasePoints(MathQuestionType.division, difficulty);

    return MathQuestion(
      displayText: '$dividend ÷ $divisor',
      answer: quotient,
      type: MathQuestionType.division,
      difficultyLevel: difficulty,
      basePoints: points,
      isVertical: false,
    );
  }

  MathQuestion _generateLcm(int difficulty) {
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
    final points = _calculateBasePoints(MathQuestionType.lcm, difficulty);

    return MathQuestion(
      displayText: 'LCM($a, $b)',
      subtitleText: 'Least Common Multiple',
      answer: answer,
      type: MathQuestionType.lcm,
      difficultyLevel: difficulty,
      basePoints: points,
      isVertical: false,
    );
  }

  MathQuestion _generateHcf(int difficulty) {
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
    final points = _calculateBasePoints(MathQuestionType.hcf, difficulty);

    return MathQuestion(
      displayText: 'HCF($a, $b)',
      subtitleText: 'Highest Common Factor',
      answer: answer,
      type: MathQuestionType.hcf,
      difficultyLevel: difficulty,
      basePoints: points,
      isVertical: false,
    );
  }
}
