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
        'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      }))
      .addHandler(router.call);

  // ── Routes ────────────────────────────────────────────────────

  // GET /health
  router.get('/health', (req) async {
    final ps = locator.get<IPaperService>();
    return _ok({'status': 'ok', 'papers': ps.papers.length});
  });

  // GET /papers
  router.get('/papers', (req) async {
    final ps = locator.get<IPaperService>();
    return _ok(ps.papers.map(_p).toList());
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
    return shelf.Response(201, body: jsonEncode(_p(p)), headers: {'content-type': 'application/json'});
  });

  // POST /ask/:id (SSE stream)
  router.post('/ask/<id>', (req, String id) async {
    final body = await _parseBody(req);
    final question = body['question'] as String?;
    if (question == null || question.isEmpty) return _badRequest('question required');
    final ps = locator.get<IPaperService>();
    return _sseStream(ps.askQuestionStream(id, question));
  });

  // POST /summarize/:id
  router.post('/summarize/<id>', (req, String id) async {
    final ps = locator.get<IPaperService>();
    return _ok({'summary': await ps.summarize(id)});
  });

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
    final ns = locator.get<INoteService>();
    await ns.addNote(paperId: paperId, text: text);
    return shelf.Response(201, body: jsonEncode({'created': true}), headers: {'content-type': 'application/json'});
  });

  // DELETE /notes/:noteId
  router.delete('/notes/<noteId>', (req, String noteId) async {
    final ns = locator.get<INoteService>();
    await ns.deleteNote(noteId);
    return _ok({'deleted': true});
  });

  // OPTIONS handler (CORS preflight)
  router.add('OPTIONS', r'/<path>', (req) => shelf.Response.ok(''));

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
        return shelf.Response(500, body: jsonEncode({'error': '$e'}), headers: {'content-type': 'application/json'});
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
    shelf.Response(400, body: jsonEncode({'error': msg}), headers: {'content-type': 'application/json'});

shelf.Response _notFound(String msg) =>
    shelf.Response(404, body: jsonEncode({'error': msg}), headers: {'content-type': 'application/json'});

shelf.Response _error(String msg) =>
    shelf.Response(500, body: jsonEncode({'error': msg}), headers: {'content-type': 'application/json'});

Future<Map<String, dynamic>> _parseBody(shelf.Request req) async {
  final body = await req.readAsString();
  if (body.isEmpty) return {};
  return jsonDecode(body) as Map<String, dynamic>;
}

// ── Serializers ────────────────────────────────────────────────

Map<String, dynamic> _p(Paper p) => {
  'id': p.id, 'title': p.title, 'authors': p.authors, 'year': p.year,
  'source': p.source, 'status': p.status.name, 'sourceType': p.sourceType,
  'importedAt': p.importedAt?.toIso8601String(), 'lastReadAt': p.lastReadAt?.toIso8601String(),
};

Map<String, dynamic> _sr(SearchResult r) => {
  'title': r.title, 'authors': r.authors, 'year': r.year, 'abstract': r.abstract,
  'pdfUrl': r.pdfUrl, 'source': r.source, 'citationCount': r.citationCount,
};

Map<String, dynamic> _n(Note n) => {
  'id': n.id, 'paperId': n.paperId, 'text': n.text,
  'createdAt': n.createdAt.toIso8601String(), 'type': n.type.name,
};
