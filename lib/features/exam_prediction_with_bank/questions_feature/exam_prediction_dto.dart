import 'package:json_annotation/json_annotation.dart';
import 'exam_prediction_entity.dart';

part 'exam_prediction_dto.g.dart';

/// Matches GenerateResponse
@JsonSerializable()
class GeneratedQuestionDto {
  final String question;
  final String subject;
  @JsonKey(name: 'examples_used')
  final int examplesUsed;

  const GeneratedQuestionDto({
    required this.question,
    required this.subject,
    required this.examplesUsed,
  });

  factory GeneratedQuestionDto.fromJson(Map<String, dynamic> json) =>
      _$GeneratedQuestionDtoFromJson(json);

  Map<String, dynamic> toJson() => _$GeneratedQuestionDtoToJson(this);

  GeneratedQuestion toDomain() => GeneratedQuestion(
        question: question,
        subject: subject,
        examplesUsed: examplesUsed,
      );
}

/// Matches UploadResponse
@JsonSerializable()
class UploadResultDto {
  final String message;
  final int added;
  final int total;
  @JsonKey(defaultValue: <String>[])
  final List<String> preview;

  const UploadResultDto({
    required this.message,
    required this.added,
    required this.total,
    required this.preview,
  });

  factory UploadResultDto.fromJson(Map<String, dynamic> json) =>
      _$UploadResultDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UploadResultDtoToJson(this);

  UploadResult toDomain() => UploadResult(
        message: message,
        added: added,
        total: total,
        preview: preview,
      );
}

/// Matches StatsResponse
@JsonSerializable()
class QuestionBankStatsDto {
  @JsonKey(name: 'total_questions')
  final int totalQuestions;
  final Map<String, int> subjects;
  @JsonKey(defaultValue: <int>[])
  final List<int> paperYears;

  const QuestionBankStatsDto({
    required this.totalQuestions,
    required this.subjects,
    required this.paperYears,
  });

  factory QuestionBankStatsDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionBankStatsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$QuestionBankStatsDtoToJson(this);

  QuestionBankStats toDomain() => QuestionBankStats(
        totalQuestions: totalQuestions,
        subjects: subjects,
        paperYears: paperYears,
      );
}

/// Matches QuestionItem
@JsonSerializable()
class QuestionItemDto {
  @JsonKey(name: 'question_text')
  final String questionText;
  final int marks;
  @JsonKey(name: 'question_type')
  final String questionType;
  final String subject;
  final int paperYear;
  @JsonKey(name: 'exam_type')
  final String examType;

  const QuestionItemDto({
    required this.questionText,
    required this.marks,
    required this.questionType,
    required this.subject,
    required this.paperYear,
    required this.examType,
  });

  factory QuestionItemDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionItemDtoFromJson(json);

  Map<String, dynamic> toJson() => _$QuestionItemDtoToJson(this);

  QuestionItem toDomain() => QuestionItem(
        questionText: questionText,
        marks: marks,
        questionType: questionType,
        subject: subject,
        paperYear: paperYear,
        examType: examType,
      );
}

/// Matches QuestionsResponse
@JsonSerializable()
class QuestionsResponseDto {
  final int total;
  final List<QuestionItemDto> questions;

  const QuestionsResponseDto({
    required this.total,
    required this.questions,
  });

  factory QuestionsResponseDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionsResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$QuestionsResponseDtoToJson(this);

  QuestionsResponse toDomain() => QuestionsResponse(
        total: total,
        questions: questions.map((q) => q.toDomain()).toList(),
      );
}
