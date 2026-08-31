import 'package:supabase_flutter/supabase_flutter.dart';
import '../entities/auth_entity.dart';
import '../repositories/auth_repository.dart';

class SendMagicLinkUseCase {
  final AuthRepository _repo;
  const SendMagicLinkUseCase(this._repo);
  Future<void> call(String email) => _repo.sendMagicLink(email);
}

class SignInWithPasswordUseCase {
  final AuthRepository _repo;
  const SignInWithPasswordUseCase(this._repo);
  Future<AuthResponse> call({
    required String email,
    required String password,
  }) => _repo.signInWithPassword(email: email, password: password);
}

class SignUpWithPasswordUseCase {
  final AuthRepository _repo;
  const SignUpWithPasswordUseCase(this._repo);
  Future<AuthResponse> call({
    required String email,
    required String password,
  }) => _repo.signUpWithPassword(email: email, password: password);
}

class SendPasswordResetUseCase {
  final AuthRepository _repo;
  const SendPasswordResetUseCase(this._repo);
  Future<void> call(String email) => _repo.sendPasswordReset(email);
}

class SignInWithGoogleUseCase {
  final AuthRepository _repo;
  const SignInWithGoogleUseCase(this._repo);
  Future<bool> call() => _repo.signInWithGoogle();
}

class ValidateCollegeEmailUseCase {
  final AuthRepository _repo;
  const ValidateCollegeEmailUseCase(this._repo);
  Future<bool> call(String email) => _repo.isValidCollegeEmail(email);
}

class GetCurrentUserUseCase {
  final AuthRepository _repo;
  const GetCurrentUserUseCase(this._repo);
  AppUser? call() => _repo.getCurrentUser();
}

class SignOutUseCase {
  final AuthRepository _repo;
  const SignOutUseCase(this._repo);
  Future<void> call() => _repo.signOut();
}
