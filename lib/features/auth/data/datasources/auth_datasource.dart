import '../dtos/auth_dto.dart';

abstract class AuthDataSource {
  Future<List<AuthDto>> getAll();
  Future<AuthDto> getById(String id);
}

class AuthRemoteDataSource implements AuthDataSource {
  @override Future<List<AuthDto>> getAll() async => [];
  @override Future<AuthDto> getById(String id) => throw UnimplementedError();
}
