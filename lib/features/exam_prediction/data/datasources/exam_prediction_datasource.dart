import '../dtos/exam_prediction_dto.dart';

abstract class ExamPredictionDataSource {
  Future<List<ExamPredictionDto>> getAll();
  Future<ExamPredictionDto> getById(String id);
}

class ExamPredictionRemoteDataSource implements ExamPredictionDataSource {
  // TODO: inject HttpClient
  @override Future<List<ExamPredictionDto>> getAll() async => [];
  @override Future<ExamPredictionDto> getById(String id) => throw UnimplementedError();
}
