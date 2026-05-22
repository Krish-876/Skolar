// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_prediction_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeneratedQuestionDto _$GeneratedQuestionDtoFromJson(
  Map<String, dynamic> json,
) => GeneratedQuestionDto(
  question: json['question'] as String,
  subject: json['subject'] as String,
  examplesUsed: (json['examples_used'] as num).toInt(),
);

Map<String, dynamic> _$GeneratedQuestionDtoToJson(
  GeneratedQuestionDto instance,
) => <String, dynamic>{
  'question': instance.question,
  'subject': instance.subject,
  'examples_used': instance.examplesUsed,
};

UploadResultDto _$UploadResultDtoFromJson(Map<String, dynamic> json) =>
    UploadResultDto(
      message: json['message'] as String,
      added: (json['added'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      preview:
          (json['preview'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );

Map<String, dynamic> _$UploadResultDtoToJson(UploadResultDto instance) =>
    <String, dynamic>{
      'message': instance.message,
      'added': instance.added,
      'total': instance.total,
      'preview': instance.preview,
    };

QuestionBankStatsDto _$QuestionBankStatsDtoFromJson(
  Map<String, dynamic> json,
) => QuestionBankStatsDto(
  totalQuestions: (json['total_questions'] as num).toInt(),
  subjects: Map<String, int>.from(json['subjects'] as Map),
  years:
      (json['years'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [],
);

Map<String, dynamic> _$QuestionBankStatsDtoToJson(
  QuestionBankStatsDto instance,
) => <String, dynamic>{
  'total_questions': instance.totalQuestions,
  'subjects': instance.subjects,
  'years': instance.years,
};

QuestionItemDto _$QuestionItemDtoFromJson(Map<String, dynamic> json) =>
    QuestionItemDto(
      questionText: json['question_text'] as String,
      marks: (json['marks'] as num).toInt(),
      questionType: json['question_type'] as String,
      subject: json['subject'] as String,
      year: (json['year'] as num).toInt(),
      examType: json['exam_type'] as String,
    );

Map<String, dynamic> _$QuestionItemDtoToJson(QuestionItemDto instance) =>
    <String, dynamic>{
      'question_text': instance.questionText,
      'marks': instance.marks,
      'question_type': instance.questionType,
      'subject': instance.subject,
      'year': instance.year,
      'exam_type': instance.examType,
    };

QuestionsResponseDto _$QuestionsResponseDtoFromJson(
  Map<String, dynamic> json,
) => QuestionsResponseDto(
  total: (json['total'] as num).toInt(),
  questions: (json['questions'] as List<dynamic>)
      .map((e) => QuestionItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$QuestionsResponseDtoToJson(
  QuestionsResponseDto instance,
) => <String, dynamic>{
  'total': instance.total,
  'questions': instance.questions,
};
