import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../entities/exam_prediction_entity.dart';

abstract class ExamPredictionRepository {
  Future<Either<Failure, List<ExamPredictionEntity>>> getAll();
  Future<Either<Failure, ExamPredictionEntity>> getById(String id);
}
