import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import '../api/mineru_api.dart';
import '../models/parse_result.dart';


final _log = Logger('ParseService');

class ParseService {
  final MineruApi _api;
  final int _batchSize;

  ParseService({required MineruApi api, int batchSize = 50})
      : _api = api,
        _batchSize = batchSize;

  final _progressController = StreamController<ParseProgress>.broadcast();
  Stream<ParseProgress> get progressStream => _progressController.stream;

  Future<ParseResult> parsePdf(File pdfFile, int pageCount) async {
    if (pageCount <= _batchSize) {
      _log.info('parsePdf: single batch, $pageCount pages');
      final result = await _api.parsePdf(pdfFile: pdfFile);
      return ParseResult(
        markdown: result,
        title: pdfFile.path.split(Platform.pathSeparator).last.replaceAll('.pdf', ''),
        startPage: 0,
        endPage: pageCount - 1,
      );
    }

    _log.info('parsePdf: splitting into batches of $_batchSize, total $pageCount pages');
    final totalBatches = (pageCount / _batchSize).ceil();
    final batchResults = <String>[];

    for (var i = 0; i < totalBatches; i++) {
      final start = i * _batchSize;
      var end = start + _batchSize - 1;
      if (end >= pageCount) end = pageCount - 1;

      _progressController.add(ParseProgress(
        currentBatch: i + 1,
        totalBatches: totalBatches,
        currentPage: start,
        totalPages: pageCount,
      ));

      try {
        final result = await _api.parsePdf(
          pdfFile: pdfFile,
          startPage: start,
          endPage: end,
        );
        batchResults.add(result);
        _log.info('parsePdf: batch ${i + 1}/$totalBatches OK');
      } catch (e) {
        _log.warning('parsePdf: batch ${i + 1}/$totalBatches failed: $e');
        rethrow;
      }
    }

    final merged = MergeService.merge(batchResults);
    _log.info('parsePdf: $totalBatches batches merged successfully');
    return merged;
  }

  void dispose() {
    _progressController.close();
  }
}

class MergeService {
  static ParseResult merge(List<String> batches) {
    final buffer = StringBuffer();
    var title = '';

    for (var i = 0; i < batches.length; i++) {
      if (i > 0) {
        buffer.write('\n\n<!-- batch-break -->\n\n');
      }
      buffer.write(batches[i]);

      if (title.isEmpty) {
        final lines = batches[i].split('\n');
        for (final line in lines) {
          if (line.startsWith('# ') && line.length > 2) {
            title = line.substring(2).trim();
            break;
          }
        }
      }
    }

    return ParseResult(
      markdown: buffer.toString(),
      title: title,
      startPage: 0,
      endPage: 0,
    );
  }
}
