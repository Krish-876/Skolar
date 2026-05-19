import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/usecase.dart';
import '../entities/onboarding_entity.dart';
import '../repositories/onboarding_repository.dart';

class GetAllOnboarding implements UseCase<List<OnboardingEntity>, NoParams> {
  final OnboardingRepository repository;
  const GetAllOnboarding(this.repository);

  @override
  Future<Either<Failure, List<OnboardingEntity>>> call(NoParams params) =>
      repository.getAll();
}
