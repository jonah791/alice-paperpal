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
import '../utils/page_counter.dart';
import 'cache_service.dart';
import 'config_service.dart';
import 'memory_service.dart';
import 'parse_service.dart';
import 'portrait_service.dart';
import 'search_service.dart';
import 'soul_service.dart';
import 'translation_service.dart';

final _log = Logger('PaperService');
final _uuid = Uuid();

class PaperService {
  final CacheService _cache;
  final SearchService _search;
  final ConfigService _config;
  final LLMProvider _llm;
  final SoulService _soul;
  final MemoryService _memory;
  final PortraitService _portrait;
  late final ParseService _parse;
  late final TranslationService _translation;

  final _papers = <Paper>{};
  final _paperController = StreamController<List<Paper>>.broadcast();
  Stream<List<Paper>> get paperStream => _paperController.stream;

  PaperService({
    required CacheService cache,
    required SearchService search,
    required ConfigService config,
    required LLMProvider llmProvider,
    required SoulService soulService,
    required MemoryService memoryService,
    required PortraitService portraitService,
  })  : _cache = cache,
        _search = search,
        _config = config,
        _llm = llmProvider,
        _soul = soulService,
        _memory = memoryService,
        _portrait = portraitService;

  Future<void> init() async {
    final cfg = _config.config;
    final mineruApi = MineruApi(
      apiKey: await _config.readMineruApiKey() ?? '',
      modelVersion: cfg.mineruModelVersion,
      enableFormula: cfg.enableFormula,
      enableTable: cfg.enableTable,
    );
    _parse = ParseService(api: mineruApi);
    _translation = TranslationService(_llm);

    final persisted = await _cache.loadAllPapers();
    _papers.addAll(persisted);
    _emitPapers();
    _log.info('init: ${_papers.length} papers');
  }

  void _emitPapers() => _paperController.add(_papers.toList());
  Future<void> _persistPaper(Paper p) => _cache.savePaperMeta(p);

  Stream<ParseProgress> get parseProgress => _parse.progressStream;
  Future<List<SearchResult>> search(String query) => _search.search(query);

  Future<Paper?> importFromSearch(SearchResult result, {void Function(int, int)? onProgress}) async {
    final tempDir = await getTemporaryDirectory();
    final pdf = await _search.downloadPdf(result, '${tempDir.path}/downloads', onProgress: onProgress);
    if (pdf == null) return null;
    return importPdf(pdf, title: result.title);
  }

  Future<Paper?> importPdf(File pdfFile, {String? title}) async {
    final paperId = _uuid.v4();
    final paper = Paper(
      id: paperId,
      title: title ?? pdfFile.path.split(Platform.pathSeparator).last.replaceAll('.pdf', ''),
      year: DateTime.now().year,
      source: 'local',
      status: PaperStatus.parsing,
      importedAt: DateTime.now(),
    );
    _papers.add(paper);
    _emitPapers();
    _cache.savePdf(paperId, pdfFile);

    try {
      final pageCount = await PageCounter.getPageCount(pdfFile.path);
      final result = await _parse.parsePdf(pdfFile, pageCount);
      await _cache.saveMarkdown(paperId, result.markdown);

      final updated = paper.copyWith(
        title: result.title.isNotEmpty ? result.title : paper.title,
        status: PaperStatus.parsed,
        pageCount: pageCount,
      );
      _papers.remove(paper);
      _papers.add(updated);
      _emitPapers();
      await _persistPaper(updated);

      // Active comment after parse
      _activeComment(paperId);

      if (_config.config.autoTranslate) {
        await _autoTranslate(updated);
      }
      return updated;
    } catch (e) {
      _log.warning('importPdf failed: $paperId → $e');
      final failed = paper.copyWith(status: PaperStatus.error);
      _papers.remove(paper);
      _papers.add(failed);
      _emitPapers();
      return failed;
    }
  }

  Future<void> _activeComment(String paperId) async {
    final md = await _cache.readMarkdown(paperId);
    if (md == null) return;
    final soul = _soul.getActiveOrDefault();
    try {
      final comment = await _llm.chat([
        {'role': 'system', 'content': '你是一位${soul.name}。根据论文开头内容，给一句简短的第一印象。不要问问题，不要用"你好"，直接评论。20字以内。'},
        {'role': 'user', 'content': md.substring(0, md.length.clamp(0, 500))},
      ], maxTokens: 50);
      _log.info('activeComment: $comment');
    } catch (_) {}
  }

  Future<void> _autoTranslate(Paper paper) async {
    final md = await _cache.readMarkdown(paper.id);
    if (md == null) return;
    if (!_translation.needsTranslation(md)) return;

    final updated = paper.copyWith(status: PaperStatus.translating);
    _papers.remove(paper);
    _papers.add(updated);
    _emitPapers();

    try {
      final translated = await _translation.translate(md);
      await _cache.saveTranslation(paper.id, translated);
      final done = updated.copyWith(status: PaperStatus.translated);
      _papers.remove(updated);
      _papers.add(done);
      _emitPapers();
      await _persistPaper(done);
    } catch (e) {
      _log.warning('autoTranslate failed: ${paper.id} → $e');
      _papers.remove(updated);
      _papers.add(updated.copyWith(status: PaperStatus.error));
      _emitPapers();
    }
  }

  Future<String?> getMarkdown(String paperId) => _cache.readMarkdown(paperId);
  Future<String?> getTranslation(String paperId) => _cache.readTranslation(paperId);

  String _buildPersonaPrompt() {
    final soul = _soul.getActiveOrDefault();
    final sb = StringBuffer();

    sb.writeln(soul.systemPrompt);
    if (soul.speechPattern != null) {
      sb.writeln('说话习惯：${soul.speechPattern}');
    }
    sb.writeln(_soul.metaSoulRules);

    return sb.toString();
  }

  String _buildContextPrompt(String paperId) {
    final sb = StringBuffer();
    final portrait = _portrait.summarize();
    if (portrait.isNotEmpty) {
      sb.writeln('关于用户：');
      sb.writeln(portrait);
      sb.writeln();
    }
    final memories = _memory.summarizeRecent(limit: 10);
    if (memories.isNotEmpty) {
      sb.writeln('我们的过往：');
      sb.writeln(memories);
      sb.writeln();
    }
    return sb.toString();
  }

  Future<String> askQuestion(String paperId, String question) async {
    final md = await getMarkdown(paperId);
    if (md == null) return '论文内容不可用';
    final translation = await getTranslation(paperId) ?? md;
    final truncated = translation.length > 12000
        ? '${translation.substring(0, 12000)}\n\n[论文较长，已截断]'
        : translation;

    final persona = _buildPersonaPrompt();
    final context = _buildContextPrompt(paperId);

    final answer = await _llm.chat([
      {'role': 'system', 'content': '$persona\n\n$context'},
      {'role': 'user', 'content': '论文内容：\n\n$truncated\n\n---\n\n问题：$question'},
    ]);

    // Background portrait update
    _portrait.updateFromConversation(question, answer, _llm);
    // Memory
    _memory.addMemory(question.substring(0, question.length.clamp(0, 80)), paperId: paperId);

    return answer;
  }

  Stream<String> askQuestionStream(String paperId, String question) async* {
    final md = await getMarkdown(paperId);
    if (md == null) {
      yield '论文内容不可用';
      return;
    }
    final translation = await getTranslation(paperId) ?? md;
    final truncated = translation.length > 12000
        ? '${translation.substring(0, 12000)}\n\n[论文较长，已截断]'
        : translation;

    final persona = _buildPersonaPrompt();
    final context = _buildContextPrompt(paperId);

    final buffer = StringBuffer();
    await for (final chunk in _llm.chatStream([
      {'role': 'system', 'content': '$persona\n\n$context'},
      {'role': 'user', 'content': '论文内容：\n\n$truncated\n\n---\n\n问题：$question'},
    ])) {
      buffer.write(chunk);
      yield chunk;
    }

    final fullAnswer = buffer.toString();
    _portrait.updateFromConversation(question, fullAnswer, _llm);
    _memory.addMemory(question.substring(0, question.length.clamp(0, 80)), paperId: paperId);
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

  Future<void> deletePaper(String paperId) async {
    _papers.removeWhere((p) => p.id == paperId);
    _emitPapers();
    await _cache.deletePaper(paperId);
    _log.info('deletePaper: $paperId');
  }

  void dispose() {
    _parse.dispose();
    _paperController.close();
  }
}
