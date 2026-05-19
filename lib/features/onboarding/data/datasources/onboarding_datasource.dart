import '../dtos/onboarding_dto.dart';

abstract class OnboardingDataSource {
  Future<List<OnboardingDto>> getAll();
  Future<OnboardingDto> getById(String id);
}

class OnboardingRemoteDataSource implements OnboardingDataSource {
  @override Future<List<OnboardingDto>> getAll() async => [];
  @override Future<OnboardingDto> getById(String id) => throw UnimplementedError();
}
