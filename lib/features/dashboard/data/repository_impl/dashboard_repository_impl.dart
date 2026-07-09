import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardDataSource dataSource;
  const DashboardRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<DashboardEntity>>> getAll() async {
    try {
      final dtos = await dataSource.getAll();
      return Right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, DashboardEntity>> getById(String id) async {
    try {
      final dto = await dataSource.getById(id);
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
