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
        return 'Addition';
      case MathQuestionType.subtraction:
        return 'Subtraction';
      case MathQuestionType.multiplication:
        return 'Multiplication';
      case MathQuestionType.division:
        return 'Division';
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

  int get baseDifficultyWeight {
    switch (this) {
      case MathQuestionType.addition:
        return 100;
      case MathQuestionType.subtraction:
        return 130;
      case MathQuestionType.multiplication:
        return 170;
      case MathQuestionType.division:
        return 220;
      case MathQuestionType.lcm:
        return 280;
      case MathQuestionType.hcf:
        return 350;
    }
  }
}

class MathQuestion {
  final String? topOperand;
  final String? bottomOperand;
  final String? operatorSymbol;
  final String displayText;
  final String? subtitleText;
  final int answer;
  final MathQuestionType type;
  final int difficultyLevel;
  final int basePoints;
  final bool isVertical;

  const MathQuestion({
    this.topOperand,
    this.bottomOperand,
    this.operatorSymbol,
    required this.displayText,
    this.subtitleText,
    required this.answer,
    required this.type,
    required this.difficultyLevel,
    required this.basePoints,
    this.isVertical = false,
  });

  bool checkAnswer(int userAnswer) => userAnswer == answer;
}
