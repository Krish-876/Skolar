class QuizQuestionDto {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String subject;
  final int marks;

  const QuizQuestionDto({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.subject,
    required this.marks,
  });

  factory QuizQuestionDto.fromJson(Map<String, dynamic> json) =>
      QuizQuestionDto(
        question: json['question'] as String,
        options: List<String>.from(json['options'] as List),
        correctIndex: json['correct_index'] as int,
        subject: json['subject'] as String,
        marks: json['marks'] as int,
      );
}

class OpenQuestionDto {
  final String question;
  final String subject;
  final int marks;
  final String modelAnswer;

  const OpenQuestionDto({
    required this.question,
    required this.subject,
    required this.marks,
    required this.modelAnswer,
  });

  factory OpenQuestionDto.fromJson(Map<String, dynamic> json) =>
      OpenQuestionDto(
        question: json['question'] as String,
        subject: json['subject'] as String,
        marks: json['marks'] as int,
        modelAnswer: json['model_answer'] as String,
      );
}
