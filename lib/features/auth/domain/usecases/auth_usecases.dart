import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/auth_entity.dart';
import '../repositories/auth_repository.dart';

class GetAllAuth implements UseCase<List<AuthEntity>, NoParams> {
  final AuthRepository repository;
  const GetAllAuth(this.repository);

  @override
  Future<Either<Failure, List<AuthEntity>>> call(NoParams params) =>
      repository.getAll();
}
