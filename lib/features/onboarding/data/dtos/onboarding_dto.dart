import '../../domain/entities/onboarding_entity.dart';

class OnboardingDto {
  final String? avatarData;
  final String? name;
  final String? id;
  final String? campus;
  final String? branch;
  final String? dualBranch;
  final int? currentYear;
  final int? currentSemester;
  final String? studyCapacity;

  final String? endgame;
  final List<String> careerInterests;
  final String? prepStyle;
  final String? derailer;
  final String? bufferPref;
  final String? dailyCapacity;

  const OnboardingDto({
    this.avatarData,
    this.name,
    this.id,
    this.campus,
    this.branch,
    this.dualBranch,
    this.currentYear,
    this.currentSemester,
    this.studyCapacity,
    this.endgame,
    this.careerInterests = const [],
    this.prepStyle,
    this.derailer,
    this.bufferPref,
    this.dailyCapacity,
  });

  factory OnboardingDto.fromEntity(OnboardingEntity e) => OnboardingDto(
    avatarData: e.avatarData,
    name: e.name,
    id: e.id,
    campus: e.campus,
    branch: e.branch,
    dualBranch: e.dualBranch,
    currentYear: e.currentYear,
    currentSemester: e.currentSemester,
    studyCapacity: e.studyCapacity,
    endgame: e.endgame,
    careerInterests: e.careerInterests,
    prepStyle: e.prepStyle,
    derailer: e.derailer,
    bufferPref: e.bufferPref,
    dailyCapacity: e.dailyCapacity,
  );
}
