import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/feed_post_entity.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/feed_remote_datasource.dart';

class FeedRepositoryImpl implements FeedRepository {
  final FeedRemoteDataSource dataSource;
  final String college;

  const FeedRepositoryImpl(this.dataSource, {required this.college});

  @override
  Future<Either<Failure, List<FeedPostEntity>>> getPosts() async {
    try {
      final dtos = await dataSource.getPosts(college: college);
      return Right(dtos.map((dto) => dto.toDomain()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> castVote({
    required String postId,
    required String userId,
    required int vote,
  }) async {
    try {
      await dataSource.castVote(postId: postId, userId: userId, vote: vote);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> fetchUserVotes({
    required String userId,
  }) async {
    try {
      final votes = await dataSource.fetchUserVotes(userId: userId);
      return Right(votes);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}