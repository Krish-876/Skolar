import 'package:Skolar/shared/models/base_models.dart';

class MockTestsEntity extends BaseEntity {
  final String testName;
  final int durationMinutes;
  const MockTestsEntity({required super.id, required this.testName, required this.durationMinutes});
}
