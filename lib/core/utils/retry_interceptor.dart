import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

final _log = Logger('RetryInterceptor');

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration baseDelay;

  RetryInterceptor({this.maxRetries = 3, this.baseDelay = const Duration(seconds: 2)});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    if (!isRetryable(err)) {
      handler.next(err);
      return;
    }

    final retries = (options.extra['retryCount'] as int?) ?? 0;
    if (retries >= maxRetries) {
      _log.warning('retry exhausted after $retries attempts: ${options.path}');
      handler.next(err);
      return;
    }

    final nextRetry = retries + 1;
    options.extra['retryCount'] = nextRetry;
    final delay = baseDelay * nextRetry;

    _log.info('retry $nextRetry/$maxRetries after ${delay.inMilliseconds}ms: ${options.path}');

    Future.delayed(delay, () {
      Dio().fetch(options).then(
        (r) => handler.resolve(r),
        onError: (e) => handler.next(e as DioException),
      );
    });
  }

  bool isRetryable(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    if (err.type == DioExceptionType.badResponse) {
      final code = err.response?.statusCode ?? 0;
      return code >= 500 && code < 600;
    }
    return false;
  }
}
