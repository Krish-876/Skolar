import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';
import '../entities/onboarding_entity.dart';

abstract class OnboardingRepository {
  Future<Either<Failure, List<OnboardingEntity>>> getAll();
  Future<Either<Failure, OnboardingEntity>> getById(String id);
}
