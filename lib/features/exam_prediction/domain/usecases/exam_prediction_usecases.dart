import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/exam_prediction_entity.dart';
import '../repositories/exam_prediction_repository.dart';

class GetAllExamPrediction implements UseCase<List<ExamPredictionEntity>, NoParams> {
  final ExamPredictionRepository repository;
  const GetAllExamPrediction(this.repository);

  @override
  Future<Either<Failure, List<ExamPredictionEntity>>> call(NoParams params) =>
      repository.getAll();
}
