import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import '../models/paper.dart';
import '../interfaces/services.dart';

final _log = Logger('CacheService');

class CacheService implements ICacheService {
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
  String get _indexPath => '$_rootDir/index.json';

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

  /// Persist paper metadata to JSON index
  Future<void> savePaperMeta(Paper paper) async {
    final all = await loadAllPapers();
    final index = all.indexWhere((p) => p.id == paper.id);
    if (index >= 0) {
      all[index] = paper;
    } else {
      all.add(paper);
    }
    await _writeIndex(all);
    _log.info('savePaperMeta: ${paper.id}');
  }

  /// Load all paper metadata from JSON index
  Future<List<Paper>> loadAllPapers() async {
    final file = File(_indexPath);
    if (!await file.exists()) return [];
    try {
      final json = await file.readAsString();
      final list = jsonDecode(json) as List;
      return list.map((e) => Paper.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _log.warning('loadAllPapers: index.json corrupted, backing up: $e');
      try {
        await file.copy('${_indexPath}.corrupted.${DateTime.now().millisecondsSinceEpoch}');
        _log.warning('loadAllPapers: backup saved, starting fresh');
      } catch (_) {}
      return [];
    }
  }

  /// Remove paper metadata from index
  Future<void> deletePaperMeta(String paperId) async {
    final all = await loadAllPapers();
    all.removeWhere((p) => p.id == paperId);
    await _writeIndex(all);
  }

  Future<void> _writeIndex(List<Paper> papers) async {
    final json = jsonEncode(papers.map((p) => p.toJson()).toList());
    await File(_indexPath).writeAsString(json);
  }

  Future<void> deletePaper(String paperId) async {
    await deletePaperMeta(paperId);
    final dir = Directory(_paperDir(paperId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _log.info('deletePaper: $paperId');
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
