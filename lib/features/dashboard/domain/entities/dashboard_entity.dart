/// A single day's completion count, used by the streak strip and the
/// weekly/monthly rollups. `date` is always a local calendar date (midnight,
/// no time component) — never a UTC instant — since a "day" for streak
/// purposes is defined by the student's local clock.
class DailyCompletion {
  final DateTime date;
  final int tasksCompleted;

  const DailyCompletion({required this.date, required this.tasksCompleted});

  /// A day counts toward the streak if any task was completed on it.
  bool get isActiveDay => tasksCompleted > 0;
}

/// Supabase-sourced counters — deliberately separate from [DashboardPlan]
/// (which comes from Nova) so the two data sources never get conflated.
class ProgressStats {
  final int tasksCompletedThisWeek;
  final int tasksPlannedThisWeek;
  final double cumulativeHoursThisSemester;

  /// Rolling last-30-days window, most recent day last.
  final List<DailyCompletion> dailyCompletions;

  const ProgressStats({
    required this.tasksCompletedThisWeek,
    required this.tasksPlannedThisWeek,
    required this.cumulativeHoursThisSemester,
    required this.dailyCompletions,
  });

  double get weeklyCompletionRatio => tasksPlannedThisWeek == 0
      ? 0.0
      : (tasksCompletedThisWeek / tasksPlannedThisWeek).clamp(0.0, 1.0);
}

/// One item in a Nova-generated plan.
class DashboardTask {
  final String id;
  final String title;
  final String subject;
  final Duration timerDuration;
  final bool completed;

  const DashboardTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.timerDuration,
    this.completed = false,
  });

  DashboardTask copyWith({bool? completed}) => DashboardTask(
    id: id,
    title: title,
    subject: subject,
    timerDuration: timerDuration,
    completed: completed ?? this.completed,
  );
}

/// Mirrors the future `POST /reasoning/{user_id}/run` response shape:
/// `{plan, stale, note}`.
class DashboardPlan {
  final List<DashboardTask> tasks;
  final bool stale;
  final String? note;

  const DashboardPlan({required this.tasks, this.stale = false, this.note});

  List<DashboardTask> get remainingTasks =>
      tasks.where((t) => !t.completed).toList(growable: false);
}

/// One axis of the all-round development radar. The axis list itself is
/// data (later: the student's declared career units), never hardcoded in
/// the chart widget.
class DevelopmentAxis {
  final String label;

  /// 0..1 scale.
  final double startOfSemester;

  /// 0..1 scale.
  final double now;

  const DevelopmentAxis({
    required this.label,
    required this.startOfSemester,
    required this.now,
  });
}
