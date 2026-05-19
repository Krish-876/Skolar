class UserModel {
  final String name;
  final String college;
  final String rollNumber;
  final int streakDays;
  final int targetDays;
  final String totalWatch;
  final int totalUploads;
  final int friendCount;
  final List<bool?> weekProgress;
  final List<String> weekLabels;

  UserModel({
    required this.name,
    required this.college,
    required this.rollNumber,
    required this.streakDays,
    required this.targetDays,
    required this.totalWatch,
    required this.totalUploads,
    required this.friendCount,
    required this.weekProgress,
    required this.weekLabels,
  });
}