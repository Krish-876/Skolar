import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../entities/colleges_entity.dart';

abstract class CollegesRepository {
  Future<Either<Failure, List<CollegesEntity>>> getAll();
  Future<Either<Failure, CollegesEntity>> getById(String id);
}
