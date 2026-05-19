// import 'package:dio/dio.dart';
// import 'package:nova/core/errors/exceptions.dart';
// import 'package:nova/core/errors/failures.dart';
// import 'package:dartz/dartz.dart';

// /// Centralized error handling and exception to failure conversion
// class ErrorHandler {
//   /// Convert exceptions to failures
//   static Failure handleException(dynamic exception) {
//     if (exception is ServerException) {
//       return ServerFailure(
//         exception.message,
//         statusCode: exception.statusCode,
//       );
//     } else if (exception is NetworkException) {
//       return NetworkFailure(exception.message);
//     } else if (exception is CacheException) {
//       return CacheFailure(exception.message);
//     } else if (exception is ValidationException) {
//       return ValidationFailure(exception.message);
//     } else if (exception is AuthException) {
//       return AuthFailure(exception.message);
//     } else if (exception is PermissionException) {
//       return PermissionFailure(exception.message);
//     } else if (exception is DataParseException) {
//       return DataParseFailure(exception.message);
//     } else if (exception is NotFoundException) {
//       return NotFoundFailure(exception.message);
//     } else if (exception is DioException) {
//       return _handleDioException(exception);
//     }
//     return UnknownFailure('Unknown error: ${exception.toString()}');
//   }

//   /// Handle DioException and convert to appropriate failure
//   static Failure _handleDioException(DioException dioException) {
//     switch (dioException.type) {
//       case DioExceptionType.connectionTimeout:
//       case DioExceptionType.receiveTimeout:
//       case DioExceptionType.sendTimeout:
//         return NetworkFailure('Connection timeout: ${dioException.message}');
//       case DioExceptionType.badResponse:
//         final statusCode = dioException.response?.statusCode;
//         final message = dioException.response?.data['message'] ?? dioException.message;
        
//         if (statusCode == 401) {
//           return AuthFailure(message ?? 'Unauthorized');
//         } else if (statusCode == 403) {
//           return PermissionFailure(message ?? 'Forbidden');
//         } else if (statusCode == 404) {
//           return NotFoundFailure(message ?? 'Not found');
//         } else {
//           return ServerFailure(
//             message ?? 'Server error',
//             statusCode: statusCode,
//           );
//         }
//       case DioExceptionType.connectionError:
//         return NetworkFailure('Connection error: ${dioException.message}');
//       case DioExceptionType.badCertificate:
//         return NetworkFailure('Invalid SSL certificate');
//       case DioExceptionType.unknown:
//         return UnknownFailure(dioException.message ?? 'Unknown error');
//       case DioExceptionType.cancel:
//         return UnknownFailure('Request cancelled');
//     }
//   }

//   /// Convert failure to user-friendly message
//   static String getErrorMessage(Failure failure) {
//     if (failure is ServerFailure) {
//       return failure.message;
//     } else if (failure is NetworkFailure) {
//       return 'Network error. Please check your connection.';
//     } else if (failure is CacheFailure) {
//       return 'Failed to load cached data.';
//     } else if (failure is ValidationFailure) {
//       return failure.message;
//     } else if (failure is AuthFailure) {
//       return 'Authentication failed. Please log in again.';
//     } else if (failure is PermissionFailure) {
//       return 'You do not have permission to access this resource.';
//     } else if (failure is DataParseFailure) {
//       return 'Failed to process data.';
//     } else if (failure is NotFoundFailure) {
//       return 'Resource not found.';
//     }
//     return 'An unknown error occurred.';
//   }
// }
