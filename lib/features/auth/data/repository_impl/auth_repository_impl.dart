import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;
  const AuthRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<AuthEntity>>> getAll() async {
    try {
      final dtos = await dataSource.getAll();
      return Right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return  Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, AuthEntity>> getById(String id) async {
    try {
      final dto = await dataSource.getById(id);
      return Right(dto.toEntity());
    } catch (e) {
      return  Left(ServerFailure());
    }
  }
}
