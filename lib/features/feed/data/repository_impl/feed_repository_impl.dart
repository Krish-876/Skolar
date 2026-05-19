import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/feed_post_entity.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/feed_local_datasource.dart';

class FeedRepositoryImpl implements FeedRepository {
  final FeedLocalDataSource dataSource;

  const FeedRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<FeedPostEntity>>> getPosts() async {
    try {
      final dtos = await dataSource.getPosts();
      final entities = dtos.map((dto) => dto.toDomain()).toList();
      return Right(entities);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}