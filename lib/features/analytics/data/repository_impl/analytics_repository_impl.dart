import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/analytics_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_datasource.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsLocalDataSource _dataSource;
  AnalyticsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, AnalyticsData>> getAnalytics() async {
    try {
      final dto = await _dataSource.getAnalytics();
      return Right(dto.toDomain());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}