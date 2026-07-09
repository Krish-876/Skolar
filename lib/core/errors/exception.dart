/// Base exception for all application errors
abstract class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

class ServerException extends AppException {
  final int? statusCode;

  ServerException({required String message, this.statusCode}) : super(message);
}

class NetworkException extends AppException {
  NetworkException({String message = 'Network Error'}) : super(message);
}

class CacheException extends AppException {
  CacheException({String message = 'Cache Error'}) : super(message);
}

class AuthenticationException extends AppException {
  AuthenticationException({String message = 'Authentication Failed'})
    : super(message);
}

class AuthorizationException extends AppException {
  AuthorizationException({String message = 'Authorization Failed'})
    : super(message);
}

class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException({required String message, this.fieldErrors})
    : super(message);
}

class AIException extends AppException {
  final String? provider;
  final String? retryMessage;

  AIException({required String message, this.provider, this.retryMessage})
    : super(message);
}
