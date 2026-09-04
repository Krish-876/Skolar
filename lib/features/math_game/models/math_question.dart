enum MathQuestionType {
  addition,
  subtraction,
  multiplication,
  division,
  lcm,
  hcf;

  String get displayName {
    switch (this) {
      case MathQuestionType.addition:
        return 'ADDITION';
      case MathQuestionType.subtraction:
        return 'SUBTRACTION';
      case MathQuestionType.multiplication:
        return 'MULTIPLICATION';
      case MathQuestionType.division:
        return 'DIVISION';
      case MathQuestionType.lcm:
        return 'LCM';
      case MathQuestionType.hcf:
        return 'HCF';
    }
  }

  String get symbol {
    switch (this) {
      case MathQuestionType.addition:
        return '+';
      case MathQuestionType.subtraction:
        return '−';
      case MathQuestionType.multiplication:
        return '×';
      case MathQuestionType.division:
        return '÷';
      case MathQuestionType.lcm:
        return 'LCM';
      case MathQuestionType.hcf:
        return 'HCF';
    }
  }
}

class MathQuestion {
  final String displayText;
  final String? subtitleText;
  final int answer;
  final MathQuestionType type;
  final int difficultyLevel;

  const MathQuestion({
    required this.displayText,
    this.subtitleText,
    required this.answer,
    required this.type,
    required this.difficultyLevel,
  });

  bool checkAnswer(int userAnswer) => userAnswer == answer;
}
