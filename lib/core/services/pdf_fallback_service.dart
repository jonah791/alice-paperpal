import 'dart:io';

import 'package:logging/logging.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/parse_result.dart';

final _log = Logger('PdfFallbackService');

class PdfFallbackService {
  Future<ParseResult> parseAsText(File pdfFile, int pageCount) async {
    if (await _hasPoppler()) {
      try {
        final result = await _parseWithPoppler(pdfFile);
        _log.info('poppler fallback OK: ${result.markdown.length} chars');
        return result;
      } catch (e) {
        _log.warning('poppler failed: $e');
      }
    }

    try {
      final result = parseWithFlutterPdf(pdfFile);
      _log.info('flutter_pdf fallback OK: ${result.markdown.length} chars');
      return result;
    } catch (e) {
      _log.warning('flutter_pdf failed: $e');
    }

    final name = pdfFile.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
    _log.info('metadata-only fallback: $name');
    return ParseResult(
      markdown: '# $name\n\n*无法解析此 PDF 的内容。*',
      title: name,
      sourceType: 'fallback_raw',
    );
  }

  Future<bool> _hasPoppler() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['pdftotext']);
        return result.exitCode == 0;
      }
      final result = await Process.run('which', ['pdftotext']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<ParseResult> _parseWithPoppler(File pdfFile) async {
    final result = await Process.run('pdftotext', ['-layout', pdfFile.path, '-']);
    if (result.exitCode != 0) {
      throw Exception('pdftotext exit code ${result.exitCode}');
    }
    final text = result.stdout as String;
    if (text.trim().isEmpty) throw Exception('pdftotext produced empty output');

    final sections = splitSections(text);
    return ParseResult(
      markdown: sections.join('\n\n'),
      title: extractTitle(text),
      sourceType: 'fallback_text',
    );
  }

  ParseResult parseWithFlutterPdf(File pdfFile) {
    final doc = PdfDocument(inputBytes: pdfFile.readAsBytesSync());
    try {
      final extractor = PdfTextExtractor(doc);
      final buffer = StringBuffer();
      for (var i = 0; i < doc.pages.count; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (i > 0) buffer.writeln('\n\n<!-- page-break -->\n');
        buffer.writeln('### 第 ${i + 1} 页');
        buffer.writeln(text.trim());
      }
      return ParseResult(
        markdown: buffer.toString(),
        title: extractTitle(buffer.toString()),
        sourceType: 'fallback_raw',
      );
    } finally {
      doc.dispose();
    }
  }

  String extractTitle(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
      }
    }
    return 'Untitled';
  }

  List<String> splitSections(String text) {
    final lines = text.split('\n');
    final sections = <String>[];
    var current = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty && current.isNotEmpty) {
        final content = current.toString().trim();
        if (content.isNotEmpty) sections.add(content);
        current = StringBuffer();
      } else if (isSectionHeader(trimmed)) {
        if (current.isNotEmpty) {
          final content = current.toString().trim();
          if (content.isNotEmpty) sections.add(content);
          current = StringBuffer();
        }
        current.writeln('## $trimmed');
      } else {
        current.writeln(trimmed);
      }
    }

    final last = current.toString().trim();
    if (last.isNotEmpty) sections.add(last);
    return sections;
  }

  bool isSectionHeader(String line) {
    if (line.length > 60 || line.isEmpty) return false;
    final keywords = [
      'introduction', 'abstract', 'method', 'approach',
      'experiment', 'result', 'conclusion', 'discussion', 'related work',
      'background', 'preliminary', 'analysis', 'evaluation', 'limitation',
      'acknowledgment', 'reference',
      '方法', '实验', '结论', '相关工作', '引言',
    ];
    final lower = line.toLowerCase().replaceAll(RegExp(r'[^a-z\u4e00-\u9fff\s]'), '').trim();
    for (final kw in keywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }
}
