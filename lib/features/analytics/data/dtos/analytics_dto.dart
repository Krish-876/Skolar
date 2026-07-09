import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/analytics_entity.dart';

part 'analytics_dto.g.dart';

@JsonSerializable()
class WeeklyDataPointDto {
  final String label;
  final double value;

  const WeeklyDataPointDto({required this.label, required this.value});

  factory WeeklyDataPointDto.fromJson(Map<String, dynamic> json) =>
      _$WeeklyDataPointDtoFromJson(json);

  Map<String, dynamic> toJson() => _$WeeklyDataPointDtoToJson(this);

  WeeklyDataPoint toDomain() => WeeklyDataPoint(label: label, value: value);
}

@JsonSerializable()
class RecentActivityDto {
  final String time;
  final String title;
  final String subtitle;
  @JsonKey(name: 'due_date')
  final String dueDate;
  @JsonKey(name: 'participant_avatars', defaultValue: [])
  final List<String> participantAvatars;

  const RecentActivityDto({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.dueDate,
    required this.participantAvatars,
  });

  factory RecentActivityDto.fromJson(Map<String, dynamic> json) =>
      _$RecentActivityDtoFromJson(json);

  Map<String, dynamic> toJson() => _$RecentActivityDtoToJson(this);

  RecentActivity toDomain() => RecentActivity(
    time: time,
    title: title,
    subtitle: subtitle,
    dueDate: dueDate,
    participantAvatars: participantAvatars,
  );
}

@JsonSerializable()
class TaskItemDto {
  final String title;
  @JsonKey(name: 'due_date')
  final String dueDate;
  @JsonKey(name: 'assignee_avatars', defaultValue: [])
  final List<String> assigneeAvatars;

  const TaskItemDto({
    required this.title,
    required this.dueDate,
    required this.assigneeAvatars,
  });

  factory TaskItemDto.fromJson(Map<String, dynamic> json) =>
      _$TaskItemDtoFromJson(json);

  Map<String, dynamic> toJson() => _$TaskItemDtoToJson(this);

  TaskItem toDomain() => TaskItem(
    title: title,
    dueDate: dueDate,
    assigneeAvatars: assigneeAvatars,
  );
}

@JsonSerializable()
class AnalyticsDataDto {
  @JsonKey(name: 'total_tasks_completed')
  final int totalTasksCompleted;
  @JsonKey(name: 'todo_percent')
  final double todoPercent;
  @JsonKey(name: 'in_progress_percent')
  final double inProgressPercent;
  @JsonKey(name: 'completed_percent')
  final double completedPercent;
  @JsonKey(name: 'weekly_progress')
  final List<WeeklyDataPointDto> weeklyProgress;
  final List<TaskItemDto> tasks;
  @JsonKey(name: 'recent_activities')
  final List<RecentActivityDto> recentActivities;
  @JsonKey(name: 'syllabus_progress', defaultValue: 0.0)
  final double syllabusProgress;
  @JsonKey(defaultValue: 0.0)
  final double accuracy;

  const AnalyticsDataDto({
    required this.totalTasksCompleted,
    required this.todoPercent,
    required this.inProgressPercent,
    required this.completedPercent,
    required this.weeklyProgress,
    required this.tasks,
    required this.recentActivities,
    required this.syllabusProgress,
    required this.accuracy,
  });

  factory AnalyticsDataDto.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsDataDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AnalyticsDataDtoToJson(this);

  AnalyticsData toDomain() => AnalyticsData(
    totalTasksCompleted: totalTasksCompleted,
    todoPercent: todoPercent,
    inProgressPercent: inProgressPercent,
    completedPercent: completedPercent,
    weeklyProgress: weeklyProgress.map((e) => e.toDomain()).toList(),
    tasks: tasks.map((e) => e.toDomain()).toList(),
    recentActivities: recentActivities.map((e) => e.toDomain()).toList(),
    syllabusProgress: syllabusProgress,
    accuracy: accuracy,
  );
}
