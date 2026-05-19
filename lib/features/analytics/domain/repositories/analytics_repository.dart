import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/analytics_entity.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, AnalyticsData>> getAnalytics();
}