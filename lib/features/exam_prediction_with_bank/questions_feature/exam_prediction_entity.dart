import 'package:freezed_annotation/freezed_annotation.dart';

part 'exam_prediction_entity.freezed.dart';

/// Matches GenerateResponse in main.py
@freezed
class GeneratedQuestion with _$GeneratedQuestion {
  const factory GeneratedQuestion({
    required String question,
    required String subject,
    required int examplesUsed,
  }) = _GeneratedQuestion;
}

/// Matches UploadResponse in main.py
@freezed
class UploadResult with _$UploadResult {
  const factory UploadResult({
    required String message,
    required int added,
    required int total,
    @Default([]) List<String> preview,
  }) = _UploadResult;
}

/// Matches StatsResponse in main.py
@freezed
class QuestionBankStats with _$QuestionBankStats {
  const factory QuestionBankStats({
    required int totalQuestions,
    required Map<String, int> subjects,
    @Default([]) List<int> years,
  }) = _QuestionBankStats;
}

/// Matches QuestionItem in main.py
@freezed
class QuestionItem with _$QuestionItem {
  const factory QuestionItem({
    required String questionText,
    required int marks,
    required String questionType,
    required String subject,
    required int year,
    required String examType,
  }) = _QuestionItem;
}

/// Matches QuestionsResponse in main.py
@freezed
class QuestionsResponse with _$QuestionsResponse {
  const factory QuestionsResponse({
    required int total,
    required List<QuestionItem> questions,
  }) = _QuestionsResponse;
}
