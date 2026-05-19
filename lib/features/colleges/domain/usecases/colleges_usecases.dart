import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/colleges_entity.dart';
import '../repositories/colleges_repository.dart';

class GetAllColleges implements UseCase<List<CollegesEntity>, NoParams> {
  final CollegesRepository repository;
  const GetAllColleges(this.repository);

  @override
  Future<Either<Failure, List<CollegesEntity>>> call(NoParams params) =>
      repository.getAll();
}
