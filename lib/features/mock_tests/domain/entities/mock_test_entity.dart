import 'package:freezed_annotation/freezed_annotation.dart';

part 'mock_test_entity.freezed.dart';

@freezed
class QuizQuestion with _$QuizQuestion {
  const factory QuizQuestion({
    required String question,
    required List<String> options,
    required int correctIndex,
    required String subject,
    required int marks,
  }) = _QuizQuestion;
}

@freezed
class OpenQuestion with _$OpenQuestion {
  const factory OpenQuestion({
    required String question,
    required String subject,
    required int marks,
    required String modelAnswer,
  }) = _OpenQuestion;
}