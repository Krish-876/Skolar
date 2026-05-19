import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/analytics_entity.dart';
import '../repositories/analytics_repository.dart';

class GetAnalyticsUseCase {
  final AnalyticsRepository _repository;
  GetAnalyticsUseCase(this._repository);

  Future<Either<Failure, AnalyticsData>> call() {
    return _repository.getAnalytics();
  }
}