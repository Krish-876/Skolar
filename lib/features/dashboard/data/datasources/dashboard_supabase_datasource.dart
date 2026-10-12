import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/week_utils.dart';
import '../../../../features/subjects/domain/utils/semester_utils.dart';
import '../dtos/dashboard_dto.dart';
import 'dashboard_datasource.dart';

/// Live Supabase implementation of [DashboardDataSource].
///
/// Calls the `get_activity_daily` RPC (SECURITY INVOKER, auth.uid() scoped)
/// over the full semester date range, then aggregates in Dart:
///
/// - semester total  = sum of counted_focus_seconds over all returned rows
/// - this week total = sum of counted_focus_seconds for rows within the
///   current calendar week (week start read from nova_config)
/// - heatmap data    = session count per day (the `sessions` column)
///
/// Plan/task/development-axis methods fall through to
/// [DashboardDummyDataSource] until Nova is wired — they are intentionally
/// separate data concerns and not part of this wiring ticket.
class DashboardSupabaseDataSource implements DashboardDataSource {
  final SupabaseClient _client;

  /// Sunday = 7 (Dart's DateTime.weekday convention).
  /// Reads from nova_config on first call and caches for the lifetime of
  /// this instance. A per-request read would add an extra round-trip on
  /// every dashboard load and is not needed since the value changes only
  /// via a DB edit, not user action.
  int? _cachedWeekStartDay;

  DashboardSupabaseDataSource(this._client);

  Future<int> _weekStartDay() async {
    if (_cachedWeekStartDay != null) return _cachedWeekStartDay!;

    final uid = _client.auth.currentUser?.id;
    // Per-user override first, then fall back to global (user_id IS NULL).
    final res = await _client
        .from('nova_config')
        .select('value, user_id')
        .eq('key', 'week_start_day')
        .or(uid != null ? 'user_id.eq.$uid,user_id.is.null' : 'user_id.is.null')
        .order('user_id', ascending: false) // non-null (user row) sorts first
        .limit(1)
        .maybeSingle();

    if (res != null) {
      final raw = res['value'];
      int? parsed;
      if (raw is int) {
        parsed = raw;
      } else if (raw is String) {
        parsed = int.tryParse(raw);
      } else if (raw is Map || raw is List) {
        // JSONB numeric literal stored as json: unwrap
        final str = raw.toString().replaceAll('"', '').trim();
        parsed = int.tryParse(str);
      }
      if (parsed != null && parsed >= 1 && parsed <= 7) {
        _cachedWeekStartDay = parsed;
        return parsed;
      }
    }

    // Default: Sunday = 7
    _cachedWeekStartDay = 7;
    return 7;
  }

  @override
  Future<ProgressStatsDto> getProgressStats() async {
    final (semStart, semEnd) = SemesterUtils.semesterRange();
    final fromStr = _dateStr(semStart);
    final toStr = _dateStr(semEnd);

    final startDay = await _weekStartDay();

    // Call RPC — returns rows for days that have at least one session.
    final rows = await _client.rpc<List<dynamic>>(
      'get_activity_daily',
      params: {'p_from': fromStr, 'p_to': toStr},
    );

    final daily = (rows as List)
        .map((r) => ActivityDailyRowDto.fromJson(r as Map<String, dynamic>))
        .toList();

    // Semester total
    int semesterSeconds = 0;
    for (final r in daily) {
      semesterSeconds += r.countedFocusSeconds;
    }

    // This week total
    final today = DateTime.now();
    final weekStart = weekStartFor(today, startDay);
    final weekEnd = weekStart.add(const Duration(days: 6));
    int weekSeconds = 0;
    for (final r in daily) {
      final d = DateTime.parse(r.day);
      if (!d.isBefore(weekStart) && !d.isAfter(weekEnd)) {
        weekSeconds += r.countedFocusSeconds;
      }
    }

    // Session count per day (heatmap)
    final completions = daily
        .map(
          (r) => DailyCompletionDto(
            date: r.day,
            tasksCompleted: r.sessions,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return ProgressStatsDto(
      tasksCompletedThisWeek: 0, // not wired — task-linking is deferred
      tasksPlannedThisWeek: 0,
      focusSecondsThisSemester: semesterSeconds,
      focusSecondsThisWeek: weekSeconds,
      dailyCompletions: completions,
    );
  }

  // Plan / task / development-axis methods are not part of this wiring
  // ticket; they still throw so the provider falls back gracefully via the
  // repository's try/catch → Left(ServerFailure).
  @override
  Future<DashboardPlanDto> getPlan() => throw UnimplementedError();

  @override
  Future<DashboardPlanDto> toggleTask(String taskId) =>
      throw UnimplementedError();

  @override
  Future<List<DevelopmentAxisDto>> getDevelopmentAxes() =>
      throw UnimplementedError();

  // ---------------------------------------------------------------------------

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
