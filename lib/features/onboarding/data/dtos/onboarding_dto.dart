import '../../domain/entities/onboarding_entity.dart';

class OnboardingDto {
  final String id;
  final String stepTitle;
  final String description;

  const OnboardingDto({required this.id, required this.stepTitle, required this.description});

  factory OnboardingDto.fromJson(Map<String, dynamic> json) => OnboardingDto(
      id: json['id'] as String,
      stepTitle: json['stepTitle'] as String,
      description: json['description'] as String,
  );

  Map<String, dynamic> toJson() => {
      'id': id,
      'stepTitle': stepTitle,
      'description': description,
  };

  OnboardingEntity toEntity() => OnboardingEntity(id: id, stepTitle: stepTitle, description: description);
}
