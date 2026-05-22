import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/mock_tests/presentation/pages/mock_tests_pages.dart';


// ── Config ────────────────────────────────────────────────────────────────────
// Same base URL used by the exam_prediction datasource.
// Change to your LAN IP when testing on a physical device.
const _kBaseUrl = 'http://192.168.29.196:8000';

// ── Request model ─────────────────────────────────────────────────────────────

class MockTestRequest {
  final String subject;
  final int count;
  final int? yearFrom;
  final int? yearTo;
  final int k;

  const MockTestRequest({
    required this.subject,
    this.count = 5,
    this.yearFrom,
    this.yearTo,
    this.k = 5,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'count': count,
        if (yearFrom != null) 'year_from': yearFrom,
        if (yearTo != null) 'year_to': yearTo,
        'k': k,
      };
}

// ── State ─────────────────────────────────────────────────────────────────────

class MockTestState {
  final List<QuizQuestion> questions;
  final bool isLoading;
  final String? error;

  const MockTestState({
    this.questions = const [],
    this.isLoading = false,
    this.error,
  });

  bool get hasQuestions => questions.isNotEmpty;

  MockTestState copyWith({
    List<QuizQuestion>? questions,
    bool? isLoading,
    String? error,
  }) =>
      MockTestState(
        questions: questions ?? this.questions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
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
      // Batch generation can take 20–40 s for 5 questions in parallel.
      // Groq is fast but we're making N concurrent calls.
      receiveTimeout: const Duration(minutes: 2),
    ));
    return const MockTestState();
  }

  Future<void> fetchQuestions(MockTestRequest request) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/generate-batch',
        data: request.toJson(),
      );

      final data = response.data!;
      final rawList = data['questions'] as List<dynamic>;

      final questions = rawList.map((item) {
        final map = item as Map<String, dynamic>;
        return QuizQuestion(
          question: map['question'] as String,
          options: List<String>.from(map['options'] as List),
          correctIndex: map['correct_index'] as int,
          subject: map['subject'] as String,
          marks: map['marks'] as int,
        );
      }).toList();

      state = state.copyWith(
        questions: questions,
        isLoading: false,
      );
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