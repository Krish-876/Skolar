import '../../domain/entities/mock_tests_entity.dart';

class MockTestsDto {
  final String id;
  final String testName;
  final int durationMinutes;

  const MockTestsDto({required this.id, required this.testName, required this.durationMinutes});

  factory MockTestsDto.fromJson(Map<String, dynamic> json) => MockTestsDto(
      id: json['id'] as String,
      testName: json['testName'] as String,
      durationMinutes: json['durationMinutes'] as int,
  );

  Map<String, dynamic> toJson() => {
      'id': id,
      'testName': testName,
      'durationMinutes': durationMinutes,
  };

  MockTestsEntity toEntity() => MockTestsEntity(id: id, testName: testName, durationMinutes: durationMinutes);
}
