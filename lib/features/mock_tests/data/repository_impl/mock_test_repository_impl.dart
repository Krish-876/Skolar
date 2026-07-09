import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import 'package:Skolar/features/mock_tests/data/datasources/mock_test_datasource.dart';
import 'package:Skolar/features/mock_tests/domain/entities/mock_test_entity.dart';
import 'package:Skolar/features/mock_tests/domain/repositories/mock_test_repository.dart';

class MockTestRepositoryImpl implements MockTestRepository {
  final MockTestRemoteDataSource _dataSource;
  MockTestRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<QuizQuestion>>> fetchMcqQuestions({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) async {
    try {
      final dtos = await _dataSource.fetchMcqQuestions(
        subject: subject,
        college: college,
        examType: examType,
        count: count,
        k: k,
        yearFrom: yearFrom,
        yearTo: yearTo,
      );
      return Right(
        dtos
            .map(
              (d) => QuizQuestion(
                question: d.question,
                options: d.options,
                correctIndex: d.correctIndex,
                subject: d.subject,
                marks: d.marks,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<OpenQuestion>>> fetchOpenQuestions({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  }) async {
    try {
      final dtos = await _dataSource.fetchOpenQuestions(
        subject: subject,
        college: college,
        examType: examType,
        count: count,
        k: k,
        yearFrom: yearFrom,
        yearTo: yearTo,
      );
      return Right(
        dtos
            .map(
              (d) => OpenQuestion(
                question: d.question,
                subject: d.subject,
                marks: d.marks,
                modelAnswer: d.modelAnswer,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<OpenQuestion>>> fetchQuestionsByIds({
    required List<String> questionIds,
  }) async {
    try {
      final dtos = await _dataSource.fetchQuestionsByIds(
        questionIds: questionIds,
      );
      return Right(
        dtos
            .map(
              (d) => OpenQuestion(
                question: d.question,
                subject: d.subject,
                marks: d.marks,
                modelAnswer: d.modelAnswer,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
