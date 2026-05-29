import 'dart:io';
import 'package:dio/dio.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_dto.dart';

abstract class ExamPredictionRemoteDataSource {
  Future<GeneratedQuestionDto> generateQuestion({
    required String subject,
    required String college,
    required int k,
    int? yearFrom,
    int? yearTo,
  });

  Future<UploadResultDto> uploadPyq({
    required String filePath,
    required String subject,
    required int year,
    required String examType,
    required String college,
  });

  Future<QuestionBankStatsDto> getStats({
    required String college,
  });

  Future<QuestionsResponseDto> getQuestions({
    required String college,
    String? subject,
    int? year,
    String? examType,
    String? questionType,
  });
}

class ExamPredictionRemoteDataSourceImpl
    implements ExamPredictionRemoteDataSource {
  final Dio _dio;

  // Use 10.0.2.2 for Android emulator.
  // Change to your machine's LAN IP for physical device testing.
  static const String _baseUrl = 'http://10.63.32.220:8000';

  ExamPredictionRemoteDataSourceImpl({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5),
              sendTimeout: const Duration(minutes: 2),
            ));

  @override
  Future<GeneratedQuestionDto> generateQuestion({
    required String subject,
    required String college,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) async {
    try {
      final body = <String, dynamic>{
        'subject': subject,
        'college': college,
        'k': k,
        if (yearFrom != null) 'year_from': yearFrom,
        if (yearTo != null) 'year_to': yearTo,
      };
      final response =
          await _dio.post<Map<String, dynamic>>('/generate', data: body);
      return GeneratedQuestionDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw Exception('Failed to generate question: ${e.message}');
    }
  }

  @override
  Future<UploadResultDto> uploadPyq({
    required String filePath,
    required String subject,
    required int year,
    required String examType,
    required String college,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: File(filePath).uri.pathSegments.last,
        ),
        'subject': subject,
        'year': year,
        'exam_type': examType,
        'college': college,
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/upload-pyq',
        data: formData,
      );
      return UploadResultDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw Exception('Failed to upload PYQ: ${e.message}');
    }
  }

  @override
  Future<QuestionBankStatsDto> getStats({
    required String college,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/stats',
        queryParameters: {'college': college},
      );
      return QuestionBankStatsDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw Exception('Failed to fetch stats: ${e.message}');
    }
  }

  @override
  Future<QuestionsResponseDto> getQuestions({
    required String college,
    String? subject,
    int? year,
    String? examType,
    String? questionType,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'college': college,
        if (subject != null) 'subject': subject,
        if (year != null) 'year': year,
        if (examType != null) 'exam_type': examType,
        if (questionType != null) 'question_type': questionType,
      };
      final response = await _dio.get<Map<String, dynamic>>(
        '/questions',
        queryParameters: queryParams,
      );
      return QuestionsResponseDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw Exception('Failed to fetch questions: ${e.message}');
    }
  }
}