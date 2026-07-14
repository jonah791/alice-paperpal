import 'dart:async';
import 'dart:io';

import 'package:paperpal/core/interfaces/services.dart';
export 'package:paperpal/core/interfaces/services.dart';
import 'package:paperpal/core/models/config.dart';
import 'package:paperpal/core/models/note.dart';
import 'package:paperpal/core/models/paper.dart';
import 'package:paperpal/core/models/parse_result.dart';
import 'package:paperpal/core/models/search_result.dart';
import 'package:paperpal/core/models/soul.dart';
import 'package:paperpal/core/services/memory_service.dart';
import 'package:paperpal/core/services/platform_service.dart';

// ─── Mock Services for Widget Tests ─────────────────────────────

class MockConfigService implements IConfigService {
  @override
  AppConfig config = const AppConfig();

  @override
  PlatformService platform = _MockPlatform();

  @override
  bool get hasLlmApiKey => _llmKey != null;

  String? _llmKey;
  String? _mineruKey;

  @override
  Future<String?> readLlmApiKey() async => _llmKey;

  @override
  Future<String?> readMineruApiKey() async => _mineruKey;

  @override
  Future<void> saveLlmApiKey(String key) async => _llmKey = key;

  @override
  Future<void> saveMineruApiKey(String key) async => _mineruKey = key;

  @override
  Future<void> updateConfig(AppConfig cfg) async => config = cfg;

  @override
  Future<void> load() async {}
}

class _MockPlatform implements PlatformService {
  @override
  Future<String> encrypt(String plainText) async => plainText;

  @override
  Future<String?> decrypt(String cipherText) async => cipherText;

  @override
  Future<void> openFile(String path) async {}

  @override
  Future<String> get dataPath async => '/tmp/mock';

  @override
  bool get isDesktop => true;

  @override
  bool get isAndroid => false;
}

class MockCacheService implements ICacheService {
  final _papers = <String, Paper>{};
  final _markdowns = <String, String>{};
  final _translations = <String, String>{};
  String _rootDir = '/tmp/mock_cache';

  @override
  String get rootDir => _rootDir;

  @override
  Future<void> savePdf(String paperId, File pdf) async {}

  @override
  String pdfPath(String paperId) => '$_rootDir/$paperId/original.pdf';

  @override
  Future<void> saveMarkdown(String paperId, String content) async => _markdowns[paperId] = content;

  @override
  Future<String?> readMarkdown(String paperId) async => _markdowns[paperId];

  @override
  Future<void> saveTranslation(String paperId, String content) async => _translations[paperId] = content;

  @override
  Future<String?> readTranslation(String paperId) async => _translations[paperId];

  @override
  Future<void> savePaperMeta(Paper paper) async => _papers[paper.id] = paper;

  @override
  Future<List<Paper>> loadAllPapers() async => _papers.values.toList();

  @override
  Future<void> deletePaper(String paperId) async {
    _papers.remove(paperId);
    _markdowns.remove(paperId);
    _translations.remove(paperId);
  }
}

class MockSearchService implements ISearchService {
  List<SearchResult> mockResults = [];
  String? mockError;

  @override
  Future<(List<SearchResult>, String?)> search(String query) async => (mockResults, mockError);

  @override
  Future<File?> downloadPdf(SearchResult result, String saveDir, {void Function(int, int)? onProgress}) async => null;
}

class MockLLMProvider implements ILLMProvider {
  String mockResponse = 'mock response';
  List<List<Map<String, String>>> chatHistory = [];

  @override
  Future<String> chat(List<Map<String, String>> messages, {int? maxTokens}) async {
    chatHistory.add(messages);
    return mockResponse;
  }

  @override
  Stream<String> chatStream(List<Map<String, String>> messages, {int? maxTokens}) async* {
    chatHistory.add(messages);
    yield mockResponse;
  }

  @override
  Future<String> translate(String text, {String target = '中文'}) async => 'translated: $text';

  @override
  Future<String> summarize(String paperText) async => 'summary: ${paperText.substring(0, paperText.length.clamp(0, 50))}...';

  @override
  void reconfigure({required String apiKey, required String apiBase, required String model}) {}
}

class MockSoulService implements ISoulService {
  @override
  Soul getActiveOrDefault() => _defaultSoul;

  @override
  Soul? activeSoul = _defaultSoul;

  @override
  List<Soul> presets = [_defaultSoul];

  @override
  List<Soul> custom = [];

  @override
  String metaSoulRules = '';

  @override
  Future<void> init() async {}

  @override
  Future<void> setActiveSoul(Soul soul) async => activeSoul = soul;

  @override
  Future<Soul> createCustomSoul(String name, String description, ILLMProvider llm) async => Soul(
    id: 'custom_1', name: name, description: description, systemPrompt: 'Custom',
  );

  @override
  Future<void> deleteCustomSoul(String id) async {
    custom.removeWhere((s) => s.id == id);
  }

  static final Soul _defaultSoul = Soul(
    id: 'academic_mentor',
    name: '学术导师',
    description: '严谨专业的学术伙伴',
    systemPrompt: '你是一位严谨的学术导师。',
    speechPattern: '让我们来分析这篇论文...',
  );
}

class MockMemoryService implements IMemoryService {
  final List<MemoryItem> _items = [];

  @override
  Future<void> init() async {}

  @override
  List<MemoryItem> getRecent({int limit = 10}) => _items;

  @override
  Future<void> addMemory(String summary, {String? paperId}) async {
    _items.add(MemoryItem(id: 'm_$_items.length', summary: summary, paperId: paperId, timestamp: DateTime.now()));
  }

  @override
  String summarizeRecent({int limit = 10}) => _items.map((m) => '- ${m.summary}').join('\n');

  @override
  Future<void> prune() async => _items.clear();
}

class MockNoteService implements INoteService {
  final _notes = <Note>[];

  @override
  Future<void> init() async {}

  @override
  List<Note> getNotesForPaper(String paperId) =>
      _notes.where((n) => n.paperId == paperId).toList();

  @override
  Future<Note> addNote({
    required String paperId, required String text,
    NoteType type = NoteType.note, String? selectedText, int? offset,
  }) async {
    final note = Note(id: 'n_${_notes.length}', paperId: paperId, text: text,
        createdAt: DateTime.now(), updatedAt: DateTime.now());
    _notes.add(note);
    return note;
  }

  @override
  Future<void> updateNote(String noteId, String text) async {}

  @override
  Future<void> deleteNote(String noteId) async => _notes.removeWhere((n) => n.id == noteId);

  @override
  Future<void> deleteNotesForPaper(String paperId) async =>
      _notes.removeWhere((n) => n.paperId == paperId);
}

class MockNetworkService implements INetworkService {
  @override
  bool isOnline = true;

  @override
  Stream<bool> get statusStream => Stream<bool>.value(true);

  @override
  void init() {}

  @override
  void dispose() {}
}

class MockPortraitService implements IPortraitService {
  Map<String, dynamic> portrait = {};

  @override
  Future<void> init() async {}

  @override
  String summarize() => portrait.isNotEmpty ? 'mock portrait summary' : '';

  @override
  Future<void> updateFromConversation(String userMessage, String assistantResponse, ILLMProvider llm) async {}
}

class MockPaperService implements IPaperService {
  final _paperController = StreamController<List<Paper>>.broadcast();
  final _progressController = StreamController<ParseProgress>.broadcast();

  List<Paper> papers = [];
  Map<String, String> markdowns = {};
  Map<String, String> translations = {};
  String? importError;
  String? askError;

  @override
  Stream<List<Paper>> get paperStream => _paperController.stream;

  @override
  Stream<ParseProgress> get parseProgress => _progressController.stream;

  @override
  Paper? getPaper(String id) {
    try {
      return papers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<(List<SearchResult>, String?)> search(String query) async => (<SearchResult>[], null);

  @override
  Future<Paper?> importFromSearch(SearchResult result, {void Function(int, int)? onProgress}) async {
    if (importError != null) return null;
    final paper = Paper(
      id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
      title: result.title,
      year: result.year,
      source: result.source,
      status: PaperStatus.parsed,
      importedAt: DateTime.now(),
    );
    papers.add(paper);
    _paperController.add(List.unmodifiable(papers));
    return paper;
  }

  @override
  Future<Paper?> importPdf(File pdfFile, {String? title}) async {
    if (importError != null) return null;
    final paper = Paper(
      id: 'pdf_${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? pdfFile.path.split(Platform.pathSeparator).last,
      year: DateTime.now().year,
      source: 'local',
      status: PaperStatus.parsed,
      importedAt: DateTime.now(),
    );
    papers.add(paper);
    _paperController.add(List.unmodifiable(papers));
    return paper;
  }

  @override
  Future<String?> getMarkdown(String paperId) async {
    return markdowns[paperId] ?? '# Mock Paper\n\nThis is test content with \$\$E=mc^2\$\$ formula.';
  }

  @override
  Future<String?> getTranslation(String paperId) async => translations[paperId];

  @override
  Future<String> askQuestion(String paperId, String question) async {
    if (askError != null) return askError!;
    return 'Mock answer to: $question';
  }

  @override
  Stream<String> askQuestionStream(String paperId, String question) async* {
    if (askError != null) {
      yield askError!;
      return;
    }
    yield 'Mock streaming answer to: $question';
  }

  @override
  Future<String> summarize(String paperId) async => '## Summary\n\nThis is a mock summary.';

  @override
  Future<void> deletePaper(String paperId) async {
    papers.removeWhere((p) => p.id == paperId);
    _paperController.add(List.unmodifiable(papers));
  }

  @override
  Future<void> touchPaper(String paperId) async {}

  @override
  Future<void> reconfigureMineru() async {}

  @override
  Future<void> reconfigureLlm() async {}

  @override
  Future<void> init() async {}

  @override
  void dispose() {
    _paperController.close();
    _progressController.close();
  }
}

class MockAvatarService implements IAvatarService {
  @override
  String? currentPath;

  @override
  bool hasCustomAvatar = false;

  @override
  int colorForName(String name) => 0xFF1565C0;

  @override
  Future<void> init() async {}

  @override
  Future<void> setAvatarFromPath(String sourcePath) async => currentPath = sourcePath;

  @override
  Future<void> deleteBuiltin() async => currentPath = null;
}
