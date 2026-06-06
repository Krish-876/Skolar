import 'package:Skolar/shared/models/exam_type.dart';
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
  final String examType;
  final List<String> questionIds;

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
    required this.examType,
    this.questionIds = const [],
  });

  // ── Local JSON (mock data) ────────────────────────────────────────────────
  factory FeedPostDto.fromJson(Map<String, dynamic> json) {
    return FeedPostDto(
      id:             json['id']             as String,
      authorName:     json['authorName']     as String,
      authorInitials: json['authorInitials'] as String,
      authorYear:     json['authorYear']     as String,
      authorBranch:   json['authorBranch']   as String,
      subject:        json['subject']        as String,
      title:          json['title']          as String,
      difficulty:     json['difficulty']     as String,
      yearRange:      json['yearRange']      as String,
      questionCount:  json['questionCount']  as int,
      upvotes:        json['upvotes']        as int,
      attempts:       json['attempts']       as int,
      tags:           List<String>.from(json['tags'] as List),
      isPublished:    json['isPublished']    as bool,
      createdAt:      json['createdAt']      as String,
      examType:       json['examType']       as String? ?? 'compre',
      questionIds:    json['questionIds'] != null
                          ? List<String>.from(json['questionIds'] as List)
                          : [],
    );
  }

  // ── Supabase (published_tests join) ───────────────────────────────────────
  factory FeedPostDto.fromSupabase(Map<String, dynamic> row) {
    final author     = row['published_by'] as Map<String, dynamic>?;
    final authorName = author?['full_name'] as String? ?? 'Anonymous';
    final initials   = authorName
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final academicYear = author?['academic_year'] as int? ?? 1;
    final examType     = row['exam_type']  as String? ?? 'compre';
    final questionIds  = List<String>.from(row['question_ids'] as List? ?? []);
    final subject      = row['subject']    as String? ?? '';

    // Derive difficulty from exam type
    final difficulty = switch (examType) {
      'quiz1'  => 'easy',
      'midsem' => 'medium',
      'quiz2'  => 'medium',
      _        => 'hard',
    };

    // Human-readable title
    final examLabel = switch (examType) {
      'quiz1'  => 'Quiz 1',
      'midsem' => 'Midsem',
      'quiz2'  => 'Quiz 2',
      _        => 'Compre',
    };
    final title = '$subject — $examLabel Practice (${questionIds.length}Q)';

    return FeedPostDto(
      id:             row['id']       as String,
      authorName:     authorName,
      authorInitials: initials.isEmpty ? '?' : initials,
      authorYear:     'Y$academicYear',
      authorBranch:   'CSE',
      subject:        subject,
      title:          title,
      difficulty:     difficulty,
      yearRange:      '',
      questionCount:  questionIds.length,
      upvotes:        row['upvotes']  as int? ?? 0,
      attempts:       row['attempts'] as int? ?? 0,
      tags:           [subject, examLabel],
      isPublished:    true,
      createdAt:      row['created_at'] as String,
      examType:       examType,
      questionIds:    questionIds,
    );
  }

  FeedPostEntity toDomain() {
    return FeedPostEntity(
      id:             id,
      authorName:     authorName,
      authorInitials: authorInitials,
      authorYear:     authorYear,
      authorBranch:   authorBranch,
      subject:        subject,
      title:          title,
      difficulty:     difficulty,
      yearRange:      yearRange,
      questionCount:  questionCount,
      upvotes:        upvotes,
      attempts:       attempts,
      tags:           tags,
      isPublished:    isPublished,
      createdAt:      DateTime.parse(createdAt),
      examType:       ExamType.values.firstWhere(
                        (e) => e.apiValue == examType,
                        orElse: () => ExamType.compre,
                      ),
      questionIds:    questionIds,
    );
  }
}