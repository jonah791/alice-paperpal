// PaperPal API Server — Flutter entry point
//
// Run:  flutter run -t lib/server_main.dart --dart-define=PORT=4090
// Build: flutter build windows --release -t lib/server_main.dart
//
// Starts an HTTP server using the full Flutter service layer.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'core/init.dart';
import 'core/di/service_locator.dart';
import 'core/interfaces/services.dart';
import 'core/models/paper.dart';
import 'core/models/search_result.dart';
import 'core/models/note.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  var port = 4090;
  if (args.contains('--port') && args.length > args.indexOf('--port') + 1) {
    port = int.tryParse(args[args.indexOf('--port') + 1]) ?? port;
  }

  final locator = await createLocator();
  await locator.get<IPaperService>().init();

  stdout.write('PaperPal API server running on http://localhost:$port\n');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  await for (final request in server) {
    try {
      await _handle(request, locator);
    } catch (e) {
      _json(request, 500, {'error': '$e'});
    }
  }
}

Future<void> _handle(HttpRequest req, ServiceLocator l) async {
  final path = Uri.parse(req.uri.toString()).pathSegments;
  final m = req.method;
  final ps = l.get<IPaperService>();
  final ns = l.get<INoteService>();

  // GET /health
  if (m == 'GET' && (path.isEmpty || path[0] == 'health'))
    return _json(req, 200, {'status': 'ok', 'papers': ps.papers.length});

  // GET /papers
  if (m == 'GET' && path.length == 1 && path[0] == 'papers')
    return _json(req, 200, ps.papers.map(_p).toList());

  // DELETE /papers/:id
  if (m == 'DELETE' && path.length == 2 && path[0] == 'papers')
    return _json(req, 200, {'deleted': await ps.deletePaper(path[1])});

  // GET /papers/:id/content , /papers/:id/translation
  if (m == 'GET' && path.length == 3 && path[0] == 'papers' && path[2] == 'content')
    return _json(req, 200, {'content': await ps.getMarkdown(path[1])});
  if (m == 'GET' && path.length == 3 && path[0] == 'papers' && path[2] == 'translation')
    return _json(req, 200, {'translation': await ps.getTranslation(path[1])});

  // POST /search
  if (m == 'POST' && path.length == 1 && path[0] == 'search') {
    final body = await _body(req);
    if ((body['query'] ?? '').isEmpty) return _json(req, 400, {'error': 'query required'});
    final (r, e) = await ps.search(body['query'] as String);
    if (e != null) return _json(req, 500, {'error': e});
    return _json(req, 200, r.map(_sr).toList());
  }

  // POST /import/search
  if (m == 'POST' && path.length == 2 && path[0] == 'import' && path[1] == 'search') {
    final body = await _body(req);
    final result = SearchResult(title: body['title'] ?? '', pdfUrl: body['pdfUrl'] ?? '', authors: [], year: 0, source: 'api');
    if (result.title.isEmpty || result.pdfUrl.isEmpty) return _json(req, 400, {'error': 'title and pdfUrl required'});
    final p = await ps.importFromSearch(result);
    return _json(req, p != null ? 201 : 500, p != null ? _p(p) : {'error': 'import failed'});
  }

  // POST /ask/:id (SSE stream)
  if (m == 'POST' && path.length == 2 && path[0] == 'ask') {
    final body = await _body(req);
    final question = body['question'] as String? ?? '';
    if (question.isEmpty) return _json(req, 400, {'error': 'question required'});
    req.response.headers.contentType = ContentType('text', 'event-stream', charset: 'utf-8');
    req.response.headers.set('Cache-Control', 'no-cache');
    try {
      await for (final chunk in ps.askQuestionStream(path[1], question)) {
        req.response.writeln('data: ${jsonEncode({'chunk': chunk})}');
      }
    } catch (e) {
      req.response.writeln('data: ${jsonEncode({'error': '$e'})}');
    }
    return req.response.close();
  }

  // POST /summarize/:id
  if (m == 'POST' && path.length == 2 && path[0] == 'summarize')
    return _json(req, 200, {'summary': await ps.summarize(path[1])});

  // GET/POST/DELETE /notes/...
  if (m == 'GET' && path.length == 2 && path[0] == 'notes')
    return _json(req, 200, ns.getNotesForPaper(path[1]).map(_n).toList());
  if (m == 'POST' && path.length == 2 && path[0] == 'notes') {
    final b = await _body(req);
    if ((b['text'] ?? '').isEmpty) return _json(req, 400, {'error': 'text required'});
    await ns.addNote(paperId: path[1], text: b['text'] as String);
    return _json(req, 201, {'created': true});
  }
  if (m == 'DELETE' && path.length == 2 && path[0] == 'notes')
    return _json(req, 200, {'deleted': await ns.deleteNote(path[1])});

  _json(req, 404, {'error': 'not found'});
}

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

Future<Map<String, dynamic>> _body(HttpRequest r) async {
  final b = await r.fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d));
  return jsonDecode(String.fromCharCodes(b.takeBytes())) as Map<String, dynamic>;
}

void _json(HttpRequest r, int s, Object d) {
  r.response.statusCode = s;
  r.response.headers.contentType = ContentType.json;
  r.response.write(jsonEncode(d));
  r.response.close();
}
