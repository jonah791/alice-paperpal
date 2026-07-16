import 'dart:io';

import '../models/config.dart';
import '../models/note.dart';
import '../models/paper.dart';
import '../models/parse_result.dart';
import '../models/search_result.dart';
import '../models/soul.dart';
import '../services/memory_service.dart';
import '../api/mineru_api.dart';
import '../services/platform_service.dart';

// ─── API Clients ────────────────────────────────────────────────

abstract class IArxivApi {
  Future<List<SearchResult>> search(String query, {int maxResults});
}

abstract class IS2Api {
  Future<List<SearchResult>> search(String query, {int limit});
}

abstract class ILLMProvider {
  Future<String> chat(List<Map<String, String>> messages, {int? maxTokens});
  Stream<String> chatStream(List<Map<String, String>> messages, {int? maxTokens});
  Future<String> translate(String text, {String target});
  Future<String> summarize(String paperText);
  void reconfigure({required String apiKey, required String apiBase, required String model});
}

// ─── Services ───────────────────────────────────────────────────

abstract class IConfigService {
  AppConfig get config;
  PlatformService get platform;
  bool get hasLlmApiKey;
  Future<String?> readLlmApiKey();
  Future<String?> readMineruApiKey();
  Future<void> saveLlmApiKey(String key);
  Future<void> saveMineruApiKey(String key);
  Future<void> updateConfig(AppConfig config);
  Future<void> load();
}

abstract class ICacheService {
  String get rootDir;
  Future<void> savePdf(String paperId, File pdf);
  String pdfPath(String paperId);
  Future<void> saveMarkdown(String paperId, String content);
  Future<String?> readMarkdown(String paperId);
  Future<void> saveTranslation(String paperId, String content);
  Future<String?> readTranslation(String paperId);
  Future<void> savePaperMeta(Paper paper);
  Future<List<Paper>> loadAllPapers();
  Future<void> deletePaper(String paperId);
}

abstract class ISearchService {
  Future<(List<SearchResult>, String?)> search(String query);
  Future<File?> downloadPdf(SearchResult result, String saveDir, {void Function(int, int)? onProgress});
}

abstract class IPaperService {
  Stream<List<Paper>> get paperStream;
  Stream<ParseProgress> get parseProgress;
  List<Paper> get papers;
  Paper? getPaper(String id);
  Future<(List<SearchResult>, String?)> search(String query);
  Future<Paper?> importFromSearch(SearchResult result, {void Function(int, int)? onProgress});
  Future<Paper?> importPdf(File pdfFile, {String? title});
  Future<String?> getMarkdown(String paperId);
  Future<String?> getTranslation(String paperId);
  Future<String> askQuestion(String paperId, String question);
  Stream<String> askQuestionStream(String paperId, String question);
  Future<String> summarize(String paperId);
  Future<void> deletePaper(String paperId);
  Future<void> updatePaper(Paper paper);
  Future<void> touchPaper(String paperId);
  Future<void> reconfigureMineru();
  Future<void> reconfigureLlm();
  Future<void> init();
  void dispose();
}

abstract class IMemoryService {
  Future<void> init();
  List<MemoryItem> getRecent({int limit});
  Future<void> addMemory(String summary, {String? paperId});
  String summarizeRecent({int limit});
  Future<void> prune();
}

abstract class INoteService {
  Future<void> init();
  List<Note> getNotesForPaper(String paperId);
  Future<Note> addNote({required String paperId, required String text, NoteType type, String? selectedText, int? offset});
  Future<void> updateNote(String noteId, String text);
  Future<void> deleteNote(String noteId);
  Future<void> deleteNotesForPaper(String paperId);
}

abstract class ISoulService {
  Soul getActiveOrDefault();
  Soul? get activeSoul;
  List<Soul> get presets;
  List<Soul> get custom;
  String get metaSoulRules;
  Future<void> init();
  Future<void> setActiveSoul(Soul soul);
  Future<Soul> createCustomSoul(String name, String description, ILLMProvider llm);
  Future<void> deleteCustomSoul(String id);
}

abstract class IPortraitService {
  Future<void> init();
  String summarize();
  Future<void> updateFromConversation(String userMessage, String assistantResponse, ILLMProvider llm);
}

abstract class IAvatarService {
  Future<void> init();
  String? get currentPath;
  bool get hasCustomAvatar;
  int colorForName(String name);
  Future<void> setAvatarFromPath(String sourcePath);
  Future<void> deleteBuiltin();
}

abstract class INetworkService {
  bool get isOnline;
  Stream<bool> get statusStream;
  void init();
  void dispose();
}

// ─── Zotero Integration (was UI → API direct) ──────────────────

abstract class IZoteroService {
  Future<List<SearchResult>> importFromZotero({int limit = 50});
  bool get isConfigured;
}

// ─── Mermaid Renderer (was no interface) ───────────────────────

abstract class IMermaidRenderer {
  List<MermaidBlock> extractBlocks(String markdown);
  String buildHtml(String diagramCode, {bool dark});
}

class MermaidBlock {
  final String code;
  final int start;
  final int end;
  const MermaidBlock({required this.code, required this.start, required this.end});
}

abstract class ITranslationService {
  String detectLanguage(String text);
  bool needsTranslation(String text);
  Future<String> translate(String markdown, {String target});
  String validateLatex(String text);
}

// ─── Unified Document Conversion (MarkItDown integration) ─────

abstract class IDocConversionService {
  Future<bool> get isPythonAvailable;
  Future<ConversionResult> convertToMarkdown(File file);
  List<String> get supportedExtensions;
  String get filterLabel;
}

class ConversionResult {
  final bool success;
  final String markdown;
  final String title;
  final String sourceFormat;
  final String sourceType;
  final String? error;

  const ConversionResult({
    required this.success,
    required this.markdown,
    required this.title,
    this.sourceFormat = 'unknown',
    this.sourceType = 'markitdown',
    this.error,
  });
}

// ─── Note Template System (Kori integration) ──────────────────

abstract class ITemplateService {
  List<NoteTemplate> get all;
  List<NoteTemplate> get custom;
  Future<void> init();
  Future<void> addTemplate(NoteTemplate template);
  Future<void> deleteTemplate(String id);
  NoteTemplate? getTemplate(String id);
}

class NoteTemplate {
  final String id;
  final String name;
  final String description;
  final String markdown;
  final bool isBuiltin;

  const NoteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.markdown,
    this.isBuiltin = false,
  });

  String render({String? paperTitle, String? dateStr}) {
    final now = dateStr ?? _formatDate(DateTime.now());
    return markdown
        .replaceAll('{{date}}', now)
        .replaceAll('{{title}}', paperTitle ?? '')
        .replaceAll('{{time}}', _formatTime(DateTime.now()));
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'markdown': markdown, 'isBuiltin': isBuiltin,
  };

  factory NoteTemplate.fromJson(Map<String, dynamic> json) => NoteTemplate(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    markdown: json['markdown'] as String? ?? '',
    isBuiltin: json['isBuiltin'] as bool? ?? false,
  );

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  static String _formatTime(DateTime dt) =>
      '${_pad(dt.hour)}:${_pad(dt.minute)}';
  static String _pad(int n) => n.toString().padLeft(2, '0');
}
