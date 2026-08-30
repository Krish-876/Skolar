import '../../domain/entities/dashboard_entity.dart';

class DailyCompletionDto {
  final String date; // ISO yyyy-MM-dd
  final int tasksCompleted;

  const DailyCompletionDto({required this.date, required this.tasksCompleted});

  factory DailyCompletionDto.fromJson(Map<String, dynamic> json) =>
      DailyCompletionDto(
        date: json['date'] as String,
        tasksCompleted: json['tasksCompleted'] as int,
      );

  Map<String, dynamic> toJson() => {'date': date, 'tasksCompleted': tasksCompleted};

  DailyCompletion toEntity() =>
      DailyCompletion(date: DateTime.parse(date), tasksCompleted: tasksCompleted);
}

class ProgressStatsDto {
  final int tasksCompletedThisWeek;
  final int tasksPlannedThisWeek;
  final double cumulativeHoursThisSemester;
  final List<DailyCompletionDto> dailyCompletions;

  const ProgressStatsDto({
    required this.tasksCompletedThisWeek,
    required this.tasksPlannedThisWeek,
    required this.cumulativeHoursThisSemester,
    required this.dailyCompletions,
  });

  factory ProgressStatsDto.fromJson(Map<String, dynamic> json) => ProgressStatsDto(
    tasksCompletedThisWeek: json['tasksCompletedThisWeek'] as int,
    tasksPlannedThisWeek: json['tasksPlannedThisWeek'] as int,
    cumulativeHoursThisSemester:
        (json['cumulativeHoursThisSemester'] as num).toDouble(),
    dailyCompletions: (json['dailyCompletions'] as List)
        .map((e) => DailyCompletionDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'tasksCompletedThisWeek': tasksCompletedThisWeek,
    'tasksPlannedThisWeek': tasksPlannedThisWeek,
    'cumulativeHoursThisSemester': cumulativeHoursThisSemester,
    'dailyCompletions': dailyCompletions.map((e) => e.toJson()).toList(),
  };

  ProgressStats toEntity() => ProgressStats(
    tasksCompletedThisWeek: tasksCompletedThisWeek,
    tasksPlannedThisWeek: tasksPlannedThisWeek,
    cumulativeHoursThisSemester: cumulativeHoursThisSemester,
    dailyCompletions: dailyCompletions.map((e) => e.toEntity()).toList(),
  );
}

class DashboardTaskDto {
  final String id;
  final String title;
  final String subject;
  final int timerMinutes;
  final bool completed;

  const DashboardTaskDto({
    required this.id,
    required this.title,
    required this.subject,
    required this.timerMinutes,
    this.completed = false,
  });

  factory DashboardTaskDto.fromJson(Map<String, dynamic> json) => DashboardTaskDto(
    id: json['id'] as String,
    title: json['title'] as String,
    subject: json['subject'] as String,
    timerMinutes: json['timerMinutes'] as int,
    completed: json['completed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'timerMinutes': timerMinutes,
    'completed': completed,
  };

  DashboardTask toEntity() => DashboardTask(
    id: id,
    title: title,
    subject: subject,
    timerDuration: Duration(minutes: timerMinutes),
    completed: completed,
  );
}

/// Mirrors the future Nova `POST /reasoning/{user_id}/run` response:
/// `{plan, stale, note}`.
class DashboardPlanDto {
  final List<DashboardTaskDto> plan;
  final bool stale;
  final String? note;

  const DashboardPlanDto({required this.plan, this.stale = false, this.note});

  factory DashboardPlanDto.fromJson(Map<String, dynamic> json) => DashboardPlanDto(
    plan: (json['plan'] as List)
        .map((e) => DashboardTaskDto.fromJson(e as Map<String, dynamic>))
        .toList(),
    stale: json['stale'] as bool? ?? false,
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'plan': plan.map((e) => e.toJson()).toList(),
    'stale': stale,
    'note': note,
  };

  DashboardPlan toEntity() => DashboardPlan(
    tasks: plan.map((e) => e.toEntity()).toList(),
    stale: stale,
    note: note,
  );
}

class DevelopmentAxisDto {
  final String label;
  final double startOfSemester;
  final double now;

  const DevelopmentAxisDto({
    required this.label,
    required this.startOfSemester,
    required this.now,
  });

  factory DevelopmentAxisDto.fromJson(Map<String, dynamic> json) =>
      DevelopmentAxisDto(
        label: json['label'] as String,
        startOfSemester: (json['startOfSemester'] as num).toDouble(),
        now: (json['now'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'label': label,
    'startOfSemester': startOfSemester,
    'now': now,
  };

  DevelopmentAxis toEntity() =>
      DevelopmentAxis(label: label, startOfSemester: startOfSemester, now: now);
}
