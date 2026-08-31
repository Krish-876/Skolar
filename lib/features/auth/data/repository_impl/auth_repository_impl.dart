import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/auth_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource _dataSource;
  const AuthRepositoryImpl(this._dataSource);

  @override
  Future<void> sendMagicLink(String email) async {
    await _dataSource.sendMagicLink(email);
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _dataSource.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    return await _dataSource.signUpWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _dataSource.sendPasswordReset(email);
  }

  @override
  Future<bool> signInWithGoogle() async {
    return await _dataSource.signInWithGoogle();
  }

  @override
  AppUser? getCurrentUser() {
    final user = _dataSource.getCurrentUser();
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      isNewUser: user.createdAt == user.lastSignInAt,
    );
  }

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  Future<bool> isValidCollegeEmail(String email) async {
    final patterns = await _dataSource.fetchEmailPatterns();
    if (patterns.isEmpty) return true;
    return patterns.any((pattern) => RegExp(pattern).hasMatch(email));
  }
}
