class UserModel {
  final String id;
  final String name;
  final String email;
  final String college;       // campus short_name e.g. 'BPHC'
  final String rollNumber;
  final int academicYear;     // 1–4
  final String? branch;
  final String plan;          // 'free' | 'premium'
  final String? institutionId;
  final String? campusId;
  final int streakDays;
  final int coins;
  final int totalUploads;
  final List<bool?> weekProgress;
  final List<String> weekLabels;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.college,
    required this.rollNumber,
    required this.academicYear,
    this.branch,
    this.plan = 'free',
    this.institutionId,
    this.campusId,
    this.streakDays = 0,
    this.coins = 0,
    this.totalUploads = 0,
    this.weekProgress = const [null, null, null, null, null, null, null],
    this.weekLabels = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
  });

  /// Placeholder used before auth loads real data
  factory UserModel.placeholder() => const UserModel(
    id:           '',
    name:         'Student',
    email:        '',
    college:      'BPHC',
    rollNumber:   '',
    academicYear: 1,
  );

  UserModel copyWith({
    String? id, String? name, String? email, String? college,
    String? rollNumber, int? academicYear, String? branch, String? plan,
    String? institutionId, String? campusId, int? streakDays, int? coins,
    int? totalUploads, List<bool?>? weekProgress, List<String>? weekLabels,
  }) => UserModel(
    id:            id            ?? this.id,
    name:          name          ?? this.name,
    email:         email         ?? this.email,
    college:       college       ?? this.college,
    rollNumber:    rollNumber    ?? this.rollNumber,
    academicYear:  academicYear  ?? this.academicYear,
    branch:        branch        ?? this.branch,
    plan:          plan          ?? this.plan,
    institutionId: institutionId ?? this.institutionId,
    campusId:      campusId      ?? this.campusId,
    streakDays:    streakDays    ?? this.streakDays,
    coins:         coins         ?? this.coins,
    totalUploads:  totalUploads  ?? this.totalUploads,
    weekProgress:  weekProgress  ?? this.weekProgress,
    weekLabels:    weekLabels    ?? this.weekLabels,
  );
}