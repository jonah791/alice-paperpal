import 'package:flutter_test/flutter_test.dart';
import 'package:paperwise/core/models/paper.dart';
import 'package:paperwise/core/models/parse_result.dart';
import 'package:paperwise/core/models/search_result.dart';
import 'package:paperwise/core/models/config.dart';
import 'package:paperwise/core/services/translation_service.dart';
import 'package:paperwise/core/api/llm_provider.dart';

void main() {
  group('Paper model', () {
    test('creates with defaults', () {
      final paper = Paper(id: 'test1', title: 'Test Paper');
      expect(paper.id, 'test1');
      expect(paper.title, 'Test Paper');
      expect(paper.authors, isEmpty);
      expect(paper.status, PaperStatus.importing);
    });

    test('copyWith updates fields', () {
      final paper = Paper(id: '1', title: 'Original');
      final updated = paper.copyWith(title: 'Updated', status: PaperStatus.parsed);
      expect(updated.title, 'Updated');
      expect(updated.status, PaperStatus.parsed);
      expect(updated.id, '1');
    });

    test('toJson and fromJson round-trip', () {
      final paper = Paper(
        id: 'test1',
        title: 'Test Paper',
        authors: ['Author A', 'Author B'],
        year: 2024,
        doi: '10.1234/test',
        status: PaperStatus.translated,
        pageCount: 15,
        importedAt: DateTime(2024, 1, 1),
        tags: ['AI', 'NLP'],
      );
      final json = paper.toJson();
      final restored = Paper.fromJson(json);
      expect(restored.id, paper.id);
      expect(restored.title, paper.title);
      expect(restored.authors, paper.authors);
      expect(restored.year, paper.year);
      expect(restored.doi, paper.doi);
      expect(restored.status, paper.status);
      expect(restored.pageCount, paper.pageCount);
      expect(restored.tags, paper.tags);
    });

    test('fromJson handles missing fields gracefully', () {
      final restored = Paper.fromJson({'id': '1', 'title': 'Test'});
      expect(restored.id, '1');
      expect(restored.authors, isEmpty);
      expect(restored.status, PaperStatus.importing);
    });
  });

  group('ParseResult', () {
    test('creates with required fields', () {
      final result = ParseResult(markdown: '# Hello');
      expect(result.markdown, '# Hello');
      expect(result.title, isEmpty);
      expect(result.imagePaths, isEmpty);
    });
  });

  group('SearchResult', () {
    test('creates with required fields', () {
      final result = SearchResult(title: 'Test', authors: ['A']);
      expect(result.title, 'Test');
      expect(result.authors, ['A']);
      expect(result.year, 0);
    });
  });

  group('AppConfig', () {
    test('has sensible defaults', () {
      final config = AppConfig();
      expect(config.defaultProvider, 'deepseek');
      expect(config.llmModel, 'deepseek-v4-flash');
      expect(config.llmApiBase, 'https://api.deepseek.com');
      expect(config.batchSize, 50);
      expect(config.fontSize, 16.0);
    });

    test('copyWith overrides fields', () {
      final config = AppConfig();
      final updated = config.copyWith(llmApiBase: 'https://custom.api.com', batchSize: 20);
      expect(updated.llmApiBase, 'https://custom.api.com');
      expect(updated.batchSize, 20);
    });
  });

  group('TranslationService language detection', () {
    test('detects Chinese', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.detectLanguage('这是一篇中文论文'), 'zh');
      expect(service.detectLanguage('研究结果表明该方法有效'), 'zh');
    });

    test('detects English', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.detectLanguage('This is an English paper'), 'en');
      expect(service.needsTranslation('This is English'), true);
    });

    test('does not need translation for Chinese', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.needsTranslation('这是一篇中文论文'), false);
    });

    test('handles empty text', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.detectLanguage(''), 'en');
    });
  });
}
