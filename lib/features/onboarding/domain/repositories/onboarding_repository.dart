import 'package:Skolar/features/onboarding/domain/entities/onboarding_entity.dart';

/// Phase 5: OnboardingRepositoryImpl writes to Firestore.
abstract class OnboardingRepository {
  Future<void> save(OnboardingEntity data);
}
