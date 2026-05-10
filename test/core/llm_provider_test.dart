import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/api/llm_provider.dart';
import 'package:paperpal/core/api/dio_client.dart';
import 'package:dio/dio.dart';

void main() {
  group('LLMProvider HttpsInterceptor', () {
    test('rejects http scheme for non-localhost', () {
      final interceptor = HttpsInterceptor();
      final options = RequestOptions(
        path: '/v1/chat/completions',
        baseUrl: 'http://api.openai.com',
      );
      var rejected = false;
      interceptor.onRequest(options, _makeHandler(
        onNext: (_) => fail('should not call next'),
        onReject: (e) {
          rejected = true;
          expect(e.type, DioExceptionType.connectionError);
          expect((e.error as String), contains('HTTPS'));
        },
      ));
      expect(rejected, true);
    });

    test('allows https scheme', () {
      var called = false;
      final interceptor = HttpsInterceptor();
      final options = RequestOptions(
        path: '/v1/chat/completions',
        baseUrl: 'https://api.deepseek.com',
      );
      interceptor.onRequest(options, _makeHandler(
        onNext: (_) => called = true,
        onReject: (_) => fail('should not reject'),
      ));
      expect(called, true);
    });

    test('allows http on localhost', () {
      var called = false;
      final interceptor = HttpsInterceptor();
      final options = RequestOptions(
        path: '/v1/chat/completions',
        baseUrl: 'http://localhost:11434',
      );
      interceptor.onRequest(options, _makeHandler(
        onNext: (_) => called = true,
        onReject: (_) => fail('should not reject'),
      ));
      expect(called, true);
    });

    test('rejects http on 127.0.0.1 (no localhost in host)', () {
      var called = false;
      final interceptor = HttpsInterceptor();
      final options = RequestOptions(
        path: '/api/tags',
        baseUrl: 'http://127.0.0.1:8080',
      );
      interceptor.onRequest(options, _makeHandler(
        onNext: (_) => called = true,
        onReject: (_) {},
      ));
      expect(called, false);
    });

    test('allows https on any host', () {
      var called = false;
      final interceptor = HttpsInterceptor();
      final options = RequestOptions(
        path: '/test',
        baseUrl: 'https://192.168.1.1:9999',
      );
      interceptor.onRequest(options, _makeHandler(
        onNext: (_) => called = true,
        onReject: (_) => fail('should not reject'),
      ));
      expect(called, true);
    });
  });

  group('LLMProvider.endpoint', () {
    test('deepseek uses /v1/chat/completions', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k'));
      expect(p.endpoint, '/v1/chat/completions');
    });

    test('openai uses /v1/chat/completions', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.openai, apiKey: 'k'));
      expect(p.endpoint, '/v1/chat/completions');
    });

    test('claude uses /v1/messages', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      expect(p.endpoint, '/v1/messages');
    });
  });

  group('LLMProvider.buildClaudeBody', () {
    test('converts system messages to top-level system param', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k', model: 'claude-3-opus'));
      final body = p.buildClaudeBody([
        {'role': 'system', 'content': 'You are helpful.'},
        {'role': 'user', 'content': 'Hello'},
      ]);
      expect(body['system'], 'You are helpful.');
      expect(body['model'], 'claude-3-opus');
      expect(body['messages'], hasLength(1));
      expect(body['messages'][0]['role'], 'user');
      expect(body['messages'][0]['content'], 'Hello');
    });

    test('converts assistant role correctly', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final body = p.buildClaudeBody([
        {'role': 'system', 'content': 'You are helpful.'},
        {'role': 'user', 'content': 'Q'},
        {'role': 'assistant', 'content': 'A'},
      ]);
      expect(body['messages'], hasLength(2));
      expect(body['messages'][0]['role'], 'user');
      expect(body['messages'][1]['role'], 'assistant');
    });

    test('handles missing system message', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final body = p.buildClaudeBody([
        {'role': 'user', 'content': 'Hello'},
      ]);
      expect(body.containsKey('system'), false);
      expect(body['messages'], hasLength(1));
    });

    test('handles multiple system messages (takes last)', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final body = p.buildClaudeBody([
        {'role': 'system', 'content': 'First'},
        {'role': 'system', 'content': 'Second'},
        {'role': 'user', 'content': 'Hello'},
      ]);
      expect(body['system'], 'Second');
    });

    test('respects maxTokens parameter', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final body = p.buildClaudeBody([
        {'role': 'user', 'content': 'Hello'},
      ], maxTokens: 1024);
      expect(body['max_tokens'], 1024);
    });

    test('defaults maxTokens to 4096', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final body = p.buildClaudeBody([
        {'role': 'user', 'content': 'Hello'},
      ]);
      expect(body['max_tokens'], 4096);
    });

    test('handles empty content in messages', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final body = p.buildClaudeBody([
        {'role': 'user', 'content': ''},
      ]);
      expect(body['messages'][0]['content'], '');
    });
  });

  group('LLMProvider.buildBody (OpenAI/DeepSeek format)', () {
    test('deepseek format includes model and messages', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k', model: 'deepseek-v4-flash'));
      final body = p.buildBody([
        {'role': 'system', 'content': 'Prompt'},
        {'role': 'user', 'content': 'Hello'},
      ]);
      expect(body['model'], 'deepseek-v4-flash');
      expect(body['messages'], hasLength(2));
      expect(body['max_tokens'], 4096);
    });

    test('openai format preserves system message in array', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.openai, apiKey: 'k'));
      final body = p.buildBody([
        {'role': 'system', 'content': 'Prompt'},
        {'role': 'user', 'content': 'Hello'},
      ]);
      expect(body['messages'][0]['role'], 'system');
      expect(body['messages'][0]['content'], 'Prompt');
    });

    test('respects custom maxTokens', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k'));
      final body = p.buildBody([
        {'role': 'user', 'content': 'Hello'},
      ], maxTokens: 100);
      expect(body['max_tokens'], 100);
    });
  });

  group('LLMProvider.extractContent', () {
    test('deepseek/openai format extracts content', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k'));
      final data = {
        'choices': [
          {'message': {'content': 'Hello, world!'}},
        ],
      };
      expect(p.extractContent(data), 'Hello, world!');
    });

    test('deepseek format with empty choices returns empty', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.openai, apiKey: 'k'));
      final data = {'choices': []};
      expect(p.extractContent(data), '');
    });

    test('deepseek format with null content returns empty', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k'));
      final data = {
        'choices': [{'message': {}}],
      };
      expect(p.extractContent(data), '');
    });

    test('claude format extracts text from content array', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final data = {
        'content': [
          {'type': 'text', 'text': 'Claude response'},
        ],
      };
      expect(p.extractContent(data), 'Claude response');
    });

    test('claude format with empty content array returns empty', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final data = {'content': []};
      expect(p.extractContent(data), '');
    });

    test('claude format with missing content key returns empty', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.claude, apiKey: 'k'));
      final data = <String, dynamic>{};
      expect(p.extractContent(data), '');
    });

    test('deepseek format with missing choices key returns empty', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k'));
      final data = <String, dynamic>{};
      expect(p.extractContent(data), '');
    });

    test('multiple choices extracts first content', () {
      final p = LLMProvider(config: LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k'));
      final data = {
        'choices': [
          {'message': {'content': 'First choice'}},
          {'message': {'content': 'Second choice'}},
        ],
      };
      expect(p.extractContent(data), 'First choice');
    });
  });

  group('LLMProviderType', () {
    test('has 3 values', () {
      expect(LLMProviderType.values.length, 3);
      expect(LLMProviderType.values, [
        LLMProviderType.deepseek,
        LLMProviderType.openai,
        LLMProviderType.claude,
      ]);
    });
  });

  group('LLMConfig', () {
    test('deepseek defaults model to deepseek-v4-flash', () {
      final c = LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k');
      expect(c.model, 'deepseek-v4-flash');
    });

    test('openai defaults apiBase to deepseek', () {
      final c = LLMConfig(type: LLMProviderType.openai, apiKey: 'k');
      expect(c.apiBase, 'https://api.deepseek.com');
    });

    test('all custom fields', () {
      final c = LLMConfig(
        type: LLMProviderType.claude,
        apiKey: 'sk-ant-key',
        apiBase: 'https://api.anthropic.com',
        model: 'claude-3-5-sonnet',
      );
      expect(c.type, LLMProviderType.claude);
      expect(c.apiKey, 'sk-ant-key');
      expect(c.apiBase, 'https://api.anthropic.com');
      expect(c.model, 'claude-3-5-sonnet');
    });
  });

  group('DioClient DioHttpsInterceptor', () {
    test('rejects http non-localhost', () {
      final interceptor = DioHttpsInterceptor();
      final options = RequestOptions(
        path: '/test',
        baseUrl: 'http://mineru.net',
      );
      var rejected = false;
      interceptor.onRequest(options, _makeHandler(
        onNext: (_) => fail('should reject'),
        onReject: (e) {
          rejected = true;
          expect(e.error, 'HTTPS is required for security');
        },
      ));
      expect(rejected, true);
    });

    test('allows https production URI', () {
      var called = false;
      final interceptor = DioHttpsInterceptor();
      final options = RequestOptions(
        path: '/api/v4/extract/task',
        baseUrl: 'https://mineru.net',
      );
      interceptor.onRequest(options, _makeHandler(
        onNext: (_) => called = true,
        onReject: (_) => fail('should not reject'),
      ));
      expect(called, true);
    });

    test('allows localhost http', () {
      var called = false;
      final interceptor = DioHttpsInterceptor();
      final options = RequestOptions(
        path: '/v1/chat/completions',
        baseUrl: 'http://localhost:1234',
      );
      interceptor.onRequest(options, _makeHandler(
        onNext: (_) => called = true,
        onReject: (_) => fail('should not reject'),
      ));
      expect(called, true);
    });
  });

  group('LLMProvider constructor', () {
    test('sets up config correctly', () {
      final p = LLMProvider(config: LLMConfig(
        type: LLMProviderType.deepseek,
        apiKey: 'sk-test',
        apiBase: 'https://custom.api.com',
      ));
      expect(p.config.apiKey, 'sk-test');
      expect(p.config.apiBase, 'https://custom.api.com');
    });
  });
}

RequestInterceptorHandler _makeHandler({
  void Function(RequestOptions options)? onNext,
  void Function(DioException error)? onReject,
}) {
  return _SimpleHandler(onNext: onNext, onReject: onReject);
}

class _SimpleHandler extends RequestInterceptorHandler {
  final void Function(RequestOptions options)? onNext;
  final void Function(DioException error)? onReject;

  _SimpleHandler({this.onNext, this.onReject});

  @override
  void next(RequestOptions options) => onNext?.call(options);

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) =>
      onReject?.call(error);

  @override
  void resolve(Response<dynamic> response, [bool callFollowingResponseInterceptor = false]) {}
}
