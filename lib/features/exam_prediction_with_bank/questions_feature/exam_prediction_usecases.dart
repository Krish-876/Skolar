import 'package:dartz/dartz.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_entity.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_repository.dart';
import '../../../../core/errors/failures.dart';

class GenerateQuestionUseCase {
  final ExamPredictionRepository _repository;
  GenerateQuestionUseCase(this._repository);

  Future<Either<Failure, GeneratedQuestion>> call({
    required String subject,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) {
    return _repository.generateQuestion(
      subject: subject,
      k: k,
      yearFrom: yearFrom,
      yearTo: yearTo,
    );
  }
}

class UploadPyqUseCase {
  final ExamPredictionRepository _repository;
  UploadPyqUseCase(this._repository);

  Future<Either<Failure, UploadResult>> call({
    required String filePath,
    required String subject,
    required int year,
    required String examType,
  }) {
    return _repository.uploadPyq(
      filePath: filePath,
      subject: subject,
      year: year,
      examType: examType,
    );
  }
}

class GetStatsUseCase {
  final ExamPredictionRepository _repository;
  GetStatsUseCase(this._repository);

  Future<Either<Failure, QuestionBankStats>> call() {
    return _repository.getStats();
  }
}

class GetQuestionsUseCase {
  final ExamPredictionRepository _repository;
  GetQuestionsUseCase(this._repository);

  Future<Either<Failure, QuestionsResponse>> call({
    String? subject,
    int? year,
    String? examType,
    String? questionType,
  }) {
    return _repository.getQuestions(
      subject: subject,
      year: year,
      examType: examType,
      questionType: questionType,
    );
  }
}
