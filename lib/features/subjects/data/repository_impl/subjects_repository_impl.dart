import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/subjects_repository.dart';
import '../datasources/subjects_datasource.dart';

class SubjectsRepositoryImpl implements SubjectsRepository {
  final SubjectsDataSource _dataSource;
  const SubjectsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<SubjectEntity>>> getSubjectsForUser({
    required String userId,
    required String institutionId,
    required String campusId,
    required int academicYear,
    required int semester,
  }) async {
    try {
      final dtos = await _dataSource.getSubjectsForUser(
        userId:        userId,
        institutionId: institutionId,
        campusId:      campusId,
        academicYear:  academicYear,
        semester:      semester,
      );
      return Right(dtos.map((d) => d.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SubjectEntity>> addCustomSubject({
    required String userId,
    required String institutionId,
    required String semester,
    required String name,
    required String courseCode,
    int? credits,
  }) async {
    try {
      final dto = await _dataSource.addCustomSubject(
        userId:        userId,
        institutionId: institutionId,
        semester:      semester,
        name:          name,
        courseCode:    courseCode,
        credits:       credits,
      );
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteUserSubject({
    required String userSubjectId,
  }) async {
    try {
      await _dataSource.deleteUserSubject(userSubjectId: userSubjectId);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SubjectEntity>> uploadHandout({
    required String userSubjectId,
    required String userId,
    required String subjectName,
    required List<int> fileBytes,
    required String filename,
  }) async {
    try {
      final dto = await _dataSource.uploadHandout(
        userSubjectId: userSubjectId,
        userId:        userId,
        subjectName:   subjectName,
        fileBytes:     fileBytes,
        filename:      filename,
      );
      return Right(dto.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int?>> getCreditTarget({
    required String userId,
  }) async {
    try {
      final value = await _dataSource.getCreditTarget(userId: userId);
      return Right(value);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setCreditTarget({
    required String userId,
    required int value,
  }) async {
    try {
      await _dataSource.setCreditTarget(userId: userId, value: value);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}