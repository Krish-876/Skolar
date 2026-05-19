import '../../domain/entities/feed_post_entity.dart';

class FeedPostDto {
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
  final int attempts;
  final List<String> tags;
  final bool isPublished;
  final String createdAt;

  const FeedPostDto({
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
    required this.attempts,
    required this.tags,
    required this.isPublished,
    required this.createdAt,
  });

  factory FeedPostDto.fromJson(Map<String, dynamic> json) {
    return FeedPostDto(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      authorInitials: json['authorInitials'] as String,
      authorYear: json['authorYear'] as String,
      authorBranch: json['authorBranch'] as String,
      subject: json['subject'] as String,
      title: json['title'] as String,
      difficulty: json['difficulty'] as String,
      yearRange: json['yearRange'] as String,
      questionCount: json['questionCount'] as int,
      upvotes: json['upvotes'] as int,
      attempts: json['attempts'] as int,
      tags: List<String>.from(json['tags'] as List),
      isPublished: json['isPublished'] as bool,
      createdAt: json['createdAt'] as String,
    );
  }

  FeedPostEntity toDomain() {
    return FeedPostEntity(
      id: id,
      authorName: authorName,
      authorInitials: authorInitials,
      authorYear: authorYear,
      authorBranch: authorBranch,
      subject: subject,
      title: title,
      difficulty: difficulty,
      yearRange: yearRange,
      questionCount: questionCount,
      upvotes: upvotes,
      attempts: attempts,
      tags: tags,
      isPublished: isPublished,
      createdAt: DateTime.parse(createdAt),
    );
  }
}