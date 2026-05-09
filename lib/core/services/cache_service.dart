import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';

final _log = Logger('CacheService');

class CacheService {
  late final String _rootDir;

  Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    _rootDir = '${appDir.path}/papers';
    final dir = Directory(_rootDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _log.info('init: cache root = $_rootDir');
  }

  String get rootDir => _rootDir;

  String _paperDir(String paperId) => '$_rootDir/$paperId';

  Future<Directory> ensurePaperDir(String paperId) async {
    final dir = Directory(_paperDir(paperId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> savePdf(String paperId, File pdf) async {
    final dir = await ensurePaperDir(paperId);
    await pdf.copy('${dir.path}/original.pdf');
    _log.info('savePdf: $paperId');
  }

  String pdfPath(String paperId) => '${_paperDir(paperId)}/original.pdf';

  Future<void> saveMarkdown(String paperId, String content) async {
    final dir = await ensurePaperDir(paperId);
    await File('${dir.path}/parsed.md').writeAsString(content);
    _log.info('saveMarkdown: $paperId, ${content.length} chars');
  }

  Future<String?> readMarkdown(String paperId) async {
    final file = File('${_paperDir(paperId)}/parsed.md');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  Future<void> saveTranslation(String paperId, String content) async {
    final dir = await ensurePaperDir(paperId);
    await File('${dir.path}/translated.md').writeAsString(content);
    _log.info('saveTranslation: $paperId, ${content.length} chars');
  }

  Future<String?> readTranslation(String paperId) async {
    final file = File('${_paperDir(paperId)}/translated.md');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  Future<void> deletePaper(String paperId) async {
    final dir = Directory(_paperDir(paperId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _log.info('deletePaper: $paperId');
    }
  }

  Future<void> cleanOldPapers({int olderThanDays = 90}) async {
    final root = Directory(_rootDir);
    if (!await root.exists()) return;

    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    await for (final entity in root.list()) {
      if (entity is Directory) {
        final stat = await entity.stat();
        if (stat.changed.isBefore(cutoff)) {
          await entity.delete(recursive: true);
          _log.info('cleanOldPapers: removed ${entity.path}');
        }
      }
    }
  }
}
