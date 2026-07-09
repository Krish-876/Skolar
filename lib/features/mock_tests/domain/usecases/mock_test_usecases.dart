import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import 'package:Skolar/features/mock_tests/domain/entities/mock_test_entity.dart';
import 'package:Skolar/features/mock_tests/domain/repositories/mock_test_repository.dart';

class FetchMcqQuestionsUseCase {
  final MockTestRepository _repository;
  FetchMcqQuestionsUseCase(this._repository);

  Future<Either<Failure, List<QuizQuestion>>> call({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) {
    return _repository.fetchMcqQuestions(
      subject: subject,
      college: college,
      examType: examType,
      count: count,
      k: k,
      yearFrom: yearFrom,
      yearTo: yearTo,
    );
  }
}

class FetchOpenQuestionsUseCase {
  final MockTestRepository _repository;
  FetchOpenQuestionsUseCase(this._repository);

  Future<Either<Failure, List<OpenQuestion>>> call({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) {
    return _repository.fetchOpenQuestions(
      subject: subject,
      college: college,
      examType: examType,
      count: count,
      k: k,
      yearFrom: yearFrom,
      yearTo: yearTo,
    );
  }
}

class FetchQuestionsByIdsUseCase {
  final MockTestRepository _repository;
  FetchQuestionsByIdsUseCase(this._repository);

  Future<Either<Failure, List<OpenQuestion>>> call({
    required List<String> questionIds,
  }) {
    return _repository.fetchQuestionsByIds(questionIds: questionIds);
  }
}
