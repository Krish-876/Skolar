class PlanItemEntity {
  final String subject;
  final String task;
  final int priority;
  final String reason;

  const PlanItemEntity({
    required this.subject,
    required this.task,
    required this.priority,
    required this.reason,
  });
}

class StudyPlanEntity {
  final List<PlanItemEntity> items;
  final String? summary;
  final bool stale;
  final String? note;

  const StudyPlanEntity({
    required this.items,
    this.summary,
    this.stale = false,
    this.note,
  });
}
