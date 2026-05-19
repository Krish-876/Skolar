import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/dashboard_entity.dart';
import '../repositories/dashboard_repository.dart';

class GetAllDashboard implements UseCase<List<DashboardEntity>, NoParams> {
  final DashboardRepository repository;
  const GetAllDashboard(this.repository);

  @override
  Future<Either<Failure, List<DashboardEntity>>> call(NoParams params) =>
      repository.getAll();
}
