import 'package:dartz/dartz.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_datasource.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_entity.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_repository.dart';
import '../../../../core/errors/failures.dart';

class ExamPredictionRepositoryImpl implements ExamPredictionRepository {
  final ExamPredictionRemoteDataSource _dataSource;
  ExamPredictionRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, GeneratedQuestion>> generateQuestion({
    required String subject,
    required String college,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) async {
    try {
      final dto = await _dataSource.generateQuestion(
        subject: subject,
        college: college,
        k: k,
        yearFrom: yearFrom,
        yearTo: yearTo,
      );
      return Right(dto.toDomain());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UploadResult>> uploadPyq({
    required String filePath,
    required String subject,
    required int paperYear,
    required String examType,
    required String college,
    String? subjectId,
    String? campusId,
    String? uploadedBy,
    String? docType,
  }) async {
    try {
      final dto = await _dataSource.uploadPyq(
        filePath: filePath,
        subject: subject,
        paperYear: paperYear,
        examType: examType,
        college: college,
        subjectId: subjectId,
        campusId: campusId,
        uploadedBy: uploadedBy,
        docType: docType,
      );
      return Right(dto.toDomain());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, QuestionBankStats>> getStats({
    required String college,
  }) async {
    try {
      final dto = await _dataSource.getStats(college: college);
      return Right(dto.toDomain());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, QuestionsResponse>> getQuestions({
    required String college,
    String? subject,
    int? paperYear,
    String? examType,
    String? questionType,
  }) async {
    try {
      final dto = await _dataSource.getQuestions(
        college: college,
        subject: subject,
        paperYear: paperYear,
        examType: examType,
        questionType: questionType,
      );
      return Right(dto.toDomain());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
