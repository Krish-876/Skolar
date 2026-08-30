import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardDataSource dataSource;
  const DashboardRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, ProgressStats>> getProgressStats() async {
    try {
      final dto = await dataSource.getProgressStats();
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, DashboardPlan>> getPlan() async {
    try {
      final dto = await dataSource.getPlan();
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, DashboardPlan>> toggleTaskCompletion(String taskId) async {
    try {
      final dto = await dataSource.toggleTask(taskId);
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<DevelopmentAxis>>> getDevelopmentAxes() async {
    try {
      final dtos = await dataSource.getDevelopmentAxes();
      return Right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
