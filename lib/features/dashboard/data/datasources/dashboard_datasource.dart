import '../dtos/dashboard_dto.dart';

abstract class DashboardDataSource {
  Future<ProgressStatsDto> getProgressStats();
  Future<DashboardPlanDto> getPlan();
  Future<DashboardPlanDto> toggleTask(String taskId);
  Future<List<DevelopmentAxisDto>> getDevelopmentAxes();
}

/// In-memory dummy data for tests and previews. No Supabase, no HTTP.
///
/// NOTE: focusSecondsThisSemester and focusSecondsThisWeek are seeded
/// with plausible values (not zero) so the semester-hours badge and
/// hours-this-week badge both render in the preview/smoke-test.
class DashboardDummyDataSource implements DashboardDataSource {
  static final DateTime _today = DateTime.now();
  static DateTime _localDate(DateTime d) => DateTime(d.year, d.month, d.day);

  // Deterministic-but-varied daily completion counts for the rolling 30-day
  // window, most recent day last.
  static final List<int> _last30 = List.generate(30, (i) {
    const pattern = [0, 2, 3, 1, 4, 0, 2, 3, 1, 0];
    return pattern[i % pattern.length];
  });

  // Empty rather than fake placeholder tasks — the collapsible card's
  // "Today's Tasks" section already shows the `empty_tasks` Lottie animation
  // whenever `remainingTasks` is empty (see `_TodaysTasks` in
  // expandable_progress_card.dart), so this is what drives that state in the
  // dummy-data preview instead of hardcoded fake tasks.
  final List<DashboardTaskDto> _tasks = [];

  @override
  Future<ProgressStatsDto> getProgressStats() async {
    await Future.delayed(const Duration(milliseconds: 400));
    // 132.5 h this semester ≈ 477_000 s; 8 h this week ≈ 28_800 s
    return ProgressStatsDto(
      tasksCompletedThisWeek: 9,
      tasksPlannedThisWeek: 14,
      focusSecondsThisSemester: 477000,
      focusSecondsThisWeek: 28800,
      dailyCompletions: List.generate(30, (i) {
        final date = _localDate(_today).subtract(Duration(days: 29 - i));
        return DailyCompletionDto(
          date: date.toIso8601String().split('T').first,
          tasksCompleted: _last30[i],
        );
      }),
    );
  }

  @override
  Future<DashboardPlanDto> getPlan() async {
    await Future.delayed(const Duration(milliseconds: 900));
    return DashboardPlanDto(plan: List.of(_tasks), stale: false, note: null);
  }

  @override
  Future<DashboardPlanDto> toggleTask(String taskId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final t = _tasks[index];
      _tasks[index] = DashboardTaskDto(
        id: t.id,
        title: t.title,
        subject: t.subject,
        timerMinutes: t.timerMinutes,
        completed: !t.completed,
      );
    }
    return DashboardPlanDto(plan: List.of(_tasks), stale: false, note: null);
  }

  @override
  Future<List<DevelopmentAxisDto>> getDevelopmentAxes() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const [
      DevelopmentAxisDto(
        label: 'Technical Depth',
        startOfSemester: 0.35,
        now: 0.62,
      ),
      DevelopmentAxisDto(
        label: 'Communication',
        startOfSemester: 0.5,
        now: 0.58,
      ),
      DevelopmentAxisDto(label: 'Leadership', startOfSemester: 0.2, now: 0.4),
      DevelopmentAxisDto(
        label: 'Research Aptitude',
        startOfSemester: 0.3,
        now: 0.45,
      ),
      DevelopmentAxisDto(
        label: 'Problem Solving',
        startOfSemester: 0.55,
        now: 0.7,
      ),
      DevelopmentAxisDto(
        label: 'Domain Breadth',
        startOfSemester: 0.4,
        now: 0.5,
      ),
    ];
  }
}
