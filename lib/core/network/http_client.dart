import 'package:dio/dio.dart';

/// Base HTTP client wrapper for Dio
class HttpClient {
  final Dio _dio;

  HttpClient(this._dio);

  Dio get dio => _dio;

  /// Configure base URL
  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  /// Add authorization header
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Remove authorization header
  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Set custom headers
  void setHeaders(Map<String, dynamic> headers) {
    _dio.options.headers.addAll(headers);
  }
}
