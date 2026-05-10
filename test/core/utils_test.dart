import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:paperpal/core/utils/retry_interceptor.dart';
import 'package:paperpal/core/utils/logger.dart' as logger;

void main() {
  group('RetryInterceptor', () {
    test('defaults', () {
      final i = RetryInterceptor();
      expect(i.maxRetries, 3);
      expect(i.baseDelay, const Duration(seconds: 2));
    });

    test('custom values', () {
      final i = RetryInterceptor(maxRetries: 2, baseDelay: const Duration(seconds: 1));
      expect(i.maxRetries, 2);
      expect(i.baseDelay, const Duration(seconds: 1));
    });

    group('isRetryable', () {
      late RetryInterceptor i;
      setUp(() => i = RetryInterceptor());

      RequestOptions opts() => RequestOptions(path: '/test');

      test('connection timeout', () => expect(i.isRetryable(DioException(requestOptions: opts(), type: DioExceptionType.connectionTimeout)), true));

      test('send timeout', () => expect(i.isRetryable(DioException(requestOptions: opts(), type: DioExceptionType.sendTimeout)), true));

      test('receive timeout', () => expect(i.isRetryable(DioException(requestOptions: opts(), type: DioExceptionType.receiveTimeout)), true));

      test('connection error', () => expect(i.isRetryable(DioException(requestOptions: opts(), type: DioExceptionType.connectionError)), true));

      test('5xx server error', () {
        final o = opts();
        expect(i.isRetryable(DioException(requestOptions: o, type: DioExceptionType.badResponse, response: Response(statusCode: 500, requestOptions: o))), true);
      });

      test('503 server error', () {
        final o = opts();
        expect(i.isRetryable(DioException(requestOptions: o, type: DioExceptionType.badResponse, response: Response(statusCode: 503, requestOptions: o))), true);
      });

      test('4xx client error', () {
        final o = opts();
        expect(i.isRetryable(DioException(requestOptions: o, type: DioExceptionType.badResponse, response: Response(statusCode: 400, requestOptions: o))), false);
      });

      test('3xx redirect', () {
        final o = opts();
        expect(i.isRetryable(DioException(requestOptions: o, type: DioExceptionType.badResponse, response: Response(statusCode: 301, requestOptions: o))), false);
      });

      test('cancel', () => expect(i.isRetryable(DioException(requestOptions: opts(), type: DioExceptionType.cancel)), false));

      test('unknown', () => expect(i.isRetryable(DioException(requestOptions: opts(), type: DioExceptionType.unknown)), false));

      test('badResponse with null response', () => expect(i.isRetryable(DioException(requestOptions: opts(), type: DioExceptionType.badResponse)), false));
    });
  });

  group('Logger sanitize', () {
    test('api_key= secret', () {
      expect(logger.sanitize('api_key=sk-abcdef'), contains('api_key=***'));
    });

    test('apikey= secret', () {
      expect(logger.sanitize('apikey=my-token'), contains('apikey=***'));
    });

    test('sk- key in text', () {
      expect(logger.sanitize('sk-abcdef1234567890abcdef12'), startsWith('sk-***'));
    });

    test('ds- key in text', () {
      expect(logger.sanitize('ds-abcdef1234567890'), startsWith('ds-***'));
    });

    test('Authorization header', () {
      expect(logger.sanitize('Authorization: Bearer sk-secret'), contains('Authorization=***'));
    });

    test('multiple sensitive patterns', () {
      final r = logger.sanitize('api_key=k1 and apikey=k2');
      expect(r, contains('api_key=***'));
      expect(r, contains('apikey=***'));
    });

    test('safe text unchanged', () {
      expect(logger.sanitize('Hello normal log'), 'Hello normal log');
    });

    test('mixed safe and sensitive', () {
      final r = logger.sanitize('Using token=ds-key-123 and doing work');
      expect(r, contains('token=***'));
      expect(r, contains('doing work'));
    });
  });
}
