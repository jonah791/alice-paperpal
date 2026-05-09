import 'dart:io';

import 'package:logging/logging.dart';
import 'package:dio/dio.dart';

import '../models/search_result.dart';
import '../api/arxiv_api.dart';
import '../api/s2_api.dart';

final _log = Logger('SearchService');

class SearchService {
  final ArxivApi _arxiv;
  final S2Api _s2;

  SearchService({ArxivApi? arxiv, S2Api? s2})
      : _arxiv = arxiv ?? ArxivApi(),
        _s2 = s2 ?? S2Api();

  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final results = await Future.wait([
        _arxiv.search(query),
        _s2.search(query),
      ]);

      final all = <String, SearchResult>{};
      for (final r in results.expand((x) => x)) {
        final key = r.doi.isNotEmpty ? r.doi : r.title.toLowerCase();
        if (!all.containsKey(key) || all[key]!.source == 'arXiv') {
          all[key] = r;
        }
      }

      final sorted = all.values.toList()
        ..sort((a, b) => b.year.compareTo(a.year));

      _log.info('search: "$query" → ${sorted.length} results (merged)');
      return sorted;
    } catch (e) {
      _log.warning('search failed: "$query" → $e');
      return [];
    }
  }

  Future<File?> downloadPdf(SearchResult result, String saveDir) async {
    if (result.pdfUrl.isEmpty) return null;

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ));

      final safeName = result.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .substring(0, result.title.length.clamp(1, 80));
      final savePath = '$saveDir/$safeName.pdf';
      final dir = Directory(saveDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      await dio.download(result.pdfUrl, savePath);
      _log.info('downloadPdf: ${result.title} → $savePath');
      return File(savePath);
    } catch (e) {
      _log.warning('downloadPdf failed: ${result.title} → $e');
      return null;
    }
  }
}
