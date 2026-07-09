import 'package:dartz/dartz.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_entity.dart';
import '../../../../core/errors/failures.dart';

abstract class ExamPredictionRepository {
  Future<Either<Failure, GeneratedQuestion>> generateQuestion({
    required String subject,
    required String college,
    required int k,
    int? yearFrom,
    int? yearTo,
  });

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
  });

  Future<Either<Failure, QuestionBankStats>> getStats({
    required String college,
  });

  Future<Either<Failure, QuestionsResponse>> getQuestions({
    required String college,
    String? subject,
    int? paperYear,
    String? examType,
    String? questionType,
  });
}
