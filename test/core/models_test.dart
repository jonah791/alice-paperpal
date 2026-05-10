import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' as m;
import 'package:paperpal/core/models/paper.dart';
import 'package:paperpal/core/models/parse_result.dart';
import 'package:paperpal/core/models/search_result.dart';
import 'package:paperpal/core/models/config.dart';
import 'package:paperpal/core/models/app_error.dart';
import 'package:paperpal/core/services/translation_service.dart';
import 'package:paperpal/core/api/llm_provider.dart';

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

    test('copyWith does not mutate original', () {
      final paper = Paper(id: '1', title: 'Original', authors: ['A']);
      paper.copyWith(title: 'Changed', authors: ['B']);
      expect(paper.title, 'Original');
      expect(paper.authors, ['A']);
    });

    test('fromJson handles null dates', () {
      final restored = Paper.fromJson({
        'id': '1',
        'title': 'Test',
        'importedAt': null,
        'lastReadAt': null,
      });
      expect(restored.importedAt, isNull);
      expect(restored.lastReadAt, isNull);
    });

    test('fromJson handles invalid date strings', () {
      final restored = Paper.fromJson({
        'id': '1',
        'title': 'Test',
        'importedAt': 'not-a-date',
      });
      expect(restored.importedAt, isNull);
    });

    test('fromJson handles unknown status as importing', () {
      final restored = Paper.fromJson({
        'id': '1',
        'title': 'Test',
        'status': 'nonexistent_status',
      });
      expect(restored.status, PaperStatus.importing);
    });

    test('PaperStatus enum has all values', () {
      expect(PaperStatus.values, hasLength(7));
      expect(PaperStatus.importing, isA<PaperStatus>());
      expect(PaperStatus.downloading, isA<PaperStatus>());
      expect(PaperStatus.parsing, isA<PaperStatus>());
      expect(PaperStatus.parsed, isA<PaperStatus>());
      expect(PaperStatus.translating, isA<PaperStatus>());
      expect(PaperStatus.translated, isA<PaperStatus>());
      expect(PaperStatus.error, isA<PaperStatus>());
    });

    test('copyWith only changes specified fields', () {
      final paper = Paper(
        id: '1', title: 'T', authors: ['A'], year: 2020,
        source: 'arXiv', doi: '10.1234/ab', status: PaperStatus.parsed,
        pageCount: 10, tags: ['ML'],
      );
      final updated = paper.copyWith(title: 'New Title');
      expect(updated.title, 'New Title');
      expect(updated.authors, ['A']);
      expect(updated.year, 2020);
      expect(updated.source, 'arXiv');
      expect(updated.doi, '10.1234/ab');
      expect(updated.status, PaperStatus.parsed);
      expect(updated.pageCount, 10);
    });
  });

  group('ParseResult', () {
    test('creates with required fields', () {
      final result = ParseResult(markdown: '# Hello');
      expect(result.markdown, '# Hello');
      expect(result.title, isEmpty);
      expect(result.imagePaths, isEmpty);
    });

    test('creates with empty markdown', () {
      final result = ParseResult(markdown: '');
      expect(result.markdown, '');
      expect(result.contentListJson, '');
    });

    test('creates with all fields', () {
      final result = ParseResult(
        markdown: '# Title',
        title: 'Test Title',
        imagePaths: ['img1.png', 'img2.png'],
        contentListJson: '[]',
        startPage: 1,
        endPage: 10,
      );
      expect(result.title, 'Test Title');
      expect(result.imagePaths, hasLength(2));
      expect(result.startPage, 1);
      expect(result.endPage, 10);
    });
  });

  group('SearchResult', () {
    test('creates with required fields', () {
      final result = SearchResult(title: 'Test', authors: ['A']);
      expect(result.title, 'Test');
      expect(result.authors, ['A']);
      expect(result.year, 0);
    });

    test('creates with all fields', () {
      final result = SearchResult(
        title: 'Test',
        authors: ['A', 'B'],
        year: 2024,
        abstract: 'Abstract here',
        pdfUrl: 'https://example.com/paper.pdf',
        source: 'arXiv',
        doi: '10.1234/test',
        citationCount: 42,
      );
      expect(result.year, 2024);
      expect(result.abstract, 'Abstract here');
      expect(result.pdfUrl, 'https://example.com/paper.pdf');
      expect(result.source, 'arXiv');
      expect(result.doi, '10.1234/test');
      expect(result.citationCount, 42);
    });

    test('defaults to empty strings and zeros', () {
      final result = SearchResult(title: 'Only Title', authors: []);
      expect(result.abstract, '');
      expect(result.pdfUrl, '');
      expect(result.source, '');
      expect(result.doi, '');
      expect(result.citationCount, 0);
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

    test('copyWith preserves unset fields', () {
      final config = AppConfig(llmModel: 'gpt-4');
      final updated = config.copyWith(llmApiBase: 'https://other.api.com');
      expect(updated.llmModel, 'gpt-4');
      expect(updated.defaultProvider, 'deepseek');
      expect(updated.fontSize, 16.0);
    });

    test('all fields can be specified', () {
      final config = AppConfig(
        defaultProvider: 'openai',
        llmModel: 'gpt-4',
        llmApiBase: 'https://api.openai.com',
        mineruApiEndpoint: 'https://mineru.example.com',
        autoTranslate: false,
        forceDarkMode: true,
        themeMode: AppThemeMode.dark,
        fontSize: 20.0,
        batchSize: 100,
        logRetentionDays: 14,
      );
      expect(config.defaultProvider, 'openai');
      expect(config.forceDarkMode, true);
      expect(config.themeMode, AppThemeMode.dark);
      expect(config.logRetentionDays, 14);
    });
  });

  group('AppThemeMode', () {
    test('system maps to ThemeMode.system', () {
      expect(AppThemeMode.system.toFlutterThemeMode(), m.ThemeMode.system);
    });

    test('light maps to ThemeMode.light', () {
      expect(AppThemeMode.light.toFlutterThemeMode(), m.ThemeMode.light);
    });

    test('dark maps to ThemeMode.dark', () {
      expect(AppThemeMode.dark.toFlutterThemeMode(), m.ThemeMode.dark);
    });
  });

  group('AppError', () {
    test('network error has correct type and defaults', () {
      final err = AppError.network('connection lost');
      expect(err.type, 'network');
      expect(err.message, 'connection lost');
      expect(err.retryable, true);
      expect(err.statusCode, isNull);
    });

    test('network error with status code', () {
      final err = AppError.network('not found', statusCode: 404, retryable: false);
      expect(err.type, 'network');
      expect(err.statusCode, 404);
      expect(err.retryable, false);
    });

    test('api error formats code and message', () {
      final err = AppError.api('RATE_LIMIT', 'too many requests');
      expect(err.type, 'api');
      expect(err.message, 'RATE_LIMIT: too many requests');
      expect(err.retryable, false);
    });

    test('parse error tracks batch counts', () {
      final err = AppError.parse(2, 5);
      expect(err.type, 'parse');
      expect(err.message, '2/5 batches failed');
      expect(err.failedBatches, 2);
      expect(err.totalBatches, 5);
    });

    test('config error', () {
      final err = AppError.config('invalid key');
      expect(err.type, 'config');
      expect(err.message, 'invalid key');
    });

    test('unknown error', () {
      final err = AppError.unknown('something went wrong');
      expect(err.type, 'unknown');
      expect(err.message, 'something went wrong');
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

    test('detects Japanese', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.detectLanguage('これはテストです'), 'ja');
    });

    test('detects Korean', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.detectLanguage('이것은 한국어 논문입니다'), 'ko');
    });

    test('detects Russian', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.detectLanguage('Это русская статья'), 'ru');
    });

    test('falls back to English for mixed unknown script', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.detectLanguage(r'12345!@#$%'), 'en');
    });

    test('detects Chinese mixed with numbers', () {
      final service = TranslationService(
        LLMProvider(config: LLMConfig(
          type: LLMProviderType.deepseek,
          apiKey: 'test',
        )),
      );
      expect(service.detectLanguage('第1章 引言'), 'zh');
    });
  });
}
