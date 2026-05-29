import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_datasource.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_entity.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_repository_impl.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_usecases.dart';

import 'package:Skolar/shared/providers/global_providers.dart' show userProvider;

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final examPredictionDataSourceProvider =
    Provider<ExamPredictionRemoteDataSource>(
  (_) => ExamPredictionRemoteDataSourceImpl(),
);

final examPredictionRepositoryProvider =
    Provider<ExamPredictionRepositoryImpl>(
  (ref) => ExamPredictionRepositoryImpl(
    ref.read(examPredictionDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final generateQuestionUseCaseProvider = Provider<GenerateQuestionUseCase>(
  (ref) =>
      GenerateQuestionUseCase(ref.read(examPredictionRepositoryProvider)),
);

final uploadPyqUseCaseProvider = Provider<UploadPyqUseCase>(
  (ref) => UploadPyqUseCase(ref.read(examPredictionRepositoryProvider)),
);

final getStatsUseCaseProvider = Provider<GetStatsUseCase>(
  (ref) => GetStatsUseCase(ref.read(examPredictionRepositoryProvider)),
);

final getQuestionsUseCaseProvider = Provider<GetQuestionsUseCase>(
  (ref) => GetQuestionsUseCase(ref.read(examPredictionRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Stats notifier  (college read internally — no call-site changes needed)
// ---------------------------------------------------------------------------

class StatsNotifier extends AsyncNotifier<QuestionBankStats?> {
  @override
  Future<QuestionBankStats?> build() async {
    final college = ref.read(userProvider).college;
    final result =
        await ref.read(getStatsUseCaseProvider).call(college: college);
    return result.fold((_) => null, (s) => s);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final college = ref.read(userProvider).college;
    final result =
        await ref.read(getStatsUseCaseProvider).call(college: college);
    state = result.fold(
      (f) => AsyncError(f, StackTrace.current),
      (s) => AsyncData(s),
    );
  }
}

final statsProvider =
    AsyncNotifierProvider<StatsNotifier, QuestionBankStats?>(
  StatsNotifier.new,
);

// ---------------------------------------------------------------------------
// Generate question notifier
// ---------------------------------------------------------------------------

class GenerateQuestionNotifier extends AsyncNotifier<GeneratedQuestion?> {
  @override
  Future<GeneratedQuestion?> build() async => null;

  Future<void> generate({
    required String subject,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) async {
    state = const AsyncLoading();
    final college = ref.read(userProvider).college;
    final result = await ref.read(generateQuestionUseCaseProvider).call(
          subject: subject,
          college: college,
          k: k,
          yearFrom: yearFrom,
          yearTo: yearTo,
        );
    state = result.fold(
      (f) => AsyncError(f, StackTrace.current),
      (q) => AsyncData(q),
    );
  }
}

final generateQuestionProvider =
    AsyncNotifierProvider<GenerateQuestionNotifier, GeneratedQuestion?>(
  GenerateQuestionNotifier.new,
);

// ---------------------------------------------------------------------------
// Upload PYQ notifier  (used by the existing single-file _UploadTab)
// ---------------------------------------------------------------------------

class UploadPyqNotifier extends AsyncNotifier<UploadResult?> {
  @override
  Future<UploadResult?> build() async => null;

  Future<void> upload({
    required String filePath,
    required String subject,
    required int year,
    required String examType,
  }) async {
    state = const AsyncLoading();
    final college = ref.read(userProvider).college;
    final result = await ref.read(uploadPyqUseCaseProvider).call(
          filePath: filePath,
          subject: subject,
          year: year,
          examType: examType,
          college: college,
        );
    state = result.fold(
      (f) => AsyncError(f, StackTrace.current),
      (r) => AsyncData(r),
    );
  }
}

final uploadPyqProvider =
    AsyncNotifierProvider<UploadPyqNotifier, UploadResult?>(
  UploadPyqNotifier.new,
);

// ---------------------------------------------------------------------------
// Questions bank notifier
// ---------------------------------------------------------------------------

class QuestionsNotifier extends AsyncNotifier<QuestionsResponse?> {
  @override
  Future<QuestionsResponse?> build() async {
    final college = ref.read(userProvider).college;
    final result = await ref
        .read(getQuestionsUseCaseProvider)
        .call(college: college);
    return result.fold((_) => null, (q) => q);
  }

  Future<void> filter({
    String? subject,
    int? year,
    String? examType,
    String? questionType,
  }) async {
    state = const AsyncLoading();
    final college = ref.read(userProvider).college;
    final result = await ref.read(getQuestionsUseCaseProvider).call(
          college: college,
          subject: subject,
          year: year,
          examType: examType,
          questionType: questionType,
        );
    state = result.fold(
      (f) => AsyncError(f, StackTrace.current),
      (q) => AsyncData(q),
    );
  }
}

final questionsProvider =
    AsyncNotifierProvider<QuestionsNotifier, QuestionsResponse?>(
  QuestionsNotifier.new,
);