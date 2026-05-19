import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/feed_post_entity.dart';

abstract class FeedRepository {
  Future<Either<Failure, List<FeedPostEntity>>> getPosts();
}