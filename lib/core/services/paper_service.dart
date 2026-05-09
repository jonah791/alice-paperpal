import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../api/llm_provider.dart';
import '../api/mineru_api.dart';
import '../models/paper.dart';
import '../models/parse_result.dart';
import '../models/search_result.dart';
import 'cache_service.dart';
import 'config_service.dart';
import 'parse_service.dart';
import 'search_service.dart';
import 'translation_service.dart';

final _log = Logger('PaperService');
final _uuid = Uuid();

class PaperService {
  final CacheService _cache;
  final SearchService _search;
  final ConfigService _config;
  late final ParseService _parse;
  late final TranslationService _translation;
  late final LLMProvider _llm;

  final _papers = <Paper>{};
  final _paperController = StreamController<List<Paper>>.broadcast();
  Stream<List<Paper>> get paperStream => _paperController.stream;

  PaperService({
    required CacheService cache,
    required SearchService search,
    required ConfigService config,
  })  : _cache = cache,
        _search = search,
        _config = config;

  Future<void> init() async {
    final cfg = _config.config;
    final apiKey = await _config.readLlmApiKey();
    _llm = LLMProvider(
      apiBase: cfg.llmApiBase,
      apiKey: apiKey ?? '',
      model: cfg.llmModel,
    );
    final mineruApi = MineruApi(
      baseUrl: cfg.mineruApiEndpoint.isNotEmpty
          ? cfg.mineruApiEndpoint
          : 'https://mineru.net/api/v2',
      apiKey: await _config.readMineruApiKey(),
    );
    _parse = ParseService(api: mineruApi, batchSize: cfg.batchSize);
    _translation = TranslationService(_llm);
    _log.info('init: ready');
  }

  Stream<ParseProgress> get parseProgress => _parse.progressStream;

  Future<List<SearchResult>> search(String query) => _search.search(query);

  Future<Paper?> importFromSearch(SearchResult result) async {
    final tempDir = await getTemporaryDirectory();
    final saveDir = '${tempDir.path}/downloads';

    final pdf = await _search.downloadPdf(result, saveDir);
    if (pdf == null) return null;

    return importPdf(pdf, title: result.title);
  }

  Future<Paper?> importPdf(File pdfFile, {String? title}) async {
    final paperId = _uuid.v4();
    final paper = Paper(
      id: paperId,
      title: title ?? pdfFile.path.split(Platform.pathSeparator).last.replaceAll('.pdf', ''),
      authors: [],
      year: DateTime.now().year,
      source: 'local',
      status: PaperStatus.parsing,
      importedAt: DateTime.now(),
      pageCount: 0,
    );

    _papers.add(paper);
    _paperController.add(_papers.toList());
    _cache.savePdf(paperId, pdfFile);

    try {
      final pageCount = 0; // placeholder - syncfusion at UI layer
      final result = await _parse.parsePdf(pdfFile, pageCount > 0 ? pageCount : 50);

      await _cache.saveMarkdown(paperId, result.markdown);

      final updated = paper.copyWith(
        title: result.title.isNotEmpty ? result.title : paper.title,
        status: PaperStatus.parsed,
        pageCount: pageCount,
      );
      _papers.remove(paper);
      _papers.add(updated);
      _paperController.add(_papers.toList());

      if (_config.config.autoTranslate) {
        await _autoTranslate(updated);
      }

      return updated;
    } catch (e) {
      _log.warning('importPdf failed: $paperId → $e');
      final failed = paper.copyWith(status: PaperStatus.error);
      _papers.remove(paper);
      _papers.add(failed);
      _paperController.add(_papers.toList());
      return failed;
    }
  }

  Future<void> _autoTranslate(Paper paper) async {
    final md = await _cache.readMarkdown(paper.id);
    if (md == null) return;

    final lang = _translation.detectLanguage(md);
    if (lang == 'zh') return;

    final updated = paper.copyWith(status: PaperStatus.translating);
    _papers.remove(paper);
    _papers.add(updated);
    _paperController.add(_papers.toList());

    try {
      final translated = await _translation.translate(md);
      await _cache.saveTranslation(paper.id, translated);

      final done = updated.copyWith(status: PaperStatus.translated);
      _papers.remove(updated);
      _papers.add(done);
      _paperController.add(_papers.toList());
      _log.info('_autoTranslate: ${paper.id} done');
    } catch (e) {
      _log.warning('_autoTranslate failed: ${paper.id} → $e');
      final failed = updated.copyWith(status: PaperStatus.error);
      _papers.remove(updated);
      _papers.add(failed);
      _paperController.add(_papers.toList());
    }
  }

  Future<String?> getMarkdown(String paperId) => _cache.readMarkdown(paperId);
  Future<String?> getTranslation(String paperId) => _cache.readTranslation(paperId);

  Future<String> askQuestion(String paperId, String question) async {
    final md = await getMarkdown(paperId);
    if (md == null) return '论文内容不可用';

    final translation = await getTranslation(paperId);
    final fullText = translation ?? md;

    final truncated = fullText.length > 12000
        ? '${fullText.substring(0, 12000)}\n\n[论文较长，已截断]'
        : fullText;

    return _llm.chat([
      {'role': 'system', 'content': '你是一个学术论文助手。请基于以下论文内容回答问题。引用论文中的具体内容来支持你的回答。'},
      {'role': 'user', 'content': '论文内容：\n\n$truncated\n\n---\n\n问题：$question'},
    ]);
  }

  Future<String> summarize(String paperId) async {
    final md = await getMarkdown(paperId);
    if (md == null) return '论文内容不可用';

    final truncated = md.length > 12000
        ? '${md.substring(0, 12000)}\n\n[论文较长，已截断]'
        : md;

    return _llm.summarize(truncated);
  }

  List<Paper> get papers => _papers.toList();

  void dispose() {
    _parse.dispose();
    _paperController.close();
  }
}
