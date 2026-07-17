class OnboardingEntity {
  final String? endgame;
  final List<String> careerInterests;
  final String? prepStyle;
  final String? derailer;
  final String? bufferPref;
  final String? dailyCapacity;

  const OnboardingEntity({
    this.endgame,
    this.careerInterests = const [],
    this.prepStyle,
    this.derailer,
    this.bufferPref,
    this.dailyCapacity,
  });

  OnboardingEntity copyWith({
    String? endgame,
    List<String>? careerInterests,
    String? prepStyle,
    String? derailer,
    String? bufferPref,
    String? dailyCapacity,
  }) => OnboardingEntity(
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
      dailyCapacity != null;
}
