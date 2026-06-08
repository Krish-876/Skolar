import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/onboarding/data/datasources/onboarding_datasource.dart';
import 'package:Skolar/features/onboarding/data/repository_impl/onboarding_repository_impl.dart';
import 'package:Skolar/features/onboarding/domain/entities/onboarding_entity.dart';
import 'package:Skolar/features/onboarding/domain/usecases/onboarding_usecases.dart';
import 'package:Skolar/shared/providers/global_providers.dart';

final _onboardingDataSourceProvider = Provider<OnboardingDataSource>(
  (_) => OnboardingRemoteDataSource(),
);

final _onboardingRepositoryProvider = Provider<OnboardingRepositoryImpl>(
  (ref) => OnboardingRepositoryImpl(ref.read(_onboardingDataSourceProvider)),
);

final saveOnboardingUseCaseProvider = Provider<SaveOnboardingUseCase>(
  (ref) => SaveOnboardingUseCase(ref.read(_onboardingRepositoryProvider)),
);

class OnboardingNotifier extends Notifier<OnboardingEntity> {
  @override
  OnboardingEntity build() => const OnboardingEntity();

  void setNickname(String value)   => state = state.copyWith(nickname: value.trim());
  void setBranch(String value)     => state = state.copyWith(branch: value);
  void setStudyGoal(String value)  => state = state.copyWith(studyGoal: value);
  void setPlan(String value)       => state = state.copyWith(plan: value);
  void toggleSubject(String id) {
    final current = List<String>.from(state.selectedSubjectIds);
    if (current.contains(id)) { current.remove(id); } else { current.add(id); }
    state = state.copyWith(selectedSubjectIds: current);
  }

  Future<void> complete() async {
    await ref.read(saveOnboardingUseCaseProvider).call(state);
    // Refresh userProvider so dashboard reads real data immediately
    await ref.read(userProvider.notifier).refresh();
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingEntity>(
  OnboardingNotifier.new,
);