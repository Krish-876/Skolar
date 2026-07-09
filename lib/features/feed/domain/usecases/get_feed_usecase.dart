import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/feed_post_entity.dart';
import '../repositories/feed_repository.dart';

class GetFeedUseCase {
  final FeedRepository repository;

  const GetFeedUseCase(this.repository);

  Future<Either<Failure, List<FeedPostEntity>>> call() {
    return repository.getPosts();
  }
}
