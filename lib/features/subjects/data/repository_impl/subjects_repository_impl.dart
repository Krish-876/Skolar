import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/subjects_repository.dart';
import '../datasources/subjects_datasource.dart';

class SubjectsRepositoryImpl implements SubjectsRepository {
  final SubjectsDataSource _dataSource;
  const SubjectsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<SubjectEntity>>> getSubjects({
    required String institutionId,
    required int academicYear,
  }) async {
    try {
      final dtos = await _dataSource.getSubjects(
        institutionId: institutionId,
        academicYear:  academicYear,
      );
      return Right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}