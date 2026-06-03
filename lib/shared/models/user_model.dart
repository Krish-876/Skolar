class UserModel {
  final String name;
  final String email;
  final String college;       // campus short_name e.g. 'BPHC' — used by pipeline
  final String rollNumber;
  final int academicYear;     // 1–4, drives subject picker UI
  final int streakDays;
  final int targetDays;
  final String totalWatch;
  final int totalUploads;
  final int friendCount;
  final List<bool?> weekProgress;
  final List<String> weekLabels;

  UserModel({
    required this.name,
    required this.email,
    required this.college,
    required this.rollNumber,
    required this.academicYear,
    required this.streakDays,
    required this.targetDays,
    required this.totalWatch,
    required this.totalUploads,
    required this.friendCount,
    required this.weekProgress,
    required this.weekLabels,
  });
}