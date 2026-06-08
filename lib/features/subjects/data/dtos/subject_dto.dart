import '../../domain/entities/subject_entity.dart';

class SubjectDto {
  final String id;
  final String name;
  final String? shortName;
  final int academicYear;
  final String institutionId;

  const SubjectDto({
    required this.id,
    required this.name,
    this.shortName,
    required this.academicYear,
    required this.institutionId,
  });

  factory SubjectDto.fromJson(Map<String, dynamic> json) => SubjectDto(
    id:            json['id']             as String,
    name:          json['name']           as String,
    shortName:     json['short_name']     as String?,
    academicYear:  json['academic_year']  as int,
    institutionId: json['institution_id'] as String,
  );

  SubjectEntity toEntity() => SubjectEntity(
    id:            id,
    name:          name,
    shortName:     shortName,
    academicYear:  academicYear,
    institutionId: institutionId,
  );
}