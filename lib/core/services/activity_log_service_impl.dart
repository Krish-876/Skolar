import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_log_service.dart';

/// Supabase implementation of [ActivityLogService].
///
/// Inserts one row into `activity_log` per completed focus session:
///   - id            = [clientId] (client-supplied uuid for idempotency)
///   - user_id       = auth.uid() via Supabase RLS (NOT passed as a param)
///   - completed_on  = device-local calendar date at call time
///   - duration_seconds = [durationSeconds] (focus seconds only)
///
/// The migration uses ON CONFLICT (id) DO NOTHING, so retrying with the
/// same [clientId] is always safe.
///
/// Throws [ActivityLogFailure] on insert error so the focus timer page can
/// surface it as a snackbar without breaking the completion UX.
class ActivityLogServiceImpl implements ActivityLogService {
  final SupabaseClient _client;

  const ActivityLogServiceImpl(this._client);

  @override
  Future<void> logFocusSession({
    required int durationSeconds,
    required String clientId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ActivityLogFailure(
        'Cannot log session: no authenticated user.',
      );
    }

    // Device-local date — no UTC, no time component.
    final now = DateTime.now();
    final localDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      await _client.from('activity_log').insert({
        'id': clientId,
        'user_id': user.id,
        'completed_on': localDate,
        'duration_seconds': durationSeconds,
      });
      // ON CONFLICT (id) DO NOTHING: supabase-dart returns an empty list
      // for a conflict-skipped row, not an error — no special handling needed.
    } on PostgrestException catch (e) {
      throw ActivityLogFailure('Insert failed: ${e.message}');
    } catch (e) {
      throw ActivityLogFailure('Insert failed: $e');
    }
  }
}
