import 'package:Skolar/features/onboarding/data/datasources/onboarding_datasource.dart';
import 'package:Skolar/features/onboarding/data/dtos/onboarding_dto.dart';
import 'package:Skolar/features/onboarding/domain/entities/onboarding_entity.dart';
import 'package:Skolar/features/onboarding/domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingDataSource _dataSource;
  const OnboardingRepositoryImpl(this._dataSource);

  @override
  Future<void> save(OnboardingEntity data) =>
      _dataSource.save(OnboardingDto.fromEntity(data));
}
