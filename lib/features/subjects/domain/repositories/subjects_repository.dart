import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import '../entities/subject_entity.dart';

abstract class SubjectsRepository {
  Future<Either<Failure, List<SubjectEntity>>> getSubjects({
    required String institutionId,
    required int academicYear,
  });
}