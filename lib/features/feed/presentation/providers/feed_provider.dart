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

// ── Vote state (persisted via Supabase, mirrored locally for optimistic UI) ──

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
    final repo    = ref.read(feedRepositoryProvider);
    final userId  = ref.read(userProvider).id;

    // Load posts
    final result = await useCase();
    final posts  = result.fold(
      (failure) => throw Exception(failure.message),
      (posts)   => posts,
    );

    // Load persisted votes and hydrate local state
    if (userId.isNotEmpty) {
      final votesResult = await repo.fetchUserVotes(userId: userId);
      votesResult.fold(
        (_) => null,
        (votes) {
          final upvoted   = <String>{};
          final downvoted = <String>{};
          for (final entry in votes.entries) {
            if (entry.value == 1)  upvoted.add(entry.key);
            if (entry.value == -1) downvoted.add(entry.key);
          }
          ref.read(upvotedPostsProvider.notifier).state   = upvoted;
          ref.read(downvotedPostsProvider.notifier).state = downvoted;
        },
      );
    }

    return posts;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggleUpvote(String postId) async {
    final isUpvoted   = ref.read(upvotedPostsProvider).contains(postId);
    final isDownvoted = ref.read(downvotedPostsProvider).contains(postId);

    // Update arrow state
    ref.read(downvotedPostsProvider.notifier).update((set) => Set<String>.from(set)..remove(postId));
    ref.read(upvotedPostsProvider.notifier).update((set) {
      final next = Set<String>.from(set);
      if (next.contains(postId)) { next.remove(postId); } else { next.add(postId); }
      return next;
    });

    // Update count in local posts list immediately
    state = AsyncData(state.value!.map((post) {
      if (post.id != postId) return post;
      int upvotes   = post.upvotes;
      int downvotes = post.downvotes;
      if (isUpvoted) {
        upvotes -= 1;
      } else {
        upvotes += 1;
        if (isDownvoted) downvotes -= 1;
      }
      return FeedPostEntity(
        id: post.id, authorName: post.authorName, authorInitials: post.authorInitials,
        authorYear: post.authorYear, authorBranch: post.authorBranch, subject: post.subject,
        title: post.title, difficulty: post.difficulty, yearRange: post.yearRange,
        questionCount: post.questionCount, upvotes: upvotes, downvotes: downvotes,
        attempts: post.attempts, tags: post.tags, isPublished: post.isPublished,
        createdAt: post.createdAt, examType: post.examType, questionIds: post.questionIds,
      );
    }).toList());

    // Persist to Supabase
    final userId = ref.read(userProvider).id;
    if (userId.isEmpty) return;
    final repo = ref.read(feedRepositoryProvider);
    await repo.castVote(postId: postId, userId: userId, vote: 1);
  }

  Future<void> toggleDownvote(String postId) async {
    final isDownvoted = ref.read(downvotedPostsProvider).contains(postId);
    final isUpvoted   = ref.read(upvotedPostsProvider).contains(postId);

    // Update arrow state
    ref.read(upvotedPostsProvider.notifier).update((set) => Set<String>.from(set)..remove(postId));
    ref.read(downvotedPostsProvider.notifier).update((set) {
      final next = Set<String>.from(set);
      if (next.contains(postId)) { next.remove(postId); } else { next.add(postId); }
      return next;
    });

    // Update count in local posts list immediately
    state = AsyncData(state.value!.map((post) {
      if (post.id != postId) return post;
      int upvotes   = post.upvotes;
      int downvotes = post.downvotes;
      if (isDownvoted) {
        downvotes -= 1;
      } else {
        downvotes += 1;
        if (isUpvoted) upvotes -= 1;
      }
      return FeedPostEntity(
        id: post.id, authorName: post.authorName, authorInitials: post.authorInitials,
        authorYear: post.authorYear, authorBranch: post.authorBranch, subject: post.subject,
        title: post.title, difficulty: post.difficulty, yearRange: post.yearRange,
        questionCount: post.questionCount, upvotes: upvotes, downvotes: downvotes,
        attempts: post.attempts, tags: post.tags, isPublished: post.isPublished,
        createdAt: post.createdAt, examType: post.examType, questionIds: post.questionIds,
      );
    }).toList());

    // Persist to Supabase
    final userId = ref.read(userProvider).id;
    if (userId.isEmpty) return;
    final repo = ref.read(feedRepositoryProvider);
    await repo.castVote(postId: postId, userId: userId, vote: -1);
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<FeedPostEntity>>(
  FeedNotifier.new,
);