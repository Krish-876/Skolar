import 'package:Skolar/features/auth/domain/entities/auth_entity.dart';

abstract class AuthRepository {
  Future<void> sendMagicLink(String email);
  AppUser? getCurrentUser();
  Future<void> signOut();
  Future<bool> isValidCollegeEmail(String email);
}
