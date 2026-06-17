import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/shared/providers/global_providers.dart';
import '../../data/datasources/subjects_datasource.dart';
import '../../data/repository_impl/subjects_repository_impl.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/subjects_repository.dart';
import '../../domain/usecases/subjects_usecases.dart';
import '../../domain/utils/semester_utils.dart';

// ── Wiring ────────────────────────────────────────────────────────────────

final _subjectsDataSourceProvider = Provider<SubjectsDataSource>(
  (_) => SubjectsRemoteDataSource(),
);

final _subjectsRepositoryProvider = Provider<SubjectsRepository>(
  (ref) => SubjectsRepositoryImpl(ref.read(_subjectsDataSourceProvider)),
);

final getSubjectsForUserUseCaseProvider = Provider<GetSubjectsForUserUseCase>(
  (ref) => GetSubjectsForUserUseCase(ref.read(_subjectsRepositoryProvider)),
);

final addCustomSubjectUseCaseProvider = Provider<AddCustomSubjectUseCase>(
  (ref) => AddCustomSubjectUseCase(ref.read(_subjectsRepositoryProvider)),
);

final deleteUserSubjectUseCaseProvider = Provider<DeleteUserSubjectUseCase>(
  (ref) => DeleteUserSubjectUseCase(ref.read(_subjectsRepositoryProvider)),
);

final uploadHandoutUseCaseProvider = Provider<UploadHandoutUseCase>(
  (ref) => UploadHandoutUseCase(ref.read(_subjectsRepositoryProvider)),
);

final getCreditTargetUseCaseProvider = Provider<GetCreditTargetUseCase>(
  (ref) => GetCreditTargetUseCase(ref.read(_subjectsRepositoryProvider)),
);

final setCreditTargetUseCaseProvider = Provider<SetCreditTargetUseCase>(
  (ref) => SetCreditTargetUseCase(ref.read(_subjectsRepositoryProvider)),
);

// ── Page state ────────────────────────────────────────────────────────────

class StagedHandout {
  final String filename;
  final List<int> bytes;
  const StagedHandout({required this.filename, required this.bytes});
}

class SubjectsPageState {
  final List<SubjectEntity> subjects;
  final bool editMode;
  final Set<String> pendingDelete;
  final int? creditTarget;
  /// True once getCreditTarget has returned successfully (value may
  /// still be null if the user has never set it). The credit sheet
  /// must only show when this is true AND creditTarget is null —
  /// a failed fetch must not trigger the sheet on every restart.
  final bool creditTargetLoaded;
  final Map<String, bool> uploadingHandout;
  final Map<String, StagedHandout> stagedHandouts;

  const SubjectsPageState({
    this.subjects            = const [],
    this.editMode            = false,
    this.pendingDelete       = const {},
    this.creditTarget,
    this.creditTargetLoaded  = false,
    this.uploadingHandout    = const {},
    this.stagedHandouts      = const {},
  });

  int get totalCredits =>
      subjects.fold(0, (sum, s) => sum + (s.credits ?? 0));

  int? get remainingCredits =>
      creditTarget == null ? null : (creditTarget! - totalCredits);

  SubjectsPageState copyWith({
    List<SubjectEntity>? subjects,
    bool? editMode,
    Set<String>? pendingDelete,
    int? creditTarget,
    bool? creditTargetLoaded,
    Map<String, bool>? uploadingHandout,
    Map<String, StagedHandout>? stagedHandouts,
  }) =>
      SubjectsPageState(
        subjects:           subjects           ?? this.subjects,
        editMode:           editMode           ?? this.editMode,
        pendingDelete:      pendingDelete      ?? this.pendingDelete,
        creditTarget:       creditTarget       ?? this.creditTarget,
        creditTargetLoaded: creditTargetLoaded ?? this.creditTargetLoaded,
        uploadingHandout:   uploadingHandout   ?? this.uploadingHandout,
        stagedHandouts:     stagedHandouts     ?? this.stagedHandouts,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

final subjectsProvider =
    AsyncNotifierProvider.autoDispose<SubjectsNotifier, SubjectsPageState>(
  SubjectsNotifier.new,
);

class SubjectsNotifier extends AutoDisposeAsyncNotifier<SubjectsPageState> {
  late String _userId;
  late String _institutionId;
  late String _campusId;
  late int _academicYear;
  late int _semester;
  late String _semesterLabel;

  @override
  Future<SubjectsPageState> build() async {
    final user = ref.watch(userProvider);

    _userId        = user.id;
    _institutionId = user.institutionId ?? '';
    _campusId      = user.campusId ?? '';
    _academicYear  = user.academicYear;
    _semester      = SemesterUtils.currentSemesterNumber();
    _semesterLabel = SemesterUtils.currentSemesterLabel();

    int? creditTarget;
    bool creditTargetLoaded = false;

    final creditResult =
        await ref.read(getCreditTargetUseCaseProvider).call(userId: _userId);
    creditResult.fold(
      (failure) {
        // Non-fatal — leave creditTargetLoaded = false so the sheet
        // does not fire on a network/RLS error.
        debugPrint(
            '[SubjectsNotifier] getCreditTarget failed: ${failure.message}');
      },
      (value) {
        creditTarget       = value;
        creditTargetLoaded = true;
      },
    );

    if (_campusId.isEmpty) {
      return SubjectsPageState(
        creditTarget:       creditTarget,
        creditTargetLoaded: creditTargetLoaded,
      );
    }

    final result = await ref.read(getSubjectsForUserUseCaseProvider).call(
          userId:        _userId,
          institutionId: _institutionId,
          campusId:      _campusId,
          academicYear:  _academicYear,
          semester:      _semester,
        );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (subjects) => SubjectsPageState(
        subjects:           subjects,
        creditTarget:       creditTarget,
        creditTargetLoaded: creditTargetLoaded,
      ),
    );
  }

  // ── Credit target ─────────────────────────────────────────────────────

  Future<void> setCreditTarget(int value) async {
    final current = state.valueOrNull ?? const SubjectsPageState();
    state = AsyncData(current.copyWith(
      creditTarget:       value,
      creditTargetLoaded: true,
    ));
    await ref
        .read(setCreditTargetUseCaseProvider)
        .call(userId: _userId, value: value);
  }

  // ── Edit mode ─────────────────────────────────────────────────────────

  void enterEditMode() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(editMode: true, pendingDelete: {}));
  }

  void exitEditMode() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(editMode: false, pendingDelete: {}));
  }

  void togglePendingDelete(String userSubjectId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = Set<String>.from(current.pendingDelete);
    next.contains(userSubjectId)
        ? next.remove(userSubjectId)
        : next.add(userSubjectId);
    state = AsyncData(current.copyWith(pendingDelete: next));
  }

  Future<void> commitDeletions() async {
    final current = state.valueOrNull;
    if (current == null || current.pendingDelete.isEmpty) {
      exitEditMode();
      return;
    }
    state = const AsyncLoading();
    try {
      for (final id in current.pendingDelete) {
        await ref
            .read(deleteUserSubjectUseCaseProvider)
            .call(userSubjectId: id);
      }
      final remaining = current.subjects
          .where((s) => !current.pendingDelete.contains(s.userSubjectId))
          .toList();
      state = AsyncData(SubjectsPageState(
        subjects:           remaining,
        creditTarget:       current.creditTarget,
        creditTargetLoaded: current.creditTargetLoaded,
        stagedHandouts:     current.stagedHandouts,
      ));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // ── Add custom subject ────────────────────────────────────────────────

  Future<String?> addCustomSubject({
    required String name,
    required String courseCode,
    required int credits,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return 'State not ready';

    final target = current.creditTarget;
    if (target != null && current.totalCredits + credits > target) {
      return 'That would put you over your $target credit limit';
    }

    state = const AsyncLoading();
    final result = await ref.read(addCustomSubjectUseCaseProvider).call(
          userId:        _userId,
          institutionId: _institutionId,
          semester:      _semesterLabel,
          name:          name,
          courseCode:    courseCode,
          credits:       credits,
        );

    return result.fold(
      (failure) {
        state = AsyncData(current);
        return failure.message;
      },
      (newSubject) {
        final updated = List<SubjectEntity>.from(current.subjects)
          ..add(newSubject);
        state = AsyncData(SubjectsPageState(
          subjects:           updated,
          creditTarget:       current.creditTarget,
          creditTargetLoaded: current.creditTargetLoaded,
          stagedHandouts:     current.stagedHandouts,
        ));
        return null;
      },
    );
  }

  // ── Staged handouts ───────────────────────────────────────────────────

  void stageHandout({
    required String userSubjectId,
    required List<int> fileBytes,
    required String filename,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = Map<String, StagedHandout>.from(current.stagedHandouts);
    next[userSubjectId] = StagedHandout(filename: filename, bytes: fileBytes);
    state = AsyncData(current.copyWith(stagedHandouts: next));
  }

  void unstageHandout(String userSubjectId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = Map<String, StagedHandout>.from(current.stagedHandouts)
      ..remove(userSubjectId);
    state = AsyncData(current.copyWith(stagedHandouts: next));
  }

  Future<String?> submitStagedHandouts() async {
    final current = state.valueOrNull;
    if (current == null || current.stagedHandouts.isEmpty) return null;

    final entries = Map<String, StagedHandout>.from(current.stagedHandouts);
    state = AsyncData(current.copyWith(
      uploadingHandout: {
        for (final id in entries.keys) id: true,
      },
    ));

    String? firstError;
    var latest = current;

    for (final entry in entries.entries) {
      final userSubjectId = entry.key;
      final staged        = entry.value;
      final subject = latest.subjects
          .firstWhere((s) => s.userSubjectId == userSubjectId);

      final result = await ref.read(uploadHandoutUseCaseProvider).call(
            userSubjectId: userSubjectId,
            userId:        _userId,
            subjectName:   subject.name,
            fileBytes:     staged.bytes,
            filename:      staged.filename,
          );

      result.fold(
        (failure) => firstError ??= failure.message,
        (updatedSubject) {
          final updatedList = latest.subjects
              .map((s) =>
                  s.userSubjectId == userSubjectId ? updatedSubject : s)
              .toList();
          latest = latest.copyWith(subjects: updatedList);
        },
      );

      final nextUploading =
          Map<String, bool>.from(latest.uploadingHandout)
            ..remove(userSubjectId);
      final nextStaged =
          Map<String, StagedHandout>.from(latest.stagedHandouts)
            ..remove(userSubjectId);
      latest = latest.copyWith(
        uploadingHandout: nextUploading,
        stagedHandouts:   nextStaged,
      );
      state = AsyncData(latest);
    }

    return firstError;
  }
}