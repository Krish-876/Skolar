// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeeklyDataPointDto _$WeeklyDataPointDtoFromJson(Map<String, dynamic> json) =>
    WeeklyDataPointDto(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
    );

Map<String, dynamic> _$WeeklyDataPointDtoToJson(WeeklyDataPointDto instance) =>
    <String, dynamic>{'label': instance.label, 'value': instance.value};

RecentActivityDto _$RecentActivityDtoFromJson(Map<String, dynamic> json) =>
    RecentActivityDto(
      time: json['time'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      dueDate: json['due_date'] as String,
      participantAvatars:
          (json['participant_avatars'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );

Map<String, dynamic> _$RecentActivityDtoToJson(RecentActivityDto instance) =>
    <String, dynamic>{
      'time': instance.time,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'due_date': instance.dueDate,
      'participant_avatars': instance.participantAvatars,
    };

TaskItemDto _$TaskItemDtoFromJson(Map<String, dynamic> json) => TaskItemDto(
  title: json['title'] as String,
  dueDate: json['due_date'] as String,
  assigneeAvatars:
      (json['assignee_avatars'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$TaskItemDtoToJson(TaskItemDto instance) =>
    <String, dynamic>{
      'title': instance.title,
      'due_date': instance.dueDate,
      'assignee_avatars': instance.assigneeAvatars,
    };

AnalyticsDataDto _$AnalyticsDataDtoFromJson(Map<String, dynamic> json) =>
    AnalyticsDataDto(
      totalTasksCompleted: (json['total_tasks_completed'] as num).toInt(),
      todoPercent: (json['todo_percent'] as num).toDouble(),
      inProgressPercent: (json['in_progress_percent'] as num).toDouble(),
      completedPercent: (json['completed_percent'] as num).toDouble(),
      weeklyProgress: (json['weekly_progress'] as List<dynamic>)
          .map((e) => WeeklyDataPointDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      tasks: (json['tasks'] as List<dynamic>)
          .map((e) => TaskItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentActivities: (json['recent_activities'] as List<dynamic>)
          .map((e) => RecentActivityDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      syllabusProgress: (json['syllabus_progress'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$AnalyticsDataDtoToJson(AnalyticsDataDto instance) =>
    <String, dynamic>{
      'total_tasks_completed': instance.totalTasksCompleted,
      'todo_percent': instance.todoPercent,
      'in_progress_percent': instance.inProgressPercent,
      'completed_percent': instance.completedPercent,
      'weekly_progress': instance.weeklyProgress,
      'tasks': instance.tasks,
      'recent_activities': instance.recentActivities,
      'syllabus_progress': instance.syllabusProgress,
      'accuracy': instance.accuracy,
    };
