import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dashboard_entity.dart';

abstract class DashboardRepository {
  Future<Either<Failure, ProgressStats>> getProgressStats();
  Future<Either<Failure, DashboardPlan>> getPlan();
  Future<Either<Failure, DashboardPlan>> toggleTaskCompletion(String taskId);
  Future<Either<Failure, List<DevelopmentAxis>>> getDevelopmentAxes();
}
