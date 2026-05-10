import 'package:dio/dio.dart';
import '../utils/retry_interceptor.dart';

Dio createApiClient({
  required String baseUrl,
  String? authToken,
  Duration connectTimeout = const Duration(seconds: 30),
  Duration receiveTimeout = const Duration(seconds: 120),
}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
    headers: {
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
    },
  ));

  dio.interceptors.addAll([
    DioHttpsInterceptor(),
    RetryInterceptor(),
  ]);

  return dio;
}

class DioHttpsInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final host = options.uri.host;
    if (!host.contains('localhost') && options.uri.scheme != 'https') {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'HTTPS is required for security',
      ));
      return;
    }
    handler.next(options);
  }
}
