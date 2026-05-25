import 'package:dartz/dartz.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_entity.dart';
import '../../../../core/errors/failures.dart';

abstract class ExamPredictionRepository {
  Future<Either<Failure, GeneratedQuestion>> generateQuestion({
    required String subject,
    required int k,
    int? yearFrom,
    int? yearTo,
  });

  Future<Either<Failure, UploadResult>> uploadPyq({
    required String filePath,
    required String subject,
    required int year,
    required String examType,
  });

  Future<Either<Failure, QuestionBankStats>> getStats();

  Future<Either<Failure, QuestionsResponse>> getQuestions({
    String? subject,
    int? year,
    String? examType,
    String? questionType,
  });
}
