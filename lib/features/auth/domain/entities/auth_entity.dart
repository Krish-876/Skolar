import 'package:nova/shared/models/base_models.dart';

class AuthEntity extends BaseEntity {
  final String email;
  final String displayName;
  const AuthEntity({required super.id, required this.email, required this.displayName});
}
