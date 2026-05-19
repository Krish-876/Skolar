import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dashboard_entity.dart';

abstract class DashboardRepository {
  Future<Either<Failure, List<DashboardEntity>>> getAll();
  Future<Either<Failure, DashboardEntity>> getById(String id);
}
