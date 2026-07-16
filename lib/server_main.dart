/// PaperPal API Server — Kori 风格重写
///
/// 使用 shelf + shelf_router，模块化路由注册。
/// 运行: flutter run -t lib/server_main.dart --dart-define=PORT=4090
/// 构建: flutter build windows --release -t lib/server_main.dart

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
import 'core/di/service_locator.dart';
import 'core/interfaces/services.dart';
import 'core/models/paper.dart';
import 'core/models/search_result.dart';
import 'core/models/note.dart';
import 'core/models/soul.dart';
import 'core/services/export_service.dart';

final _log = Logger('Server');
const _version = '0.5.0';

// ─── Entry Point ────────────────────────────────────────────────

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final port = _parsePort(args);
  final locator = await createLocator();
  await locator.get<IPaperService>().init();

  final router = Router();
  _registerRoutes(router, locator);

  // 静态文件服务 (Web UI)
  final webDir = Directory('web');
  final staticHandler = (shelf.Request req) async {
    var path = req.url.path;
    if (path.isEmpty || path == '/') path = 'index.html';
    final file = File('${webDir.path}/$path');
    if (await file.exists()) {
      final ext = path.split('.').last;
      final mime = _mimeTypes[ext] ?? 'application/octet-stream';
      return shelf.Response.ok(await file.readAsBytes(),
          headers: {'content-type': mime, 'cache-control': 'no-cache'});
    }
    // SPA fallback: 为所有非 API 路径返回 index.html
    if (!path.startsWith('api/')) {
      final index = File('${webDir.path}/index.html');
      if (await index.exists()) {
        return shelf.Response.ok(await index.readAsString(),
            headers: {'content-type': 'text/html; charset=utf-8'});
      }
    }
    return shelf.Response.notFound('Not found');
  };

  final handler = shelf.Pipeline()
      .addMiddleware(_requestLogger())
      .addMiddleware(corsHeaders(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      }))
      .addHandler((req) async {
        // API 路由优先
        final response = await router.call(req);
        if (response.statusCode != 404) return response;
        // 404 → 尝试静态文件
        return staticHandler(req);
      });

  await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  _log.info('PaperPal API server v$_version running on http://localhost:$port');
  // 自动打开浏览器
  if (await File('web/index.html').exists()) {
    _log.info('Web UI: http://localhost:$port');
  }
}

int _parsePort(List<String> args) {
  final idx = args.indexOf('--port');
  if (idx != -1 && idx + 1 < args.length) {
    return int.tryParse(args[idx + 1]) ?? 4090;
  }
  return 4090;
}

// ─── Route Registration ─────────────────────────────────────────

void _registerRoutes(Router router, ServiceLocator loc) {
  _healthRoutes(router, loc);
  _paperRoutes(router, loc);
  _searchRoutes(router, loc);
  _aiRoutes(router, loc);
  _noteRoutes(router, loc);
  _soulRoutes(router, loc);
  _memoryRoutes(router, loc);
  _templateRoutes(router, loc);
  _configRoutes(router, loc);
  _exportRoutes(router, loc);

  // CORS preflight
  router.add('OPTIONS', r'/<path>', (req) => shelf.Response.ok(''));
}

// ── Health ──────────────────────────────────────────────────────

void _healthRoutes(Router r, ServiceLocator loc) {
  r.get('/health', (req) {
    final ps = loc.get<IPaperService>();
    final ns = loc.get<INoteService>();
    return _ok({
      'status': 'ok',
      'papers': ps.papers.length,
      'notes': ns.getNotesForPaper('').length,
      'version': _version,
    });
  });

  r.get('/stats', (req) {
    final ps = loc.get<IPaperService>();
    final ns = loc.get<INoteService>();
    final ms = loc.get<IMemoryService>();
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
}

// ── Papers ──────────────────────────────────────────────────────

void _paperRoutes(Router r, ServiceLocator loc) {
  r.get('/papers', (req) {
    final ps = loc.get<IPaperService>();
    var list = ps.papers;
    final statusParam = req.url.queryParameters['status'];
    if (statusParam != null) {
      final s = PaperStatus.values.where((e) => e.name == statusParam);
      if (s.isNotEmpty) list = list.where((p) => p.status == s.first).toList();
    }
    if (req.url.queryParameters['starred'] == 'true') {
      list = list.where((p) => p.starred).toList();
    }
    final q = req.url.queryParameters['q'];
    if (q != null && q.isNotEmpty) {
      list = list.where((p) => p.title.toLowerCase().contains(q)).toList();
    }
    if (req.url.queryParameters['sort'] == 'recent') {
      list = List.from(list)..sort((a, b) =>
          (b.lastReadAt ?? b.importedAt ?? DateTime(0))
              .compareTo(a.lastReadAt ?? a.importedAt ?? DateTime(0)));
    }
    return _ok(list.map(_p).toList());
  });

  r.get('/papers/<id>', (req, String id) {
    final paper = loc.get<IPaperService>().getPaper(id);
    return paper != null ? _ok(_p(paper)) : _notFound('paper not found');
  });

  r.delete('/papers/<id>', (req, String id) async {
    await loc.get<IPaperService>().deletePaper(id);
    return _ok({'deleted': true});
  });

  r.put('/papers/<id>/star', (req, String id) async {
    final ps = loc.get<IPaperService>();
    final paper = ps.getPaper(id);
    if (paper == null) return _notFound('paper not found');
    await ps.updatePaper(paper.copyWith(starred: !paper.starred));
    return _ok({'starred': !paper.starred});
  });

  r.put('/papers/<id>/status', (req, String id) async {
    final body = await _parseBody(req);
    final statusName = body['status'] as String?;
    if (statusName == null) return _badRequest('status required');
    final ps = loc.get<IPaperService>();
    final paper = ps.getPaper(id);
    if (paper == null) return _notFound('paper not found');
    final s = PaperStatus.values.where((e) => e.name == statusName);
    if (s.isEmpty) return _badRequest('invalid status');
    await ps.updatePaper(paper.copyWith(status: s.first));
    return _ok({'status': statusName});
  });

  r.get('/papers/<id>/content', (req, String id) async {
    final content = await loc.get<IPaperService>().getMarkdown(id);
    return _ok({'content': content});
  });

  r.get('/papers/<id>/translation', (req, String id) async {
    final t = await loc.get<IPaperService>().getTranslation(id);
    return _ok({'translation': t});
  });
}

// ── Search & Import ─────────────────────────────────────────────

void _searchRoutes(Router r, ServiceLocator loc) {
  r.post('/search', (req) async {
    final body = await _parseBody(req);
    final query = body['query'] as String?;
    if (query == null || query.isEmpty) return _badRequest('query required');
    final (results, error) = await loc.get<IPaperService>().search(query);
    return error != null ? _error(error) : _ok(results.map(_sr).toList());
  });

  r.post('/import/search', (req) async {
    final body = await _parseBody(req);
    final result = SearchResult(
      title: body['title'] as String? ?? '',
      pdfUrl: body['pdfUrl'] as String? ?? '',
      authors: [], year: 0, source: 'api',
    );
    if (result.title.isEmpty || result.pdfUrl.isEmpty) {
      return _badRequest('title and pdfUrl required');
    }
    final paper = await loc.get<IPaperService>().importFromSearch(result);
    if (paper == null) return _error('import failed');
    return shelf.Response(201, body: jsonEncode(_p(paper)), headers: hdrJson);
  });

  r.post('/convert', (req) async {
    final body = await _parseBody(req);
    final filePath = body['path'] as String?;
    if (filePath == null || filePath.isEmpty) return _badRequest('path required');
    final file = File(filePath);
    if (!await file.exists()) return _notFound('file not found');
    final result = await loc.get<IDocConversionService>().convertToMarkdown(file);
    if (!result.success) return _error(result.error ?? 'conversion failed');
    return _ok({'markdown': result.markdown, 'title': result.title, 'length': result.markdown.length});
  });
}

// ── AI ──────────────────────────────────────────────────────────

void _aiRoutes(Router r, ServiceLocator loc) {
  r.post('/ask/<id>', (req, String id) async {
    final body = await _parseBody(req);
    final q = body['question'] as String?;
    if (q == null || q.isEmpty) return _badRequest('question required');
    return _sseStream(loc.get<IPaperService>().askQuestionStream(id, q));
  });

  r.post('/ask/<id>/sync', (req, String id) async {
    final body = await _parseBody(req);
    final q = body['question'] as String?;
    if (q == null || q.isEmpty) return _badRequest('question required');
    return _ok({'answer': await loc.get<IPaperService>().askQuestion(id, q)});
  });

  r.post('/summarize/<id>', (req, String id) async {
    return _ok({'summary': await loc.get<IPaperService>().summarize(id)});
  });
}

// ── Notes ───────────────────────────────────────────────────────

void _noteRoutes(Router r, ServiceLocator loc) {
  r.get('/notes/<paperId>', (req, String paperId) {
    return _ok(loc.get<INoteService>().getNotesForPaper(paperId).map(_n).toList());
  });

  r.post('/notes/<paperId>', (req, String paperId) async {
    final body = await _parseBody(req);
    final text = body['text'] as String?;
    if (text == null || text.isEmpty) return _badRequest('text required');
    final typeStr = body['type'] as String?;
    final t = typeStr != null
        ? NoteType.values.where((e) => e.name == typeStr).firstOrNull ?? NoteType.note
        : NoteType.note;
    await loc.get<INoteService>().addNote(paperId: paperId, text: text, type: t);
    return shelf.Response(201, body: jsonEncode({'created': true}), headers: hdrJson);
  });

  r.delete('/notes/<noteId>', (req, String noteId) async {
    await loc.get<INoteService>().deleteNote(noteId);
    return _ok({'deleted': true});
  });
}

// ── Souls ───────────────────────────────────────────────────────

void _soulRoutes(Router r, ServiceLocator loc) {
  r.get('/souls', (req) {
    final ss = loc.get<ISoulService>();
    return _ok({
      'active': _soulJson(ss.activeSoul ?? ss.getActiveOrDefault()),
      'presets': ss.presets.map(_soulJson).toList(),
      'custom': ss.custom.map(_soulJson).toList(),
    });
  });

  r.get('/souls/active', (req) => _ok(_soulJson(loc.get<ISoulService>().activeSoul ?? loc.get<ISoulService>().getActiveOrDefault())));

  r.put('/souls/active', (req) async {
    final body = await _parseBody(req);
    final id = body['id'] as String?;
    if (id == null) return _badRequest('id required');
    final ss = loc.get<ISoulService>();
    final soul = [...ss.presets, ...ss.custom].where((s) => s.id == id).firstOrNull;
    if (soul == null) return _notFound('soul not found');
    await ss.setActiveSoul(soul!);
    return _ok({'active': soul.id, 'name': soul.name});
  });

  r.post('/souls', (req) async {
    final body = await _parseBody(req);
    final name = body['name'] as String?;
    final desc = body['description'] as String?;
    if (name == null || name.isEmpty) return _badRequest('name required');
    if (desc == null || desc.isEmpty) return _badRequest('description required');
    final soul = await loc.get<ISoulService>().createCustomSoul(name, desc, loc.get<ILLMProvider>());
    return shelf.Response(201, body: jsonEncode(_soulJson(soul)), headers: hdrJson);
  });

  r.delete('/souls/<id>', (req, String id) async {
    await loc.get<ISoulService>().deleteCustomSoul(id);
    return _ok({'deleted': true});
  });
}

// ── Memory & Portrait ───────────────────────────────────────────

void _memoryRoutes(Router r, ServiceLocator loc) {
  r.get('/memories', (req) {
    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 10;
    return _ok(loc.get<IMemoryService>().getRecent(limit: limit).map((m) => {
      'summary': m.summary,
      if (m.paperId != null) 'paperId': m.paperId,
      if (m.timestamp != null) 'timestamp': m.timestamp?.toIso8601String(),
    }).toList());
  });

  r.post('/memories/prune', (req) async {
    await loc.get<IMemoryService>().prune();
    return _ok({'pruned': true});
  });

  r.get('/portrait', (req) => _ok({'portrait': loc.get<IPortraitService>().summarize()}));
}

// ── Templates ───────────────────────────────────────────────────

void _templateRoutes(Router r, ServiceLocator loc) {
  r.get('/templates', (req) {
    return _ok(loc.get<ITemplateService>().all.map((t) => {
      'id': t.id, 'name': t.name, 'description': t.description,
      'isBuiltin': t.isBuiltin, 'markdown': t.markdown,
    }).toList());
  });
}

// ── Config ──────────────────────────────────────────────────────

void _configRoutes(Router r, ServiceLocator loc) {
  r.get('/config', (req) {
    final cfg = loc.get<IConfigService>().config;
    return _ok({
      'llmApiBase': cfg.llmApiBase, 'llmModel': cfg.llmModel,
      'mineruModelVersion': cfg.mineruModelVersion,
      'autoTranslate': cfg.autoTranslate, 'enableFormula': cfg.enableFormula, 'enableTable': cfg.enableTable,
      'fontSize': cfg.fontSize, 'themeMode': cfg.themeMode.name,
      'hasLlmKey': loc.get<IConfigService>().hasLlmApiKey,
      'version': _version,
    });
  });
}

// ── Export ──────────────────────────────────────────────────────

void _exportRoutes(Router r, ServiceLocator loc) {
  r.post('/export/markdown/<id>', (req, String id) async {
    final ps = loc.get<IPaperService>();
    final paper = ps.getPaper(id);
    if (paper == null) return _notFound('paper not found');
    await ExportService.exportMarkdown(paper, await ps.getMarkdown(id) ?? '');
    return _ok({'exported': true, 'format': 'markdown'});
  });

  r.post('/export/bibtex/<id>', (req, String id) async {
    final paper = loc.get<IPaperService>().getPaper(id);
    if (paper == null) return _notFound('paper not found');
    await ExportService.exportBibtex(paper);
    return _ok({'exported': true, 'format': 'bibtex'});
  });
}

// ─── Middleware ─────────────────────────────────────────────────

shelf.Middleware _requestLogger() {
  return (inner) => (request) async {
    final sw = Stopwatch()..start();
    _log.info('${request.method} ${request.requestedUri.path}');
    try {
      final response = await inner(request);
      _log.info('${request.method} ${request.requestedUri.path} → ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
      return response;
    } catch (e) {
      _log.warning('${request.method} ${request.requestedUri.path} → ERROR: $e');
      return _serverError('$e');
    }
  };
}

// ─── SSE Streaming ──────────────────────────────────────────────

shelf.Response _sseStream(Stream<String> data) {
  final ctrl = StreamController<List<int>>();
  data.listen(
    (chunk) => ctrl.add(utf8.encode('data: ${jsonEncode({'chunk': chunk})}\n\n')),
    onError: (e) { ctrl.add(utf8.encode('data: ${jsonEncode({'error': '$e'})}\n\n')); ctrl.close(); },
    onDone: () => ctrl.close(),
  );
  return shelf.Response.ok(ctrl.stream, headers: {
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-cache',
    'connection': 'keep-alive',
  });
}

// ─── Response Helpers ───────────────────────────────────────────

const _mimeTypes = <String, String>{
  'html': 'text/html; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'js': 'application/javascript; charset=utf-8',
  'json': 'application/json',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'svg': 'image/svg+xml',
  'ico': 'image/x-icon',
  'woff2': 'font/woff2',
  'ttf': 'font/ttf',
};

const hdrJson = {'content-type': 'application/json'};

shelf.Response _ok(Object d) => shelf.Response.ok(jsonEncode(d), headers: hdrJson);
shelf.Response _badRequest(String m) => shelf.Response(400, body: jsonEncode({'error': m}), headers: hdrJson);
shelf.Response _notFound(String m) => shelf.Response(404, body: jsonEncode({'error': m}), headers: hdrJson);
shelf.Response _error(String m) => shelf.Response(500, body: jsonEncode({'error': m}), headers: hdrJson);
shelf.Response _serverError(String m) => shelf.Response(500, body: jsonEncode({'error': m}), headers: hdrJson);

Future<Map<String, dynamic>> _parseBody(shelf.Request req) async {
  final body = await req.readAsString();
  return body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
}

// ─── Serializers ────────────────────────────────────────────────

Map<String, dynamic> _p(Paper p) => {
  'id': p.id, 'title': p.title, 'authors': p.authors, 'year': p.year,
  'source': p.source, 'doi': p.doi, 'status': p.status.name,
  'sourceType': p.sourceType, 'starred': p.starred, 'pageCount': p.pageCount,
  'importedAt': p.importedAt?.toIso8601String(), 'lastReadAt': p.lastReadAt?.toIso8601String(),
};

Map<String, dynamic> _sr(SearchResult r) => {
  'title': r.title, 'authors': r.authors, 'year': r.year,
  'abstract': r.abstract, 'pdfUrl': r.pdfUrl, 'source': r.source, 'citationCount': r.citationCount,
};

Map<String, dynamic> _n(Note n) => {
  'id': n.id, 'paperId': n.paperId, 'text': n.text,
  'createdAt': n.createdAt.toIso8601String(), 'type': n.type.name,
};

Map<String, dynamic> _soulJson(Soul s) => {
  'id': s.id, 'name': s.name, 'description': s.description, 'traits': s.traits,
  'style': s.style, 'specialty': s.specialty, 'speechPattern': s.speechPattern,
  'isBuiltin': s.isBuiltin, 'isCustom': s.isCustom,
};
