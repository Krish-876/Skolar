import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../analytics/data/datasources/analytics_datasource.dart';
import '../../../analytics/data/repository_impl/analytics_repository_impl.dart';
import '../../../analytics/domain/entities/analytics_entity.dart';
import '../../../analytics/domain/usecases/analytics_usecases.dart';

final _analyticsRepoProvider = Provider(
  (ref) => AnalyticsRepositoryImpl(AnalyticsLocalDataSourceImpl()),
);

final getAnalyticsUseCaseProvider = Provider(
  (ref) => GetAnalyticsUseCase(ref.read(_analyticsRepoProvider)),
);

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, AnalyticsData>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AsyncNotifier<AnalyticsData> {
  @override
  Future<AnalyticsData> build() async {
    final useCase = ref.read(getAnalyticsUseCaseProvider);
    final result = await useCase();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}