import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Skolar/core/utils/email_parser.dart';
import '../dtos/onboarding_dto.dart';

abstract class OnboardingDataSource {
  Future<void> save(OnboardingDto dto);
}

class OnboardingRemoteDataSource implements OnboardingDataSource {
  final _client = Supabase.instance.client;

  @override
  Future<void> save(OnboardingDto dto) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw Exception('No authenticated user');

    final email   = authUser.email ?? '';
    final parsed  = EmailParser.parse(email);

    // Resolve campus from subdomain
    String? campusId;
    String  college = 'BPHC';
    String? institutionId;
    int     academicYear = 1;

    if (parsed != null) {
      academicYear = parsed.academicYear;

      final campusResponse = await _client
          .from('campuses')
          .select('id, short_name, institution_id')
          .eq('subdomain', parsed.subdomain)
          .maybeSingle();

      if (campusResponse != null) {
        campusId      = campusResponse['id']             as String;
        college       = campusResponse['short_name']     as String;
        institutionId = campusResponse['institution_id'] as String;
      }
    }

    // Upsert user row
    await _client.from('users').upsert({
      'id':             authUser.id,
      'email':          email,
      'full_name':      dto.nickname,
      'roll_number':    parsed?.rollNumber ?? '',
      'college':        college,
      'campus_id':      campusId,
      'institution_id': institutionId,
      'academic_year':  academicYear,
      'branch':         dto.branch,
      'plan':           dto.plan,
    });

    // Save selected subjects
    if (dto.selectedSubjectIds.isNotEmpty) {
      final semester = _currentSemester();
      final rows = dto.selectedSubjectIds.map((subjectId) => {
        'user_id':    authUser.id,
        'subject_id': subjectId,
        'semester':   semester,
      }).toList();

      await _client
          .from('user_subjects')
          .upsert(rows, onConflict: 'user_id,subject_id,semester');
    }
  }

  String _currentSemester() {
    final now = DateTime.now();
    final semester = now.month >= 7 ? 'S1' : 'S2';
    return '${now.year}-$semester';
  }
}