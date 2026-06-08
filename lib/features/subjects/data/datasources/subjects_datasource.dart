import 'package:supabase_flutter/supabase_flutter.dart';
import '../dtos/subject_dto.dart';

abstract class SubjectsDataSource {
  Future<List<SubjectDto>> getSubjects({
    required String institutionId,
    required int academicYear,
  });
}

class SubjectsRemoteDataSource implements SubjectsDataSource {
  final _client = Supabase.instance.client;

  @override
  Future<List<SubjectDto>> getSubjects({
    required String institutionId,
    required int academicYear,
  }) async {
    final response = await _client
        .from('subjects')
        .select('id, name, short_name, academic_year, institution_id')
        .eq('institution_id', institutionId)
        .eq('academic_year', academicYear)
        .order('name');

    return (response as List<dynamic>)
        .map((e) => SubjectDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}