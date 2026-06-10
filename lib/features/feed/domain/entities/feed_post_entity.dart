import 'package:Skolar/shared/models/exam_type.dart';

class FeedPostEntity {
  final String id;
  final String authorName;
  final String authorInitials;
  final String authorYear;
  final String authorBranch;
  final String subject;
  final String title;
  final String difficulty;
  final String yearRange;
  final int questionCount;
  final int upvotes;
  final int downvotes;
  final int attempts;
  final List<String> tags;
  final bool isPublished;
  final DateTime createdAt;
  final ExamType examType;
  final List<String> questionIds;  // UUIDs from published_tests.question_ids

  const FeedPostEntity({
    required this.id,
    required this.authorName,
    required this.authorInitials,
    required this.authorYear,
    required this.authorBranch,
    required this.subject,
    required this.title,
    required this.difficulty,
    required this.yearRange,
    required this.questionCount,
    required this.upvotes,
    required this.downvotes,
    required this.attempts,
    required this.tags,
    required this.isPublished,
    required this.createdAt,
    required this.examType,
    this.questionIds = const [],
  });
}