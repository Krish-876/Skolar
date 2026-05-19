import 'package:nova/shared/models/base_models.dart';

class ExamPredictionEntity extends BaseEntity {
  final String examName;
  final double predictedScore;
  const ExamPredictionEntity({required super.id, required this.examName, required this.predictedScore});
}
