class SubjectEntity {
  final String id;
  final String name;
  final String? shortName;
  final int academicYear;
  final String institutionId;

  const SubjectEntity({
    required this.id,
    required this.name,
    this.shortName,
    required this.academicYear,
    required this.institutionId,
  });
}