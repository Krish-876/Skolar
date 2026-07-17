import '../../domain/entities/onboarding_entity.dart';

class OnboardingDto {
  final String? endgame;
  final List<String> careerInterests;
  final String? prepStyle;
  final String? derailer;
  final String? bufferPref;
  final String? dailyCapacity;

  const OnboardingDto({
    this.endgame,
    this.careerInterests = const [],
    this.prepStyle,
    this.derailer,
    this.bufferPref,
    this.dailyCapacity,
  });

  factory OnboardingDto.fromEntity(OnboardingEntity e) => OnboardingDto(
    endgame: e.endgame,
    careerInterests: e.careerInterests,
    prepStyle: e.prepStyle,
    derailer: e.derailer,
    bufferPref: e.bufferPref,
    dailyCapacity: e.dailyCapacity,
  );
}
