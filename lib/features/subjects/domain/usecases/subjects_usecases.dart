import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import '../entities/subject_entity.dart';
import '../repositories/subjects_repository.dart';

class GetSubjectsForUserUseCase {
  final SubjectsRepository _repository;
  const GetSubjectsForUserUseCase(this._repository);

  Future<Either<Failure, List<SubjectEntity>>> call({
    required String userId,
    required String institutionId,
    required String campusId,
    required int academicYear,
    required int semester,
  }) {
    return _repository.getSubjectsForUser(
      userId:        userId,
      institutionId: institutionId,
      campusId:      campusId,
      academicYear:  academicYear,
      semester:      semester,
    );
  }
}

class AddCustomSubjectUseCase {
  final SubjectsRepository _repository;
  const AddCustomSubjectUseCase(this._repository);

  Future<Either<Failure, SubjectEntity>> call({
    required String userId,
    required String institutionId,
    required String semester,
    required String name,
    required String courseCode,
    int? credits,
  }) {
    return _repository.addCustomSubject(
      userId:        userId,
      institutionId: institutionId,
      semester:      semester,
      name:          name,
      courseCode:    courseCode,
      credits:       credits,
    );
  }
}

class DeleteUserSubjectUseCase {
  final SubjectsRepository _repository;
  const DeleteUserSubjectUseCase(this._repository);

  Future<Either<Failure, Unit>> call({required String userSubjectId}) {
    return _repository.deleteUserSubject(userSubjectId: userSubjectId);
  }
}

class UploadHandoutUseCase {
  final SubjectsRepository _repository;
  const UploadHandoutUseCase(this._repository);

  Future<Either<Failure, SubjectEntity>> call({
    required String userSubjectId,
    required String userId,
    required String subjectName,
    required List<int> fileBytes,
    required String filename,
  }) {
    return _repository.uploadHandout(
      userSubjectId: userSubjectId,
      userId:        userId,
      subjectName:   subjectName,
      fileBytes:     fileBytes,
      filename:      filename,
    );
  }
}

class GetCreditTargetUseCase {
  final SubjectsRepository _repository;
  const GetCreditTargetUseCase(this._repository);

  Future<Either<Failure, int?>> call({required String userId}) {
    return _repository.getCreditTarget(userId: userId);
  }
}

class SetCreditTargetUseCase {
  final SubjectsRepository _repository;
  const SetCreditTargetUseCase(this._repository);

  Future<Either<Failure, Unit>> call({
    required String userId,
    required int value,
  }) {
    return _repository.setCreditTarget(userId: userId, value: value);
  }
}