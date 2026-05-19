import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../entities/auth_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, List<AuthEntity>>> getAll();
  Future<Either<Failure, AuthEntity>> getById(String id);
}
