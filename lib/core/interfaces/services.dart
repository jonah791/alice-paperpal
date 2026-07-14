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

abstract class IMineruApi {
  Future<MineruResult> parseUrl(String pdfUrl, {String? pageRanges, Duration pollTimeout});
  Future<MineruResult> parseFile(File pdfFile, {String? pageRanges, Duration pollTimeout});
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

abstract class ITranslationService {
  String detectLanguage(String text);
  bool needsTranslation(String text);
  Future<String> translate(String markdown, {String target});
  String validateLatex(String text);
}
