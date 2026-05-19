import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/exam_prediction_entity.dart';
import '../../domain/repositories/exam_prediction_repository.dart';
import '../datasources/exam_prediction_datasource.dart';

class ExamPredictionRepositoryImpl implements ExamPredictionRepository {
  final ExamPredictionDataSource dataSource;
  const ExamPredictionRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<ExamPredictionEntity>>> getAll() async {
    try {
      final dtos = await dataSource.getAll();
      return Right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, ExamPredictionEntity>> getById(String id) async {
    try {
      final dto = await dataSource.getById(id);
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
