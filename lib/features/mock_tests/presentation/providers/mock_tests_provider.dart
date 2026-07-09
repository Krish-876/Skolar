import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/mock_tests/data/datasources/mock_test_datasource.dart';
import 'package:Skolar/features/mock_tests/data/repository_impl/mock_test_repository_impl.dart';
import 'package:Skolar/features/mock_tests/domain/entities/mock_test_entity.dart';
import 'package:Skolar/features/mock_tests/domain/usecases/mock_test_usecases.dart';
import 'package:Skolar/shared/models/exam_type.dart';
import 'package:Skolar/shared/providers/global_providers.dart';

// ── Exam mode ─────────────────────────────────────────────────────────────────

enum ExamMode { mcqBlitz, writtenPractice }

// ── Request model ─────────────────────────────────────────────────────────────

class MockTestRequest {
  final String subject;
  final ExamMode mode;
  final ExamType examType;
  final int count;
  final int? yearFrom;
  final int? yearTo;
  final int k;

  const MockTestRequest({
    required this.subject,
    required this.mode,
    required this.examType,
    this.count = 5,
    this.yearFrom,
    this.yearTo,
    this.k = 5,
  });
}

// ── State ─────────────────────────────────────────────────────────────────────

class MockTestState {
  final List<QuizQuestion> mcqQuestions;
  final List<OpenQuestion> openQuestions;
  final ExamMode mode;
  final bool isLoading;
  final String? error;

  const MockTestState({
    this.mcqQuestions = const [],
    this.openQuestions = const [],
    this.mode = ExamMode.mcqBlitz,
    this.isLoading = false,
    this.error,
  });

  bool get hasQuestions => mcqQuestions.isNotEmpty || openQuestions.isNotEmpty;

  MockTestState copyWith({
    List<QuizQuestion>? mcqQuestions,
    List<OpenQuestion>? openQuestions,
    ExamMode? mode,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => MockTestState(
    mcqQuestions: mcqQuestions ?? this.mcqQuestions,
    openQuestions: openQuestions ?? this.openQuestions,
    mode: mode ?? this.mode,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

// ── Infrastructure providers ──────────────────────────────────────────────────

final _mockTestDataSourceProvider = Provider<MockTestRemoteDataSource>(
  (_) => MockTestRemoteDataSourceImpl(),
);

final _mockTestRepositoryProvider = Provider<MockTestRepositoryImpl>(
  (ref) => MockTestRepositoryImpl(ref.read(_mockTestDataSourceProvider)),
);

final _fetchMcqUseCaseProvider = Provider<FetchMcqQuestionsUseCase>(
  (ref) => FetchMcqQuestionsUseCase(ref.read(_mockTestRepositoryProvider)),
);

final _fetchOpenUseCaseProvider = Provider<FetchOpenQuestionsUseCase>(
  (ref) => FetchOpenQuestionsUseCase(ref.read(_mockTestRepositoryProvider)),
);

// ── Notifier ──────────────────────────────────────────────────────────────────

class MockTestNotifier extends Notifier<MockTestState> {
  @override
  MockTestState build() => const MockTestState();

  Future<void> fetchQuestions(MockTestRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final college = ref.read(userProvider).college;

    if (request.mode == ExamMode.mcqBlitz) {
      final result = await ref
          .read(_fetchMcqUseCaseProvider)
          .call(
            subject: request.subject,
            college: college,
            examType: request.examType.apiValue,
            count: request.count,
            k: request.k,
            yearFrom: request.yearFrom,
            yearTo: request.yearTo,
          );
      result.fold(
        (failure) =>
            state = state.copyWith(isLoading: false, error: failure.message),
        (questions) => state = state.copyWith(
          mcqQuestions: questions,
          openQuestions: [],
          mode: ExamMode.mcqBlitz,
          isLoading: false,
        ),
      );
    } else {
      final result = await ref
          .read(_fetchOpenUseCaseProvider)
          .call(
            subject: request.subject,
            college: college,
            examType: request.examType.apiValue,
            count: request.count,
            k: request.k,
            yearFrom: request.yearFrom,
            yearTo: request.yearTo,
          );
      result.fold(
        (failure) =>
            state = state.copyWith(isLoading: false, error: failure.message),
        (questions) => state = state.copyWith(
          openQuestions: questions,
          mcqQuestions: [],
          mode: ExamMode.writtenPractice,
          isLoading: false,
        ),
      );
    }
  }

  Future<void> loadExistingTest({
    required List<String> questionIds,
    required ExamMode mode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await ref
        .read(_fetchByIdsUseCaseProvider)
        .call(questionIds: questionIds);

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (questions) => state = state.copyWith(
        openQuestions: questions,
        mcqQuestions: [],
        mode: mode,
        isLoading: false,
      ),
    );
  }

  void reset() => state = const MockTestState();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final mockTestProvider = NotifierProvider<MockTestNotifier, MockTestState>(
  MockTestNotifier.new,
);

final _fetchByIdsUseCaseProvider = Provider<FetchQuestionsByIdsUseCase>(
  (ref) => FetchQuestionsByIdsUseCase(ref.read(_mockTestRepositoryProvider)),
);
