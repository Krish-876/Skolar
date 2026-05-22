import 'package:dartz/dartz.dart';
import 'package:nova/features/exam_prediction_with_bank/questions_feature/exam_prediction_datasource.dart';
import 'package:nova/features/exam_prediction_with_bank/questions_feature/exam_prediction_entity.dart';
import 'package:nova/features/exam_prediction_with_bank/questions_feature/exam_prediction_repository.dart';
import '../../../../core/errors/failures.dart';

class ExamPredictionRepositoryImpl implements ExamPredictionRepository {
  final ExamPredictionRemoteDataSource _dataSource;
  ExamPredictionRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, GeneratedQuestion>> generateQuestion({
    required String subject,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) async {
    try {
      final dto = await _dataSource.generateQuestion(
        subject: subject,
        k: k,
        yearFrom: yearFrom,
        yearTo: yearTo,
      );
      return Right(dto.toDomain());
    } catch (e) {
      print('REPO ERROR generateQuestion: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UploadResult>> uploadPyq({
    required String filePath,
    required String subject,
    required int year,
    required String examType,
  }) async {
    try {
      final dto = await _dataSource.uploadPyq(
        filePath: filePath,
        subject: subject,
        year: year,
        examType: examType,
      );
      return Right(dto.toDomain());
    } catch (e) {
      print('REPO ERROR uploadPyq: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, QuestionBankStats>> getStats() async {
    try {
      final dto = await _dataSource.getStats();
      return Right(dto.toDomain());
    } catch (e) {
      print('REPO ERROR getStats: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, QuestionsResponse>> getQuestions({
    String? subject,
    int? year,
    String? examType,
    String? questionType,
  }) async {
    try {
      final dto = await _dataSource.getQuestions(
        subject: subject,
        year: year,
        examType: examType,
        questionType: questionType,
      );
      return Right(dto.toDomain());
    } catch (e) {
      print('REPO ERROR getQuestions: $e');
      return Left(ServerFailure(e.toString()));
    }
  }
}
