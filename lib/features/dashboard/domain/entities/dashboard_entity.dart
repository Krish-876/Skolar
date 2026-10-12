/// A single day's completion data, used by the streak strip and rollups.
///
/// [date] is always a local calendar date (midnight, no time component)
/// — never a UTC instant — since a "day" for streak purposes is defined
/// by the student's local clock.
///
/// [sessionCount] is the number of activity_log rows for this day (used
/// by the heatmap tint — previously called tasksCompleted).
///
/// [focusSecondsThisDay] is the sum of duration_seconds only for rows
/// that meet or exceed the configured threshold (used for the hours badge).
class DailyCompletion {
  final DateTime date;

  /// Number of focus sessions logged on this day (drives heatmap tint).
  /// Replaces the old `tasksCompleted` field; semantics differ: these are
  /// session-count rows, not task-completion events. isActiveDay semantics
  /// are preserved: any session > 0 counts as an active day.
  final int sessionCount;

  const DailyCompletion({required this.date, required this.sessionCount});

  /// A day counts toward the streak if at least one session was logged.
  bool get isActiveDay => sessionCount > 0;

  /// Legacy accessor so widgets that read `.tasksCompleted` keep compiling
  /// without changes; both refer to the same value.
  int get tasksCompleted => sessionCount;
}

/// Supabase-sourced counters — deliberately separate from [DashboardPlan]
/// (which comes from Nova) so the two data sources never get conflated.
class ProgressStats {
  final int tasksCompletedThisWeek;
  final int tasksPlannedThisWeek;

  /// Total focus seconds that meet the threshold, for the current semester.
  /// Format in presentation only (presentation/providers compute hours label).
  final int focusSecondsThisSemester;

  /// Focus seconds that meet the threshold for the current configured week.
  final int focusSecondsThisWeek;

  /// Rolling window (semester range), one entry per calendar day, most
  /// recent day last. Days with no sessions will still be present if the
  /// datasource includes them, but may also be absent — the widget handles
  /// both via a Map lookup with a default of zero.
  final List<DailyCompletion> dailyCompletions;

  const ProgressStats({
    required this.tasksCompletedThisWeek,
    required this.tasksPlannedThisWeek,
    required this.focusSecondsThisSemester,
    required this.focusSecondsThisWeek,
    required this.dailyCompletions,
  });

  double get weeklyCompletionRatio => tasksPlannedThisWeek == 0
      ? 0.0
      : (tasksCompletedThisWeek / tasksPlannedThisWeek).clamp(0.0, 1.0);

  /// Convenience accessor in hours (for display).
  double get hoursThisWeek => focusSecondsThisWeek / 3600.0;

  /// Convenience accessor in hours (for display).
  double get hoursThisSemester => focusSecondsThisSemester / 3600.0;
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
