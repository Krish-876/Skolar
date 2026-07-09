import '../../domain/entities/subject_entity.dart';

class SubjectDto {
  final String userSubjectId;
  final String? subjectId;
  final String name;
  final String? shortName;
  final int? academicYear;
  final int? semester;
  final int? credits;
  final String? institutionId;
  final bool isCustom;
  final String? handoutUrl;
  final String? handoutFilename;

  const SubjectDto({
    required this.userSubjectId,
    this.subjectId,
    required this.name,
    this.shortName,
    this.academicYear,
    this.semester,
    this.credits,
    this.institutionId,
    this.isCustom = false,
    this.handoutUrl,
    this.handoutFilename,
  });

  factory SubjectDto.fromUserSubjectJson(Map<String, dynamic> json) {
    final subjectRel = json['subjects'] as Map<String, dynamic>?;
    final customRel = json['custom_subjects'] as Map<String, dynamic>?;

    if (subjectRel != null) {
      return SubjectDto(
        userSubjectId: json['id'] as String,
        subjectId: json['subject_id'] as String?,
        name: subjectRel['name'] as String? ?? 'Untitled',
        shortName: subjectRel['short_name'] as String?,
        academicYear: subjectRel['academic_year'] as int?,
        semester: subjectRel['semester'] as int?,
        credits: subjectRel['credits'] as int?,
        institutionId: subjectRel['institution_id'] as String?,
        isCustom: false,
        handoutUrl: json['handout_url'] as String?,
        handoutFilename: json['handout_filename'] as String?,
      );
    }

    return SubjectDto(
      userSubjectId: json['id'] as String,
      subjectId: null,
      name: customRel?['name'] as String? ?? 'Untitled',
      shortName: customRel?['course_code'] as String?,
      academicYear: null,
      semester: null,
      credits: customRel?['credits'] as int?,
      institutionId: null,
      isCustom: true,
      handoutUrl: json['handout_url'] as String?,
      handoutFilename: json['handout_filename'] as String?,
    );
  }

  SubjectEntity toEntity() => SubjectEntity(
    userSubjectId: userSubjectId,
    subjectId: subjectId,
    name: name,
    shortName: shortName,
    academicYear: academicYear,
    semester: semester,
    credits: credits,
    institutionId: institutionId,
    isCustom: isCustom,
    handoutUrl: handoutUrl,
    handoutFilename: handoutFilename,
  );
}
