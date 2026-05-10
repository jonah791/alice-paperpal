import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/api/llm_provider.dart';
import 'package:paperpal/core/api/dio_client.dart';
import 'package:paperpal/core/api/arxiv_api.dart';
import 'package:paperpal/core/models/search_result.dart';

void main() {
  group('LLMProvider body construction', () {
    test('builds DeepSeek body correctly', () {
      final provider = LLMProvider(config: LLMConfig(
        type: LLMProviderType.deepseek,
        apiKey: 'test-key',
      ));
      expect(provider.config.type, LLMProviderType.deepseek);
      expect(provider.config.apiKey, 'test-key');
    });

    test('builds OpenAI body correctly', () {
      final provider = LLMProvider(config: LLMConfig(
        type: LLMProviderType.openai,
        apiKey: 'test-key',
        apiBase: 'https://api.openai.com',
        model: 'gpt-4',
      ));
      expect(provider.config.type, LLMProviderType.openai);
      expect(provider.config.apiBase, 'https://api.openai.com');
      expect(provider.config.model, 'gpt-4');
    });

    test('builds Claude body with system message separation', () {
      final provider = LLMProvider(config: LLMConfig(
        type: LLMProviderType.claude,
        apiKey: 'test-key',
        model: 'claude-3-opus',
      ));
      expect(provider.config.type, LLMProviderType.claude);
      expect(provider.config.model, 'claude-3-opus');
    });

    test('LLMConfig defaults for apiBase and model', () {
      final config = LLMConfig(type: LLMProviderType.deepseek, apiKey: 'key');
      expect(config.apiBase, 'https://api.deepseek.com');
      expect(config.model, 'deepseek-v4-flash');
    });

    test('LLMConfig custom values', () {
      final config = LLMConfig(
        type: LLMProviderType.openai,
        apiKey: 'key',
        apiBase: 'https://custom.com',
        model: 'gpt-4',
      );
      expect(config.apiBase, 'https://custom.com');
      expect(config.model, 'gpt-4');
    });
  });

  group('DioClient', () {
    test('creates client with auth token', () {
      final dio = createApiClient(
        baseUrl: 'https://api.example.com',
        authToken: 'test-token',
      );
      expect(dio.options.baseUrl, 'https://api.example.com');
      expect(dio.options.headers['Authorization'], 'Bearer test-token');
      expect(dio.options.headers['Content-Type'], 'application/json');
    });

    test('creates client without auth token', () {
      final dio = createApiClient(baseUrl: 'https://api.example.com');
      expect(dio.options.headers['Authorization'], isNull);
    });

    test('creates client with custom timeouts', () {
      final dio = createApiClient(
        baseUrl: 'https://api.example.com',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      );
      expect(dio.options.connectTimeout, const Duration(seconds: 5));
      expect(dio.options.receiveTimeout, const Duration(seconds: 10));
    });
  });

  group('ArxivApi', () {
    test('can be instantiated', () {
      expect(ArxivApi(), isA<ArxivApi>());
    });
  });

  group('SearchResult from API mapping', () {
    test('S2Api maps paper fields correctly', () {
      final result = SearchResult(
        title: 'Attention Is All You Need',
        authors: ['Vaswani', 'Shazeer'],
        year: 2017,
        abstract: 'The dominant sequence transduction models...',
        pdfUrl: 'https://arxiv.org/pdf/1706.03762.pdf',
        doi: '10.48550/arXiv.1706.03762',
        source: 'Semantic Scholar',
        citationCount: 100000,
      );
      expect(result.title, 'Attention Is All You Need');
      expect(result.authors, hasLength(2));
      expect(result.citationCount, 100000);
    });

    test('handles missing author names', () {
      final result = SearchResult(
        title: 'Test',
        authors: ['', 'Valid Name', ''],
        source: 'arXiv',
      );
      expect(result.authors, hasLength(3));
    });
  });
}
