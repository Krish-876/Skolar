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
    return patterns.any(
      (pattern) => RegExp(pattern).hasMatch(email),
    );
  }
}