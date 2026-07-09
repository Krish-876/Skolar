class OnboardingEntity {
  final String? nickname;
  final String? branch;
  final String? studyGoal;
  final String plan;
  final List<String> selectedSubjectIds;

  const OnboardingEntity({
    this.nickname,
    this.branch,
    this.studyGoal,
    this.plan = 'free',
    this.selectedSubjectIds = const [],
  });

  OnboardingEntity copyWith({
    String? nickname,
    String? branch,
    String? studyGoal,
    String? plan,
    List<String>? selectedSubjectIds,
  }) => OnboardingEntity(
    nickname: nickname ?? this.nickname,
    branch: branch ?? this.branch,
    studyGoal: studyGoal ?? this.studyGoal,
    plan: plan ?? this.plan,
    selectedSubjectIds: selectedSubjectIds ?? this.selectedSubjectIds,
  );

  bool get isComplete =>
      nickname != null && nickname!.trim().isNotEmpty && branch != null;
}
