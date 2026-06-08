import '../../domain/entities/onboarding_entity.dart';

class OnboardingDto {
  final String nickname;
  final String branch;
  final String studyGoal;
  final String plan;
  final List<String> selectedSubjectIds;

  const OnboardingDto({
    required this.nickname,
    required this.branch,
    required this.studyGoal,
    required this.plan,
    required this.selectedSubjectIds,
  });

  factory OnboardingDto.fromEntity(OnboardingEntity e) => OnboardingDto(
    nickname:           e.nickname   ?? '',
    branch:             e.branch     ?? '',
    studyGoal:          e.studyGoal  ?? '',
    plan:               e.plan,
    selectedSubjectIds: e.selectedSubjectIds,
  );
}