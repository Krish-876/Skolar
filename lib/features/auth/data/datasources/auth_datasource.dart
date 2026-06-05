import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthDataSource {
  Future<void> sendMagicLink(String email);
  User? getCurrentUser();
  Future<void> signOut();
  Future<List<String>> fetchEmailPatterns();
}

class AuthRemoteDataSource implements AuthDataSource {
  final SupabaseClient _client;
  const AuthRemoteDataSource(this._client);

  @override
  Future<void> sendMagicLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
  }

  @override
  User? getCurrentUser() => _client.auth.currentUser;

  @override
  Future<void> signOut() async => await _client.auth.signOut();

  @override
  Future<List<String>> fetchEmailPatterns() async {
    final response = await _client
        .from('institutions')
        .select('email_patterns');
    
    final patterns = <String>[];
    for (final row in response) {
      final list = row['email_patterns'] as List<dynamic>;
      patterns.addAll(list.map((e) => e as String));
    }
    return patterns;
  }
}