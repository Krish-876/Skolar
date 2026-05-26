import 'package:Skolar/features/onboarding/domain/entities/onboarding_entity.dart';

/// Phase 5: add @JsonSerializable + fromJson/toJson for Firestore.
/// Currently unused — onboarding data lives in memory only.
class OnboardingDto {
  final String nickname;
  final String branch;
  final String studyGoal;

  const OnboardingDto({
    required this.nickname,
    required this.branch,
    required this.studyGoal,
  });

  OnboardingEntity toEntity() => OnboardingEntity(
        nickname: nickname,
        branch: branch,
        studyGoal: studyGoal,
      );

  factory OnboardingDto.fromEntity(OnboardingEntity e) => OnboardingDto(
        nickname: e.nickname ?? '',
        branch: e.branch ?? '',
        studyGoal: e.studyGoal ?? '',
      );
}