import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import '../api/mineru_api.dart';
import '../models/parse_result.dart';
import '../interfaces/services.dart';

final _log = Logger('ParseService');

class ParseService {
  final IMineruApi _api;

  ParseService({required IMineruApi api}) : _api = api;

  final _progressController = StreamController<ParseProgress>.broadcast();
  Stream<ParseProgress> get progressStream => _progressController.stream;

  static const int maxPagesPerTask = 200;

  Future<ParseResult> parsePdf(File pdfFile, int pageCount) async {
    final ranges = buildPageRanges(pageCount);

    if (ranges.isEmpty) {
      _log.info('parsePdf: single task, $pageCount pages');
      _progressController.add(ParseProgress(
        currentBatch: 1, totalBatches: 1,
        currentPage: 0, totalPages: pageCount,
      ));
      final result = await _api.parseFile(pdfFile);
      final title = pdfFile.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
      return ParseResult(
        markdown: result.markdown,
        title: title,
        imagePaths: result.imagePaths,
        contentListJson: result.contentListJson,
        startPage: 0,
        endPage: pageCount - 1,
      );
    }

    _log.info('parsePdf: splitting into ${ranges.length} tasks, $pageCount pages');
    final batchMarkdowns = <String>[];
    final allImagePaths = <String>[];
    var mergedContentJson = '';
    var mergedStartPage = 0;
    var mergedEndPage = 0;

    for (var i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      _progressController.add(ParseProgress(
        currentBatch: i + 1,
        totalBatches: ranges.length,
        currentPage: range.start,
        totalPages: pageCount,
      ));

      try {
        final result = await _api.parseFile(
          pdfFile,
          pageRanges: '${range.start + 1}-${range.end + 1}',
        );
        batchMarkdowns.add(result.markdown);
        allImagePaths.addAll(result.imagePaths);
        if (result.contentListJson.isNotEmpty) {
          mergedContentJson = result.contentListJson;
        }
        if (i == 0) mergedStartPage = range.start;
        mergedEndPage = range.end;
        _log.info('parsePdf: batch ${i + 1}/${ranges.length} OK, ${result.markdown.length} chars');
      } catch (e) {
        _log.warning('parsePdf: batch ${i + 1}/${ranges.length} failed: $e');
        rethrow;
      }
    }

    final merged = MergeService.merge(batchMarkdowns);
    _log.info('parsePdf: ${ranges.length} tasks merged successfully');
    return ParseResult(
      markdown: merged.markdown,
      title: merged.title,
      imagePaths: allImagePaths,
      contentListJson: mergedContentJson,
      startPage: mergedStartPage,
      endPage: mergedEndPage,
    );
  }

  List<PageRange> buildPageRanges(int totalPages) {
    if (totalPages <= maxPagesPerTask) return [];
    final ranges = <PageRange>[];
    for (var start = 0; start < totalPages; start += maxPagesPerTask) {
      var end = start + maxPagesPerTask - 1;
      if (end >= totalPages) end = totalPages - 1;
      ranges.add(PageRange(start, end));
    }
    return ranges;
  }

  void dispose() {
    _progressController.close();
  }
}

class PageRange {
  final int start;
  final int end;
  const PageRange(this.start, this.end);
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
