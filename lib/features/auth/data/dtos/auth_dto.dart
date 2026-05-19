import '../../domain/entities/auth_entity.dart';

class AuthDto {
  final String id;
  final String email;
  final String displayName;

  const AuthDto({required this.id, required this.email, required this.displayName});

  factory AuthDto.fromJson(Map<String, dynamic> json) => AuthDto(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
  );

  Map<String, dynamic> toJson() => {
      'id': id,
      'email': email,
      'displayName': displayName,
  };

  AuthEntity toEntity() => AuthEntity(id: id, email: email, displayName: displayName);
}
