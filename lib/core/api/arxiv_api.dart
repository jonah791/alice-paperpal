import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import '../models/search_result.dart';

final _log = Logger('ArxivApi');

class ArxivApi {
  final Dio _dio;

  ArxivApi() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static const _baseUrl = 'http://export.arxiv.org/api/query';

  Future<List<SearchResult>> search(String query, {int maxResults = 10}) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'search_query': 'all:$query',
          'start': 0,
          'max_results': maxResults,
          'sortBy': 'relevance',
          'sortOrder': 'descending',
        },
      );

      final xml = response.data as String;
      final results = parseXml(xml);
      _log.info('search: "$query" → ${results.length} results from arXiv');
      return results;
    } on DioException catch (e) {
      _log.warning('search failed: "$query" → ${e.message}');
      return [];
    }
  }

  List<SearchResult> parseXml(String xml) {
    final results = <SearchResult>[];
    final entries = xml.split('<entry>');
    if (entries.length <= 1) return results;

    for (var i = 1; i < entries.length; i++) {
      final entry = entries[i];
      try {
        final title = extractTag(entry, 'title').replaceAll('\n  ', '').trim();
        final summary = extractTag(entry, 'summary').replaceAll('\n', ' ').trim();
        final published = extractTag(entry, 'published');
        final pdfLink = extractPdfLink(entry);
        final doi = extractDoi(entry);
        final authors = extractAuthors(entry);

        final year = published.isNotEmpty
            ? int.tryParse(published.substring(0, 4)) ?? 0
            : 0;

        results.add(SearchResult(
          title: title,
          authors: authors,
          year: year,
          abstract: summary.length > 500
              ? '${summary.substring(0, 500)}...'
              : summary,
          pdfUrl: pdfLink,
          doi: doi,
          source: 'arXiv',
        ));
      } catch (e) {
        continue;
      }
    }
    return results;
  }

  String extractTag(String xml, String tag) {
    final start = xml.indexOf('<$tag>');
    if (start == -1) return '';
    final end = xml.indexOf('</$tag>', start);
    if (end == -1) return '';
    return xml.substring(start + tag.length + 2, end);
  }

  String extractPdfLink(String xml) {
    final pattern = RegExp(r'<link[^>]*title="pdf"[^>]*href="([^"]+)"');
    final match = pattern.firstMatch(xml);
    return match?.group(1) ?? '';
  }

  String extractDoi(String xml) {
    final pattern = RegExp(r'<arxiv:doi[^>]*>([^<]+)</arxiv:doi>');
    final match = pattern.firstMatch(xml);
    return match?.group(1) ?? '';
  }

  List<String> extractAuthors(String xml) {
    final authors = <String>[];
    final namePattern = RegExp(r'<name>([^<]+)</name>');
    final matches = namePattern.allMatches(xml);
    for (final m in matches) {
      authors.add(m.group(1)!);
    }
    return authors;
  }
}
