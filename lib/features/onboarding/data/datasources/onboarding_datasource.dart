import 'package:supabase_flutter/supabase_flutter.dart';
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
    await _client.rpc(
      'save_onboarding_seed_context',
      params: {
        'p_endgame': dto.endgame,
        'p_derailer': dto.derailer,
        'p_buffer_pref': dto.bufferPref,
        'p_prep_style': dto.prepStyle,
        'p_career_interests': dto.careerInterests,
        'p_daily_capacity': {'hours': dto.dailyCapacity},
        'p_avatar_data': dto.avatarData,
        'p_full_name': dto.name,
        'p_roll_number': dto.id,
        'p_college': dto.campus,
        'p_branch': dto.branch,
        'p_dual_branch': dto.dualBranch,
        'p_academic_year': dto.currentYear,
        'p_current_semester': dto.currentSemester,
        'p_study_capacity': dto.studyCapacity,
      },
    );
  }
}
