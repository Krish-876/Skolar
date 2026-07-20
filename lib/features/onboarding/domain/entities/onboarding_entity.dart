class OnboardingEntity {
  // Pre-Questionnaire fields
  final String? avatarData;
  final String? name;
  final String? id;
  final String? campus;
  final String? branch;
  final String? dualBranch;
  final int? currentYear;
  final int? currentSemester;
  final String? studyCapacity;

  // Questionnaire fields
  final String? endgame;
  final List<String> careerInterests;
  final String? prepStyle;
  final String? derailer;
  final String? bufferPref;
  final String? dailyCapacity;

  const OnboardingEntity({
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

  OnboardingEntity copyWith({
    String? avatarData,
    String? name,
    String? id,
    String? campus,
    String? branch,
    String? dualBranch,
    int? currentYear,
    int? currentSemester,
    String? studyCapacity,
    String? endgame,
    List<String>? careerInterests,
    String? prepStyle,
    String? derailer,
    String? bufferPref,
    String? dailyCapacity,
  }) => OnboardingEntity(
    avatarData: avatarData ?? this.avatarData,
    name: name ?? this.name,
    id: id ?? this.id,
    campus: campus ?? this.campus,
    branch: branch ?? this.branch,
    dualBranch: dualBranch ?? this.dualBranch,
    currentYear: currentYear ?? this.currentYear,
    currentSemester: currentSemester ?? this.currentSemester,
    studyCapacity: studyCapacity ?? this.studyCapacity,
    endgame: endgame ?? this.endgame,
    careerInterests: careerInterests ?? this.careerInterests,
    prepStyle: prepStyle ?? this.prepStyle,
    derailer: derailer ?? this.derailer,
    bufferPref: bufferPref ?? this.bufferPref,
    dailyCapacity: dailyCapacity ?? this.dailyCapacity,
  );

  bool get isComplete =>
      endgame != null &&
      careerInterests.isNotEmpty &&
      prepStyle != null &&
      derailer != null &&
      bufferPref != null &&
      (dailyCapacity != null || studyCapacity != null);
}
