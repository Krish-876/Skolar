import 'package:dartz/dartz.dart';
import 'package:Skolar/core/errors/failures.dart';
import 'package:Skolar/features/mock_tests/domain/entities/mock_test_entity.dart';

abstract class MockTestRepository {
  Future<Either<Failure, List<QuizQuestion>>> fetchMcqQuestions({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  });

  Future<Either<Failure, List<OpenQuestion>>> fetchOpenQuestions({
    required String subject,
    required String college,
    required String examType,
    required int count,
    required int k,
    int? yearFrom,
    int? yearTo,
  });

  Future<Either<Failure, List<OpenQuestion>>> fetchQuestionsByIds({
    required List<String> questionIds,
  });
}