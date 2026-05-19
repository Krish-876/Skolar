import 'package:dio/dio.dart';

/// Custom Dio interceptor for handling requests/responses
class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Pre-request logging and modifications
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Post-response handling
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Error handling and retry logic
    super.onError(err, handler);
  }
}
