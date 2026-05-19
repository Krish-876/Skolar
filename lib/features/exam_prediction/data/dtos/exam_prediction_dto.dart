import '../../domain/entities/exam_prediction_entity.dart';

class ExamPredictionDto {
  final String id;
  final String examName;
  final double predictedScore;

  const ExamPredictionDto({required this.id, required this.examName, required this.predictedScore});

  factory ExamPredictionDto.fromJson(Map<String, dynamic> json) => ExamPredictionDto(
      id: json['id'] as String,
      examName: json['examName'] as String,
      predictedScore: json['predictedScore'] as double,
  );

  Map<String, dynamic> toJson() => {
      'id': id,
      'examName': examName,
      'predictedScore': predictedScore,
  };

  ExamPredictionEntity toEntity() => ExamPredictionEntity(id: id, examName: examName, predictedScore: predictedScore);
}
