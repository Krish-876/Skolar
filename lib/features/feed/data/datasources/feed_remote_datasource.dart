import 'package:supabase_flutter/supabase_flutter.dart';
import '../dtos/feed_post_dto.dart';

abstract class FeedRemoteDataSource {
  Future<List<FeedPostDto>> getPosts({required String college});
  Future<void> castVote({required String postId, required String userId, required int vote});
  Future<Map<String, int>> fetchUserVotes({required String userId});
}

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  final _client = Supabase.instance.client;

  @override
  Future<List<FeedPostDto>> getPosts({required String college}) async {
    final response = await _client
        .from('published_tests')
        .select('''
          id,
          subject,
          exam_type,
          question_ids,
          upvotes,
          downvotes,
          attempts,
          created_at,
          published_by (
            full_name,
            academic_year,
            college
          )
        ''')
        .eq('college', college)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List<dynamic>)
        .map((row) => FeedPostDto.fromSupabase(row as Map<String, dynamic>))
        .toList();
  }

  // vote: 1 = upvote, -1 = downvote
  @override
  Future<void> castVote({
    required String postId,
    required String userId,
    required int vote,
  }) async {
    await _client.rpc('handle_vote', params: {
      'p_post_id': postId,
      'p_user_id': userId,
      'p_vote':    vote,
    });
  }

  // Returns map of postId -> vote (1 or -1) for all posts this user has voted on
  @override
  Future<Map<String, int>> fetchUserVotes({required String userId}) async {
    final response = await _client
        .from('post_votes')
        .select('post_id, vote')
        .eq('user_id', userId);

    return {
      for (final row in response as List<dynamic>)
        row['post_id'] as String: row['vote'] as int,
    };
  }
}