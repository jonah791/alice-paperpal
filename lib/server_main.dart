// PaperPal API Server — Flutter entry point
//
// Run:  flutter run -t lib/server_main.dart --dart-define=PORT=4090
// Build: flutter build windows --release -t lib/server_main.dart
//
// Starts an HTTP server using shelf for routing + middleware.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Router;
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'core/init.dart';
import 'core/interfaces/services.dart';
import 'core/models/paper.dart';
import 'core/models/search_result.dart';
import 'core/models/note.dart';
import 'core/models/soul.dart';
import 'core/models/document.dart';
import 'core/services/export_service.dart';

final _log = Logger('Server');

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  var port = 4090;
  if (args.contains('--port') && args.length > args.indexOf('--port') + 1) {
    port = int.tryParse(args[args.indexOf('--port') + 1]) ?? port;
  }

  final locator = await createLocator();
  await locator.get<IPaperService>().init();

  final router = Router();

  // ── Middleware chain ──────────────────────────────────────────
  final handler = const shelf.Pipeline()
      .addMiddleware(_requestLogger())
      .addMiddleware(corsHeaders(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      }))
      .addHandler(router.call);

  // ── Health & Stats ────────────────────────────────────────────

  // GET /health
  router.get('/health', (req) async {
    final ps = locator.get<IPaperService>();
    final ns = locator.get<INoteService>();
    final ms = locator.get<IMemoryService>();
    return _ok({
      'status': 'ok',
      'papers': ps.papers.length,
      'notes': ns.getNotesForPaper('').length, // total approximation
      'version': '0.4.3',
    });
  });

  // GET /stats
  router.get('/stats', (req) async {
    final ps = locator.get<IPaperService>();
    final ns = locator.get<INoteService>();
    final ms = locator.get<IMemoryService>();
    final papers = ps.papers;
    return _ok({
      'totalPapers': papers.length,
      'parsed': papers.where((p) => p.status == PaperStatus.parsed).length,
      'translated': papers.where((p) => p.status == PaperStatus.translated).length,
      'starred': papers.where((p) => p.starred).length,
      'errors': papers.where((p) => p.status == PaperStatus.error).length,
      'totalNotes': papers.fold(0, (sum, p) => sum + ns.getNotesForPaper(p.id).length),
      'recentMemories': ms.getRecent(limit: 3).length,
    });
  });

  // ── Papers ────────────────────────────────────────────────────

  // GET /papers?status=parsed&starred=true
  router.get('/papers', (req) async {
    final ps = locator.get<IPaperService>();
    var list = ps.papers;
    // Filter by status
    final statusParam = req.url.queryParameters['status'];
    if (statusParam != null) {
      final s = PaperStatus.values.where((e) => e.name == statusParam);
      if (s.isNotEmpty) list = list.where((p) => p.status == s.first).toList();
    }
    // Filter by starred
    final starredParam = req.url.queryParameters['starred'];
    if (starredParam == 'true') list = list.where((p) => p.starred).toList();
    // Search by title
    final searchParam = req.url.queryParameters['q'];
    if (searchParam != null && searchParam.isNotEmpty) {
      final q = searchParam.toLowerCase();
      list = list.where((p) => p.title.toLowerCase().contains(q)).toList();
    }
    // Sort
    final sortParam = req.url.queryParameters['sort'];
    if (sortParam == 'recent') {
      list = List.from(list)
        ..sort((a, b) => (b.lastReadAt ?? b.importedAt ?? DateTime(0))
            .compareTo(a.lastReadAt ?? a.importedAt ?? DateTime(0)));
    }
    return _ok(list.map(_p).toList());
  });

  // GET /papers/:id
  router.get('/papers/<id>', (req, String id) async {
    final ps = locator.get<IPaperService>();
    final paper = ps.getPaper(id);
    if (paper == null) return _notFound('paper not found');
    return _ok(_p(paper));
  });

  // DELETE /papers/:id
  router.delete('/papers/<id>', (req, String id) async {
    final ps = locator.get<IPaperService>();
    await ps.deletePaper(id);
    return _ok({'deleted': true});
  });

  // PUT /papers/:id/star
  router.put('/papers/<id>/star', (req, String id) async {
    final ps = locator.get<IPaperService>();
    final paper = ps.getPaper(id);
    if (paper == null) return _notFound('paper not found');
    await ps.updatePaper(paper.copyWith(starred: !paper.starred));
    return _ok({'starred': !paper.starred});
  });

  // PUT /papers/:id/status
  router.put('/papers/<id>/status', (req, String id) async {
    final body = await _parseBody(req);
    final statusName = body['status'] as String?;
    if (statusName == null) return _badRequest('status required');
    final ps = locator.get<IPaperService>();
    final paper = ps.getPaper(id);
    if (paper == null) return _notFound('paper not found');
    final newStatus = PaperStatus.values.where((s) => s.name == statusName);
    if (newStatus.isEmpty) return _badRequest('invalid status: $statusName');
    await ps.updatePaper(paper.copyWith(status: newStatus.first));
    return _ok({'status': statusName});
  });

  // GET /papers/:id/content
  router.get('/papers/<id>/content', (req, String id) async {
    final ps = locator.get<IPaperService>();
    final content = await ps.getMarkdown(id);
    return _ok({'content': content});
  });

  // GET /papers/:id/translation
  router.get('/papers/<id>/translation', (req, String id) async {
    final ps = locator.get<IPaperService>();
    final translation = await ps.getTranslation(id);
    return _ok({'translation': translation});
  });

  // ── Search & Import ───────────────────────────────────────────

  // POST /search
  router.post('/search', (req) async {
    final body = await _parseBody(req);
    final query = body['query'] as String?;
    if (query == null || query.isEmpty) return _badRequest('query required');
    final ps = locator.get<IPaperService>();
    final (r, e) = await ps.search(query);
    if (e != null) return _error(e);
    return _ok(r.map(_sr).toList());
  });

  // POST /import/search
  router.post('/import/search', (req) async {
    final body = await _parseBody(req);
    final result = SearchResult(
      title: body['title'] as String? ?? '',
      pdfUrl: body['pdfUrl'] as String? ?? '',
      authors: [], year: 0, source: 'api',
    );
    if (result.title.isEmpty || result.pdfUrl.isEmpty) {
      return _badRequest('title and pdfUrl required');
    }
    final ps = locator.get<IPaperService>();
    final p = await ps.importFromSearch(result);
    if (p == null) return _error('import failed');
    return shelf.Response(201,
        body: jsonEncode(_p(p)),
        headers: {'content-type': 'application/json'});
  });

  // POST /convert — convert any document to Markdown (MarkItDown)
  router.post('/convert', (req) async {
    final body = await _parseBody(req);
    final filePath = body['path'] as String?;
    if (filePath == null || filePath.isEmpty) {
      return _badRequest('path required (file path on server)');
    }
    final file = File(filePath);
    if (!await file.exists()) return _notFound('file not found: $filePath');
    final converter = locator.get<IDocConversionService>();
    final result = await converter.convertToMarkdown(file);
    if (!result.success) return _error(result.error ?? 'conversion failed');
    return _ok({
      'markdown': result.markdown,
      'title': result.title,
      'length': result.markdown.length,
    });
  });

  // ── AI: Ask & Summarize ─────────────────────────────────────

  // POST /ask/:id (SSE stream)
  router.post('/ask/<id>', (req, String id) async {
    final body = await _parseBody(req);
    final question = body['question'] as String?;
    if (question == null || question.isEmpty) return _badRequest('question required');
    final ps = locator.get<IPaperService>();
    return _sseStream(ps.askQuestionStream(id, question));
  });

  // POST /ask/:id/sync (non-streaming)
  router.post('/ask/<id>/sync', (req, String id) async {
    final body = await _parseBody(req);
    final question = body['question'] as String?;
    if (question == null || question.isEmpty) return _badRequest('question required');
    final ps = locator.get<IPaperService>();
    final answer = await ps.askQuestion(id, question);
    return _ok({'answer': answer});
  });

  // POST /summarize/:id
  router.post('/summarize/<id>', (req, String id) async {
    final ps = locator.get<IPaperService>();
    return _ok({'summary': await ps.summarize(id)});
  });

  // ── Notes ─────────────────────────────────────────────────────

  // GET /notes/:paperId
  router.get('/notes/<paperId>', (req, String paperId) async {
    final ns = locator.get<INoteService>();
    return _ok(ns.getNotesForPaper(paperId).map(_n).toList());
  });

  // POST /notes/:paperId
  router.post('/notes/<paperId>', (req, String paperId) async {
    final body = await _parseBody(req);
    final text = body['text'] as String?;
    if (text == null || text.isEmpty) return _badRequest('text required');
    final typeStr = body['type'] as String?;
    final type = NoteType.values.where((t) => t.name == typeStr).firstOrNull ?? NoteType.note;
    final ns = locator.get<INoteService>();
    await ns.addNote(paperId: paperId, text: text, type: type);
    return shelf.Response(201,
        body: jsonEncode({'created': true}),
        headers: {'content-type': 'application/json'});
  });

  // DELETE /notes/:noteId
  router.delete('/notes/<noteId>', (req, String noteId) async {
    final ns = locator.get<INoteService>();
    await ns.deleteNote(noteId);
    return _ok({'deleted': true});
  });

  // ── Soul System ───────────────────────────────────────────────

  // GET /souls
  router.get('/souls', (req) async {
    final ss = locator.get<ISoulService>();
    return _ok({
      'active': _soulJson(ss.activeSoul ?? ss.getActiveOrDefault()),
      'presets': ss.presets.map(_soulJson).toList(),
      'custom': ss.custom.map(_soulJson).toList(),
    });
  });

  // GET /souls/active
  router.get('/souls/active', (req) async {
    final ss = locator.get<ISoulService>();
    return _ok(_soulJson(ss.activeSoul ?? ss.getActiveOrDefault()));
  });

  // PUT /souls/active
  router.put('/souls/active', (req) async {
    final body = await _parseBody(req);
    final id = body['id'] as String?;
    if (id == null || id.isEmpty) return _badRequest('id required');
    final ss = locator.get<ISoulService>();
    final allSouls = [...ss.presets, ...ss.custom];
    final soul = allSouls.where((s) => s.id == id).firstOrNull;
    if (soul == null) return _notFound('soul not found: $id');
    await ss.setActiveSoul(soul);
    return _ok({'active': soul.id, 'name': soul.name});
  });

  // POST /souls (create custom)
  router.post('/souls', (req) async {
    final body = await _parseBody(req);
    final name = body['name'] as String?;
    final description = body['description'] as String?;
    if (name == null || name.isEmpty) return _badRequest('name required');
    if (description == null || description.isEmpty) return _badRequest('description required');
    final ss = locator.get<ISoulService>();
    final llm = locator.get<ILLMProvider>();
    final soul = await ss.createCustomSoul(name, description, llm);
    return shelf.Response(201,
        body: jsonEncode(_soulJson(soul)),
        headers: {'content-type': 'application/json'});
  });

  // DELETE /souls/:id
  router.delete('/souls/<id>', (req, String id) async {
    final ss = locator.get<ISoulService>();
    await ss.deleteCustomSoul(id);
    return _ok({'deleted': true});
  });

  // ── Memory & Portrait ─────────────────────────────────────────

  // GET /memories
  router.get('/memories', (req) async {
    final ms = locator.get<IMemoryService>();
    final limitStr = req.url.queryParameters['limit'];
    final limit = int.tryParse(limitStr ?? '') ?? 10;
    return _ok(ms.getRecent(limit: limit).map((m) => {
      'summary': m.summary,
      if (m.paperId != null) 'paperId': m.paperId,
      if (m.timestamp != null) 'timestamp': m.timestamp?.toIso8601String(),
    }).toList());
  });

  // POST /memories/prune
  router.post('/memories/prune', (req) async {
    final ms = locator.get<IMemoryService>();
    await ms.prune();
    return _ok({'pruned': true});
  });

  // GET /portrait
  router.get('/portrait', (req) async {
    final ps = locator.get<IPortraitService>();
    return _ok({'portrait': ps.summarize()});
  });

  // ── Templates ─────────────────────────────────────────────────

  // GET /templates
  router.get('/templates', (req) async {
    final ts = locator.get<ITemplateService>();
    return _ok(ts.all.map((t) => {
      'id': t.id,
      'name': t.name,
      'description': t.description,
      'isBuiltin': t.isBuiltin,
      'markdown': t.markdown,
    }).toList());
  });

  // ── Config ────────────────────────────────────────────────────

  // GET /config (sanitized — no API keys)
  router.get('/config', (req) async {
    final cs = locator.get<IConfigService>();
    final cfg = cs.config;
    return _ok({
      'llmApiBase': cfg.llmApiBase,
      'llmModel': cfg.llmModel,
      'mineruModelVersion': cfg.mineruModelVersion,
      'autoTranslate': cfg.autoTranslate,
      'enableFormula': cfg.enableFormula,
      'enableTable': cfg.enableTable,
      'fontSize': cfg.fontSize,
      'themeMode': cfg.themeMode.name,
      'hasLlmKey': cs.hasLlmApiKey,
    });
  });

  // ── Export ────────────────────────────────────────────────────

  // POST /export/markdown/:id
  router.post('/export/markdown/<id>', (req, String id) async {
    final ps = locator.get<IPaperService>();
    final paper = ps.getPaper(id);
    if (paper == null) return _notFound('paper not found');
    final content = await ps.getMarkdown(id) ?? '';
    await ExportService.exportMarkdown(paper, content);
    return _ok({'exported': true, 'format': 'markdown', 'paperId': id});
  });

  // POST /export/bibtex/:id
  router.post('/export/bibtex/<id>', (req, String id) async {
    final ps = locator.get<IPaperService>();
    final paper = ps.getPaper(id);
    if (paper == null) return _notFound('paper not found');
    await ExportService.exportBibtex(paper);
    return _ok({'exported': true, 'format': 'bibtex', 'paperId': id});
  });

  // ── CORS preflight ────────────────────────────────────────────

  router.add('OPTIONS', r'/<path>', (req) => shelf.Response.ok(''));

  // ── Start ─────────────────────────────────────────────────────

  await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  _log.info('PaperPal API server running on http://localhost:$port');
}

// ── Middleware ─────────────────────────────────────────────────

shelf.Middleware _requestLogger() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      final sw = Stopwatch()..start();
      _log.info('${request.method} ${request.requestedUri.path}');
      try {
        final response = await innerHandler(request);
        _log.info('${request.method} ${request.requestedUri.path} → ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
        return response;
      } catch (e) {
        _log.warning('${request.method} ${request.requestedUri.path} → ERROR: $e (${sw.elapsedMilliseconds}ms)');
        return shelf.Response(500,
            body: jsonEncode({'error': '$e'}),
            headers: {'content-type': 'application/json'});
      }
    };
  };
}

// ── SSE Streaming ──────────────────────────────────────────────

shelf.Response _sseStream(Stream<String> dataStream) {
  final controller = StreamController<List<int>>();
  final encoder = utf8.encoder;

  dataStream.listen(
    (chunk) {
      controller.add(encoder.convert('data: ${jsonEncode({'chunk': chunk})}\n\n'));
    },
    onError: (e) {
      controller.add(encoder.convert('data: ${jsonEncode({'error': '$e'})}\n\n'));
      controller.close();
    },
    onDone: () => controller.close(),
  );

  return shelf.Response.ok(
    controller.stream,
    headers: {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-cache',
      'connection': 'keep-alive',
    },
  );
}

// ── Response helpers ───────────────────────────────────────────

shelf.Response _ok(Object data) =>
    shelf.Response.ok(jsonEncode(data), headers: {'content-type': 'application/json'});

shelf.Response _badRequest(String msg) =>
    shelf.Response(400,
        body: jsonEncode({'error': msg}),
        headers: {'content-type': 'application/json'});

shelf.Response _notFound(String msg) =>
    shelf.Response(404,
        body: jsonEncode({'error': msg}),
        headers: {'content-type': 'application/json'});

shelf.Response _error(String msg) =>
    shelf.Response(500,
        body: jsonEncode({'error': msg}),
        headers: {'content-type': 'application/json'});

Future<Map<String, dynamic>> _parseBody(shelf.Request req) async {
  final body = await req.readAsString();
  if (body.isEmpty) return {};
  return jsonDecode(body) as Map<String, dynamic>;
}

// ── Serializers ────────────────────────────────────────────────

Map<String, dynamic> _p(Paper p) => {
  'id': p.id,
  'title': p.title,
  'authors': p.authors,
  'year': p.year,
  'source': p.source,
  'doi': p.doi,
  'status': p.status.name,
  'sourceType': p.sourceType,
  'starred': p.starred,
  'pageCount': p.pageCount,
  'importedAt': p.importedAt?.toIso8601String(),
  'lastReadAt': p.lastReadAt?.toIso8601String(),
};

Map<String, dynamic> _sr(SearchResult r) => {
  'title': r.title,
  'authors': r.authors,
  'year': r.year,
  'abstract': r.abstract,
  'pdfUrl': r.pdfUrl,
  'source': r.source,
  'citationCount': r.citationCount,
};

Map<String, dynamic> _n(Note n) => {
  'id': n.id,
  'paperId': n.paperId,
  'text': n.text,
  'createdAt': n.createdAt.toIso8601String(),
  'type': n.type.name,
};

Map<String, dynamic> _soulJson(Soul s) => {
  'id': s.id,
  'name': s.name,
  'description': s.description,
  'traits': s.traits,
  'style': s.style,
  'specialty': s.specialty,
  'speechPattern': s.speechPattern,
  'isBuiltin': s.isBuiltin,
  'isCustom': s.isCustom,
};
