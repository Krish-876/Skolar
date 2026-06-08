import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Skolar/shared/models/user_model.dart';

final isLoadingProvider    = StateProvider<bool>((ref) => false);
final errorMessageProvider = StateProvider<String?>((ref) => null);
final successMessageProvider = StateProvider<String?>((ref) => null);

// ── User provider — reads from Supabase, falls back to placeholder ──────────

final userProvider = StateNotifierProvider<UserNotifier, UserModel>(
  (ref) => UserNotifier(),
);

class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier() : super(UserModel.placeholder()) {
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return;

    try {
      final response = await client
          .from('users')
          .select('id, email, full_name, roll_number, college, campus_id, institution_id, academic_year, branch, plan')
          .eq('id', authUser.id)
          .single();

      state = UserModel(
        id:            response['id']            as String,
        name:          response['full_name']      as String? ?? 'Student',
        email:         response['email']          as String? ?? '',
        college:       response['college']        as String? ?? 'BPHC',
        rollNumber:    response['roll_number']    as String? ?? '',
        academicYear:  response['academic_year']  as int?    ?? 1,
        branch:        response['branch']         as String?,
        plan:          response['plan']           as String? ?? 'free',
        institutionId: response['institution_id'] as String?,
        campusId:      response['campus_id']      as String?,
      );
    } catch (_) {
      // Keep placeholder if fetch fails — app still works
    }
  }

  Future<void> refresh() => _loadFromSupabase();

  void update(UserModel user) => state = user;
}