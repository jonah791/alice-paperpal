import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import '../models/paper.dart';

final _log = Logger('ExportService');

class ExportService {
  static Future<void> exportMarkdown(Paper paper, String markdown) async {
    final path = await FilePicker.saveFile(
      dialogTitle: '导出 Markdown',
      fileName: '${paper.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.md',
    );
    if (path == null) return;

    try {
      await File(path).writeAsString(markdown);
      _log.info('exportMarkdown: $path');
    } catch (e) {
      _log.warning('exportMarkdown failed: $e');
      rethrow;
    }
  }

  static Future<void> exportBibtex(Paper paper) async {
    final bibtex = generateBibtex(paper);
    final path = await FilePicker.saveFile(
      dialogTitle: '导出 BibTeX',
      fileName: '${paper.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.bib',
    );
    if (path == null) return;

    try {
      await File(path).writeAsString(bibtex);
      _log.info('exportBibtex: $path');
    } catch (e) {
      _log.warning('exportBibtex failed: $e');
      rethrow;
    }
  }

  static String generateBibtex(Paper paper) {
    final key = paper.doi.isNotEmpty
        ? paper.doi.replaceAll(RegExp(r'[/.-]'), '_')
        : paper.title.split(RegExp(r'\s+')).take(3).join('_');

    final authorLine = paper.authors.isNotEmpty
        ? paper.authors.map((a) {
            final parts = a.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              return '${parts.last}, ${parts.sublist(0, parts.length - 1).join(' ')}';
            }
            return a;
          }).join(' and ')
        : '{Anonymous}';

    return '''@article{$key,
  title={${paper.title}},
  author={$authorLine},
  year={${paper.year}},
}''';
  }
}
