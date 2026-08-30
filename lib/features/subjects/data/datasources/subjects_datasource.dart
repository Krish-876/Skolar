import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/utils/semester_utils.dart';
import '../dtos/subject_dto.dart';

const _userSubjectSelect =
    'id, subject_id, custom_subject_id, semester, '
    'handout_url, handout_filename, '
    'subjects(name, short_name, academic_year, semester, credits, institution_id), '
    'custom_subjects(name, course_code, credits)';

abstract class SubjectsDataSource {
  Future<List<SubjectDto>> getSubjectsForUser({
    required String userId,
    required String institutionId,
    required String campusId,
    required int academicYear,
    required int semester,
  });

  Future<SubjectDto> addCustomSubject({
    required String userId,
    required String institutionId,
    required String semester,
    required String name,
    required String courseCode,
    int? credits,
  });

  Future<void> deleteUserSubject({required String userSubjectId});

  Future<SubjectDto> uploadHandout({
    required String userSubjectId,
    required String userId,
    required String subjectName,
    required List<int> fileBytes,
    required String filename,
  });

  Future<int?> getCreditTarget({required String userId});

  Future<void> setCreditTarget({required String userId, required int value});
}

class SubjectsRemoteDataSource implements SubjectsDataSource {
  final _client = Supabase.instance.client;

  @override
  Future<List<SubjectDto>> getSubjectsForUser({
    required String userId,
    required String institutionId,
    required String campusId,
    required int academicYear,
    required int semester,
  }) async {
    final existing = await _client
        .from('user_subjects')
        .select(_userSubjectSelect)
        .eq('user_id', userId);

    final existingRows = existing as List<dynamic>;

    // If campusId is not set, or user already has enrolled catalog subjects,
    // return whatever user_subjects already exist (catalog or custom).
    final hasCatalogSubject = existingRows.any((r) => r['subject_id'] != null);
    final campus = campusId.trim();

    if (hasCatalogSubject || campus.isEmpty) {
      return existingRows
          .map((e) => SubjectDto.fromUserSubjectJson(e))
          .toList();
    }

    // First load with campusId set — seed from the campus-scoped catalog.
    final catalog = await _client
        .from('subjects')
        .select(
          'id, name, short_name, academic_year, semester, credits, institution_id',
        )
        .eq('campus_id', campus)
        .eq('academic_year', academicYear)
        .eq('semester', semester)
        .order('name');

    final catalogRows = catalog as List<dynamic>;

    // No catalog entries for this campus/year/semester yet —
    // return whatever custom subjects already exist (possibly none).
    if (catalogRows.isEmpty) {
      return existingRows
          .map((e) => SubjectDto.fromUserSubjectJson(e))
          .toList();
    }

    final semesterLabel = SemesterUtils.currentSemesterLabel();

    final inserted = await _client
        .from('user_subjects')
        .insert(
          catalogRows
              .map(
                (row) => {
                  'user_id': userId,
                  'subject_id': row['id'],
                  'semester': semesterLabel,
                },
              )
              .toList(),
        )
        .select(_userSubjectSelect);

    // Merge any pre-existing custom subjects with freshly seeded CDC rows.
    final customRows = existingRows
        .where((r) => r['subject_id'] == null)
        .toList();

    return [
      ...customRows,
      ...(inserted as List<dynamic>),
    ].map((e) => SubjectDto.fromUserSubjectJson(e)).toList();
  }

  @override
  Future<SubjectDto> addCustomSubject({
    required String userId,
    required String institutionId,
    required String semester,
    required String name,
    required String courseCode,
    int? credits,
  }) async {
    String resolvedInstitutionId = institutionId.trim();

    if (resolvedInstitutionId.isEmpty) {
      final userRow = await _client
          .from('users')
          .select('institution_id')
          .eq('id', userId)
          .maybeSingle();

      if (userRow != null && userRow['institution_id'] != null) {
        resolvedInstitutionId = userRow['institution_id'] as String;
      }
    }

    if (resolvedInstitutionId.isEmpty) {
      final subjectRow = await _client
          .from('subjects')
          .select('institution_id')
          .not('institution_id', 'is', null)
          .limit(1)
          .maybeSingle();

      if (subjectRow != null && subjectRow['institution_id'] != null) {
        resolvedInstitutionId = subjectRow['institution_id'] as String;
      }
    }

    if (resolvedInstitutionId.isEmpty) {
      final campusRow = await _client
          .from('campuses')
          .select('institution_id')
          .limit(1)
          .maybeSingle();

      if (campusRow != null && campusRow['institution_id'] != null) {
        resolvedInstitutionId = campusRow['institution_id'] as String;
      }
    }

    if (resolvedInstitutionId.isEmpty) {
      final instRow = await _client
          .from('institutions')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (instRow != null && instRow['id'] != null) {
        resolvedInstitutionId = instRow['id'] as String;
      }
    }

    if (resolvedInstitutionId.isEmpty) {
      throw Exception('Could not determine institution ID for custom subject.');
    }

    if (institutionId.isEmpty && resolvedInstitutionId.isNotEmpty) {
      _client
          .from('users')
          .update({'institution_id': resolvedInstitutionId})
          .eq('id', userId)
          .then((_) {})
          .catchError((_) {});
    }

    final catalogRow = await _client
        .from('custom_subjects')
        .upsert(
          {
            'institution_id': resolvedInstitutionId,
            'course_code': courseCode,
            'name': name,
            'credits': credits,
          },
          onConflict: 'institution_id, course_code',
          ignoreDuplicates: false,
        )
        .select('id')
        .single();

    final customSubjectId = catalogRow['id'] as String;

    final response = await _client
        .from('user_subjects')
        .insert({
          'user_id': userId,
          'subject_id': null,
          'semester': semester,
          'custom_subject_id': customSubjectId,
        })
        .select(_userSubjectSelect)
        .single();

    return SubjectDto.fromUserSubjectJson(response);
  }

  @override
  Future<void> deleteUserSubject({required String userSubjectId}) async {
    await _client.from('user_subjects').delete().eq('id', userSubjectId);
  }

  @override
  Future<SubjectDto> uploadHandout({
    required String userSubjectId,
    required String userId,
    required String subjectName,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final storagePath = 'handouts/$userId/$userSubjectId/$filename';
    await _client.storage
        .from('handouts')
        .uploadBinary(
          storagePath,
          Uint8List.fromList(fileBytes),
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

    final publicUrl = _client.storage
        .from('handouts')
        .getPublicUrl(storagePath);

    final updated = await _client
        .from('user_subjects')
        .update({'handout_url': publicUrl, 'handout_filename': filename})
        .eq('id', userSubjectId)
        .select(_userSubjectSelect)
        .single();

    _triggerPlanExtraction(
      userSubjectId: userSubjectId,
      userId: userId,
      subjectName: subjectName,
      handoutUrl: publicUrl,
    );

    return SubjectDto.fromUserSubjectJson(updated);
  }

  @override
  Future<int?> getCreditTarget({required String userId}) async {
    final row = await _client
        .from('users')
        .select('semester_credits')
        .eq('id', userId)
        .single();
    return row['semester_credits'] as int?;
  }

  @override
  Future<void> setCreditTarget({
    required String userId,
    required int value,
  }) async {
    await _client
        .from('users')
        .update({'semester_credits': value})
        .eq('id', userId);
  }

  void _triggerPlanExtraction({
    required String userSubjectId,
    required String userId,
    required String subjectName,
    required String handoutUrl,
  }) {
    Future(() async {
      try {
        await _client.functions.invoke(
          'extract-plan-proxy',
          body: {
            'user_subject_id': userSubjectId,
            'user_id': userId,
            'subject_name': subjectName,
            'handout_url': handoutUrl,
          },
        );
      } catch (e) {
        debugPrint('[uploadHandout] plan trigger failed: $e');
      }
    });
  }
}
