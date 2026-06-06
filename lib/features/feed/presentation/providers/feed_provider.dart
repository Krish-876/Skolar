import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/shared/providers/global_providers.dart';
import '../../data/datasources/feed_remote_datasource.dart';
import '../../data/repository_impl/feed_repository_impl.dart';
import '../../domain/entities/feed_post_entity.dart';
import '../../domain/usecases/get_feed_usecase.dart';
import 'feed_sort_option.dart';

// ── Dependency providers ──────────────────────────────────────────────────────

final feedDataSourceProvider = Provider<FeedRemoteDataSource>(
  (_) => FeedRemoteDataSourceImpl(),
);

final feedRepositoryProvider = Provider<FeedRepositoryImpl>((ref) {
  final college = ref.read(userProvider).college;
  return FeedRepositoryImpl(
    ref.watch(feedDataSourceProvider),
    college: college,
  );
});

final getFeedUseCaseProvider = Provider<GetFeedUseCase>(
  (ref) => GetFeedUseCase(ref.watch(feedRepositoryProvider)),
);

// ── Sort state ────────────────────────────────────────────────────────────────

final feedSortProvider = StateProvider<FeedSortOption>(
  (_) => FeedSortOption.upvotes,
);

// ── Vote state (local, per post id) ──────────────────────────────────────────

final upvotedPostsProvider   = StateProvider<Set<String>>((_) => {});
final downvotedPostsProvider = StateProvider<Set<String>>((_) => {});

// ── Sorted feed provider (derived, cached) ────────────────────────────────────

final sortedFeedProvider = Provider<List<FeedPostEntity>>((ref) {
  final feedAsync  = ref.watch(feedProvider);
  final sortOption = ref.watch(feedSortProvider);
  return feedAsync.maybeWhen(
    data: (posts) {
      final copy = List<FeedPostEntity>.from(posts);
      switch (sortOption) {
        case FeedSortOption.upvotes:
          copy.sort((a, b) => b.upvotes.compareTo(a.upvotes));
        case FeedSortOption.mostAttempted:
          copy.sort((a, b) => b.attempts.compareTo(a.attempts));
        case FeedSortOption.difficultyEasyFirst:
          copy.sort((a, b) => _diffRank(a.difficulty).compareTo(_diffRank(b.difficulty)));
        case FeedSortOption.difficultyHardFirst:
          copy.sort((a, b) => _diffRank(b.difficulty).compareTo(_diffRank(a.difficulty)));
      }
      return copy;
    },
    orElse: () => [],
  );
});

int _diffRank(String d) => switch (d) {
  'easy'   => 0,
  'medium' => 1,
  'hard'   => 2,
  _        => 1,
};

// ── Feed notifier ─────────────────────────────────────────────────────────────

class FeedNotifier extends AsyncNotifier<List<FeedPostEntity>> {
  @override
  Future<List<FeedPostEntity>> build() async {
    final useCase = ref.watch(getFeedUseCaseProvider);
    final result  = await useCase();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (posts)   => posts,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  void toggleUpvote(String postId) {
    ref.read(downvotedPostsProvider.notifier).update((set) {
      final next = Set<String>.from(set)..remove(postId);
      return next;
    });
    ref.read(upvotedPostsProvider.notifier).update((set) {
      final next = Set<String>.from(set);
      if (next.contains(postId)) { next.remove(postId); } else { next.add(postId); }
      return next;
    });
  }

  void toggleDownvote(String postId) {
    ref.read(upvotedPostsProvider.notifier).update((set) {
      final next = Set<String>.from(set)..remove(postId);
      return next;
    });
    ref.read(downvotedPostsProvider.notifier).update((set) {
      final next = Set<String>.from(set);
      if (next.contains(postId)) { next.remove(postId); } else { next.add(postId); }
      return next;
    });
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<FeedPostEntity>>(
  FeedNotifier.new,
);