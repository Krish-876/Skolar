class SubjectEntity {
  final String userSubjectId; // PK in user_subjects
  final String? subjectId; // null for custom subjects
  final String name;
  final String? shortName;
  final int? academicYear;
  final int? semester;
  final int? credits;
  final String? institutionId;
  final bool isCustom;
  final String? handoutUrl;
  final String? handoutFilename;

  const SubjectEntity({
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

  SubjectEntity copyWith({String? handoutUrl, String? handoutFilename}) =>
      SubjectEntity(
        userSubjectId: userSubjectId,
        subjectId: subjectId,
        name: name,
        shortName: shortName,
        academicYear: academicYear,
        semester: semester,
        credits: credits,
        institutionId: institutionId,
        isCustom: isCustom,
        handoutUrl: handoutUrl ?? this.handoutUrl,
        handoutFilename: handoutFilename ?? this.handoutFilename,
      );
}
