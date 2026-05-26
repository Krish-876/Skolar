import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/onboarding/domain/entities/onboarding_entity.dart';

/// Holds onboarding answers in memory until Firebase auth is complete.
/// Phase 5: inject SaveOnboardingUseCase and call it inside [complete].
class OnboardingNotifier extends Notifier<OnboardingEntity> {
  @override
  OnboardingEntity build() => const OnboardingEntity();

  void setNickname(String value) =>
      state = state.copyWith(nickname: value.trim());

  void setBranch(String value) =>
      state = state.copyWith(branch: value);

  void setStudyGoal(String value) =>
      state = state.copyWith(studyGoal: value);

  /// Phase 5: await saveOnboardingUseCase(state) here.
  void complete() {
    // TODO(phase5): persist via SaveOnboardingUseCase
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingEntity>(
  OnboardingNotifier.new,
);