enum FeedSortOption {
  upvotes,
  mostAttempted,
  difficultyEasyFirst,
  difficultyHardFirst;

  String get label {
    switch (this) {
      case FeedSortOption.upvotes:
        return 'Upvotes';
      case FeedSortOption.mostAttempted:
        return 'Most attempted';
      case FeedSortOption.difficultyEasyFirst:
        return 'Difficulty: Easy first';
      case FeedSortOption.difficultyHardFirst:
        return 'Difficulty: Hard first';
    }
  }
}