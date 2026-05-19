import 'package:nova/features/onboarding/domain/entities/onboarding_entity.dart';

import '../../../../core/errors/either.dart';
import '../../../../core/errors/failures.dart';

abstract class OnboardingRepository {
  Future<Either<Failure, List<OnboardingEntity>>> getAll();
  Future<Either<Failure, OnboardingEntity>> getById(String id);
}
