// ALICE PaperPal — REST API Server
//
// Run:  dart run tool/server.dart [--port 4090]
//
// Provides HTTP API access to all PaperPal features without a GUI.
// Uses the same API clients and models as the CLI.

import 'dart:convert';
import 'dart:io';

import 'cli_state.dart' show ensureDirs;
import '../lib/core/models/paper.dart';
import '../lib/core/models/search_result.dart';
import '../lib/core/models/note.dart';
import '../lib/core/api/arxiv_api.dart';
import '../lib/core/api/s2_api.dart';

// ── In-memory state (loaded from disk on start) ──

List<Paper> _papers = [];
List<Note> _allNotes = [];
SearchResult? _lastImportedResult;

// ── Main ──

Future<void> main(List<String> args) async {
  var port = 4090;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[i + 1]) ?? port;
    }
    if (args[i] == '--help' || args[i] == '-h') {
      print('PaperPal API Server\n');
      print('Usage: dart run tool/server.dart [--port <port>]\n');
      print('Endpoints:');
      print('  GET  /health');
      print('  GET  /papers');
      print('  POST /search       {"query": "..."}');
      print('  POST /import/pdf    {"pdf_path": "...", "title": "..."}');
      print('  POST /import/url    {"url": "...", "title": "..."}');
      print('  POST /ask/:id       {"question": "..."}  (SSE stream)');
      print('  POST /summarize/:id');
      print('  POST /translate/:id');
      print('  GET  /papers/:id/content');
      print('  GET  /papers/:id/translation');
      print('  DELETE /papers/:id');
      print('  GET  /notes/:paperId');
      print('  POST /notes/:paperId  {"text": "..."}');
      print('  DELETE /notes/:id\n');
      print('  GET  /papers/:id/pdf');
      return;
    }
  }

  ensureDirs();
  _loadState();
  stdout.write('\x1b[32mPaperPal API server running on http://localhost:$port\x1b[0m\n');
  stdout.write('Endpoints: /health /papers /search /import/pdf /import/url /ask/:id /summarize/:id /translate/:id\n');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  await for (final request in server) {
    try {
      await _handle(request);
    } catch (e) {
      _sendJson(request, 500, {'error': '$e'});
    }
  }
}

// ── Routing ──

Future<void> _handle(HttpRequest request) async {
  final uri = Uri.parse(request.uri.toString());
  final path = uri.pathSegments;
  final method = request.method;

  // Health
  if (method == 'GET' && path.isEmpty || (path.length == 1 && path[0] == 'health')) {
    return _sendJson(request, 200, {'status': 'ok', 'papers': _papers.length});
  }

  // Papers list
  if (method == 'GET' && path.length == 1 && path[0] == 'papers') {
    final json = _papers.map((p) => {
      'id': p.id, 'title': p.title, 'authors': p.authors,
      'year': p.year, 'source': p.source, 'status': p.status.name,
      'sourceType': p.sourceType, 'errorMessage': p.errorMessage,
      'importedAt': p.importedAt?.toIso8601String(),
      'lastReadAt': p.lastReadAt?.toIso8601String(),
    }).toList();
    return _sendJson(request, 200, json);
  }

  // Search
  if (method == 'POST' && path.length == 1 && path[0] == 'search') {
    final body = await _readBody(request);
    final query = body['query'] as String? ?? '';
    if (query.isEmpty) return _sendJson(request, 400, {'error': 'query required'});

    final arxiv = ArxivApi();
    final s2 = S2Api();
    final r1 = await arxiv.search(query);
    final r2 = await s2.search(query);
    final merged = _mergeResults(r1, r2);
    _lastImportedResult = null;
    return _sendJson(request, 200, merged.map((r) => {
      'title': r.title, 'authors': r.authors, 'year': r.year,
      'abstract': r.abstract, 'pdfUrl': r.pdfUrl, 'source': r.source,
      'doi': r.doi, 'citationCount': r.citationCount,
    }).toList());
  }

  // Import PDF
  if (method == 'POST' && path.length == 2 && path[0] == 'import' && path[1] == 'pdf') {
    final body = await _readBody(request);
    final pdfPath = body['pdf_path'] as String?;
    if (pdfPath == null || !await File(pdfPath).exists()) {
      return _sendJson(request, 400, {'error': 'pdf_path not found'});
    }
    final title = body['title'] as String? ?? pdfPath.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
    final paper = Paper(
      id: _uuid(),
      title: title,
      source: 'local',
      status: PaperStatus.parsed,
      importedAt: DateTime.now(),
    );
    _papers.add(paper);
    _saveState();
    return _sendJson(request, 200, _paperJson(paper));
  }

  // Import URL
  if (method == 'POST' && path.length == 2 && path[0] == 'import' && path[1] == 'url') {
    final body = await _readBody(request);
    final url = body['url'] as String?;
    if (url == null || url.isEmpty) return _sendJson(request, 400, {'error': 'url required'});
    final paper = Paper(
      id: _uuid(),
      title: body['title'] as String? ?? url,
      source: 'url',
      status: PaperStatus.importing,
      importedAt: DateTime.now(),
    );
    _papers.add(paper);
    _saveState();
    return _sendJson(request, 200, _paperJson(paper));
  }

  // Paper content
  if (method == 'GET' && path.length == 3 && path[0] == 'papers' && path[2] == 'content') {
    final paper = _findPaper(path[1]);
    if (paper == null) return _sendJson(request, 404, {'error': 'not found'});
    return _sendJson(request, 200, {'id': paper.id, 'title': paper.title, 'content': '(PDF parsing requires GUI)'});
  }

  // Paper translation
  if (method == 'GET' && path.length == 3 && path[0] == 'papers' && path[2] == 'translation') {
    final paper = _findPaper(path[1]);
    if (paper == null) return _sendJson(request, 404, {'error': 'not found'});
    return _sendJson(request, 200, {'id': paper.id, 'translation': null});
  }

  // Delete paper
  if (method == 'DELETE' && path.length == 2 && path[0] == 'papers') {
    _papers.removeWhere((p) => p.id == path[1]);
    _saveState();
    return _sendJson(request, 200, {'deleted': true});
  }

  // Ask (SSE stream)
  if (method == 'POST' && path.length == 2 && path[0] == 'ask') {
    final body = await _readBody(request);
    final question = body['question'] as String? ?? '';
    if (question.isEmpty) return _sendJson(request, 400, {'error': 'question required'});

    return _sendJson(request, 200, {'role': 'assistant', 'content': 'AI 问答需要运行完整 GUI。请使用桌面应用或 CLI。'});
  }

  // Summarize
  if (method == 'POST' && path.length == 2 && path[0] == 'summarize') {
    return _sendJson(request, 200, {'summary': '摘要功能需要运行完整 GUI。请使用桌面应用或 CLI。'});
  }

  // Translate
  if (method == 'POST' && path.length == 2 && path[0] == 'translate') {
    return _sendJson(request, 200, {'translation': '翻译功能需要运行完整 GUI。请使用桌面应用或 CLI。'});
  }

  // Notes list
  if (method == 'GET' && path.length == 2 && path[0] == 'notes') {
    final notes = _allNotes.where((n) => n.paperId == path[1]).toList();
    return _sendJson(request, 200, notes.map(_noteJson).toList());
  }

  // Add note
  if (method == 'POST' && path.length == 2 && path[0] == 'notes') {
    final body = await _readBody(request);
    final text = body['text'] as String? ?? '';
    if (text.isEmpty) return _sendJson(request, 400, {'error': 'text required'});
    final note = Note(
      id: _uuid(),
      paperId: path[1],
      text: text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _allNotes.add(note);
    _saveState();
    return _sendJson(request, 201, _noteJson(note));
  }

  // Delete note
  if (method == 'DELETE' && path.length == 2 && path[0] == 'notes') {
    _allNotes.removeWhere((n) => n.id == path[1]);
    _saveState();
    return _sendJson(request, 200, {'deleted': true});
  }

  // Paper PDF
  if (method == 'GET' && path.length == 3 && path[0] == 'papers' && path[2] == 'pdf') {
    return _sendJson(request, 404, {'error': 'PDF file access requires GUI'});
  }

  _sendJson(request, 404, {'error': 'not found'});
}

// ── Helpers ──

Map<String, dynamic> _paperJson(Paper p) => {
  'id': p.id, 'title': p.title, 'authors': p.authors,
  'year': p.year, 'source': p.source, 'status': p.status.name,
  'sourceType': p.sourceType,
  'importedAt': p.importedAt?.toIso8601String(),
  'lastReadAt': p.lastReadAt?.toIso8601String(),
};

Map<String, dynamic> _noteJson(Note n) => {
  'id': n.id, 'paperId': n.paperId, 'text': n.text,
  'createdAt': n.createdAt.toIso8601String(),
  'type': n.type.name,
};

Paper? _findPaper(String id) {
  try { return _papers.firstWhere((p) => p.id == id); } catch (_) { return null; }
}

String _uuid() => '${DateTime.now().millisecondsSinceEpoch}_${_papers.length}';

Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
  final bytes = await request.fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d));
  return jsonDecode(String.fromCharCodes(bytes.takeBytes())) as Map<String, dynamic>;
}

void _sendJson(HttpRequest request, int status, Object data) {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(data));
  request.response.close();
}

List<SearchResult> _mergeResults(List<SearchResult> arxiv, List<SearchResult> s2) {
  final seen = <String>{};
  final merged = <SearchResult>[];
  for (final r in [...arxiv, ...s2]) {
    final key = r.title.toLowerCase();
    if (seen.add(key)) merged.add(r);
  }
  merged.sort((a, b) => b.citationCount.compareTo(a.citationCount));
  return merged;
}

void _loadState() {
  try {
    final f = File(_papersPath);
    if (f.existsSync()) {
      final list = jsonDecode(f.readAsStringSync()) as List;
      _papers = list.map((e) => Paper.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
  try {
    final f = File(_notesPath);
    if (f.existsSync()) {
      final list = jsonDecode(f.readAsStringSync()) as List;
      _allNotes = list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
}

void _saveState() {
  final dir = Directory(_dataDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File(_papersPath).writeAsStringSync(jsonEncode(_papers.map((p) => p.toJson()).toList()));
  File(_notesPath).writeAsStringSync(jsonEncode(_allNotes.map((n) => n.toJson()).toList()));
}

String get _dataDir {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '${Platform.environment['HOMEDRIVE']}${Platform.environment['HOMEPATH']}';
  return '$home/.paperwise';
}
String get _papersPath => '$_dataDir/papers.json';
String get _notesPath => '$_dataDir/notes.json';
