import 'package:supabase_flutter/supabase_flutter.dart';
import '../dtos/feed_post_dto.dart';

abstract class FeedRemoteDataSource {
  Future<List<FeedPostDto>> getPosts({required String college});
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
}