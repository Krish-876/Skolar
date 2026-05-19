import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/colleges_entity.dart';
import '../../domain/repositories/colleges_repository.dart';
import '../datasources/colleges_datasource.dart';

class CollegesRepositoryImpl implements CollegesRepository {
  final CollegesDataSource dataSource;
  const CollegesRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<CollegesEntity>>> getAll() async {
    try {
      final dtos = await dataSource.getAll();
      return Right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, CollegesEntity>> getById(String id) async {
    try {
      final dto = await dataSource.getById(id);
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
