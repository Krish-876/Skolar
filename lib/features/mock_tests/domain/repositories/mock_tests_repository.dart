import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../entities/mock_tests_entity.dart';

abstract class MockTestsRepository {
  Future<Either<Failure, List<MockTestsEntity>>> getAll();
  Future<Either<Failure, MockTestsEntity>> getById(String id);
}
