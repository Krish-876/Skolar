import 'package:Skolar/features/nova_chat/domain/entities/study_plan_entity.dart';

class PlanItemDto {
  final String subject;
  final String task;
  final int priority;
  final String reason;

  const PlanItemDto({
    required this.subject,
    required this.task,
    required this.priority,
    required this.reason,
  });

  factory PlanItemDto.fromJson(Map<String, dynamic> json) {
    return PlanItemDto(
      subject: json['subject'] as String? ?? 'General',
      task: json['task'] as String? ?? '',
      priority: json['priority'] as int? ?? 1,
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'task': task,
      'priority': priority,
      'reason': reason,
    };
  }

  PlanItemEntity toEntity() => PlanItemEntity(
    subject: subject,
    task: task,
    priority: priority,
    reason: reason,
  );
}

class StudyPlanDto {
  final List<PlanItemDto> items;
  final String? summary;
  final bool stale;
  final String? note;

  const StudyPlanDto({
    required this.items,
    this.summary,
    this.stale = false,
    this.note,
  });

  factory StudyPlanDto.fromJson(Map<String, dynamic> json) {
    final planObj = json['plan'] as Map<String, dynamic>? ?? json;
    final rawItems = planObj['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => PlanItemDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return StudyPlanDto(
      items: items,
      summary: planObj['summary'] as String?,
      stale: json['stale'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  StudyPlanEntity toEntity() => StudyPlanEntity(
    items: items.map((e) => e.toEntity()).toList(),
    summary: summary,
    stale: stale,
    note: note,
  );
}
