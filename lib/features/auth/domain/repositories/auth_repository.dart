import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Skolar/features/auth/domain/entities/auth_entity.dart';

abstract class AuthRepository {
  Future<void> sendMagicLink(String email);
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<bool> signInWithGoogle();
  AppUser? getCurrentUser();
  Future<void> signOut();
  Future<bool> isValidCollegeEmail(String email);
}
