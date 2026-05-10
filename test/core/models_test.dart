import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' as m;
import 'package:paperpal/core/models/paper.dart';
import 'package:paperpal/core/models/parse_result.dart';
import 'package:paperpal/core/models/search_result.dart';
import 'package:paperpal/core/models/config.dart';
import 'package:paperpal/core/models/app_error.dart';
import 'package:paperpal/core/models/soul.dart';
import 'package:paperpal/core/models/note.dart';
import 'package:paperpal/core/services/memory_service.dart';

void main() {
  group('Paper', () {
    test('defaults', () {
      final p = Paper(id: 'x', title: 'T');
      expect(p.id, 'x');
      expect(p.title, 'T');
      expect(p.authors, isEmpty);
      expect(p.year, 0);
      expect(p.source, 'local');
      expect(p.doi, '');
      expect(p.status, PaperStatus.importing);
      expect(p.pageCount, 0);
      expect(p.tags, isEmpty);
    });

    test('full constructor', () {
      final t = DateTime(2024, 6, 1);
      final p = Paper(
        id: '1', title: 'T', authors: ['A'], year: 2024,
        source: 'arXiv', doi: '10.1234/ab', status: PaperStatus.parsed,
        pageCount: 10, importedAt: t, lastReadAt: t, tags: ['ML'],
      );
      expect(p.authors, ['A']);
      expect(p.year, 2024);
      expect(p.source, 'arXiv');
      expect(p.lastReadAt, t);
    });

    test('copyWith is immutable', () {
      final p = Paper(id: '1', title: 'O', authors: ['A']);
      p.copyWith(title: 'C', authors: ['B']);
      expect(p.title, 'O');
      expect(p.authors, ['A']);
    });

    test('copyWith overrides single field', () {
      final p = Paper(id: '1', title: 'T', authors: ['A'], year: 2020);
      final u = p.copyWith(title: 'New');
      expect(u.title, 'New');
      expect(u.authors, ['A']);
      expect(u.year, 2020);
    });

    test('toJson fromJson round-trip', () {
      final t = DateTime(2024, 1, 1);
      final p = Paper(
        id: 'x', title: 'T', authors: ['A'], year: 2024,
        source: 'arXiv', doi: '10.1', status: PaperStatus.translated,
        pageCount: 15, importedAt: t, lastReadAt: t, tags: ['AI'],
      );
      final r = Paper.fromJson(p.toJson());
      expect(r.id, p.id);
      expect(r.title, p.title);
      expect(r.authors, p.authors);
      expect(r.year, p.year);
      expect(r.doi, p.doi);
      expect(r.status, p.status);
      expect(r.pageCount, p.pageCount);
      expect(r.tags, p.tags);
      expect(r.importedAt?.toIso8601String(), t.toIso8601String());
    });

    test('fromJson missing fields', () {
      final r = Paper.fromJson({'id': '1', 'title': 'T'});
      expect(r.id, '1');
      expect(r.authors, isEmpty);
      expect(r.status, PaperStatus.importing);
    });

    test('fromJson null dates', () {
      final r = Paper.fromJson({'id': '1', 'title': 'T', 'importedAt': null});
      expect(r.importedAt, isNull);
    });

    test('fromJson invalid date string', () {
      final r = Paper.fromJson({'id': '1', 'title': 'T', 'importedAt': 'bad'});
      expect(r.importedAt, isNull);
    });

    test('fromJson unknown status defaults to importing', () {
      final r = Paper.fromJson({'id': '1', 'title': 'T', 'status': 'alien'});
      expect(r.status, PaperStatus.importing);
    });

    test('fromJson empty id', () {
      final r = Paper.fromJson({'title': 'T'});
      expect(r.id, '');
    });

    test('PaperStatus has 7 values', () {
      expect(PaperStatus.values, [
        PaperStatus.importing, PaperStatus.downloading, PaperStatus.parsing,
        PaperStatus.parsed, PaperStatus.translating, PaperStatus.translated,
        PaperStatus.error,
      ]);
    });
  });

  group('ParseResult', () {
    test('defaults', () {
      final r = ParseResult(markdown: '# M');
      expect(r.markdown, '# M');
      expect(r.title, '');
      expect(r.imagePaths, isEmpty);
    });

    test('empty markdown', () {
      final r = ParseResult(markdown: '');
      expect(r.contentListJson, '');
    });

    test('full fields', () {
      final r = ParseResult(
        markdown: '# T', title: 'T', imagePaths: ['a.png'],
        contentListJson: '[]', startPage: 1, endPage: 5,
      );
      expect(r.title, 'T');
      expect(r.imagePaths, hasLength(1));
      expect(r.startPage, 1);
    });

    test('ParseProgress construction', () {
      final p = ParseProgress(currentBatch: 1, totalBatches: 3, currentPage: 0, totalPages: 10);
      expect(p.totalBatches, 3);
      expect(p.totalPages, 10);
    });
  });

  group('SearchResult', () {
    test('defaults', () {
      final r = SearchResult(title: 'T', authors: []);
      expect(r.year, 0);
      expect(r.abstract, '');
      expect(r.pdfUrl, '');
      expect(r.citationCount, 0);
    });

    test('full fields', () {
      final r = SearchResult(
        title: 'T', authors: ['A', 'B'], year: 2024,
        abstract: 'abs', pdfUrl: 'https://x.com/p.pdf',
        source: 'arXiv', doi: '10.1', citationCount: 42,
      );
      expect(r.authors, ['A', 'B']);
      expect(r.pdfUrl, 'https://x.com/p.pdf');
      expect(r.citationCount, 42);
    });

    test('empty pdfUrl', () {
      final r = SearchResult(title: 'T', authors: ['A']);
      expect(r.pdfUrl, isEmpty);
    });
  });

  group('AppConfig', () {
    test('defaults', () {
      final c = AppConfig();
      expect(c.defaultProvider, 'deepseek');
      expect(c.llmModel, 'deepseek-v4-flash');
      expect(c.llmApiBase, 'https://api.deepseek.com');
      expect(c.mineruModelVersion, 'vlm');
      expect(c.enableFormula, true);
      expect(c.enableTable, true);
      expect(c.autoTranslate, true);
      expect(c.batchSize, 50);
    });

    test('copyWith overrides', () {
      final c = AppConfig();
      final u = c.copyWith(llmApiBase: 'https://c.c', batchSize: 10, enableFormula: false);
      expect(u.llmApiBase, 'https://c.c');
      expect(u.batchSize, 10);
      expect(u.enableFormula, false);
    });

    test('copyWith preserves unset', () {
      final c = AppConfig(llmModel: 'gpt-4', mineruModelVersion: 'pipeline');
      final u = c.copyWith(llmApiBase: 'https://o.c');
      expect(u.llmModel, 'gpt-4');
      expect(u.mineruModelVersion, 'pipeline');
      expect(u.defaultProvider, 'deepseek');
    });

    test('all fields', () {
      final c = AppConfig(
        defaultProvider: 'o', llmModel: 'g', llmApiBase: 'https://o.c',
        mineruModelVersion: 'p', autoTranslate: false, enableFormula: false,
        enableTable: false, forceDarkMode: true, themeMode: AppThemeMode.dark,
        fontSize: 20.0, batchSize: 5, logRetentionDays: 30,
      );
      expect(c.mineruModelVersion, 'p');
      expect(c.enableFormula, false);
      expect(c.logRetentionDays, 30);
    });
  });

  group('AppThemeMode', () {
    test('system', () => expect(AppThemeMode.system.toFlutterThemeMode(), m.ThemeMode.system));
    test('light', () => expect(AppThemeMode.light.toFlutterThemeMode(), m.ThemeMode.light));
    test('dark', () => expect(AppThemeMode.dark.toFlutterThemeMode(), m.ThemeMode.dark));
  });

  group('AppError', () {
    test('network', () {
      final e = AppError.network('lost');
      expect(e.type, 'network');
      expect(e.retryable, true);
      expect(e.statusCode, isNull);
    });

    test('network with status', () {
      final e = AppError.network('nf', statusCode: 404, retryable: false);
      expect(e.statusCode, 404);
      expect(e.retryable, false);
    });

    test('api', () {
      final e = AppError.api('RATE', 'too fast');
      expect(e.type, 'api');
      expect(e.message, 'RATE: too fast');
    });

    test('parse', () {
      final e = AppError.parse(2, 10);
      expect(e.message, '2/10 batches failed');
      expect(e.failedBatches, 2);
      expect(e.totalBatches, 10);
    });

    test('config', () {
      final e = AppError.config('bad key');
      expect(e.type, 'config');
    });

    test('unknown', () {
      final e = AppError.unknown('boom');
      expect(e.type, 'unknown');
    });
  });

  group('Soul', () {
    test('defaults', () {
      final s = Soul(id: 'a', name: 'N', description: 'D', systemPrompt: 'P');
      expect(s.traits, isEmpty);
      expect(s.style, '');
      expect(s.speechPattern, isNull);
      expect(s.isBuiltin, false);
      expect(s.isCustom, false);
    });

    test('full constructor', () {
      final s = Soul(
        id: 'c', name: 'N', description: 'D', traits: ['a', 'b'],
        style: 's', specialty: 'sp', systemPrompt: 'P',
        speechPattern: 'like', isBuiltin: true, isCustom: false,
      );
      expect(s.traits, ['a', 'b']);
      expect(s.speechPattern, 'like');
      expect(s.isBuiltin, true);
    });

    test('toJson fromJson round-trip', () {
      final s = Soul(
        id: 'x', name: 'N', description: 'D', traits: ['a'],
        style: 'S', specialty: 'Sp', systemPrompt: 'P', speechPattern: 'like',
        isBuiltin: true, isCustom: false,
      );
      final r = Soul.fromJson(s.toJson());
      expect(r.id, s.id);
      expect(r.name, s.name);
      expect(r.traits, s.traits);
      expect(r.systemPrompt, s.systemPrompt);
      expect(r.speechPattern, s.speechPattern);
      expect(r.isBuiltin, s.isBuiltin);
    });

    test('fromJson missing optional fields', () {
      final r = Soul.fromJson({'id': '1', 'name': 'N', 'systemPrompt': 'P'});
      expect(r.traits, isEmpty);
      expect(r.speechPattern, isNull);
      expect(r.isBuiltin, false);
    });

    test('fromJson empty string fields', () {
      final r = Soul.fromJson({'id': '', 'name': '', 'systemPrompt': ''});
      expect(r.id, '');
      expect(r.description, '');
    });
  });

  group('Note', () {
    test('defaults', () {
      final t = DateTime.now();
      final n = Note(id: 'n1', paperId: 'p1', text: 't', createdAt: t, updatedAt: t);
      expect(n.type, NoteType.note);
      expect(n.selectedText, isNull);
      expect(n.offset, isNull);
    });

    test('full constructor', () {
      final t = DateTime(2024, 6, 1);
      final n = Note(id: 'n1', paperId: 'p1', text: 't', createdAt: t, updatedAt: t,
          type: NoteType.highlight, selectedText: 'sel', offset: 10);
      expect(n.selectedText, 'sel');
      expect(n.offset, 10);
    });

    test('toJson fromJson round-trip', () {
      final t = DateTime(2024, 6, 1, 10, 30);
      final n = Note(id: 'n1', paperId: 'p1', text: 't', createdAt: t, updatedAt: t,
          type: NoteType.question, selectedText: 'sel', offset: 5);
      final r = Note.fromJson(n.toJson());
      expect(r.id, n.id);
      expect(r.text, n.text);
      expect(r.type, n.type);
      expect(r.selectedText, n.selectedText);
      expect(r.offset, n.offset);
    });

    test('fromJson missing fields', () {
      final r = Note.fromJson({'id': 'n1', 'paperId': 'p1', 'text': 't'});
      expect(r.type, NoteType.note);
      expect(r.selectedText, isNull);
    });

    test('copyWith updates text and updatedAt', () {
      final t = DateTime(2024, 1, 1);
      final n = Note(id: 'n1', paperId: 'p1', text: 'o', createdAt: t, updatedAt: t);
      final u = n.copyWith(text: 'new');
      expect(u.text, 'new');
      expect(u.id, 'n1');
      expect(u.updatedAt.isAfter(t), true);
    });
  });

  group('MemoryItem', () {
    test('defaults', () {
      final t = DateTime(2024, 1, 1);
      final m = MemoryItem(id: 'm1', summary: 's', paperId: 'p1', timestamp: t);
      expect(m.paperId, 'p1');
    });

    test('null paperId', () {
      final m = MemoryItem(id: 'm1', summary: 's', timestamp: DateTime.now());
      expect(m.paperId, isNull);
    });

    test('toJson fromJson round-trip', () {
      final t = DateTime(2024, 6, 1, 12, 0, 0);
      final m = MemoryItem(id: 'm1', summary: 's', paperId: 'p1', timestamp: t);
      final r = MemoryItem.fromJson(m.toJson());
      expect(r.id, 'm1');
      expect(r.summary, 's');
      expect(r.timestamp.toIso8601String(), t.toIso8601String());
    });

    test('fromJson missing fields', () {
      final r = MemoryItem.fromJson({'id': 'm1', 'summary': 's'});
      expect(r.paperId, isNull);
      expect(r.timestamp, isA<DateTime>());
    });

    test('fromJson invalid timestamp', () {
      final r = MemoryItem.fromJson({'id': 'm1', 'summary': 's', 'timestamp': 'bad'});
      expect(r.timestamp, isA<DateTime>());
    });

    test('fromJson empty summary', () {
      final r = MemoryItem.fromJson({'id': 'm1', 'summary': ''});
      expect(r.summary, '');
    });
  });
}
