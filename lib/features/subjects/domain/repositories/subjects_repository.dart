import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import '../entities/subject_entity.dart';

abstract class SubjectsRepository {
  /// Fetches the user's subjects for the given campus/year/semester.
  /// On first load, auto-seeds compulsory (CDC) subjects from the
  /// read-only catalog for that campus/year/semester.
  Future<Either<Failure, List<SubjectEntity>>> getSubjectsForUser({
    required String userId,
    required String institutionId,
    required String campusId,
    required int academicYear,
    required int semester,
  });

  /// Adds a free-text elective. Not catalog-backed by design.
  Future<Either<Failure, SubjectEntity>> addCustomSubject({
    required String userId,
    required String institutionId,
    required String semester,
    required String name,
    required String courseCode,
    int? credits,
  });

  Future<Either<Failure, Unit>> deleteUserSubject({
    required String userSubjectId,
  });

  /// Uploads a handout PDF to Supabase Storage, updates user_subjects.handout_url,
  /// then calls /extract-plan on the backend to generate and persist a study plan.
  Future<Either<Failure, SubjectEntity>> uploadHandout({
    required String userSubjectId,
    required String userId,
    required String subjectName,
    required List<int> fileBytes,
    required String filename,
  });

  /// Reads the student's self-reported total credit load for the
  /// semester. Returns null if never set.
  Future<Either<Failure, int?>> getCreditTarget({
    required String userId,
  });

  /// Persists the student's self-reported total credit load.
  Future<Either<Failure, Unit>> setCreditTarget({
    required String userId,
    required int value,
  });
}