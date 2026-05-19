import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/mock_tests_entity.dart';
import '../../domain/repositories/mock_tests_repository.dart';
import '../datasources/mock_tests_datasource.dart';

class MockTestsRepositoryImpl implements MockTestsRepository {
  final MockTestsDataSource dataSource;
  const MockTestsRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<MockTestsEntity>>> getAll() async {
    try {
      final dtos = await dataSource.getAll();
      return Right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, MockTestsEntity>> getById(String id) async {
    try {
      final dto = await dataSource.getById(id);
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
