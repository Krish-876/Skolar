import '../../domain/entities/auth_entity.dart';

class AppUserDto {
  final String id;
  final String email;

  const AppUserDto({required this.id, required this.email});

  factory AppUserDto.fromSupabase(Map<String, dynamic> data) =>
      AppUserDto(id: data['id'] as String, email: data['email'] as String);

  AppUser toDomain({required bool isNewUser}) =>
      AppUser(id: id, email: email, isNewUser: isNewUser);
}
