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

  void setEndgame(String value) => state = state.copyWith(endgame: value);
  void setPrepStyle(String value) => state = state.copyWith(prepStyle: value);
  void setDerailer(String value) => state = state.copyWith(derailer: value);
  void setBufferPref(String value) => state = state.copyWith(bufferPref: value);
  void setDailyCapacity(String value) =>
      state = state.copyWith(dailyCapacity: value);

  void toggleCareerInterest(String interest) {
    final current = List<String>.from(state.careerInterests);
    if (current.contains(interest)) {
      current.remove(interest);
    } else {
      current.add(interest);
    }
    state = state.copyWith(careerInterests: current);
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
