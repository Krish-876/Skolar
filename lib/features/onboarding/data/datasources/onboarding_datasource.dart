import 'package:Skolar/features/onboarding/data/dtos/onboarding_dto.dart';

/// Phase 5: replace with OnboardingRemoteDataSource (Firestore write).
abstract class OnboardingDataSource {
  Future<void> save(OnboardingDto dto);
}

/// Stub — no-op until Firebase lands.
class OnboardingLocalDataSource implements OnboardingDataSource {
  @override
  Future<void> save(OnboardingDto dto) async {}
}