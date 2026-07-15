import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import '../models/search_result.dart';

final _log = Logger('ZoteroApi');

class ZoteroApi {
  final Dio _dio;
  final String userId;

  ZoteroApi({required String apiKey, required this.userId})
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.zotero.org',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Zotero-API-Key': apiKey,
            'Content-Type': 'application/json',
          },
        ));

  Future<List<SearchResult>> listItems({int limit = 50, int start = 0}) async {
    try {
      final response = await _dio.get('/users/$userId/items/top', queryParameters: {
        'limit': limit,
        'start': start,
        'itemType': 'journalArticle || preprint || conferencePaper || bookSection || thesis',
      });
      final data = response.data as List;
      return data.map((item) {
        final d = item['data'] as Map<String, dynamic>;
        final creators = (d['creators'] as List?) ?? [];
        final authors = creators.map((c) {
          final name = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
          return name.isNotEmpty ? name : (c['name'] as String? ?? '');
        }).where((n) => n.isNotEmpty).toList();

        return SearchResult(
          title: d['title'] as String? ?? '',
          authors: authors,
          year: _parseYear(d['date'] as String? ?? ''),
          abstract: d['abstractNote'] as String? ?? '',
          pdfUrl: d['url'] as String? ?? '',
          doi: d['DOI'] as String? ?? '',
          source: 'zotero',
        );
      }).toList();
    } on DioException catch (e) {
      _log.warning('Zotero listItems failed: ${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  int _parseYear(String date) {
    final match = RegExp(r'(\d{4})').firstMatch(date);
    return match != null ? int.parse(match.group(1)!) : 0;
  }
}

Future<ZoteroApi?> createZoteroApi() {
  try {
    final key = Platform.environment['ZOTERO_API_KEY'] ?? '';
    final uid = Platform.environment['ZOTERO_USER_ID'] ?? '';
    if (key.isEmpty || uid.isEmpty) return Future.value(null);
    return Future.value(ZoteroApi(apiKey: key, userId: uid));
  } catch (_) {
    return Future.value(null);
  }
}
