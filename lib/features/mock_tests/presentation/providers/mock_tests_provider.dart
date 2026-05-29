import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/features/mock_tests/presentation/pages/mock_tests_pages.dart';

// ── Config ────────────────────────────────────────────────────────────────────

const _kBaseUrl = 'http://172.16.18.138:8000';

// ── Exam mode ─────────────────────────────────────────────────────────────────

enum ExamMode {
  /// Timed MCQ blitz — used for Compre Part A practice
  mcqBlitz,

  /// Open-ended written practice — used for Quiz, Midsem, Compre Part B
  writtenPractice,
}

enum ExamType { quiz, midsem, comprePaA, comprePartB }

// ── Request model ─────────────────────────────────────────────────────────────

class MockTestRequest {
  final String subject;
  final String college;
  final ExamMode mode;
  final int count;
  final int? yearFrom;
  final int? yearTo;
  final int k;

  const MockTestRequest({
    required this.subject,
    required this.college,
    required this.mode,
    this.count = 5,
    this.yearFrom,
    this.yearTo,
    this.k = 5,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'college': college,
        'count': count,
        if (yearFrom != null) 'year_from': yearFrom,
        if (yearTo != null) 'year_to': yearTo,
        'k': k,
        // with_answers always true for written practice
        if (mode == ExamMode.writtenPractice) 'with_answers': true,
      };

  String get endpoint => mode == ExamMode.mcqBlitz
      ? '/generate-batch'
      : '/generate-open-batch';
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

  bool get hasQuestions =>
      mcqQuestions.isNotEmpty || openQuestions.isNotEmpty;

  MockTestState copyWith({
    List<QuizQuestion>? mcqQuestions,
    List<OpenQuestion>? openQuestions,
    ExamMode? mode,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      MockTestState(
        mcqQuestions: mcqQuestions ?? this.mcqQuestions,
        openQuestions: openQuestions ?? this.openQuestions,
        mode: mode ?? this.mode,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MockTestNotifier extends Notifier<MockTestState> {
  late final Dio _dio;

  @override
  MockTestState build() {
    _dio = Dio(BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      // Written practice makes 2 Groq calls per question — needs longer timeout
      receiveTimeout: const Duration(minutes: 3),
    ));
    return const MockTestState();
  }

  Future<void> fetchQuestions(MockTestRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        request.endpoint,
        data: request.toJson(),
      );

      final data = response.data!;
      final rawList = data['questions'] as List<dynamic>;

      if (request.mode == ExamMode.mcqBlitz) {
        final questions = rawList.map((item) {
          final map = item as Map<String, dynamic>;
          return QuizQuestion(
            question:     map['question']      as String,
            options:      List<String>.from(map['options'] as List),
            correctIndex: map['correct_index'] as int,
            subject:      map['subject']       as String,
            marks:        map['marks']         as int,
          );
        }).toList();

        state = state.copyWith(
          mcqQuestions: questions,
          openQuestions: [],
          mode: ExamMode.mcqBlitz,
          isLoading: false,
        );
      } else {
        final questions = rawList.map((item) {
          final map = item as Map<String, dynamic>;
          return OpenQuestion(
            question:    map['question']     as String,
            subject:     map['subject']      as String,
            marks:       map['marks']        as int,
            modelAnswer: map['model_answer'] as String,
          );
        }).toList();

        state = state.copyWith(
          openQuestions: questions,
          mcqQuestions: [],
          mode: ExamMode.writtenPractice,
          isLoading: false,
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ??
          e.message ??
          'Network error';
      state = state.copyWith(isLoading: false, error: msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const MockTestState();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final mockTestProvider = NotifierProvider<MockTestNotifier, MockTestState>(
  MockTestNotifier.new,
);