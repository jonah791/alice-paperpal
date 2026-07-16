/// Unified Document Conversion Service.
library;

import 'dart:io';

import 'package:logging/logging.dart';

import '../api/markitdown_bridge.dart';
import '../interfaces/services.dart';
import '../models/document.dart';

final _log = Logger('DocConversionService');

/// Supported conversion target.
enum ConvertTarget {
  pdf, office, epub, html, markdown, text, image, audio,
}

/// Unified service for converting documents to Markdown.
class DocConversionService implements IDocConversionService {
  final MarkitdownBridge _bridge;
  bool _pythonChecked = false;
  bool _pythonAvailable = false;

  DocConversionService(this._bridge);

  @override
  Future<bool> get isPythonAvailable async {
    if (!_pythonChecked) {
      _pythonAvailable = await _bridge.isAvailable;
      _pythonChecked = true;
    }
    return _pythonAvailable;
  }

  @override
  Future<ConversionResult> convertToMarkdown(File file) async {
    final ext = file.path.split('.').last;
    final format = DocumentFormat.fromExtension(ext);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final title = fileName.replaceAll('.$ext', '').replaceAll(RegExp(r'[_\-]+'), ' ');

    _log.info('convertToMarkdown: $fileName (${format.label})');

    return switch (format) {
      DocumentFormat.markdown || DocumentFormat.txt ||
      DocumentFormat.json || DocumentFormat.xml || DocumentFormat.csv ||
      DocumentFormat.html =>
        _convertTextFile(file, format, title),

      DocumentFormat.audio || DocumentFormat.image ||
      DocumentFormat.docx || DocumentFormat.pptx ||
      DocumentFormat.xlsx || DocumentFormat.epub ||
      DocumentFormat.pdf =>
        await _convertWithMarkitdown(file, format, title),

      DocumentFormat.url || DocumentFormat.unknown =>
        ConversionResult(success: false, markdown: '', title: title, error: 'Unsupported: ${format.label}'),
    };
  }

  ConversionResult _convertTextFile(File file, DocumentFormat format, String title) {
    try {
      final content = file.readAsStringSync();
      final markdown = format == DocumentFormat.html ? _simpleHtmlToMarkdown(content) : content;
      return ConversionResult(success: true, markdown: markdown, title: title, sourceType: 'direct');
    } catch (e) {
      return ConversionResult(success: false, markdown: '', title: title, error: 'Read failed: $e');
    }
  }

  Future<ConversionResult> _convertWithMarkitdown(File file, DocumentFormat format, String title) async {
    if (!await isPythonAvailable) {
      return ConversionResult(success: false, markdown: '', title: title, error: 'Python/MarkItDown not available');
    }
    final result = await _bridge.convert(file.path, type: format == DocumentFormat.pdf ? 'pdf' : null);
    if (result.success) {
      return ConversionResult(success: true, markdown: result.markdown, title: title);
    }
    return ConversionResult(success: false, markdown: '', title: title, error: result.error);
  }

  /// Basic HTML to Markdown conversion using replaceAllMapped to avoid $ issues.
  String _simpleHtmlToMarkdown(String html) {
    final regexes = <(RegExp, String Function(Match))>[
      (RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false), (m) => '# ${m[1]}\n\n'),
      (RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false), (m) => '## ${m[1]}\n\n'),
      (RegExp(r'<h3[^>]*>(.*?)</h3>', caseSensitive: false), (m) => '### ${m[1]}\n\n'),
      (RegExp(r'<h4[^>]*>(.*?)</h4>', caseSensitive: false), (m) => '#### ${m[1]}\n\n'),
      (RegExp(r'<a[^>]*href="(.*?)"[^>]*>(.*?)</a>', caseSensitive: false), (m) => '[${m[2]}](${m[1]})'),
      (RegExp(r'<img[^>]*src="(.*?)"[^>]*alt="(.*?)"[^>]*>', caseSensitive: false), (m) => '![${m[2]}](${m[1]})'),
      (RegExp(r'<strong>(.*?)</strong>', caseSensitive: false), (m) => '**${m[1]}**'),
      (RegExp(r'<em>(.*?)</em>', caseSensitive: false), (m) => '*${m[1]}*'),
      (RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false), (m) => '${m[1]}\n\n'),
      (RegExp(r'<li>(.*?)</li>', caseSensitive: false), (m) => '- ${m[1]}\n'),
    ];

    var text = html;
    // Strip scripts and styles first
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    // Apply all content conversions
    for (final (re, fn) in regexes) {
      text = text.replaceAllMapped(re, fn);
    }
    // Cleanup
    text = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
    return text;
  }

  @override
  List<String> get supportedExtensions => [
    '.pdf', '.docx', '.pptx', '.xlsx', '.xls',
    '.epub', '.html', '.htm',
    '.md', '.markdown', '.txt',
    '.csv', '.json', '.xml',
    '.png', '.jpg', '.jpeg', '.gif', '.webp',
    '.mp3', '.wav', '.m4a', '.ogg',
  ];

  @override
  String get filterLabel => '所有支持的文档 (*.pdf, *.docx, *.pptx, *.xlsx, *.md, *.html, *.epub, *.txt)';
}
