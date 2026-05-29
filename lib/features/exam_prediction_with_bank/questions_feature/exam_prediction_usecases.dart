import 'package:dartz/dartz.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_entity.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_repository.dart';
import '../../../../core/errors/failures.dart';

class GenerateQuestionUseCase {
  final ExamPredictionRepository _repository;
  GenerateQuestionUseCase(this._repository);

  Future<Either<Failure, GeneratedQuestion>> call({
    required String subject,
    required String college,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) {
    return _repository.generateQuestion(
      subject: subject,
      college: college,
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
    required String college,
  }) {
    return _repository.uploadPyq(
      filePath: filePath,
      subject: subject,
      year: year,
      examType: examType,
      college: college,
    );
  }
}

class GetStatsUseCase {
  final ExamPredictionRepository _repository;
  GetStatsUseCase(this._repository);

  Future<Either<Failure, QuestionBankStats>> call({
    required String college,
  }) {
    return _repository.getStats(college: college);
  }
}

class GetQuestionsUseCase {
  final ExamPredictionRepository _repository;
  GetQuestionsUseCase(this._repository);

  Future<Either<Failure, QuestionsResponse>> call({
    required String college,
    String? subject,
    int? year,
    String? examType,
    String? questionType,
  }) {
    return _repository.getQuestions(
      college: college,
      subject: subject,
      year: year,
      examType: examType,
      questionType: questionType,
    );
  }
}