/// Onboarding data collected before auth.
/// Plain Dart — no @freezed until Firebase lands (Phase 5).
class OnboardingEntity {
  final String? nickname;
  final String? branch;
  final String? studyGoal;

  const OnboardingEntity({this.nickname, this.branch, this.studyGoal});

  OnboardingEntity copyWith({
    String? nickname,
    String? branch,
    String? studyGoal,
  }) =>
      OnboardingEntity(
        nickname:  nickname  ?? this.nickname,
        branch:    branch    ?? this.branch,
        studyGoal: studyGoal ?? this.studyGoal,
      );

  /// Gates the final CTA — all three fields must be filled.
  bool get isComplete =>
      nickname != null &&
      nickname!.trim().isNotEmpty &&
      branch != null &&
      studyGoal != null;
}