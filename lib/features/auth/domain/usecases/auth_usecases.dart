import '../entities/auth_entity.dart';
import '../repositories/auth_repository.dart';

class SendMagicLinkUseCase {
  final AuthRepository _repo;
  const SendMagicLinkUseCase(this._repo);
  Future<void> call(String email) => _repo.sendMagicLink(email);
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