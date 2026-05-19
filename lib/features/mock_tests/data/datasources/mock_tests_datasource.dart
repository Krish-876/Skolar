import '../dtos/mock_tests_dto.dart';

abstract class MockTestsDataSource {
  Future<List<MockTestsDto>> getAll();
  Future<MockTestsDto> getById(String id);
}

class MockTestsRemoteDataSource implements MockTestsDataSource {
  // TODO: inject HttpClient
  @override Future<List<MockTestsDto>> getAll() async => [];
  @override Future<MockTestsDto> getById(String id) => throw UnimplementedError();
}
