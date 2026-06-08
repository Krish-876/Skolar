import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/shared/providers/global_providers.dart';
import '../../data/datasources/subjects_datasource.dart';
import '../../data/repository_impl/subjects_repository_impl.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/usecases/subjects_usecases.dart';

final _subjectsDataSourceProvider = Provider<SubjectsDataSource>(
  (_) => SubjectsRemoteDataSource(),
);

final _subjectsRepositoryProvider = Provider<SubjectsRepositoryImpl>(
  (ref) => SubjectsRepositoryImpl(ref.read(_subjectsDataSourceProvider)),
);

final getSubjectsUseCaseProvider = Provider<GetSubjectsUseCase>(
  (ref) => GetSubjectsUseCase(ref.read(_subjectsRepositoryProvider)),
);

final subjectsProvider =
    AsyncNotifierProvider<SubjectsNotifier, List<SubjectEntity>>(
  SubjectsNotifier.new,
);

class SubjectsNotifier extends AsyncNotifier<List<SubjectEntity>> {
  @override
  Future<List<SubjectEntity>> build() async {
    final user = ref.watch(userProvider);
    if (user.institutionId == null) return [];

    final result = await ref.read(getSubjectsUseCaseProvider).call(
      institutionId: user.institutionId!,
      academicYear:  user.academicYear,
    );
    return result.fold((_) => [], (subjects) => subjects);
  }
}