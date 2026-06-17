import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Skolar/features/mock_tests/data/dtos/mock_test_dto.dart';

abstract class MockTestRemoteDataSource {
  Future<List<QuizQuestionDto>> fetchMcqQuestions({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  });

  Future<List<OpenQuestionDto>> fetchOpenQuestions({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  });

  Future<List<OpenQuestionDto>> fetchQuestionsByIds({
    required List<String> questionIds,
  });
}

class MockTestRemoteDataSourceImpl implements MockTestRemoteDataSource {
  final Dio _dio;
  final _supabase = Supabase.instance.client;

  static const String _baseUrl = 'http://192.168.0.122:8000';

  MockTestRemoteDataSourceImpl({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 3),
            ));

  @override
  Future<List<QuizQuestionDto>> fetchMcqQuestions({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/generate-batch',
        data: {
          'subject':   subject,
          'college':   college,
          'exam_type': examType,
          'count':     count,
          'k':         k,
          if (yearFrom != null) 'year_from': yearFrom,
          if (yearTo   != null) 'year_to':   yearTo,
        },
      );
      final rawList = response.data!['questions'] as List<dynamic>;
      return rawList
          .map((e) => QuizQuestionDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch MCQ questions: ${e.message}');
    }
  }

  @override
  Future<List<OpenQuestionDto>> fetchOpenQuestions({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/generate-open-batch',
        data: {
          'subject':      subject,
          'college':      college,
          'exam_type':    examType,
          'count':        count,
          'k':            k,
          'with_answers': true,
          if (yearFrom != null) 'year_from': yearFrom,
          if (yearTo   != null) 'year_to':   yearTo,
        },
      );
      final rawList = response.data!['questions'] as List<dynamic>;
      return rawList
          .map((e) => OpenQuestionDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch open questions: ${e.message}');
    }
  }

  @override
  Future<List<OpenQuestionDto>> fetchQuestionsByIds({
    required List<String> questionIds,
  }) async {
    try {
      final response = await _supabase
          .from('questions')
          .select('id, question_text, marks, question_type, subject, exam_type')
          .inFilter('id', questionIds);

      return (response as List<dynamic>)
          .map((row) => OpenQuestionDto(
                question:    row['question_text'] as String,
                subject:     row['subject']       as String,
                marks:       row['marks']         as int,
                modelAnswer: '',  // not stored — shown as "No model answer available"
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch questions by ids: $e');
    }
  }
}