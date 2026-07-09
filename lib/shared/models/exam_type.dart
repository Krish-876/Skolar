enum ExamType {
  quiz1,
  midsem,
  quiz2,
  compre,
  generated;

  String get apiValue => switch (this) {
    ExamType.quiz1 => 'quiz1',
    ExamType.midsem => 'midsem',
    ExamType.quiz2 => 'quiz2',
    ExamType.compre => 'compre',
    ExamType.generated => 'generated',
  };

  String get displayLabel => switch (this) {
    ExamType.quiz1 => 'Quiz',
    ExamType.midsem => 'Midsem',
    ExamType.quiz2 => 'Quiz 2',
    ExamType.compre => 'Compre',
    ExamType.generated => 'Generated',
  };
}
