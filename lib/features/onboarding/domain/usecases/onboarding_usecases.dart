import 'package:Skolar/features/onboarding/domain/entities/onboarding_entity.dart';
import 'package:Skolar/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Phase 5: called from OnboardingNotifier.complete() once Firestore is live.
class SaveOnboardingUseCase {
  final OnboardingRepository _repository;
  const SaveOnboardingUseCase(this._repository);

  Future<void> call(OnboardingEntity data) => _repository.save(data);
}