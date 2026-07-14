import 'dart:io';

import 'package:logging/logging.dart';
import 'package:dio/dio.dart';

import '../models/search_result.dart';
import '../interfaces/services.dart';
import '../api/arxiv_api.dart';
import '../api/s2_api.dart';

final _log = Logger('SearchService');

class SearchService implements ISearchService {
  final ArxivApi _arxiv;
  final S2Api _s2;

  SearchService({ArxivApi? arxiv, S2Api? s2})
      : _arxiv = arxiv ?? ArxivApi(),
        _s2 = s2 ?? S2Api();

  Future<(List<SearchResult>, String?)> search(String query) async {
    if (query.trim().isEmpty) return (<SearchResult>[], null);

    try {
      final results = await Future.wait([
        _arxiv.search(query),
        _s2.search(query),
      ]);

      final all = <String, SearchResult>{};
      for (final r in results.expand((x) => x)) {
        final key = r.doi.isNotEmpty ? r.doi : r.title.toLowerCase();
        if (!all.containsKey(key)) {
          all[key] = r;
        } else {
          final existing = all[key]!;
          final existingHasPdf = existing.pdfUrl.isNotEmpty;
          final newHasPdf = r.pdfUrl.isNotEmpty;
          if (!existingHasPdf && newHasPdf) {
            all[key] = r;
          } else if (existingHasPdf == newHasPdf && existing.source == 'arXiv') {
            all[key] = r;
          }
        }
      }

      final sorted = all.values.toList()
        ..sort((a, b) => b.year.compareTo(a.year));

      _log.info('search: "$query" → ${sorted.length} results (merged)');
      return (sorted, null);
    } catch (e) {
      _log.warning('search failed: "$query" → $e');
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          return (<SearchResult>[], '请求超时，请检查网络后重试');
        }
        return (<SearchResult>[], '网络请求失败，请检查网络连接');
      }
      return (<SearchResult>[], '搜索出错，请稍后重试');
    }
  }

  Future<File?> downloadPdf(SearchResult result, String saveDir, {void Function(int, int)? onProgress}) async {
    if (result.pdfUrl.isEmpty) return null;

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          'User-Agent': 'PaperPal/0.1.1 (Academic Paper Reader; mailto:paperpal@alice.app)',
        },
      ));

      final safeName = result.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final safeTruncated = safeName.substring(0, safeName.length.clamp(1, 80));
      final savePath = '$saveDir/$safeTruncated.pdf';
      final dir = Directory(saveDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      await dio.download(
        result.pdfUrl,
        savePath,
        onReceiveProgress: onProgress,
      );

      // Verify it looks like a real PDF, not an HTML error page
      final file = File(savePath);
      if (await file.exists()) {
        final header = await file.readAsBytes();
        if (header.length < 4 || header[0] != 0x25 || header[1] != 0x50 || header[2] != 0x44 || header[3] != 0x46) {
          await file.delete();
          _log.warning('downloadPdf: not a valid PDF: ${result.title}');
          return null;
        }
      }

      _log.info('downloadPdf: ${result.title} → $savePath');
      return File(savePath);
    } catch (e) {
      _log.warning('downloadPdf failed: ${result.title} → $e');
      return null;
    }
  }
}
