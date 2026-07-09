import '../dtos/colleges_dto.dart';

abstract class CollegesDataSource {
  Future<List<CollegesDto>> getAll();
  Future<CollegesDto> getById(String id);
}

class CollegesRemoteDataSource implements CollegesDataSource {
  // TODO: inject HttpClient
  @override
  Future<List<CollegesDto>> getAll() async => [];
  @override
  Future<CollegesDto> getById(String id) => throw UnimplementedError();
}
