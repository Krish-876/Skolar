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

  /// Splits the question into stacked display lines (top-to-bottom), for the
  /// vertical-equation layout: e.g. "24 + 37" -> ["24", "+37"], or
  /// "LCM(4, 6)" -> ["LCM", "4", "6"].
  List<String> get stackedLines {
    switch (type) {
      case MathQuestionType.lcm:
      case MathQuestionType.hcf:
        final match = RegExp(r'\((\d+),\s*(\d+)\)').firstMatch(displayText);
        if (match == null) return [displayText];
        return [type.symbol, match.group(1)!, match.group(2)!];
      default:
        final symbol = type.symbol;
        final separator = ' $symbol ';
        final idx = displayText.indexOf(separator);
        if (idx == -1) return [displayText];
        final a = displayText.substring(0, idx);
        final b = displayText.substring(idx + separator.length);
        return [a, '$symbol$b'];
    }
  }
}
