import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:paperpal/core/utils/retry_interceptor.dart';
import 'package:paperpal/core/utils/logger.dart' as logger;

void main() {
  group('RetryInterceptor', () {
    late RetryInterceptor interceptor;

    setUp(() {
      interceptor = RetryInterceptor(maxRetries: 3, baseDelay: const Duration(milliseconds: 1));
    });

    test('defaults are set correctly', () {
      final i = RetryInterceptor();
      expect(i.maxRetries, 3);
      expect(i.baseDelay, const Duration(seconds: 2));
    });

    test('custom maxRetries and baseDelay', () {
      final i = RetryInterceptor(maxRetries: 5, baseDelay: const Duration(seconds: 1));
      expect(i.maxRetries, 5);
      expect(i.baseDelay, const Duration(seconds: 1));
    });

    test('isRetryable returns true for connection timeout', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
      expect(interceptor.isRetryable(err), true);
    });

    test('isRetryable returns true for send timeout', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.sendTimeout,
      );
      expect(interceptor.isRetryable(err), true);
    });

    test('isRetryable returns true for receive timeout', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
      expect(interceptor.isRetryable(err), true);
    });

    test('isRetryable returns true for connection error', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
      expect(interceptor.isRetryable(err), true);
    });

    test('isRetryable returns true for server errors (5xx)', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(statusCode: 500, requestOptions: options),
      );
      expect(interceptor.isRetryable(err), true);
    });

    test('isRetryable returns false for client errors (4xx)', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(statusCode: 400, requestOptions: options),
      );
      expect(interceptor.isRetryable(err), false);
    });

    test('isRetryable returns false for cancel', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
      expect(interceptor.isRetryable(err), false);
    });

    test('isRetryable returns false for unknown', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
      );
      expect(interceptor.isRetryable(err), false);
    });

    test('isRetryable returns false for badResponse 3xx', () {
      final options = RequestOptions(path: '/test');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(statusCode: 301, requestOptions: options),
      );
      expect(interceptor.isRetryable(err), false);
    });
  });

  group('Logger sanitize', () {
    test('redacts api key in query string', () {
      const input = 'api_key=sk-1234567890abcdef';
      final result = logger.sanitize(input);
      expect(result, contains('api_key=***'));
      expect(result, isNot(contains('sk-1234567890abcdef')));
    });

    test('redacts sk- keys in text', () {
      const input = 'using sk-abcdef1234567890abcdef12';
      final result = logger.sanitize(input);
      expect(result, startsWith('using sk-***'));
      expect(result, isNot(contains('abcdef1234567890abcdef12')));
    });

    test('redacts ds- keys in text', () {
      const input = 'ds-abcdef1234567890';
      final result = logger.sanitize(input);
      expect(result, startsWith('ds-***'));
      expect(result, isNot(contains('abcdef1234567890')));
    });

    test('redacts Authorization header value', () {
      const input = 'Authorization: Bearer sk-abcdef1234567890';
      final result = logger.sanitize(input);
      expect(result, contains('Authorization=***'));
    });

    test('redacts api_key with equals format', () {
      const input = 'apikey=my-secret-token-here';
      final result = logger.sanitize(input);
      expect(result, contains('apikey=***'));
    });

    test('passes through safe text unchanged', () {
      const input = 'Hello this is normal log text';
      expect(logger.sanitize(input), input);
    });

    test('redacts token pattern in mixed text', () {
      const input = 'Using token=ds-secret-key and doing work';
      final result = logger.sanitize(input);
      expect(result, contains('token=***'));
    });

    test('redacts multiple sensitive patterns', () {
      const input = 'api_key=key1 and apikey=key2';
      final result = logger.sanitize(input);
      expect(result, allOf([
        contains('api_key=***'),
        contains('apikey=***'),
      ]));
    });
  });
}
