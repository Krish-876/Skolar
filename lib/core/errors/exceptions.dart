/// Custom exception classes for error handling throughout the app
library;

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  AppException({required this.message, this.code, this.originalException});

  @override
  String toString() =>
      'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

class ServerException extends AppException {
  final int? statusCode;

  ServerException({
    required super.message,
    this.statusCode,
    String? code,
    super.originalException,
  }) : super(
         code: code ?? statusCode.toString(),
       );
}

class NetworkException extends AppException {
  NetworkException({
    required super.message,
    super.code,
    super.originalException,
  });
}

class CacheException extends AppException {
  CacheException({
    required super.message,
    super.code,
    super.originalException,
  });
}

class ValidationException extends AppException {
  ValidationException({
    required super.message,
    super.code,
    super.originalException,
  });
}

class AuthException extends AppException {
  AuthException({
    required super.message,
    super.code,
    super.originalException,
  });
}

class PermissionException extends AppException {
  PermissionException({
    required super.message,
    super.code,
    super.originalException,
  });
}

class DataParseException extends AppException {
  DataParseException({
    required super.message,
    super.code,
    super.originalException,
  });
}

class NotFoundException extends AppException {
  NotFoundException({
    required super.message,
    super.code,
    super.originalException,
  });
}
