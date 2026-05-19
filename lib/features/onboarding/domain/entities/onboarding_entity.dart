import 'package:nova/shared/models/base_models.dart';

class OnboardingEntity extends BaseEntity {
  final String stepTitle;
  final String description;
  const OnboardingEntity({required super.id, required this.stepTitle, required this.description});
}
