import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/semester_utils.dart';
import '../../../../core/utils/week_utils.dart';
import '../dtos/dashboard_dto.dart';
import 'dashboard_datasource.dart';

/// Live Supabase implementation of [DashboardDataSource].
///
/// Calls the `get_activity_daily` RPC (SECURITY INVOKER, auth.uid() scoped)
/// over the union of semester, week, and heatmap ranges, then aggregates in Dart:
///
/// - semester total  = sum of counted_focus_seconds within the active semester
/// - this week total = sum of counted_focus_seconds within the calendar week
/// - heatmap data    = 30-day daily completions array with session counts
///
/// Plan/task/development-axis methods delegate to [DashboardDummyDataSource]
/// until Nova endpoints are wired up.
class DashboardSupabaseDataSource implements DashboardDataSource {
  final SupabaseClient _client;
  final DashboardDummyDataSource _dummy = DashboardDummyDataSource();

  /// Sunday = 7 (Dart's DateTime.weekday convention).
  /// Cached in memory; call [invalidateConfigCache] to refresh.
  int? _cachedWeekStartDay;

  DashboardSupabaseDataSource(this._client);

  void invalidateConfigCache() {
    _cachedWeekStartDay = null;
  }

  Future<int> _weekStartDay() async {
    if (_cachedWeekStartDay != null) return _cachedWeekStartDay!;

    try {
      final uid = _client.auth.currentUser?.id;
      // Per-user override first, then fall back to global (user_id IS NULL).
      // nullsFirst: false ensures non-null user_id row sorts before NULL global row.
      final res = await _client
          .from('nova_config')
          .select('value, user_id')
          .eq('key', 'week_start_day')
          .or(
            uid != null ? 'user_id.eq.$uid,user_id.is.null' : 'user_id.is.null',
          )
          .order('user_id', ascending: false, nullsFirst: false)
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
          final str = raw.toString().replaceAll('"', '').trim();
          parsed = int.tryParse(str);
        }
        if (parsed != null && parsed >= 1 && parsed <= 7) {
          _cachedWeekStartDay = parsed;
          return parsed;
        }
      }
    } catch (_) {
      // Degrade gracefully to documented default (Sunday)
    }

    // Default: Sunday = 7
    _cachedWeekStartDay = 7;
    return 7;
  }

  @override
  Future<ProgressStatsDto> getProgressStats() async {
    final today = DateTime.now();
    final todayLocal = DateTime(today.year, today.month, today.day);

    final (semStart, semEnd) = semesterRangeFromTerms(now: todayLocal);

    final startDay = await _weekStartDay();
    final weekStart = weekStartFor(todayLocal, startDay);
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );

    // 30-day heatmap rolling window
    final heatmapStart = DateTime(
      todayLocal.year,
      todayLocal.month,
      todayLocal.day - 29,
    );
    final heatmapEnd = todayLocal;

    // Union range for RPC call
    DateTime queryStart = semStart;
    if (weekStart.isBefore(queryStart)) queryStart = weekStart;
    if (heatmapStart.isBefore(queryStart)) queryStart = heatmapStart;

    DateTime queryEnd = semEnd;
    if (weekEnd.isAfter(queryEnd)) queryEnd = weekEnd;
    if (heatmapEnd.isAfter(queryEnd)) queryEnd = heatmapEnd;

    final fromStr = _dateStr(queryStart);
    final toStr = _dateStr(queryEnd);

    // Call RPC — returns rows for days that have at least one counted session.
    final dynamic rows = await _client.rpc(
      'get_activity_daily',
      params: {'p_from': fromStr, 'p_to': toStr},
    );

    final daily = (rows as List<dynamic>)
        .map((r) => ActivityDailyRowDto.fromJson(r as Map<String, dynamic>))
        .toList();

    final dailyByDateStr = <String, ActivityDailyRowDto>{
      for (final r in daily) r.day: r,
    };

    // Semester total: sum of countedFocusSeconds within [semStart, semEnd]
    int semesterSeconds = 0;
    for (final r in daily) {
      final d = DateTime.parse(r.day);
      if (!d.isBefore(semStart) && !d.isAfter(semEnd)) {
        semesterSeconds += r.countedFocusSeconds;
      }
    }

    // This week total: sum of countedFocusSeconds within [weekStart, weekEnd]
    int weekSeconds = 0;
    for (final r in daily) {
      final d = DateTime.parse(r.day);
      if (!d.isBefore(weekStart) && !d.isAfter(weekEnd)) {
        weekSeconds += r.countedFocusSeconds;
      }
    }

    // 30-day heatmap daily completions: each of the 30 days present, most recent day last
    final completions = List.generate(30, (i) {
      final dayDate = DateTime(
        todayLocal.year,
        todayLocal.month,
        todayLocal.day - (29 - i),
      );
      final dateStr = _dateStr(dayDate);
      final row = dailyByDateStr[dateStr];
      return DailyCompletionDto(
        date: dateStr,
        tasksCompleted: row?.sessions ?? 0,
      );
    });

    return ProgressStatsDto(
      tasksCompletedThisWeek: 0, // not wired — task-linking is deferred
      tasksPlannedThisWeek: 0,
      focusSecondsThisSemester: semesterSeconds,
      focusSecondsThisWeek: weekSeconds,
      dailyCompletions: completions,
    );
  }

  // Plan / task / development-axis delegate to dummy until Nova is wired
  @override
  Future<DashboardPlanDto> getPlan() => _dummy.getPlan();

  @override
  Future<DashboardPlanDto> toggleTask(String taskId) =>
      _dummy.toggleTask(taskId);

  @override
  Future<List<DevelopmentAxisDto>> getDevelopmentAxes() =>
      _dummy.getDevelopmentAxes();

  // ---------------------------------------------------------------------------

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
