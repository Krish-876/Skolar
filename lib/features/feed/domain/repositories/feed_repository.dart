import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/feed_post_entity.dart';

abstract class FeedRepository {
  Future<Either<Failure, List<FeedPostEntity>>> getPosts();
  Future<Either<Failure, void>> castVote({
    required String postId,
    required String userId,
    required int vote,
  });
  Future<Either<Failure, Map<String, int>>> fetchUserVotes({
    required String userId,
  });
}