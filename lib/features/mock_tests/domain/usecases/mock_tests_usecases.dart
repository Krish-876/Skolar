import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/mock_tests_entity.dart';
import '../repositories/mock_tests_repository.dart';

class GetAllMockTests implements UseCase<List<MockTestsEntity>, NoParams> {
  final MockTestsRepository repository;
  const GetAllMockTests(this.repository);

  @override
  Future<Either<Failure, List<MockTestsEntity>>> call(NoParams params) =>
      repository.getAll();
}
