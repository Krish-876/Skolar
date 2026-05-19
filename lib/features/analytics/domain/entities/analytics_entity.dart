import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_entity.freezed.dart';

@freezed
class WeeklyDataPoint with _$WeeklyDataPoint {
  const factory WeeklyDataPoint({
    required String label,
    required double value,
  }) = _WeeklyDataPoint;
}

@freezed
class RecentActivity with _$RecentActivity {
  const factory RecentActivity({
    required String time,
    required String title,
    required String subtitle,
    required String dueDate,
    @Default([]) List<String> participantAvatars,
  }) = _RecentActivity;
}

@freezed
class TaskItem with _$TaskItem {
  const factory TaskItem({
    required String title,
    required String dueDate,
    @Default([]) List<String> assigneeAvatars,
  }) = _TaskItem;
}

@freezed
class AnalyticsData with _$AnalyticsData {
  const factory AnalyticsData({
    required int totalTasksCompleted,
    required double todoPercent,
    required double inProgressPercent,
    required double completedPercent,
    required List<WeeklyDataPoint> weeklyProgress,
    required List<TaskItem> tasks,
    required List<RecentActivity> recentActivities,
    @Default(0.0) double syllabusProgress,
    @Default(0.0) double accuracy,
  }) = _AnalyticsData;
}