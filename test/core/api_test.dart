import 'package:flutter_test/flutter_test.dart';
import 'package:paperpal/core/api/llm_provider.dart';
import 'package:paperpal/core/api/dio_client.dart';
import 'package:paperpal/core/api/arxiv_api.dart';
import 'package:paperpal/core/models/search_result.dart';

void main() {
  group('LLMConfig', () {
    test('deepseek defaults', () {
      const c = LLMConfig(type: LLMProviderType.deepseek, apiKey: 'k');
      expect(c.apiBase, 'https://api.deepseek.com');
      expect(c.model, 'deepseek-v4-flash');
    });

    test('openai custom', () {
      const c = LLMConfig(type: LLMProviderType.openai, apiKey: 'k', apiBase: 'https://o.c', model: 'gpt-4');
      expect(c.apiBase, 'https://o.c');
      expect(c.model, 'gpt-4');
    });

    test('claude config', () {
      const c = LLMConfig(type: LLMProviderType.claude, apiKey: 'k', model: 'claude-3-opus');
      expect(c.type, LLMProviderType.claude);
      // Default apiBase is deepseek — Claude users must set apiBase explicitly to https://api.anthropic.com
      expect(c.apiBase, 'https://api.deepseek.com');
    });
  });

  group('DioClient', () {
    test('with auth token', () {
      final d = createApiClient(baseUrl: 'https://api.x.com', authToken: 't');
      expect(d.options.baseUrl, 'https://api.x.com');
      expect(d.options.headers['Authorization'], 'Bearer t');
      expect(d.options.headers['Content-Type'], 'application/json');
    });

    test('without auth token', () {
      final d = createApiClient(baseUrl: 'https://api.x.com');
      expect(d.options.headers['Authorization'], isNull);
    });

    test('custom timeouts', () {
      final d = createApiClient(baseUrl: 'https://api.x.com', connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 10));
      expect(d.options.connectTimeout, const Duration(seconds: 5));
      expect(d.options.receiveTimeout, const Duration(seconds: 10));
    });
  });

  group('ArxivApi XML parsing', () {
    final api = ArxivApi();

    test('parseXml empty XML returns empty', () {
      expect(api.parseXml('<?xml?><feed></feed>'), isEmpty);
    });

    test('parseXml no entries returns empty', () {
      expect(api.parseXml('<feed><title>X</title></feed>'), isEmpty);
    });

    test('parseXml single entry', () {
      const xml = '<feed><entry>'
          '<title>  My Paper  </title>'
          '<author><name>Alice Doe</name></author>'
          '<author><name>Bob Smith</name></author>'
          '<published>2024-03-15</published>'
          '<summary>This is an interesting abstract.</summary>'
          '<link title="pdf" href="https://arxiv.org/pdf/2401.00001.pdf"/>'
          '<arxiv:doi>10.1234/paper</arxiv:doi>'
          '</entry></feed>';
      final results = api.parseXml(xml);
      expect(results, hasLength(1));
      expect(results[0].title, 'My Paper');
      expect(results[0].authors, ['Alice Doe', 'Bob Smith']);
      expect(results[0].year, 2024);
      expect(results[0].abstract, 'This is an interesting abstract.');
      expect(results[0].pdfUrl, 'https://arxiv.org/pdf/2401.00001.pdf');
      expect(results[0].doi, '10.1234/paper');
      expect(results[0].source, 'arXiv');
    });

    test('parseXml multiple entries', () {
      const xml = '<feed>'
          '<entry><title>Paper A</title><author><name>Author A</name></author><published>2024</published><summary>Abs A</summary></entry>'
          '<entry><title>Paper B</title><author><name>Author B</name></author><published>2023</published><summary>Abs B</summary></entry>'
          '</feed>';
      expect(api.parseXml(xml), hasLength(2));
    });

    test('parseXml missing optional fields', () {
      const xml = '<feed><entry><title>T</title><author><name>A</name></author></entry></feed>';
      final results = api.parseXml(xml);
      expect(results, hasLength(1));
      expect(results[0].year, 0);
      expect(results[0].pdfUrl, '');
      expect(results[0].doi, '');
    });

    test('parseXml malformed entry creates result with empty title', () {
      const xml = '<feed><entry><title>Good</title><author><name>A</name></author></entry><entry>bad</entry></feed>';
      final results = api.parseXml(xml);
      expect(results, hasLength(2));
      expect(results[0].title, 'Good');
      expect(results[1].title, '');
    });

    test('extractTag', () {
      expect(api.extractTag('<title>Hello</title>', 'title'), 'Hello');
    });

    test('extractTag missing', () {
      expect(api.extractTag('<body>X</body>', 'title'), '');
    });

    test('extractTag unclosed', () {
      expect(api.extractTag('<title>Hello', 'title'), '');
    });

    test('extractPdfLink', () {
      const xml = '<link title="pdf" href="https://arxiv.org/pdf/2401.00001.pdf"/>';
      expect(api.extractPdfLink(xml), 'https://arxiv.org/pdf/2401.00001.pdf');
    });

    test('extractPdfLink missing', () {
      expect(api.extractPdfLink('<link href="other"/>'), '');
    });

    test('extractDoi', () {
      expect(api.extractDoi('<arxiv:doi>10.1234/test</arxiv:doi>'), '10.1234/test');
    });

    test('extractDoi missing', () {
      expect(api.extractDoi('<body>X</body>'), '');
    });

    test('extractAuthors', () {
      const xml = '<author><name>Alice</name></author><author><name>Bob</name></author>';
      expect(api.extractAuthors(xml), ['Alice', 'Bob']);
    });

    test('extractAuthors empty', () {
      expect(api.extractAuthors('<body>X</body>'), isEmpty);
    });

    test('abstract truncated at 500 chars', () {
      final longSummary = 'A' * 600;
      final xml = '<feed><entry><title>T</title><author><name>A</name></author><published>2024</published><summary>$longSummary</summary></entry></feed>';
      final results = api.parseXml(xml);
      expect(results[0].abstract, endsWith('...'));
      expect(results[0].abstract.length, 503);
    });
  });

  group('SearchResult from API mapping', () {
    test('full S2-like result', () {
      const r = SearchResult(
        title: 'Attention Is All You Need', authors: ['Vaswani', 'Shazeer'],
        year: 2017, abstract: 'abstract here',
        pdfUrl: 'https://arxiv.org/pdf/1706.03762.pdf',
        doi: '10.48550/arXiv.1706.03762', source: 'Semantic Scholar',
        citationCount: 100000,
      );
      expect(r.citationCount, 100000);
    });

    test('authors stored verbatim with empty strings unfiltered', () {
      const r = SearchResult(title: 'T', authors: ['', 'Valid', ''], source: 'arXiv');
      expect(r.authors, ['', 'Valid', '']);
    });

    test('zero citation count', () {
      const r = SearchResult(title: 'T', authors: ['A']);
      expect(r.citationCount, 0);
    });
  });
}
