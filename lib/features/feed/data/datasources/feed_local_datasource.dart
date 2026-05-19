import 'dart:convert';
import 'package:flutter/services.dart';
import '../dtos/feed_post_dto.dart';

abstract class FeedLocalDataSource {
  Future<List<FeedPostDto>> getPosts();
}

class FeedLocalDataSourceImpl implements FeedLocalDataSource {
  @override
  Future<List<FeedPostDto>> getPosts() async {
    final jsonString = await rootBundle.loadString('assets/data/feed.json');
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    final postsJson = jsonMap['posts'] as List<dynamic>;
    return postsJson
        .map((e) => FeedPostDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}