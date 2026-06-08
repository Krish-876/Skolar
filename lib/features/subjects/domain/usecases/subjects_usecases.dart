import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import '../entities/subject_entity.dart';
import '../repositories/subjects_repository.dart';

class GetSubjectsUseCase {
  final SubjectsRepository _repository;
  const GetSubjectsUseCase(this._repository);

  Future<Either<Failure, List<SubjectEntity>>> call({
    required String institutionId,
    required int academicYear,
  }) {
    return _repository.getSubjects(
      institutionId: institutionId,
      academicYear:  academicYear,
    );
  }
}