import '../dtos/dashboard_dto.dart';

abstract class DashboardDataSource {
  Future<List<DashboardDto>> getAll();
  Future<DashboardDto> getById(String id);
}

class DashboardRemoteDataSource implements DashboardDataSource {
  // TODO: inject HttpClient
  @override
  Future<List<DashboardDto>> getAll() async => [];
  @override
  Future<DashboardDto> getById(String id) => throw UnimplementedError();
}
