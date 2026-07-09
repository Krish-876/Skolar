import 'package:dio/dio.dart';
import 'package:Skolar/core/config/environment.dart';

/// Dio HTTP client configuration and setup
/// Handles base URL, headers, interceptors, and timeout configuration
class DioHttpClient {
  static const String _defaultContentType = 'application/json';
  static const Duration _defaultConnectTimeout = Duration(seconds: 30);
  static const Duration _defaultReceiveTimeout = Duration(seconds: 30);
  static const Duration _defaultSendTimeout = Duration(seconds: 30);

  final Environment environment;
  late final Dio _dio;

  DioHttpClient({required this.environment}) {
    _initializeDio();
  }

  /// Initialize Dio with configuration
  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: environment.apiBaseUrl,
        contentType: _defaultContentType,
        connectTimeout: _defaultConnectTimeout,
        receiveTimeout: _defaultReceiveTimeout,
        sendTimeout: _defaultSendTimeout,
        validateStatus: (status) {
          /// Don't throw error for any status code
          /// Handle it in the interceptor instead
          return true;
        },
      ),
    );

    /// Add interceptors
    _dio.interceptors.add(_createLoggingInterceptor());
    _dio.interceptors.add(_createErrorInterceptor());
    _dio.interceptors.add(_createAuthInterceptor());
  }

  /// Logging interceptor for debugging
  Interceptor _createLoggingInterceptor() {
    return LoggingInterceptor();
  }

  /// Error handling interceptor
  Interceptor _createErrorInterceptor() {
    return ErrorInterceptor();
  }

  /// Auth token interceptor
  Interceptor _createAuthInterceptor() {
    return AuthInterceptor();
  }

  /// Get the Dio instance
  Dio get client => _dio;

  /// Set bearer token
  void setBearerToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear bearer token
  void clearBearerToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Set custom header
  void setHeader(String key, dynamic value) {
    _dio.options.headers[key] = value;
  }

  /// Remove custom header
  void removeHeader(String key) {
    _dio.options.headers.remove(key);
  }
}

/// Logging interceptor for API requests
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('🔵 [HTTP REQUEST] ${options.method} ${options.path}');
    debugPrint('Headers: ${options.headers}');
    if (options.data != null) {
      debugPrint('Body: ${options.data}');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '🟢 [HTTP RESPONSE] ${response.statusCode} ${response.requestOptions.path}',
    );
    debugPrint('Response: ${response.data}');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '🔴 [HTTP ERROR] ${err.response?.statusCode} ${err.requestOptions.path}',
    );
    debugPrint('Error: ${err.message}');
    super.onError(err, handler);
  }
}

/// Error interceptor for handling API errors
class ErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Handle specific status codes if needed
    if (response.statusCode != null && response.statusCode! >= 400) {
      // Let the repository handle the error conversion
      return handler.next(response);
    }
    super.onResponse(response, handler);
  }
}

/// Auth interceptor for adding auth tokens
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Token will be set manually via setBearerToken
    // This can be extended to refresh tokens automatically
    super.onRequest(options, handler);
  }
}

/// Helper method for logging during development
void debugPrint(String message) {
  // Use this instead of print() to avoid logs in production
  // In production, you'd use a proper logging service
  print(message);
}
