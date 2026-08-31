import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/dashboard_entity.dart';
import '../repositories/dashboard_repository.dart';

class GetProgressStats implements UseCase<ProgressStats, NoParams> {
  final DashboardRepository repository;
  const GetProgressStats(this.repository);

  @override
  Future<Either<Failure, ProgressStats>> call(NoParams params) =>
      repository.getProgressStats();
}

class GetDashboardPlan implements UseCase<DashboardPlan, NoParams> {
  final DashboardRepository repository;
  const GetDashboardPlan(this.repository);

  @override
  Future<Either<Failure, DashboardPlan>> call(NoParams params) =>
      repository.getPlan();
}

class ToggleTaskParams {
  final String taskId;
  const ToggleTaskParams(this.taskId);
}

class ToggleTaskCompletion implements UseCase<DashboardPlan, ToggleTaskParams> {
  final DashboardRepository repository;
  const ToggleTaskCompletion(this.repository);

  @override
  Future<Either<Failure, DashboardPlan>> call(ToggleTaskParams params) =>
      repository.toggleTaskCompletion(params.taskId);
}

class GetDevelopmentAxes implements UseCase<List<DevelopmentAxis>, NoParams> {
  final DashboardRepository repository;
  const GetDevelopmentAxes(this.repository);

  @override
  Future<Either<Failure, List<DevelopmentAxis>>> call(NoParams params) =>
      repository.getDevelopmentAxes();
}
